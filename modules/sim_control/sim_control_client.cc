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

#include "modules/sim_control/sim_control_client.h"

#include <chrono>
#include <cstdlib>
#include <string>

#include "modules/common/configs/config_gflags.h"
#include "modules/sim_control/sim_control_channel.h"

namespace apollo {
namespace sim_control {

namespace {
constexpr std::chrono::seconds kCommandTimeout(15);
constexpr char kStartCommand[] =
    "bash /apollo/scripts/sim_control.sh start >/dev/null 2>&1";
constexpr char kStopCommand[] =
    "bash /apollo/scripts/sim_control.sh stop >/dev/null 2>&1";
}  // namespace

SimControlClient::SimControlClient() {
  node_ = apollo::cyber::CreateNode("sim_control_client");
  client_ = node_->CreateClient<SimControlCommand, SimControlCommandResult>(
      kSimControlCommandService);
}

std::shared_ptr<SimControlCommandResult> SimControlClient::Call(
    const SimControlCommand& command) {
  if (client_ == nullptr) {
    AERROR << "sim_control client was not created.";
    return nullptr;
  }
  auto request = std::make_shared<SimControlCommand>(command);
  if (!request->has_map_dir() && !FLAGS_map_dir.empty()) {
    request->set_map_dir(FLAGS_map_dir);
  }
  auto response = client_->SendRequest(request, kCommandTimeout);
  if (response == nullptr) {
    AERROR << "sim_control is not running. Start it with "
              "`cyber_launch start modules/sim_control/launch/sim_control.launch`.";
  }
  return response;
}

bool SimControlClient::IsEnabled() {
  if (client_ == nullptr ||
      !client_->WaitForService(std::chrono::milliseconds(200))) {
    return false;
  }
  SimControlCommand command;
  command.set_command(IS_ENABLED);
  auto request = std::make_shared<SimControlCommand>(command);
  auto response = client_->SendRequest(request, std::chrono::seconds(2));
  return response != nullptr && response->enabled();
}

nlohmann::json SimControlClient::LoadDynamicModels() {
  nlohmann::json result;
  result["result"] = false;
  result["loaded_dynamic_models"] = nlohmann::json::array();
  SimControlCommand command;
  command.set_command(LOAD_DYNAMIC_MODELS);
  auto response = Call(command);
  if (response == nullptr) {
    return result;
  }
  result["result"] = response->success();
  for (const auto& model : response->loaded_dynamic_models()) {
    result["loaded_dynamic_models"].push_back(model);
  }
  return result;
}

bool SimControlClient::AddDynamicModel(const std::string& dynamic_model_name) {
  SimControlCommand command;
  command.set_command(ADD_DYNAMIC_MODEL);
  command.set_dynamic_model_name(dynamic_model_name);
  auto response = Call(command);
  return response != nullptr && response->success();
}

bool SimControlClient::ChangeDynamicModel(
    const std::string& dynamic_model_name) {
  SimControlCommand command;
  command.set_command(CHANGE_DYNAMIC_MODEL);
  command.set_dynamic_model_name(dynamic_model_name);
  auto response = Call(command);
  return response != nullptr && response->success();
}

bool SimControlClient::DeleteDynamicModel(
    const std::string& dynamic_model_name) {
  SimControlCommand command;
  command.set_command(DELETE_DYNAMIC_MODEL);
  command.set_dynamic_model_name(dynamic_model_name);
  auto response = Call(command);
  return response != nullptr && response->success();
}

void SimControlClient::Restart(double x, double y) {
  SimControlCommand command;
  command.set_command(RESTART);
  command.set_has_pose(true);
  command.set_x(x);
  command.set_y(y);
  Call(command);
}

void SimControlClient::ReSetPoinstion(double x, double y, double heading) {
  SimControlCommand command;
  command.set_command(SET_POSITION);
  command.set_has_pose(true);
  command.set_x(x);
  command.set_y(y);
  command.set_heading(heading);
  Call(command);
}

void SimControlClient::Restart() {
  SimControlCommand command;
  command.set_command(RESTART);
  Call(command);
}

void SimControlClient::Reset() {
  SimControlCommand command;
  command.set_command(RESET);
  Call(command);
}

void SimControlClient::Start() {
  if (client_ != nullptr &&
      client_->WaitForService(std::chrono::milliseconds(200))) {
    AINFO << "sim_control is already running.";
    return;
  }
  AINFO << "Starting sim_control with: " << kStartCommand;
  std::system(kStartCommand);
  if (client_ == nullptr ||
      !client_->WaitForService(std::chrono::seconds(30))) {
    AERROR << "sim_control did not register " << kSimControlCommandService;
  }
}

void SimControlClient::Stop() {
  AINFO << "Stopping sim_control with: " << kStopCommand;
  std::system(kStopCommand);
}

}  // namespace sim_control
}  // namespace apollo
