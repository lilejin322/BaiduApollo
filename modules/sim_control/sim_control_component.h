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
#include <mutex>

#include "cyber/component/component.h"
#include "modules/sim_control/proto/sim_control_command.pb.h"

namespace apollo {
namespace sim_control {

class SimControlComponent final : public apollo::cyber::Component<> {
 public:
  bool Init() override;
  // Runs on process shutdown: stops the dynamic model and sim_obstacle, as
  // SimControlManager::Stop did when Dreamview turned sim control off.
  void Clear() override;

 private:
  void OnCommand(const std::shared_ptr<SimControlCommand>& request,
                 std::shared_ptr<SimControlCommandResult>& response);

  std::shared_ptr<
      apollo::cyber::Service<SimControlCommand, SimControlCommandResult>>
      command_service_;
  std::mutex mutex_;
  // Identifies this process so Dreamview can tell a restart from a live one.
  uint64_t instance_id_ = 0;
};

CYBER_REGISTER_COMPONENT(SimControlComponent)

}  // namespace sim_control
}  // namespace apollo
