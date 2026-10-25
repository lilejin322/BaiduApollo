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

#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

#include <atomic>
#include <thread>

#include "cyber/common/log.h"
#include "modules/bridge/common/bridge_gflags.h"

namespace apollo {
namespace bridge {

// epoll size of the standalone test tools (test/bridge_receiver_test.cc)
constexpr int MAXEPOLLSIZE = 100;

// Receives one UDP port on a thread of its own: the thread calls the
// receiver's handler, which reads one datagram (blocking recvfrom), over and
// over, so every datagram is read in arrival order. The socket has a large
// receive buffer, as a multi-MB message arrives as a burst of frames, and a
// receive timeout so Stop() can end the thread.
template <typename T>
class UDPListener {
 public:
  typedef bool (T::*func)(int fd);
  UDPListener() {}
  UDPListener(T *receiver, uint16_t port, func msg_handle) {
    receiver_ = receiver;
    listened_port_ = port;
    msg_handle_ = msg_handle;
  }
  ~UDPListener() { Stop(); }

  void SetMsgHandle(func msg_handle) { msg_handle_ = msg_handle; }
  bool Initialize(T *receiver, func msg_handle, uint16_t port);
  // Starts the receive thread and returns.
  bool Listen();
  // Stops the receive thread; call it before the receiver goes away.
  void Stop();

 private:
  T *receiver_ = nullptr;
  uint16_t listened_port_ = 0;
  int listener_sock_ = -1;
  func msg_handle_ = nullptr;
  std::atomic<bool> running_{false};
  std::thread thread_;
};

template <typename T>
bool UDPListener<T>::Initialize(T *receiver, func msg_handle, uint16_t port) {
  msg_handle_ = msg_handle;
  if (!msg_handle_) {
    return false;
  }
  receiver_ = receiver;
  if (!receiver_) {
    return false;
  }
  listened_port_ = port;
  listener_sock_ = socket(AF_INET, SOCK_DGRAM, 0);
  if (listener_sock_ == -1) {
    return false;
  }
  int opt = 1;
  setsockopt(listener_sock_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
  int rcvbuf = FLAGS_bridge_udp_rcvbuf_mb * 1024 * 1024;
  setsockopt(listener_sock_, SOL_SOCKET, SO_RCVBUF, &rcvbuf, sizeof(rcvbuf));
  int actual = 0;
  socklen_t len = sizeof(actual);
  getsockopt(listener_sock_, SOL_SOCKET, SO_RCVBUF, &actual, &len);
  AINFO << "UDP bridge port " << listened_port_ << " receive buffer "
        << actual / 1024 << " KB";
  struct timeval timeout = {0, 200 * 1000};
  setsockopt(listener_sock_, SOL_SOCKET, SO_RCVTIMEO, &timeout,
             sizeof(timeout));

  struct sockaddr_in serv_addr;
  serv_addr.sin_family = PF_INET;
  serv_addr.sin_port = htons((uint16_t)listened_port_);
  serv_addr.sin_addr.s_addr = INADDR_ANY;
  if (bind(listener_sock_, (struct sockaddr *)&serv_addr,
           sizeof(struct sockaddr)) == -1) {
    AERROR << "UDP bridge cannot bind port " << listened_port_;
    close(listener_sock_);
    listener_sock_ = -1;
    return false;
  }
  return true;
}

template <typename T>
bool UDPListener<T>::Listen() {
  if (listener_sock_ == -1 || running_.exchange(true)) {
    return listener_sock_ != -1;
  }
  thread_ = std::thread([this]() {
    while (running_) {
      // false on a receive timeout, a bad datagram or an incomplete message
      (receiver_->*msg_handle_)(listener_sock_);
    }
  });
  return true;
}

template <typename T>
void UDPListener<T>::Stop() {
  running_ = false;
  if (thread_.joinable()) {
    thread_.join();
  }
  if (listener_sock_ != -1) {
    close(listener_sock_);
    listener_sock_ = -1;
  }
}

}  // namespace bridge
}  // namespace apollo
