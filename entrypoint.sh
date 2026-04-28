#!/usr/bin/env bash
set -euo pipefail

BRANCH=main

git config --global user.email "builder@s57.io"
git config --global user.name "Github Builder"

cd /build
git clone https://github.com/rdkcentral/bolt-pkg-build-scripts work | true
cd /build/work

if [[ -n "${OPEN_SHELL:-}" ]]; then
  exec /bin/bash
fi

PRIVATE_KEY_PATH="${PRIVATE_KEY_PATH:-/build/keys/private_key.pem}"
PUBLIC_KEY_PATH="${PUBLIC_KEY_PATH:-/build/keys/public.pem}"
PRIVATE_KEY_PASSPHRASE="${PRIVATE_KEY_PASSPHRASE:-}"
KEY_FORMAT="${KEY_FORMAT:-PEM}"
BUILD_LIST="${BUILD_LIST:-base:bitbake,wpe:bitbake,refui:refui}"
BOLTS_DIR="${BOLTS_DIR:-/build/bolts}"
BOLT_DL_DIR="${BOLT_DL_DIR:-/build/downloads}"
BOLT_SSTATE_DIR="${BOLT_SSTATE_DIR:-/build/sstate-cache}"
MANIFEST_FILE="${MANIFEST_FILE:-${BOLTS_DIR}/factory-app-version.json}"

build_args=(
  --private-key "$PRIVATE_KEY_PATH"
  --public-key "$PUBLIC_KEY_PATH"
  --key-format "$KEY_FORMAT"
  --bolts-dir "$BOLTS_DIR"
  --bolt-dl-dir "$BOLT_DL_DIR"
  --bolt-sstate-dir "$BOLT_SSTATE_DIR"
  --manifest-file "$MANIFEST_FILE"
  --build-list "$BUILD_LIST"
)

if [[ -n "$PRIVATE_KEY_PASSPHRASE" ]]; then
  build_args+=(--key-passphrase "$PRIVATE_KEY_PASSPHRASE")
fi

bash gen-bolt-pkgs.sh "${build_args[@]}"

if [[ "$KEY_FORMAT" == "PEM" ]]; then
  SIGNING_CERT_PATH="${SIGNING_CERT_PATH:-/build/keys/public-cert.pem}"

  if [[ ! -f "$SIGNING_CERT_PATH" ]]; then
    echo "Error: PEM signing requires certificate file: $SIGNING_CERT_PATH"
    exit 1
  fi

  shopt -s nullglob
  bolts=("$BOLTS_DIR"/*.bolt)
  if [[ ${#bolts[@]} -eq 0 ]]; then
    echo "Error: no .bolt packages found in $BOLTS_DIR"
    exit 1
  fi

  for bolt in "${bolts[@]}"; do
    sign_cmd=(/usr/bin/ralfpack sign --key "$PRIVATE_KEY_PATH" --certificate "$SIGNING_CERT_PATH")
    if [[ -n "$PRIVATE_KEY_PASSPHRASE" ]]; then
      sign_cmd+=(--passphrase "$PRIVATE_KEY_PASSPHRASE")
    fi
    sign_cmd+=("$bolt")

    "${sign_cmd[@]}"
    /usr/bin/ralfpack verify --ca-roots "$SIGNING_CERT_PATH" "$bolt"
  done
fi
