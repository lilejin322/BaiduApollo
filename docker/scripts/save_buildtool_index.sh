#!/usr/bin/env bash
# Save buildtool's package index from a dev container into this source tree,
# where dev_start.sh restores it into every new container (the patched
# buildtool never downloads it from the Baidu server itself).
#
#   # in the container: fetch the latest index from Baidu once
#   BUILDTOOL_REFRESH_INDEX=1 buildtool build
#   # on the host: store it, then commit the archive
#   bash docker/scripts/save_buildtool_index.sh [container]
set -euo pipefail

CONTAINER="${1:-apollo_dev_${USER}}"
SRC=/opt/apollo/neo/share/buildtool
OUT=/apollo/docker/scripts/buildtool_index/index.tar.gz

docker exec -u "${USER}" "${CONTAINER}" bash -c "
  set -e
  ls ${SRC}/namespaces/*/Packages ${SRC}/namespaces/*/Cyberfiles >/dev/null
  mkdir -p \$(dirname ${OUT})
  tar -czf ${OUT}.tmp -C ${SRC} namespaces
  mv ${OUT}.tmp ${OUT}
  echo \"saved \$(du -h ${OUT} | cut -f1) package index: ${OUT}\"
  tar -tzf ${OUT} | sed 's/^/  /'"
