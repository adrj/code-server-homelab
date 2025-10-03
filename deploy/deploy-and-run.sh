#!/usr/bin/env bash
set -euo pipefail

# deploy-and-run.sh
# - removes existing image if present
# - builds new image from repository context
# - removes old container named $CONTAINER_NAME if exists
# - runs the new container named $CONTAINER_NAME with standard mounts

IMAGE_NAME="${IMAGE_NAME:-localhost:5000/code-server}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"
CONTAINER_NAME="${CONTAINER_NAME:-code-server}"
VOLUME_NAME="${VOLUME_NAME:-code-server}"
HOST_SSH_PORT="${HOST_SSH_PORT:-2222}"
WORKDIR="${WORKDIR:-/workspace}"
PUSH_IMAGE="${PUSH_IMAGE:-0}"

echo "Deploy script starting: image=${FULL_IMAGE} container=${CONTAINER_NAME} volume=${VOLUME_NAME}"

cd "${WORKDIR}"

echo "Checking for existing image ${FULL_IMAGE}"
if docker image inspect "${FULL_IMAGE}" >/dev/null 2>&1; then
  echo "Image exists — removing ${FULL_IMAGE}"
  docker image rm -f "${FULL_IMAGE}" || true
fi

echo "Building image ${FULL_IMAGE} from ${WORKDIR}"
docker build --pull -t "${FULL_IMAGE}" .

if [ "${PUSH_IMAGE}" = "1" ]; then
  echo "Pushing image ${FULL_IMAGE} to registry"
  docker push "${FULL_IMAGE}"
fi

echo "Stopping and removing any existing container named ${CONTAINER_NAME}"
if docker ps -a --format '{{.Names}}' | grep -w "${CONTAINER_NAME}" >/dev/null 2>&1; then
  docker rm -f "${CONTAINER_NAME}" || true
fi

echo "Running container ${CONTAINER_NAME}"
docker run -d \
  --name "${CONTAINER_NAME}" \
  -p "${HOST_SSH_PORT}:2222" \
  -v "${VOLUME_NAME}:/users-config" \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  --restart unless-stopped \
  "${FULL_IMAGE}" \
  /bin/bash -c "/usr/local/bin/init-users.sh"

echo "Container ${CONTAINER_NAME} started."
