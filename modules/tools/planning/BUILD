load("@rules_python//python:defs.bzl", "py_binary")

package(default_visibility = ["//visibility:public"])

py_binary(
    name = "test_case",
    srcs = ["test_case.py"],
    deps = [
        "//cyber/python/cyber_py3:cyber",
        "//cyber/python/cyber_py3:cyber_time",
        "//modules/prediction/proto:prediction_obstacle_py_pb2",
        "//modules/localization/proto:localization_py_pb2"
    ],
)