/******************************************************************************
 * Copyright 2018 The Apollo Authors. All Rights Reserved.
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

#include <cstddef>
#include <cstdint>

namespace apollo {
namespace bridge {

#define _1K 1024

#define FREE_ARRY(arry) \
  if (arry) {           \
    delete[] arry;      \
  }                     \
  arry = nullptr

#define FREE_POINTER(p) \
  if (p) {              \
    delete p;           \
  }                     \
  p = nullptr

// Frame size Apollo's own sender uses.
constexpr uint32_t FRAME_SIZE = 1024;
// Largest datagram a receiver takes. The frame size is in each frame's header,
// so a sender may use larger frames (up to ~64KB): a multi-MB message (point
// cloud, image) then needs ~100 datagrams instead of thousands.
constexpr uint32_t MAX_DATAGRAM_SIZE = 65536;
// Largest message a receiver reassembles.
constexpr uint32_t MAX_MSG_SIZE = 64 * 1024 * 1024;
// Incomplete messages a receiver keeps; one that lost a frame never completes
// and is dropped once newer ones push it out.
constexpr size_t MAX_PENDING_MSGS = 4;
}  // namespace bridge
}  // namespace apollo
