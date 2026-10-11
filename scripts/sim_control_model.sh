#!/usr/bin/env bash

###############################################################################
# Copyright 2026 The Apollo Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
###############################################################################

# Send the same dynamic-model commands the Dreamview sim-control switch sends
# after the sim_control process is already running.
#
#   bash scripts/sim_control.sh start
#   bash scripts/sim_control_model.sh
#   bash scripts/sim_control_model.sh "Simulation Perfect Control"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${DIR}/apollo_base.sh"

BINARY="${APOLLO_BIN_PREFIX}/modules/sim_control/sim_control_command"
if [[ ! -x "${BINARY}" ]]; then
  echo "Missing ${BINARY}. Build it with: bash apollo.sh build sim_control" >&2
  exit 1
fi

exec "${BINARY}" \
  --flagfile="${DIR}/../modules/common/data/global_flagfile.txt" \
  "$@"
