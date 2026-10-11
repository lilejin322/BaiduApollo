/******************************************************************************
 * Copyright 2026 The Apollo Authors. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *****************************************************************************/

#include "modules/sim_control/sim_control_component.h"

#include <unistd.h>

#include <chrono>
#include <string>

#include "gflags/gflags.h"
#include "nlohmann/json.hpp"

#include "modules/common/configs/config_gflags.h"
#include "modules/sim_control/core/dynamic_model_factory.h"
#include "modules/sim_control/sim_control_channel.h"
#include "modules/sim_control/sim_control_manager.h"
#include "modules/sim_control/sim_map.h"

namespace apollo {
namespace sim_control {

using apollo::dreamview::DynamicModelFactory;
using apollo::dreamview::SimControlManager;

namespace {

bool CommandUsesMap(SimControlCommandType command) {
  switch (command) {
    case RESTART:
    case SET_POSITION:
    case CHANGE_DYNAMIC_MODEL:
      return true;
    default:
      return false;
  }
}

// Loads a caller-supplied map without leaving FLAGS_map_dir or the HD map
// pointer on the failed directory. Stop and status commands do not come here.
bool PrepareMap(const SimControlCommand& request, std::string* error) {
  if (!CommandUsesMap(request.command())) {
    return true;
  }
  const bool map_dir_changed = request.has_map_dir() &&
                               !request.map_dir().empty() &&
                               request.map_dir() != FLAGS_map_dir;
  const bool reload = request.command() == RESTART || map_dir_changed;
  if (!reload) {
    return true;
  }
  const std::string previous = FLAGS_map_dir;
  if (map_dir_changed) {
    FLAGS_map_dir = request.map_dir();
  }
  if (apollo::dreamview::SimMap::ReloadMaps()) {
    return true;
  }
  *error = "Failed to reload map from " + FLAGS_map_dir;
  AERROR << *error;
  if (FLAGS_map_dir != previous) {
    FLAGS_map_dir = previous;
    if (!apollo::dreamview::SimMap::ReloadMaps()) {
      AERROR << "Failed to restore the previous map from " << previous;
    }
  }
  return false;
}

bool IsLiveSharedFlag(const std::string& name) {
  // Read on each localization publish, so it can change after the model exists.
  return name == "use_navigation_mode";
}

// Restores the flags Dreamview and sim_control used to share in one process.
void ApplySharedFlags(const SimControlCommand& request, std::string* note) {
  const bool channels_bound = DynamicModelFactory::IsConstructed();
  std::string mismatched;
  for (const auto& item : request.shared_flag()) {
    const auto eq = item.find('=');
    if (eq == std::string::npos || eq == 0) {
      continue;
    }
    const std::string name = item.substr(0, eq);
    const std::string value = item.substr(eq + 1);
    std::string current;
    if (!google::GetCommandLineOption(name.c_str(), &current) ||
        current == value) {
      continue;
    }
    if (channels_bound && !IsLiveSharedFlag(name)) {
      if (!mismatched.empty()) {
        mismatched += ", ";
      }
      mismatched += name;
      continue;
    }
    if (google::SetCommandLineOption(name.c_str(), value.c_str()).empty()) {
      AWARN << "Rejected shared sim_control flag " << name;
      continue;
    }
    AINFO << "Applied shared sim_control flag " << name << "=" << value;
  }
  if (!mismatched.empty()) {
    *note = "sim_control already bound different channels: " + mismatched;
    AWARN << *note;
  }
}

void FillStatus(SimControlCommandResult* response, SimControlManager* manager,
                uint64_t instance_id, const std::string& note) {
  if (!note.empty()) {
    if (response->message().empty()) {
      response->set_message(note);
    } else {
      response->set_message(response->message() + " " + note);
    }
  }
  response->set_enabled(manager->IsEnabled());
  response->set_current_dynamic_model(manager->CurrentDynamicModel());
  response->set_model_running(manager->HasModel());
  response->set_instance_id(instance_id);
  response->set_use_navigation_mode(FLAGS_use_navigation_mode);
}

}  // namespace

bool SimControlComponent::Init() {
  instance_id_ =
      (static_cast<uint64_t>(::getpid()) << 32) ^
      static_cast<uint64_t>(
          std::chrono::steady_clock::now().time_since_epoch().count());
  // The process being up starts the manager. A later STOP command can disable
  // it without exiting, and the client's Start() sends START to turn it back
  // on. Selecting a dynamic model is a later command.
  SimControlManager::Instance()->Start();
  command_service_ =
      node_->CreateService<SimControlCommand, SimControlCommandResult>(
          kSimControlCommandService,
          [this](const std::shared_ptr<SimControlCommand>& request,
                 std::shared_ptr<SimControlCommandResult>& response) {
            OnCommand(request, response);
          });
  if (command_service_ == nullptr) {
    AERROR << "Failed to create " << kSimControlCommandService;
    return false;
  }
  AINFO << "sim_control command service ready: " << kSimControlCommandService;
  return true;
}

void SimControlComponent::Clear() {
  std::lock_guard<std::mutex> lock(mutex_);
  SimControlManager::Instance()->Stop();
}

void SimControlComponent::OnCommand(
    const std::shared_ptr<SimControlCommand>& request,
    std::shared_ptr<SimControlCommandResult>& response) {
  std::lock_guard<std::mutex> lock(mutex_);
  auto* manager = SimControlManager::Instance();
  response->set_success(false);
  std::string note;
  ApplySharedFlags(*request, &note);

  std::string map_error;
  if (!PrepareMap(*request, &map_error)) {
    response->set_message(map_error);
    FillStatus(response.get(), manager, instance_id_, note);
    return;
  }

  switch (request->command()) {
    case START:
      manager->Start();
      response->set_success(true);
      break;
    case STOP:
      manager->Stop();
      response->set_success(true);
      break;
    case RESET:
      response->set_success(manager->Reset());
      if (!response->success()) {
        response->set_message(
            "Sim control has no active model, so reset was not applied.");
      }
      break;
    case RESTART:
      if (request->has_pose()) {
        response->set_success(manager->Restart(request->x(), request->y()));
      } else {
        response->set_success(manager->Restart());
      }
      if (!response->success()) {
        response->set_message(
            "Sim control has no active model, so restart was not applied.");
      }
      break;
    case SET_POSITION:
      response->set_success(manager->ReSetPoinstion(
          request->x(), request->y(), request->heading()));
      if (!response->success()) {
        response->set_message(
            "Sim control has no active model, so the position was not "
            "applied.");
      }
      break;
    case LOAD_DYNAMIC_MODELS: {
      const nlohmann::json loaded = manager->LoadDynamicModels();
      response->set_success(loaded.value("result", false));
      if (loaded.contains("loaded_dynamic_models")) {
        for (const auto& model : loaded["loaded_dynamic_models"]) {
          response->add_loaded_dynamic_models(model.get<std::string>());
        }
      }
      break;
    }
    case ADD_DYNAMIC_MODEL:
      response->set_success(
          manager->AddDynamicModel(request->dynamic_model_name()));
      break;
    case CHANGE_DYNAMIC_MODEL:
      if (!manager->IsEnabled()) {
        response->set_success(false);
        response->set_message(
            "Sim control is not enabled, so the dynamic model was not "
            "started.");
        break;
      }
      response->set_success(
          manager->ChangeDynamicModel(request->dynamic_model_name()));
      if (!response->success()) {
        response->set_message("Failed to change dynamic model.");
      }
      break;
    case DELETE_DYNAMIC_MODEL:
      response->set_success(
          manager->DeleteDynamicModel(request->dynamic_model_name()));
      break;
    case IS_ENABLED:
      response->set_success(true);
      break;
    default:
      response->set_success(false);
      response->set_message("Unknown sim_control command.");
      break;
  }
  FillStatus(response.get(), manager, instance_id_, note);
}

}  // namespace sim_control
}  // namespace apollo
