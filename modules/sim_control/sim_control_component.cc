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

#include "nlohmann/json.hpp"

#include "modules/common/configs/config_gflags.h"
#include "modules/map/hdmap/hdmap_util.h"
#include "modules/sim_control/sim_control_channel.h"
#include "modules/sim_control/sim_control_manager.h"

namespace apollo {
namespace sim_control {

using apollo::dreamview::SimControlManager;

bool SimControlComponent::Init() {
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
  // The process being up is the switch. HMI starts and stops that process
  // with a shell command; later commands arrive on this service.
  SimControlManager::Instance()->Start();
  AINFO << "sim_control command service ready: " << kSimControlCommandService;
  return true;
}

void SimControlComponent::OnCommand(
    const std::shared_ptr<SimControlCommand>& request,
    std::shared_ptr<SimControlCommandResult>& response) {
  std::lock_guard<std::mutex> lock(mutex_);
  bool reload_map = request->command() == RESTART;
  if (request->has_map_dir() && !request->map_dir().empty() &&
      request->map_dir() != FLAGS_map_dir) {
    FLAGS_map_dir = request->map_dir();
    reload_map = true;
  }
  if (reload_map && !apollo::hdmap::HDMapUtil::ReloadMaps()) {
    AERROR << "Failed to reload map from " << FLAGS_map_dir;
  }

  auto* manager = SimControlManager::Instance();
  response->set_success(true);
  switch (request->command()) {
    case START:
      manager->Start();
      break;
    case STOP:
      manager->Stop();
      break;
    case RESET:
      manager->Reset();
      break;
    case RESTART:
      if (request->has_pose()) {
        manager->Restart(request->x(), request->y());
      } else {
        manager->Restart();
      }
      break;
    case SET_POSITION:
      manager->ReSetPoinstion(request->x(), request->y(), request->heading());
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
      response->set_success(
          manager->ChangeDynamicModel(request->dynamic_model_name()));
      break;
    case DELETE_DYNAMIC_MODEL:
      response->set_success(
          manager->DeleteDynamicModel(request->dynamic_model_name()));
      break;
    case IS_ENABLED:
      break;
    default:
      response->set_success(false);
      response->set_message("Unknown sim_control command.");
      break;
  }
  response->set_enabled(manager->IsEnabled());
}

}  // namespace sim_control
}  // namespace apollo
