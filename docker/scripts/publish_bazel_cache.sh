#!/usr/bin/env bash
# Publish Bazel's repository cache (the http_archive downloads of WORKSPACE,
# several of which exist only on apollo-system.cdn.bcebos.com) to Hugging
# Face, so dev_start.sh can restore it into a fresh source tree. Bazel finds
# the archives by sha256 and does not download them again. Build outputs are
# not published; they belong to one source tree and toolchain.
#
#   bash docker/scripts/publish_bazel_cache.sh    # after a full build
#
# Needs `hf auth login` with write access to ${APOLLO_NEO_DEPS_REPO}
# (default lilejin322/BaiduApolloCtn).
set -euo pipefail

CURR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
APOLLO_ROOT_DIR="$(cd "${CURR_DIR}/../.." && pwd -P)"
REPO="${APOLLO_NEO_DEPS_REPO:-lilejin322/BaiduApolloCtn}"
NAME="bazel-repo-cache.tar.gz"
SRC=".cache/bazel/cache/repos"
WORK="$(mktemp -d /var/tmp/bazel-cache.XXXXXX)"
trap 'rm -rf "${WORK}"' EXIT

cd "${APOLLO_ROOT_DIR}"
ls "${SRC}/v1/content_addressable/sha256" > /dev/null
# leave out tmp/ and other per-run state; keep only the downloaded archives
tar --owner=0 --group=0 --numeric-owner -cf - "${SRC}/v1/content_addressable" | pigz -p "$(nproc)" > "${WORK}/${NAME}"
echo "[publish] $(ls "${SRC}/v1/content_addressable/sha256" | wc -l) archives:"
ls -lh "${WORK}/${NAME}"

hf upload "${REPO}" "${WORK}/${NAME}" "${NAME}" --repo-type dataset
echo "[publish] https://huggingface.co/datasets/${REPO}/resolve/main/${NAME}"
