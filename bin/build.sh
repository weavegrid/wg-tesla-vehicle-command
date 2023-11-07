#!/bin/bash

set -xeo pipefail

THIS_DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)
ROOT_DIR=${THIS_DIR}/..

# Sets the Dockerfile name and tag
DOCKER_REPO=${DOCKER_REPO:-docker.wg-dev.net}
DOCKER_APP=tesla-http-proxy
DOCKER_TAG=${DOCKER_TAG:-dev}

BUILD_ARGS=(
  docker build -t "${DOCKER_REPO}/${DOCKER_APP}:${DOCKER_TAG}"
  "--target=tesla-http-proxy" "${ROOT_DIR}"
)
if [ -n "${DOCKER_DEFAULT_PLATFORM}" ]; then
  BUILD_ARGS+=(--platform "${DOCKER_DEFAULT_PLATFORM}")
fi
if GIT_HASH=$(git rev-parse HEAD); then
  BUILD_ARGS+=(--build-arg "GIT_HASH=${GIT_HASH}")
fi

# Builds the tesla http proxy  image from the Dockerfile in the parent directory
exec "${BUILD_ARGS[@]}"
