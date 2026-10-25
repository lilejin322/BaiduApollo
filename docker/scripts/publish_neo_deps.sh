#!/usr/bin/env bash
# Publish the packages buildtool installed in a dev container (from
# /opt/apollo/neo, i.e. the apollo_neo_volume) to Hugging Face, so dev_start.sh can seed a new volume
# from it instead of having buildtool fetch ~100 packages from the Baidu
# servers (tens of minutes to hours from outside mainland China).
#
#   bash docker/scripts/publish_neo_deps.sh [container]
#
# Run after a successful `buildtool build`. Needs `hf auth login` with write
# access to ${APOLLO_NEO_DEPS_REPO} (default lilejin322/BaiduApolloCtn).
set -euo pipefail

CONTAINER="${1:-apollo_dev_${USER}}"
REPO="${APOLLO_NEO_DEPS_REPO:-lilejin322/BaiduApolloCtn}"
IMAGE="$(docker inspect -f '{{.Config.Image}}' "${CONTAINER}")"
NAME="neo-deps-${IMAGE##*:}.tar.gz"            # e.g. neo-deps-10.0-u23.tar.gz
WORK="$(mktemp -d /var/tmp/neo-deps.XXXXXX)"
trap 'rm -rf "${WORK}"' EXIT

echo "[publish] recording packages installed after ${IMAGE}"
docker run --rm --entrypoint cat "${IMAGE}" /var/lib/dpkg/status > "${WORK}/baseline"
docker cp "${WORK}/baseline" "${CONTAINER}:/tmp/neo_deps_dpkg_baseline"
docker exec -u root "${CONTAINER}" \
  python3 /apollo/docker/scripts/neo_deps_state.py save \
  --baseline /tmp/neo_deps_dpkg_baseline --version "${NAME}"
docker exec -u root "${CONTAINER}" rm -f /tmp/neo_deps_dpkg_baseline

echo "[publish] packing the packages' files in /opt/apollo/neo -> ${WORK}/${NAME}"
# only the files neo_deps_state.py listed: what buildtool built from source
# and installed there stays out. Owned by root in the archive; dev_start.sh
# hands /opt/apollo/neo to the container user after unpacking it.
# pigz: same .gz format, compressed on all host cores
docker exec -u root "${CONTAINER}" tar -C /opt/apollo/neo \
  --owner=0 --group=0 --numeric-owner --no-recursion \
  -T /opt/apollo/neo/.neo_deps/files -cf - \
  | pigz -p "$(nproc)" > "${WORK}/${NAME}"
ls -lh "${WORK}/${NAME}"

echo "[publish] uploading to ${REPO}"
hf upload "${REPO}" "${WORK}/${NAME}" "${NAME}" --repo-type dataset
echo "[publish] https://huggingface.co/datasets/${REPO}/resolve/main/${NAME}"
