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

#include "modules/sim_control/common/sim_control_gflags.h"

DEFINE_string(sim_control_module_name, "sim_control", "Module name");

DEFINE_string(sim_perfect_control, "Simulation Perfect Control",
              "Default perfect-control dynamic model name.");

DEFINE_string(resource_dynamic_model_path,
              "/.apollo/resources/dynamic_models/models/",
              "Dynamic model package placement, relative to $HOME.");

DEFINE_string(dynamic_model_library_path,
              "/.apollo/resources/dynamic_models/library/",
              "Dynamic model library placement, relative to $HOME.");

DEFINE_string(dynamic_model_package_library_path,
              "/opt/apollo/neo/lib/modules/dynamic_model/",
              "Installed dynamic model package library path.");

DEFINE_string(sim_obstacle_stop_command, "pkill -9 -f \"sim_obstacle\" ",
              "Command used to stop sim_obstacle when sim control stops.");

DEFINE_string(dynamic_model_name, "perfect_control",
              "the name for the selected model");

DEFINE_string(calibration_conf_file,
              "sim_control_lincoln.pb.txt",
              "the name for the selected model");

DEFINE_string(fnn_model_path, "sim_control/conf/fnn_model.bin",
              "fnn model file path");

DEFINE_string(backward_fnn_model_path,
              "sim_control/conf/fnn_model_backward.bin",
              "fnn model file path for reverse driving");

DEFINE_string(echo_lincoln_conf_file,
              "sim_control/conf/echo_lincoln_conf.pb.txt",
              "echo lincoln conf file path");

DEFINE_int32(reader_pending_queue_size, 10, "Cyber Reader pending queue size.");

// echosim model
DEFINE_string(echosim_license_file, "sim_control/conf/echosim.lic",
              "echo lincoln license file");
DEFINE_string(echosim_parameters_file, "sim_control/conf/echosim_lincoln.par",
              "echo lincoln vehicle parameter file");
DEFINE_double(echosim_simulation_step, 0.001, "echosim simulation step");
// DEFINE_double(dynamics_echosim_friction_coefficient, 0.85,
//               "ground friction coefficient");

DEFINE_bool(echo_lincoln_switch_model, false,
            "switch to point mass model at forward low speed");

DEFINE_bool(enable_steering_latency, false, "add steering latecy to control");

DEFINE_bool(enable_backward_fnn_model, true,
            "switch to add backward fnn model");

DEFINE_bool(enable_sim_at_nonauto_mode, true,
            "enable the simulation even before starting auto");

// cascade model
DEFINE_string(torch_gp_model_file,
              "sim_control/conf/LiteTrans-20201023-1043/gp_model.pt",
              "Gaussian process regression model file");

DEFINE_bool(use_cuda_in_cascade_model, false, "use CUDA for torch.");

DEFINE_string(
    cascade_model_conf_file,
    "sim_control/conf/LiteTrans-20201023-1043/standardization_factors.bin",
    "cascade model conf file path");
