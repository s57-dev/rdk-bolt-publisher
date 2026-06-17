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
PRIVATE_KEY_PASSPHRASE="${PRIVATE_KEY_PASSPHRASE:-}"
KEY_FORMAT="${KEY_FORMAT:-PEM}"
BUILD_LIST="${BUILD_LIST:-base:bitbake,wpe:bitbake,refui:refui}"
BOLT_MACHINE="${BOLT_MACHINE:-arm}"
BOLTS_DIR="${BOLTS_DIR:-/build/bolts}"
BOLT_DL_DIR="${BOLT_DL_DIR:-/build/downloads}"
BOLT_SSTATE_DIR="${BOLT_SSTATE_DIR:-/build/sstate-cache}"
MANIFEST_FILE="${MANIFEST_FILE:-${BOLTS_DIR}/factory-app-version.json}"

if [[ -z "${SIGNING_CERT_PATH:-}" ]]; then
  if [[ -f /build/keys/signing-cert.pem ]]; then
    SIGNING_CERT_PATH=/build/keys/signing-cert.pem
  else
    SIGNING_CERT_PATH=/build/keys/certificate.pem
  fi
fi

case "$BOLT_MACHINE" in
  arm|arm64|amd64) ;;
  *)
    echo "Unsupported BOLT_MACHINE: $BOLT_MACHINE"
    echo "Supported values: arm, arm64, amd64"
    exit 1
    ;;
esac

python3 - <<'PY'
import re
from pathlib import Path

path = Path("/build/work/gen-bolt-pkgs.sh")
text = path.read_text(encoding="utf-8")
marker = "BOLT_MACHINE_OVERRIDE"
if marker in text:
    raise SystemExit(0)

pattern = re.compile(r"^([ \t]*)source setup-environment\s*$", re.MULTILINE)
match = pattern.search(text)
if not match:
    raise SystemExit("Unable to patch gen-bolt-pkgs.sh for machine override")

indent = match.group(1)
injection = f"""{indent}source setup-environment
{indent}if [ -n "${{BOLT_MACHINE_OVERRIDE:-}}" ] && [ -n "${{BUILDDIR:-}}" ] && [ -f "${{BUILDDIR}}/conf/local.conf" ]; then
{indent}    echo "Configuring MACHINE=${{BOLT_MACHINE_OVERRIDE}} in ${{BUILDDIR}}/conf/local.conf"
{indent}    if grep -qE '^[[:space:]]*MACHINE[[:space:]]*=' "${{BUILDDIR}}/conf/local.conf"; then
{indent}        sed -i -E "s|^[[:space:]]*MACHINE[[:space:]]*=.*$|MACHINE = \\"${{BOLT_MACHINE_OVERRIDE}}\\"|" "${{BUILDDIR}}/conf/local.conf"
{indent}    else
{indent}        echo "MACHINE = \\"${{BOLT_MACHINE_OVERRIDE}}\\"" >> "${{BUILDDIR}}/conf/local.conf"
{indent}    fi
{indent}fi"""

text = text[:match.start()] + injection + text[match.end():]
path.write_text(text, encoding="utf-8")
PY

build_args=(
  --private-key "$PRIVATE_KEY_PATH"
  --signing-certificate "$SIGNING_CERT_PATH"
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

BOLT_MACHINE_OVERRIDE="$BOLT_MACHINE" bash gen-bolt-pkgs.sh "${build_args[@]}"
