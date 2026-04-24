#!/bin/bash
# Local convenience wrapper to build and run the bolt package builder
# inside Docker.
#
# Usage:
#   ./docker-build.sh                          # build image + run entrypoint.sh
#   ./docker-build.sh --rebuild                # force image rebuild first

set -e -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="bolt-builder"

for arg in "$@"; do
  case "$arg" in
    --rebuild)
      docker build --tag ${IMAGE_NAME}  . ;;
    *) echo "Unknown argument: $arg"; exit 1 ;;
  esac
done


KEYS_DIR="${SCRIPT_DIR}/keys"
if [ ! -d "$KEYS_DIR" ]; then
  echo ""
  echo "Error: keys/ directory not found at $KEYS_DIR"
  exit 1
fi

mkdir -p "${SCRIPT_DIR}/bolts" "${SCRIPT_DIR}/work" \
         "${SCRIPT_DIR}/downloads" "${SCRIPT_DIR}/sstate-cache"

echo ""
echo "Starting build..."
echo "  Workspace       : ${SCRIPT_DIR}"
echo "  Downloads cache : ${SCRIPT_DIR}/downloads"
echo "  sstate cache    : ${SCRIPT_DIR}/sstate-cache"
echo "  Output (bolts/) : ${SCRIPT_DIR}/bolts"
echo ""

if [[ -n "${OPEN_SHELL}" ]]; then
  DOCKER_EXTRA_ARTGS="${DOCKER_EXTRA_ARGS} -ti"
fi

docker run --rm $DOCKER_EXTRA_ARGS \
  -e OPEN_SHELL="${OPEN_SHELL}" \
  -v "${SCRIPT_DIR}:/build" \
  -e RALFPACK_PASSPHRASE="${RALFPACK_PASSPHRASE:-}" \
  "$IMAGE_NAME"
