#!/usr/bin/env bash

###############################################################################
# Copyright 2017 The Apollo Authors. All Rights Reserved.
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
CURR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${CURR_DIR}/docker_base.sh"

CACHE_ROOT_DIR="${APOLLO_ROOT_DIR}/.cache"

DOCKER_REPO="apolloauto/apollo"
DEV_CONTAINER_PREFIX='apollo_dev_'
DEV_CONTAINER="${DEV_CONTAINER_PREFIX}${USER}"
DEV_INSIDE="in-dev-docker"

CO_DEV_PATH=

SUPPORTED_ARCHS=(x86_64 aarch64)
TARGET_ARCH="$(uname -m)"

VERSION_X86_64="dev-x86_64-18.04-20240620_1444"
# x86_64 NVIDIA dev image: the Apollo 10.0+ env image (Ubuntu 22.04, CUDA 11.8,
# TensorRT 8.6) that aem uses, instead of the 18.04 / CUDA 11.1 / TensorRT 7.2
# dev image above, which cannot target RTX 40xx (sm_89). Only on the Baidu
# registry, so it is fully qualified. Map/audio volumes still use DOCKER_REPO.
NVIDIA_DEV_REPO_X86_64="registry.baidubce.com/apollo/apollo-env-gpu"
NVIDIA_DEV_VERSION_X86_64="10.0-u23"
# Hugging Face dataset mirroring what the Baidu servers serve: docker images
# (dev image, map and data volumes), installed packages (neo volume),
# perception models, the Bazel repository cache
NEO_DEPS_REPO="${APOLLO_NEO_DEPS_REPO:-lilejin322/BaiduApolloCtn}"
TESTING_VERSION_X86_64="dev-x86_64-18.04-testing-20210112_0008"

VERSION_AARCH64="dev-aarch64-20.04-20240626_1642"
USER_VERSION_OPT=

ROCM_DOCKER_REPO="rocmapollo/apollo"
VERSION_ROCM_X86_64="dev-x86_64-rocm-18.04-20221027_0916"
TESTING_VERSION_ROCM_X86_64="dev-x86_64-rocm-18.04-testing"

FAST_MODE="no"

GEOLOC=
TIMEZONE_CN=(
  "Time zone: Asia/Shanghai (CST, +0800)"
  "+0800"
)

USE_LOCAL_IMAGE=0
CUSTOM_DIST=
USER_AGREED="no"

VOLUME_VERSION="latest"
SHM_SIZE="2G"
USER_SPECIFIED_MAPS=
MAP_VOLUMES_CONF=
OTHER_VOLUMES_CONF=

CROSS_PLATFORM_FLAG=0

# Map
DEFAULT_MAPS=(
  sunnyvale
  sunnyvale_big_loop
  sunnyvale_loop
  sunnyvale_with_two_offices
  san_mateo
  apollo_virutal_map
)

DEFAULT_TEST_MAPS=(
  sunnyvale_big_loop
  sunnyvale_loop
)

function show_usage() {
  cat << EOF
Usage: $0 [options] ...
OPTIONS:
    -h, --help                    Display this help and exit
    -f, --fast                    Fast mode without pulling all map volumes
    -g, --geo <us|cn|none>        Pull docker image from geolocation specific registry mirror
    -l, --local                   Use local docker image
    -t, --tag <TAG>               Specify docker image with tag <TAG> to start
    -d, --dist                    Specify Apollo distribution(stable/testing)
    -c, --cross-platform <arch>   Run a cross-platform image
    --co-dev <path>               Run collaborative env between source image and package manager image
    --shm-size <bytes>            Size of /dev/shm, passed directly to "docker run"
    -y                            Agree to Apollo License Agreement non-interactively
    stop                          Stop all running Apollo containers
EOF
}

function cross_platform_setup() {
  info "Setup qemu user static..."
  docker run --rm --privileged multiarch/qemu-user-static --reset -p yes -c yes > /dev/null
  if [[ ! $? -eq 0 ]]; then
    error "Qemu setup failed! Please report this issue to Apollo team."
    exit -1
  fi
}

function parse_arguments() {
  local custom_version=""
  local custom_dist=""
  local shm_size=""
  local geo=""
  local fast_mode=""

  while [ $# -gt 0 ]; do
    local opt="$1"
    shift
    case "${opt}" in
      -t | --tag)
        if [ -n "${custom_version}" ]; then
          warning "Multiple option ${opt} specified, only the last one will take effect."
        fi
        custom_version="$1"
        shift
        optarg_check_for_opt "${opt}" "${custom_version}"
        ;;

      -c | --cross-platform)
        custom_arch="$1"
        shift
        if [[ "$TARGET_ARCH" == "aarch64" && "$custom_arch" == "x86_64" ]]; then
          error "Run x86_64 image on aarch64 currently is not supported!"
          exit -1
        fi
        if [[ ! "$TARGET_ARCH" == "$custom_arch" ]]; then
          CROSS_PLATFORM_FLAG=1
        fi
        TARGET_ARCH="$custom_arch"
        check_target_arch
        cross_platform_setup
        ;;

      --co-dev)
        mount_workspace_path="$1"
        shift
        CO_DEV_PATH="$mount_workspace_path"
        ;;

      -d | --dist)
        custom_dist="$1"
        shift
        optarg_check_for_opt "${opt}" "${custom_dist}"
        ;;

      -h | --help)
        show_usage
        exit 1
        ;;

      -f | --fast)
        fast_mode="$1"
        shift
        optarg_check_for_opt "${opt}" "${fast_mode}"
        ;;

      -g | --geo)
        geo="$1"
        shift
        optarg_check_for_opt "${opt}" "${geo}"
        ;;

      -l | --local)
        USE_LOCAL_IMAGE=1
        ;;

      --user)
        export CUSTOM_USER="$1"
        shift
        ;;

      --uid)
        export CUSTOM_UID="$1"
        shift
        ;;

      --group)
        export CUSTOM_GROUP="$1"
        shift
        ;;
      --gid)
        export CUSTOM_GID="$1"
        shift
        ;;

      -n | --name)
        DEV_CONTAINER="${DEV_CONTAINER_PREFIX}${1}"
        shift
        ;;

      --shm-size)
        shm_size="$1"
        shift
        optarg_check_for_opt "${opt}" "${shm_size}"
        ;;

      --map)
        map_name="$1"
        shift
        USER_SPECIFIED_MAPS="${USER_SPECIFIED_MAPS} ${map_name}"
        ;;
      -y)
        USER_AGREED="yes"
        ;;
      stop)
        info "Now, stop all Apollo containers created by ${USER} ..."
        stop_all_apollo_containers "-f"
        exit 0
        ;;
      *)
        warning "Unknown option: ${opt}"
        exit 2
        ;;
    esac
  done # End while loop

  [[ -n "${geo}" ]] && GEOLOC="${geo}"
  [[ -n "${fast_mode}" ]] && FAST_MODE="${fast_mode}"
  [[ -n "${custom_version}" ]] && USER_VERSION_OPT="${custom_version}"
  [[ -n "${custom_dist}" ]] && CUSTOM_DIST="${custom_dist}"
  [[ -n "${shm_size}" ]] && SHM_SIZE="${shm_size}"
}

function determine_dev_image() {
  local docker_repo="${DOCKER_REPO}"
  local version="$1"
  # If no custom version specified
  if [[ -z "${version}" ]]; then
    if [[ "${TARGET_ARCH}" == "x86_64" ]]; then
      if [[ ${USE_AMD_GPU} == 1 ]]; then
        docker_repo="${ROCM_DOCKER_REPO}"
        version="${VERSION_ROCM_X86_64}"
      elif (($USE_NVIDIA_GPU == 1)) || (($USE_GPU_HOST == 0)); then
        if [[ "${CUSTOM_DIST}" == "testing" ]]; then
          version="${TESTING_VERSION_X86_64}"
        elif (($USE_NVIDIA_GPU == 1)); then
          docker_repo="${NVIDIA_DEV_REPO_X86_64}"
          version="${NVIDIA_DEV_VERSION_X86_64}"
        else
          version="${VERSION_X86_64}"
        fi
      fi
    elif [[ "${TARGET_ARCH}" == "aarch64" ]]; then
      version="${VERSION_AARCH64}"
    else
      error "Logic can't reach here! Please report this issue to Apollo@GitHub."
      exit 3
    fi
  fi
  DEV_IMAGE="${docker_repo}:${version}"
}

function check_host_environment() {
  if [[ "${HOST_OS}" != "Linux" ]]; then
    warning "Running Apollo dev container on ${HOST_OS} is UNTESTED, exiting..."
    exit 1
  fi
}

function check_target_arch() {
  local arch="${TARGET_ARCH}"
  local support_arch=""
  for ent in "${SUPPORTED_ARCHS[@]}"; do
    support_arch="$support_arch $ent"
    if [[ "${ent}" == "${TARGET_ARCH}" ]]; then
      return 0
    fi
  done
  error "Unsupported target architecture: ${TARGET_ARCH}."
  error "Current Apollo support architecture:$support_arch."
  exit 1
}

function check_timezone_cn() {
  # https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
  # time_zone=$(timedatectl | grep "Time zone" | xargs)
  # time_zone=$(date +"%z")

  # for tz in "${TIMEZONE_CN[@]}"; do
  #   if [[ "${time_zone}" == "${tz}" ]]; then
  #     GEOLOC="cn"
  #     return 0
  #   fi
  # done
  # Upstream forces GEOLOC="cn" here, which sends every image pull (map and
  # data volumes) to registry.baidubce.com. Images come from Hugging Face,
  # else Docker Hub, instead; `-g cn` still selects the Baidu registry.
  return 0
}

function setup_devices_and_mount_local_volumes() {
  local __retval="$1"

  [ -d "${CACHE_ROOT_DIR}" ] || mkdir -p "${CACHE_ROOT_DIR}"

  source "${APOLLO_ROOT_DIR}/scripts/apollo_base.sh"
  setup_device

  local volumes="-v $APOLLO_ROOT_DIR:/apollo"

  [ ! -z "${CO_DEV_PATH}" ] && volumes="-v ${PWD}/${CO_DEV_PATH}:/apollo_workspace ${volumes}"
  [ ! -z "${CO_DEV_PATH}" ] && volumes="-e CO_DEV=1 ${volumes}"

  [ -d "${APOLLO_CONFIG_HOME}" ] || mkdir -p "${APOLLO_CONFIG_HOME}"
  volumes="-v ${APOLLO_CONFIG_HOME}:${APOLLO_CONFIG_HOME} ${volumes}"

  local teleop="${APOLLO_ROOT_DIR}/../apollo-teleop"
  if [ -d "${teleop}" ]; then
    volumes="${volumes} -v ${teleop}:/apollo/modules/teleop ${volumes}"
  fi
  local apollo_tools="${APOLLO_ROOT_DIR}/../apollo-tools"
  if [ -d "${apollo_tools}" ]; then
    volumes="${volumes} -v ${apollo_tools}:/tools"
  fi

  local os_release="$(lsb_release -rs)"
  case "${os_release}" in
    16.04)
      warning "[Deprecated] Support for Ubuntu 16.04 will be removed" \
        "in the near future. Please upgrade to ubuntu 18.04+."
      volumes="${volumes} -v /dev:/dev"
      ;;
    18.04 | 20.04 | *)
      volumes="${volumes} -v /dev:/dev"
      ;;
  esac
  # local tegra_dir="/usr/lib/aarch64-linux-gnu/tegra"
  # if [[ "${TARGET_ARCH}" == "aarch64" && -d "${tegra_dir}" ]]; then
  #    volumes="${volumes} -v ${tegra_dir}:${tegra_dir}:ro"
  # fi
  volumes="${volumes} -v /media:/media \
                        -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
                        -v /etc/localtime:/etc/localtime:ro \
                        -v /usr/src:/usr/src \
                        -v /lib/modules:/lib/modules"
  volumes="$(tr -s " " <<< "${volumes}")"
  eval "${__retval}='${volumes}'"
}

# Prefix GEO_REGISTRY unless the image already names a registry host
# (a first path component with a dot, e.g. registry.baidubce.com/...).
function with_geo_registry() {
  local img="$1"
  if [[ -n "${GEO_REGISTRY}" && "${img%%/*}" != *.* ]]; then
    img="${GEO_REGISTRY}/${img}"
  fi
  echo "${img}"
}

# Download a (large) file into ${HF_DOWNLOAD_DIR} and print its path. An
# interrupted download is resumed, on a retry here or on the next dev_start.sh
# run; the result is checked against the sha256 Hugging Face reports
# (X-Linked-Etag). Callers delete the file once they have used it.
HF_DOWNLOAD_DIR="${APOLLO_DOWNLOAD_DIR:-/var/tmp/apollo_downloads_${USER}}"
function hf_fetch() {
  local url="$1"
  local file="${HF_DOWNLOAD_DIR}/$(basename "${url%%\?*}")"
  mkdir -p "${HF_DOWNLOAD_DIR}" || return 1
  # parallel A/AAAA lookups stall 5s on some networks; serialize them
  local -x RES_OPTIONS="${RES_OPTIONS:-single-request-reopen}"
  local sha
  sha="$(curl -fsSI --retry 5 "${url}" | tr -d '\r' \
    | awk -F'"' 'tolower($0) ~ /^x-linked-etag:/ {print $2}')"
  local i
  for i in $(seq 1 20); do
    # -C -: continue from what is already in the file
    curl -fL -C - --retry 5 --retry-delay 3 -o "${file}" "${url}" >&2 && break
    # 416: the file is already complete
    [[ -n "${sha}" ]] && echo "${sha}  ${file}" | sha256sum -c --status && break
    warning "Download of ${url} interrupted; resuming (${i}/20) ..."
    sleep 3
  done
  if [[ -n "${sha}" ]] && ! echo "${sha}  ${file}" | sha256sum -c --status; then
    error "Checksum mismatch for ${file}; removed it"
    rm -f "${file}"
    return 1
  fi
  echo "${file}"
}

function docker_pull() {
  local img="$1"
  if [[ "${USE_LOCAL_IMAGE}" -gt 0 ]]; then
    if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "${img}"; then
      info "Local image ${img} found and will be used."
      return
    fi
    warning "Image ${img} not found locally although local mode enabled. Trying to pull from remote registry."
  fi
  img="$(with_geo_registry "${img}")"

  # Use a local copy as is, else load the copy mirrored on Hugging Face (the
  # apollo-env image lives on registry.baidubce.com only), else pull it.
  if docker image inspect "${img}" > /dev/null 2>&1; then
    info "Local image ${img} found and will be used."
    return
  fi
  local name="${img##*/}"
  name="${name/:/-}.tar.gz" # apollo-env-gpu-10.0-u23.tar.gz
  local url="${APOLLO_IMAGES_URL:-https://huggingface.co/datasets/${NEO_DEPS_REPO}/resolve/main}/${name}"
  info "Loading docker image ${img} from ${url} ..."
  local file
  if file="$(hf_fetch "${url}")" && docker load -i "${file}" \
      && docker image inspect "${img}" > /dev/null 2>&1; then
    rm -f "${file}"
    return
  fi
  warning "Could not load ${img} from ${url}; pulling it from the registry"

  info "Start pulling docker image ${img} ..."
  if ! docker pull "${img}"; then
    error "Failed to pull docker image : ${img}"
    exit 1
  fi
}

function docker_restart_volume() {
  local volume="$1"
  local image="$2"
  local path="$3"
  info "Create volume ${volume} from image: ${image}"
  docker_pull "${image}"
  docker volume rm "${volume}" > /dev/null 2>&1
  docker run -v "${volume}":"${path}" --rm "${image}" true > /dev/null
}

function restart_map_volume_if_needed() {
  local map_name="$1"
  local map_version="$2"
  local map_volume="apollo_map_volume-${map_name}_${USER}"
  local map_path="/apollo/modules/map/data/${map_name}"
  # some map image does not support aarch64, force to use image of x86_64
  local TARGET_ARCH="x86_64"

  if [[ ${MAP_VOLUMES_CONF} == *"${map_volume}"* ]]; then
    info "Map ${map_name} has already been included."
  else
    local map_image=
    if [ "${TARGET_ARCH}" = "aarch64" ]; then
      map_image="${DOCKER_REPO}:map_volume-${map_name}-${TARGET_ARCH}-${map_version}"
    else
      map_image="${DOCKER_REPO}:map_volume-${map_name}-${map_version}"
    fi
    info "Load map ${map_name} from image: ${map_image}"

    docker_restart_volume "${map_volume}" "${map_image}" "${map_path}"
    MAP_VOLUMES_CONF="${MAP_VOLUMES_CONF} --volume ${map_volume}:${map_path}"
  fi
}

function mount_map_volumes() {
  info "Starting mounting map volumes ..."
  if [ -n "${USER_SPECIFIED_MAPS}" ]; then
    for map_name in ${USER_SPECIFIED_MAPS}; do
      restart_map_volume_if_needed "${map_name}" "${VOLUME_VERSION}"
    done
  fi

  if [[ "$FAST_MODE" == "no" ]]; then
    for map_name in ${DEFAULT_MAPS[@]}; do
      restart_map_volume_if_needed "${map_name}" "${VOLUME_VERSION}"
    done
  else
    for map_name in ${DEFAULT_TEST_MAPS[@]}; do
      restart_map_volume_if_needed "${map_name}" "${VOLUME_VERSION}"
    done
  fi
}

function mount_other_volumes() {
  info "Mount other volumes ..."
  local volume_conf=
  local TARGET_ARCH="x86_64"

  # AUDIO
  local audio_volume="apollo_audio_volume_${USER}"
  local audio_image="${DOCKER_REPO}:data_volume-audio_model-${TARGET_ARCH}-latest"
  local audio_path="/apollo/modules/audio/data/"
  docker_restart_volume "${audio_volume}" "${audio_image}" "${audio_path}"
  volume_conf="${volume_conf} --volume ${audio_volume}:${audio_path}"

  # buildtool installs the third-party packages and the built Apollo under
  # /opt/apollo/neo at runtime. Keep that in a named volume that outlives the
  # container (unlike the volumes above, it is never recreated), so a new
  # container runs the existing build instead of rebuilding everything.
  # Docker fills a new, empty volume with the image's /opt/apollo/neo.
  # APOLLO_NEO_VOLUME_RESET=1 starts over from the image.
  if [[ "${DEV_IMAGE}" == *apollo-env* ]]; then
    local neo_volume="apollo_neo_volume_${USER}"
    if [[ "${APOLLO_NEO_VOLUME_RESET:-0}" == "1" ]]; then
      info "Removing volume ${neo_volume} (APOLLO_NEO_VOLUME_RESET=1)"
      docker volume rm "${neo_volume}" > /dev/null 2>&1
    fi
    if docker volume inspect "${neo_volume}" > /dev/null 2>&1; then
      info "Reuse volume ${neo_volume} for /opt/apollo/neo"
    else
      info "Create volume ${neo_volume} for /opt/apollo/neo"
      docker volume create "${neo_volume}" > /dev/null
    fi
    volume_conf="${volume_conf} --volume ${neo_volume}:/opt/apollo/neo"
  fi
  OTHER_VOLUMES_CONF="${volume_conf}"
}

# buildtool's package index (~7M) comes from the Baidu server, which can take
# minutes per container on slow links, and the patched buildtool no longer
# downloads it (fix_buildtool_index_cache.py). The index ships in this tree
# instead; refresh it with docker/scripts/save_buildtool_index.sh.
BUILDTOOL_INDEX_ARCHIVE="/apollo/docker/scripts/buildtool_index/index.tar.gz"
function seed_buildtool_index() {
  local container="$1"
  docker exec -u "${USER}" "${container}" bash -c "
      set -e
      mkdir -p /opt/apollo/neo/share/buildtool
      tar -xzf ${BUILDTOOL_INDEX_ARCHIVE} -C /opt/apollo/neo/share/buildtool" \
    || { error "Could not restore buildtool's package index from ${BUILDTOOL_INDEX_ARCHIVE}"; return 1; }
  info "Restored buildtool's package index from ${BUILDTOOL_INDEX_ARCHIVE}"
}

# The apollo_neo_volume (see mount_other_volumes) holds buildtool's installed
# packages. A volume without them (first use, APOLLO_NEO_VOLUME_RESET=1) is
# seeded from the archive docker/scripts/publish_neo_deps.sh puts on Hugging
# Face (one ~GB download instead of buildtool fetching ~100 packages file by
# file from the Baidu servers); a volume that has them is reused offline.
# Either way the packages' dpkg records go into the new container, since
# buildtool checks `dpkg -l` to see what is installed.
NEO_DEPS_RESTORED=0
function restore_neo_deps() {
  local container="$1"
  local marker="/opt/apollo/neo/.neo_deps/VERSION"
  if docker exec "${container}" test -f "${marker}"; then
    info "Reuse installed packages in the neo volume ($(docker exec "${container}" cat "${marker}"))"
    NEO_DEPS_RESTORED=1
  else
    local name="neo-deps-${DEV_IMAGE##*:}.tar.gz"
    local url="${APOLLO_NEO_DEPS_URL:-https://huggingface.co/datasets/${NEO_DEPS_REPO}/resolve/main/${name}}"
    info "Seeding the neo volume from ${url} ..."
    local file
    if ! file="$(hf_fetch "${url}")" \
        || ! docker exec -i -u root "${container}" tar -xzf - -C /opt/apollo/neo < "${file}" \
        || ! docker exec "${container}" test -f "${marker}"; then
      warning "Could not seed the neo volume; buildtool will install the packages itself"
      return 0
    fi
    rm -f "${file}"
    NEO_DEPS_RESTORED=1
  fi
  docker exec -u root "${container}" \
    python3 /apollo/docker/scripts/neo_deps_state.py restore \
    || { error "Could not restore the dpkg records of the installed packages"; return 1; }
}

# The perception model weights are not in git; buildtool would fetch them from
# the Baidu servers. Restore them from Hugging Face into the source tree, once
# (see publish_perception_models.sh).
function restore_perception_models() {
  source "${CURR_DIR}/perception_models.sh"
  local f missing=0
  for f in "${PERCEPTION_MODEL_WEIGHTS[@]}"; do
    [[ -f "${APOLLO_ROOT_DIR}/${PERCEPTION_MODELS_DIR}/${f}" ]] || missing=1
  done
  [[ "${missing}" -eq 0 ]] && return 0
  local url="${APOLLO_PERCEPTION_MODELS_URL:-https://huggingface.co/datasets/${NEO_DEPS_REPO}/resolve/main/${PERCEPTION_MODELS_ARCHIVE}}"
  info "Restoring perception models from ${url} ..."
  local file
  if file="$(hf_fetch "${url}")" && tar -xzf "${file}" -C "${APOLLO_ROOT_DIR}"; then
    rm -f "${file}"
  else
    warning "Could not restore the perception models; perception will not start"
  fi
}

# Several WORKSPACE archives are hosted only on the Baidu servers. Seed an
# empty Bazel repository cache from Hugging Face; Bazel then finds them by
# sha256 instead of downloading (see publish_bazel_cache.sh).
function restore_bazel_repo_cache() {
  local cache="${APOLLO_ROOT_DIR}/.cache/bazel/cache/repos/v1/content_addressable/sha256"
  [[ -n "$(ls -A "${cache}" 2> /dev/null)" ]] && return 0
  local url="${APOLLO_BAZEL_CACHE_URL:-https://huggingface.co/datasets/${NEO_DEPS_REPO}/resolve/main/bazel-repo-cache.tar.gz}"
  info "Restoring the Bazel repository cache from ${url} ..."
  mkdir -p "${APOLLO_ROOT_DIR}/.cache"
  local file
  if file="$(hf_fetch "${url}")" && tar -xzf "${file}" -C "${APOLLO_ROOT_DIR}"; then
    rm -f "${file}"
  else
    warning "Could not restore the Bazel repository cache; Bazel will download it"
  fi
}

# The apollo-env images are meant for aem, which prepares them after creating
# the container (aem funcs.sh apollo_container_created_post_action); do the
# same here, or buildtool cannot write /opt/apollo/neo/setup.sh (owned by the
# image's "apollo" user).
function postrun_apollo_env_image() {
  local container="$1"
  [[ "${DEV_IMAGE}" == *apollo-env* ]] || return 0
  # parallel A/AAAA lookups can stall 5s on some networks, which trips
  # buildtool's 5s network check; ask glibc to send them one after another
  local res_opts="RES_OPTIONS=single-request-reopen"
  info "Preparing apollo-env image (buildtool, permissions) ..."
  restore_neo_deps "${container}" || return 1
  # The neo volume carries the buildtool the packages were installed with;
  # only without it (or with APOLLO_UPGRADE_BUILDTOOL=1) ask the Baidu apt
  # repo for the latest buildtool.
  if [[ "${NEO_DEPS_RESTORED}" -eq 0 || "${APOLLO_UPGRADE_BUILDTOOL:-0}" -eq 1 ]]; then
    docker exec -u root -e "${res_opts}" "${container}" bash -c \
      "apt-get update -qq && apt-get install --only-upgrade -y -qq apollo-neo-buildtool" \
      || warning "Could not upgrade apollo-neo-buildtool; keeping the image's version"
  fi
  # buildtool's network check is one curl with a 5s timeout and no retry, so a
  # slow lookup flips the whole run to offline mode. The upgrade above
  # reinstalls that version, so re-apply the retry patch (15s x 7) every time.
  docker exec -u root "${container}" \
    python3 /apollo/docker/scripts/patches/fix_buildtool_network_check.py \
    || warning "Could not patch buildtool's network check"
  # buildtool assumes package-workspace tools/external paths. Full Apollo
  # source trees keep OpenSSL's build rule under third_party/openssl instead.
  # Also preserve source-mode proto deps during whole-workspace builds.
  docker exec -u root "${container}" \
    python3 /apollo/docker/scripts/patches/fix_buildtool_workspace_paths.py \
    || { error "Could not patch buildtool's workspace paths"; return 1; }
  # buildtool re-downloads the whole package index on every online run; use
  # the local copy once it exists (BUILDTOOL_REFRESH_INDEX=1 forces a refresh).
  docker exec -u root "${container}" \
    python3 /apollo/docker/scripts/patches/fix_buildtool_index_cache.py \
    || warning "Could not patch buildtool's package index cache"
  # Offline, buildtool stops on a third-party package whose installed version
  # differs from the requested one, although it would download nothing.
  docker exec -u root "${container}" \
    python3 /apollo/docker/scripts/patches/fix_buildtool_offline_reinstall.py \
    || { error "Could not patch buildtool's offline reinstall check"; return 1; }
  docker exec -u root "${container}" bash -c \
    "chmod 777 /opt/apollo/neo/packages/buildtool/latest/setup.sh && \
     mkdir -p /opt/apollo/neo/etc && chmod -R 777 /opt/apollo/neo/etc"
  # buildtool installs packages with sudo but reads and writes its own
  # metadata (/opt/apollo/neo/share/buildtool/installed_package, the index
  # under share/buildtool/namespaces, python/, ...) as the user. The root
  # upgrade above leaves those directories root-owned 755, so the user's
  # first build fails with "Permission denied". Hand /opt/apollo/neo to the
  # container user now, while it holds little more than the image's ~175M.
  local group
  group="$(id -gn)"
  docker exec -u root "${container}" \
    chown -R "${USER}:${group}" /opt/apollo/neo \
    || { error "Could not hand /opt/apollo/neo to ${USER}"; return 1; }
  seed_buildtool_index "${container}" || return 1
  docker exec -u "${USER}" "${container}" bash -c \
    "grep -qs 'source /opt/apollo/neo/setup.sh' ~/.bashrc || \
     echo '[[ -e /opt/apollo/neo/setup.sh ]] && source /opt/apollo/neo/setup.sh' >> ~/.bashrc"
}

function main() {
  check_host_environment
  check_target_arch

  parse_arguments "$@"

  if [[ "${USER_AGREED}" != "yes" ]]; then
    check_agreement
  fi

  info "Determine whether host GPU is available ..."
  determine_gpu_use_host
  info "USE_GPU_HOST: ${USE_GPU_HOST}"
  info "USE_AMD_GPU: ${USE_AMD_GPU}"
  info "USE_NVIDIA_GPU: ${USE_NVIDIA_GPU}"

  determine_dev_image "${USER_VERSION_OPT}"

  [[ -z "${GEOLOC}" ]] && check_timezone_cn
  geo_specific_config "${GEOLOC}"

  if [[ "${USE_LOCAL_IMAGE}" -gt 0 ]]; then
    info "Start docker container based on local image : ${DEV_IMAGE}"
  fi

  if ! docker_pull "${DEV_IMAGE}"; then
    error "Failed to pull docker image ${DEV_IMAGE}"
    exit 1
  fi

  restore_perception_models
  restore_bazel_repo_cache

  info "Remove existing Apollo Development container ..."
  remove_container_if_exists ${DEV_CONTAINER}

  local local_volumes=
  setup_devices_and_mount_local_volumes local_volumes

  mount_map_volumes
  mount_other_volumes

  warning "Starting in 9.0 we do not automatically download models!" \
    "If you want to run the perception module, download the model manually" \
    "reference https://github.com/ApolloAuto/apollo/discussions/15212"

  info "Starting Docker container \"${DEV_CONTAINER}\" ..."

  local local_host="$(hostname)"
  local display="${DISPLAY:-:0}"
  local user="${CUSTOM_USER-$USER}"
  local uid="${CUSTOM_UID-$(id -u)}"
  local group="${CUSTOM_GROUP-$(id -g -n)}"
  local gid="${CUSTOM_GID-$(id -g)}"

  local start_img="$(with_geo_registry "${DEV_IMAGE}")"

  set -x

  ${DOCKER_RUN_CMD} -itd \
    --privileged \
    --name "${DEV_CONTAINER}" \
    --label "owner=${USER}" \
    -e CROSS_PLATFORM="${CROSS_PLATFORM_FLAG}" \
    -e DISPLAY="${display}" \
    -e DOCKER_USER="${user}" \
    -e USER="${user}" \
    -e DOCKER_USER_ID="${uid}" \
    -e DOCKER_GRP="${group}" \
    -e DOCKER_GRP_ID="${gid}" \
    -e DOCKER_IMG="${DEV_IMAGE}" \
    -e USE_GPU_HOST="${USE_GPU_HOST}" \
    -e NVIDIA_VISIBLE_DEVICES=all \
    -e NVIDIA_DRIVER_CAPABILITIES=compute,video,graphics,utility \
    ${MAP_VOLUMES_CONF} \
    ${OTHER_VOLUMES_CONF} \
    ${local_volumes} \
    --net host \
    -w /apollo \
    --add-host "${DEV_INSIDE}:127.0.0.1" \
    --add-host "${local_host}:127.0.0.1" \
    --hostname "${DEV_INSIDE}" \
    --shm-size "${SHM_SIZE}" \
    --pid=host \
    -v /dev/null:/dev/raw1394 \
    --entrypoint /bin/bash \
    "${start_img}"

  if [ $? -ne 0 ]; then
    error "Failed to start docker container \"${DEV_CONTAINER}\" based on image: ${start_img}"
    exit 1
  fi
  set +x

  if [[ "$(docker inspect -f '{{.State.Running}}' "${DEV_CONTAINER}" 2>/dev/null)" != "true" ]]; then
    error "Container \"${DEV_CONTAINER}\" exited right after start:"
    docker logs --tail 5 "${DEV_CONTAINER}" >&2
    exit 1
  fi

  postrun_start_user "${DEV_CONTAINER}"
  postrun_apollo_env_image "${DEV_CONTAINER}" || exit 1
  postrun_cross_platfrom_download "${DEV_CONTAINER}" "${CROSS_PLATFORM_FLAG}"

  ok "Congratulations! You have successfully finished setting up Apollo Dev Environment."
  ok "To login into the newly created ${DEV_CONTAINER} container, please run the following command:"
  ok "  bash docker/scripts/dev_into.sh"
  ok "Enjoy!"
}

main "$@"
