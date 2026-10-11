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

#include <chrono>
#include <iostream>
#include <memory>
#include <string>

#include "cyber/cyber.h"
#include "modules/common/configs/config_gflags.h"
#include "modules/sim_control/common/sim_control_gflags.h"
#include "modules/sim_control/proto/sim_control_command.pb.h"
#include "modules/sim_control/sim_control_channel.h"

namespace {

constexpr std::chrono::seconds kServiceWait(30);
constexpr std::chrono::seconds kCommandTimeout(15);

std::shared_ptr<apollo::sim_control::SimControlCommandResult> Send(
    const std::shared_ptr<apollo::cyber::Client<
        apollo::sim_control::SimControlCommand,
        apollo::sim_control::SimControlCommandResult>>& client,
    apollo::sim_control::SimControlCommandType type,
    const std::string& model_name) {
  auto request = std::make_shared<apollo::sim_control::SimControlCommand>();
  request->set_command(type);
  if (!model_name.empty()) {
    request->set_dynamic_model_name(model_name);
  }
  if (!FLAGS_map_dir.empty()) {
    request->set_map_dir(FLAGS_map_dir);
  }
  return client->SendRequest(request, kCommandTimeout);
}

}  // namespace

int main(int argc, char* argv[]) {
  google::ParseCommandLineFlags(&argc, &argv, true);
  apollo::cyber::Init(argv[0]);

  const std::string model =
      argc > 1 ? argv[1] : FLAGS_sim_perfect_control;

  auto node = apollo::cyber::CreateNode("sim_control_command");
  auto client =
      node->CreateClient<apollo::sim_control::SimControlCommand,
                         apollo::sim_control::SimControlCommandResult>(
          apollo::sim_control::kSimControlCommandService);
  if (client == nullptr || !client->WaitForService(kServiceWait)) {
    std::cerr << "sim_control is not running. Start it with "
                 "scripts/sim_control.sh start" << std::endl;
    apollo::cyber::Clear();
    return 1;
  }

  // Same two requests the Dreamview sim-control switch sends after startup.
  Send(client, apollo::sim_control::LOAD_DYNAMIC_MODELS, "");
  auto response =
      Send(client, apollo::sim_control::CHANGE_DYNAMIC_MODEL, model);
  const bool ok = response != nullptr && response->success();
  if (!ok) {
    std::cerr << "Failed to select dynamic model: " << model << std::endl;
  } else {
    std::cout << "Selected dynamic model: " << model << std::endl;
  }
  apollo::cyber::Clear();
  return ok ? 0 : 1;
}
