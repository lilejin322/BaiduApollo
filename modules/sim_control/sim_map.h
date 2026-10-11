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

#include "modules/common_msgs/basic_msgs/geometry.pb.h"

namespace apollo {
namespace dreamview {

// Map queries sim control needs. This replaces Dreamview's MapService so the
// module does not link the Dreamview backend. PointIsValid follows
// MapService: any sim-map element within 20 meters counts.
class SimMap {
 public:
  bool PointIsValid(double x, double y) const;

  bool GetPoseWithRegardToLane(double x, double y, double* theta,
                               double* s) const;

  bool GetStartPoint(apollo::common::PointENU* start_point) const;

  // Reloads the process-wide HD map. Shares one lock with every query so a
  // reader cannot use a map object while it is being replaced.
  static bool ReloadMaps();
};

}  // namespace dreamview
}  // namespace apollo
