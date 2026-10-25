#!/usr/bin/env bash
# Publish the perception model weights (all Apollo publishes) to Hugging
# Face, so dev_start.sh can restore them into a fresh source tree instead of
# fetching them from the Baidu servers. Only the weights are packed (git keeps
# each model's BUILD/README/cyberfile.xml); TRTengine.cache is left out, as
# TensorRT builds it for the local GPU on first use.
#
#   bash docker/scripts/publish_perception_models.sh
#
# Needs `hf auth login` with write access to ${APOLLO_NEO_DEPS_REPO}
# (default lilejin322/BaiduApolloCtn).
set -euo pipefail

CURR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
APOLLO_ROOT_DIR="$(cd "${CURR_DIR}/../.." && pwd -P)"
source "${CURR_DIR}/perception_models.sh"
REPO="${APOLLO_NEO_DEPS_REPO:-lilejin322/BaiduApolloCtn}"
WORK="$(mktemp -d /var/tmp/perception-models.XXXXXX)"
trap 'rm -rf "${WORK}"' EXIT

cd "${APOLLO_ROOT_DIR}"
for f in "${PERCEPTION_MODEL_WEIGHTS[@]}"; do
  [[ -f "${PERCEPTION_MODELS_DIR}/${f}" ]] || { echo "missing ${f}" >&2; exit 1; }
done
dirs=()
for f in "${PERCEPTION_MODEL_WEIGHTS[@]}"; do
  dirs+=("${PERCEPTION_MODELS_DIR}/${f%%/*}")
done
git ls-files -o --exclude-standard -- "${dirs[@]}" | grep -v '/TRTengine\.cache$' \
  > "${WORK}/files"
tar --owner=0 --group=0 --numeric-owner -cf - -T "${WORK}/files" | pigz -p "$(nproc)" > "${WORK}/${PERCEPTION_MODELS_ARCHIVE}"
echo "[publish] $(wc -l < "${WORK}/files") files:"
ls -lh "${WORK}/${PERCEPTION_MODELS_ARCHIVE}"

hf upload "${REPO}" "${WORK}/${PERCEPTION_MODELS_ARCHIVE}" "${PERCEPTION_MODELS_ARCHIVE}" \
  --repo-type dataset
echo "[publish] https://huggingface.co/datasets/${REPO}/resolve/main/${PERCEPTION_MODELS_ARCHIVE}"
