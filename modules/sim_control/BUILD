load("//tools:apollo_package.bzl", "apollo_cc_binary", "apollo_cc_library", "apollo_cc_test", "apollo_component", "apollo_package")
load("//tools:cpplint.bzl", "cpplint")

package(default_visibility = ["//visibility:public"])

SIM_CONTROL_COPTS = ['-DMODULE_NAME=\\"sim_control\\"']

apollo_cc_library(
    name = "sim_control_gflags",
    srcs = ["common/sim_control_gflags.cc"],
    hdrs = ["common/sim_control_gflags.h"],
    copts = SIM_CONTROL_COPTS,
    deps = [
        "@com_github_gflags_gflags//:gflags",
    ],
)

apollo_cc_library(
    name = "sim_control_client",
    srcs = ["sim_control_client.cc"],
    hdrs = [
        "sim_control_channel.h",
        "sim_control_client.h",
    ],
    copts = SIM_CONTROL_COPTS,
    deps = [
        ":sim_control_gflags",
        "//cyber",
        "//modules/common/adapters:adapter_gflags",
        "//modules/common/configs:config_gflags",
        "//modules/sim_control/proto:sim_control_command_cc_proto",
        "@com_github_nlohmann_json//:json",
    ],
)

apollo_cc_library(
    name = "sim_control",
    srcs = [
        "common/interpolation_2d.cc",
        "common/sim_control_util.cc",
        "core/dynamic_model_factory.cc",
        "core/sim_control_base.cc",
        "core/sim_control_with_model_base.cc",
        "dynamic_model/perfect_control/sim_perfect_control.cc",
        "sim_control_manager.cc",
        "sim_map.cc",
    ],
    hdrs = [
        "common/interpolation_2d.h",
        "common/sim_control_util.h",
        "core/dynamic_model_factory.h",
        "core/sim_control_base.h",
        "core/sim_control_with_model_base.h",
        "dynamic_model/perfect_control/sim_perfect_control.h",
        "sim_control_manager.h",
        "sim_map.h",
    ],
    copts = SIM_CONTROL_COPTS,
    deps = [
        ":sim_control_gflags",
        "//cyber",
        "//modules/common/adapters:adapter_gflags",
        "//modules/common/configs:config_gflags",
        "//modules/common/configs:vehicle_config_helper",
        "//modules/common/math",
        "//modules/common/util:common_util",
        "//modules/common/util:message_util",
        "//modules/common/util:util_tool",
        "//modules/common_msgs/basic_msgs:geometry_cc_proto",
        "//modules/common_msgs/chassis_msgs:chassis_cc_proto",
        "//modules/common_msgs/control_msgs:control_cmd_cc_proto",
        "//modules/common_msgs/localization_msgs:localization_cc_proto",
        "//modules/common_msgs/planning_msgs:planning_cc_proto",
        "//modules/common_msgs/planning_msgs:planning_command_cc_proto",
        "//modules/common_msgs/planning_msgs:navigation_cc_proto",
        "//modules/common_msgs/prediction_msgs:prediction_obstacle_cc_proto",
        "//modules/common_msgs/routing_msgs:routing_cc_proto",
        "//modules/map:apollo_map",
        "//modules/sim_control/proto:dynamic_model_conf_cc_proto",
        "@boost",
        "//modules/sim_control/proto:sim_control_internal_cc_proto",
        "@com_github_nlohmann_json//:json",
        "@eigen",
    ],
)

apollo_component(
    name = "libsim_control_component.so",
    srcs = ["sim_control_component.cc"],
    hdrs = [
        "sim_control_channel.h",
        "sim_control_component.h",
    ],
    copts = SIM_CONTROL_COPTS,
    deps = [
        ":sim_control",
        "//cyber",
        "//modules/common/configs:config_gflags",
        "@com_github_gflags_gflags//:gflags",
        "//modules/map:apollo_map",
        "//modules/sim_control/proto:sim_control_command_cc_proto",
        "@com_github_nlohmann_json//:json",
    ],
)

apollo_cc_binary(
    name = "sim_control_command",
    srcs = [
        "sim_control_command.cc",
        "sim_control_channel.h",
    ],
    copts = SIM_CONTROL_COPTS,
    deps = [
        ":sim_control_client",
        ":sim_control_gflags",
        "//cyber",
        "//modules/common/configs:config_gflags",
        "//modules/sim_control/proto:sim_control_command_cc_proto",
    ],
)

apollo_cc_test(
    name = "sim_control_test",
    size = "small",
    srcs = ["dynamic_model/perfect_control/sim_control_test.cc"],
    data = [
        "testdata/garage.bin",
    ],
    deps = [
        ":sim_control",
        "//cyber",
        "@com_google_googletest//:gtest_main",
    ],
)

filegroup(
    name = "runtime_data",
    srcs = glob([
        "conf/*.conf",
        "dag/*.dag",
        "launch/*.launch",
    ]),
)

apollo_package()

cpplint()
