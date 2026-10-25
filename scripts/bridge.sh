#!/usr/bin/env bash

TOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "${TOP_DIR}/scripts/apollo_base.sh"

# buildtool installs it under /opt/apollo/neo/bin; bazel-bin only points at it
# until a build in another compilation mode (e.g. buildtool test) moves the link
BRIDGE_BIN="/opt/apollo/neo/bin/cyber_bridge"
[[ -x "${BRIDGE_BIN}" ]] || BRIDGE_BIN="${TOP_DIR}/bazel-bin/modules/contrib/cyber_bridge/cyber_bridge"
"${BRIDGE_BIN}"
