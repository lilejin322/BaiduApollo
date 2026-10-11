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

#pragma once

#include <cstdint>
#include <memory>
#include <string>

#include "nlohmann/json.hpp"

#include "cyber/common/macros.h"
#include "cyber/cyber.h"
#include "modules/sim_control/proto/sim_control_command.pb.h"

namespace apollo {
namespace sim_control {

struct SimControlServiceStatus {
  bool reachable = false;
  bool enabled = false;
  bool model_running = false;
  uint64_t instance_id = 0;
  std::string current_dynamic_model;
};

// Copies the gflags that must match across the Dreamview and sim_control
// processes onto a command. Defined with the client because both Dreamview
// and scripts/sim_control_model.sh send commands.
void CopySharedRuntimeFlags(SimControlCommand* command);

// Talks to the sim_control process. Dreamview and Dreamview Plus use this
// instead of the in-process SimControlManager singleton.
class SimControlClient {
 public:
  bool IsEnabled();
  SimControlServiceStatus QueryStatus();
  nlohmann::json LoadDynamicModels();
  bool AddDynamicModel(const std::string& dynamic_model_name);
  bool ChangeDynamicModel(const std::string& dynamic_model_name);
  bool DeleteDynamicModel(const std::string& dynamic_model_name);
  bool Restart(double x, double y);
  bool ReSetPoinstion(double x, double y, double heading);
  bool Restart();
  bool Reset();
  void Start();
  void Stop();

 private:
  std::shared_ptr<SimControlCommandResult> Call(
      const SimControlCommand& command);

  std::shared_ptr<apollo::cyber::Node> node_;
  std::shared_ptr<
      apollo::cyber::Client<SimControlCommand, SimControlCommandResult>>
      client_;

  DECLARE_SINGLETON(SimControlClient)
};

}  // namespace sim_control
}  // namespace apollo
