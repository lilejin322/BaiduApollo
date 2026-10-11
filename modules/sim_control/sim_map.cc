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

#include <boost/thread/locks.hpp>
#include <boost/thread/shared_mutex.hpp>

#include "cyber/common/log.h"
#include "modules/map/hdmap/hdmap_util.h"

namespace apollo {
namespace dreamview {

using apollo::common::PointENU;
using apollo::hdmap::ClearAreaInfoConstPtr;
using apollo::hdmap::CrosswalkInfoConstPtr;
using apollo::hdmap::HDMapUtil;
using apollo::hdmap::JunctionInfoConstPtr;
using apollo::hdmap::LaneInfoConstPtr;
using apollo::hdmap::ParkingSpaceInfoConstPtr;
using apollo::hdmap::PNCJunctionInfoConstPtr;
using apollo::hdmap::SignalInfoConstPtr;
using apollo::hdmap::SpeedBumpInfoConstPtr;
using apollo::hdmap::StopSignInfoConstPtr;
using apollo::hdmap::YieldSignInfoConstPtr;

namespace {

// Same element set as MapService::CollectMapElementIds. A query failure is
// logged and does not by itself make the point invalid.
template <typename InfoPtr>
bool HasSimMapElements(const apollo::hdmap::HDMap* map, const PointENU& point,
                       double radius, const char* element_name,
                       int (apollo::hdmap::HDMap::*query)(
                           const PointENU&, double, std::vector<InfoPtr>*)
                           const) {
  std::vector<InfoPtr> elements;
  if ((map->*query)(point, radius, &elements) != 0) {
    AERROR << "Fail to get " << element_name << " from sim_map.";
  }
  return !elements.empty();
}

boost::shared_mutex& MapMutex() {
  static boost::shared_mutex mutex;
  return mutex;
}

}  // namespace

bool SimMap::ReloadMaps() {
  boost::unique_lock<boost::shared_mutex> lock(MapMutex());
  return HDMapUtil::ReloadMaps();
}

bool SimMap::PointIsValid(const double x, const double y) const {
  boost::shared_lock<boost::shared_mutex> lock(MapMutex());
  // MapService::MapReady requires both the base map and the sim map.
  if (HDMapUtil::BaseMapPtr() == nullptr || HDMapUtil::SimMapPtr() == nullptr) {
    return false;
  }
  const auto* map = HDMapUtil::SimMapPtr();
  PointENU point;
  point.set_x(x);
  point.set_y(y);
  constexpr double kRadius = 20.0;
  return HasSimMapElements<LaneInfoConstPtr>(map, point, kRadius, "lanes",
                                             &apollo::hdmap::HDMap::GetLanes) ||
         HasSimMapElements<ClearAreaInfoConstPtr>(
             map, point, kRadius, "clear areas",
             &apollo::hdmap::HDMap::GetClearAreas) ||
         HasSimMapElements<CrosswalkInfoConstPtr>(
             map, point, kRadius, "crosswalks",
             &apollo::hdmap::HDMap::GetCrosswalks) ||
         HasSimMapElements<JunctionInfoConstPtr>(
             map, point, kRadius, "junctions",
             &apollo::hdmap::HDMap::GetJunctions) ||
         HasSimMapElements<PNCJunctionInfoConstPtr>(
             map, point, kRadius, "pnc junctions",
             &apollo::hdmap::HDMap::GetPNCJunctions) ||
         HasSimMapElements<ParkingSpaceInfoConstPtr>(
             map, point, kRadius, "parking spaces",
             &apollo::hdmap::HDMap::GetParkingSpaces) ||
         HasSimMapElements<SpeedBumpInfoConstPtr>(
             map, point, kRadius, "speed bumps",
             &apollo::hdmap::HDMap::GetSpeedBumps) ||
         HasSimMapElements<SignalInfoConstPtr>(
             map, point, kRadius, "signals",
             &apollo::hdmap::HDMap::GetSignals) ||
         HasSimMapElements<StopSignInfoConstPtr>(
             map, point, kRadius, "stop signs",
             &apollo::hdmap::HDMap::GetStopSigns) ||
         HasSimMapElements<YieldSignInfoConstPtr>(
             map, point, kRadius, "yield signs",
             &apollo::hdmap::HDMap::GetYieldSigns);
}

bool SimMap::GetPoseWithRegardToLane(const double x, const double y,
                                     double* theta, double* s) const {
  boost::shared_lock<boost::shared_mutex> lock(MapMutex());
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
  boost::shared_lock<boost::shared_mutex> lock(MapMutex());
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
