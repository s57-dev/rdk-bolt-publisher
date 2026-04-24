#!/usr/bin/env bash
set -euo pipefail

BRANCH=main

git config --global user.email "builder@s57.io"
git config --global user.name "Github Builder"

cd /build
git clone https://github.com/rdkcentral/bolt-pkg-build-scripts work | true
cd /build/work

if [[ -n "${OPEN_SHELL}" ]]; then
  exec /bin/bash
fi

PRIVATE_KEY_PATH="${PRIVATE_KEY_PATH:-/build/keys/private_key.pem}"
PUBLIC_KEY_PATH="${PUBLIC_KEY_PATH:-/build/keys/public.pem}"
PRIVATE_KEY_PASSPHRASE="${PRIVATE_KEY_PASSPHRASE:-}"
KEY_FORMAT="${KEY_FORMAT:-PEM}"
BUILD_LIST="${BUILD_LIST:-base:bitbake,wpe:bitbake,refui:refui}"
BOLTS_DIR="${BOLTS_DIR:-/build/bolts}"

build_args=(
  --private-key "$PRIVATE_KEY_PATH"
  --public-key "$PUBLIC_KEY_PATH"
  --key-format "$KEY_FORMAT"
  --bolts-dir "$BOLTS_DIR"
  --build-list "$BUILD_LIST"
)

if [[ -n "$PRIVATE_KEY_PASSPHRASE" ]]; then
  build_args+=(--key-passphrase "$PRIVATE_KEY_PASSPHRASE")
fi

bash gen-bolt-pkgs.sh "${build_args[@]}"
