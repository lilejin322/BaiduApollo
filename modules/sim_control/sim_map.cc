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

#include "modules/sim_control/sim_map.h"

#include <vector>

#include "cyber/common/log.h"
#include "modules/map/hdmap/hdmap_util.h"

namespace apollo {
namespace dreamview {

using apollo::common::PointENU;
using apollo::hdmap::HDMapUtil;
using apollo::hdmap::LaneInfoConstPtr;

bool SimMap::PointIsValid(const double x, const double y) const {
  const auto* map = HDMapUtil::BaseMapPtr();
  if (map == nullptr) {
    return false;
  }
  PointENU point;
  point.set_x(x);
  point.set_y(y);
  std::vector<LaneInfoConstPtr> lanes;
  if (map->GetLanes(point, 20.0, &lanes) != 0) {
    return false;
  }
  return !lanes.empty();
}

bool SimMap::GetPoseWithRegardToLane(const double x, const double y,
                                     double* theta, double* s) const {
  const auto* map = HDMapUtil::BaseMapPtr();
  if (map == nullptr) {
    return false;
  }
  PointENU point;
  point.set_x(x);
  point.set_y(y);
  LaneInfoConstPtr nearest_lane;
  double nearest_l = 0.0;
  if (map->GetNearestLane(point, &nearest_lane, s, &nearest_l) < 0 ||
      nearest_lane == nullptr) {
    AERROR << "Failed to get nearest lane!";
    return false;
  }
  *theta = nearest_lane->Heading(*s);
  return true;
}

bool SimMap::GetStartPoint(apollo::common::PointENU* start_point) const {
  const auto* map = HDMapUtil::BaseMapPtr();
  if (map == nullptr) {
    return false;
  }
  PointENU origin;
  origin.set_x(0.0);
  origin.set_y(0.0);
  LaneInfoConstPtr lane;
  double s = 0.0;
  double l = 0.0;
  if (map->GetNearestLane(origin, &lane, &s, &l) < 0 || lane == nullptr) {
    AERROR << "Failed to get nearest lane!";
    return false;
  }
  *start_point = lane->GetSmoothPoint(0.0);
  return true;
}

}  // namespace dreamview
}  // namespace apollo
