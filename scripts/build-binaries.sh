#!/usr/bin/env bash
# Build single-file executables for Zerexa Video Server.
#
# Output:
#   zerexa-video-server-linux-x64         (ELF, self-contained)
#   zerexa-video-server-win-x64.exe       (PE32+, self-contained)
#
# Each binary is the Go launcher (~2 MB) with a base64-encoded tar.gz
# payload appended after the literal marker line __PAYLOAD_BELOW__.
# The payload contains:
#   node          - Node.js runtime (platform-native binary from nodejs.org)
#   standalone/   - Next.js standalone build (server.js + .next/ + public/ + node_modules)
#   run.sh        - POSIX launcher
#   run.bat       - Windows launcher
#
# Prerequisites:
#   - bun (for next build)
#   - go (for launcher cross-compile)
#   - curl + tar (for downloading Node binaries)

set -euo pipefail

VERSION="${1:-dev}"
OUT_DIR="${2:-/tmp/zerexa-binaries}"

# --- Config ---
NODE_VERSION="v22.11.0"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LAUNCHER_SRC="${PROJECT_ROOT}/scripts/launcher/main.go"
WORK_DIR="$(mktemp -d)"
PAYLOAD_DIR="${WORK_DIR}/payload"

cleanup() { rm -rf "${WORK_DIR}"; }
trap cleanup EXIT

mkdir -p "${PAYLOAD_DIR}" "${OUT_DIR}"

echo "[1/6] Building Next.js standalone..."
cd "${PROJECT_ROOT}"
bun install --frozen-lockfile
bunx prisma generate
bun run build

if [ ! -d ".next/standalone" ]; then
  echo "ERROR: .next/standalone missing after build" >&2
  exit 1
fi

echo "[2/6] Copying Next.js standalone into payload..."
cp -r .next/standalone "${PAYLOAD_DIR}/standalone"

# --- Create launcher scripts ---
cat > "${PAYLOAD_DIR}/run.sh" <<'RUN_SH'
#!/bin/sh
# Zerexa Video Server launcher (POSIX)
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}"
: "${PORT:=3000}"
: "${HOSTNAME:=0.0.0.0}"
: "${NODE_ENV:=production}"
export PORT HOSTNAME NODE_ENV
echo "Zerexa Video Server"
echo "  Listening:  http://${HOSTNAME}:${PORT}"
echo "  Working dir: ${SCRIPT_DIR}"
echo "  Press Ctrl+C to stop."
echo
exec ./node standalone/server.js "$@"
RUN_SH
chmod +x "${PAYLOAD_DIR}/run.sh"

cat > "${PAYLOAD_DIR}/run.bat" <<'RUN_BAT'
@echo off
REM Zerexa Video Server launcher (Windows)
cd /d "%~dp0"
if "%PORT%"=="" set PORT=3000
if "%HOSTNAME%"=="" set HOSTNAME=0.0.0.0
if "%NODE_ENV%"=="" set NODE_ENV=production
echo Zerexa Video Server
echo   Listening:  http://%HOSTNAME%:%PORT%
echo   Working dir: %CD%
echo   Press Ctrl+C to stop.
echo.
node.exe standalone\server.js %*
RUN_BAT

echo "[3/6] Downloading Node.js ${NODE_VERSION} binaries..."
NODE_LINUX_TARBALL="node-${NODE_VERSION}-linux-x64.tar.xz"
NODE_WIN_ZIP="node-${NODE_VERSION}-win-x64.zip"
NODE_LINUX_URL="https://nodejs.org/dist/${NODE_VERSION}/${NODE_LINUX_TARBALL}"
NODE_WIN_URL="https://nodejs.org/dist/${NODE_VERSION}/${NODE_WIN_ZIP}"

# Cache downloads in /tmp
mkdir -p /tmp/node-cache
if [ ! -f "/tmp/node-cache/${NODE_LINUX_TARBALL}" ]; then
  curl -fsSL "${NODE_LINUX_URL}" -o "/tmp/node-cache/${NODE_LINUX_TARBALL}"
fi
if [ ! -f "/tmp/node-cache/${NODE_WIN_ZIP}" ]; then
  curl -fsSL "${NODE_WIN_URL}" -o "/tmp/node-cache/${NODE_WIN_ZIP}"
fi

echo "[4/6] Cross-compiling Go launcher for linux-x64 + win-x64..."
LAUNCHER_DIR="$(dirname "${LAUNCHER_SRC}")"
# Init go.mod if missing
if [ ! -f "${LAUNCHER_DIR}/go.mod" ]; then
  ( cd "${LAUNCHER_DIR}" && go mod init zerexa-launcher )
fi
# Build from project root (so we don't lose cwd). Use GOENV=off + GOFLAGS=-mod=mod
# to avoid fetching anything; this is a self-contained single-file program.
GOFLAGS="-mod=mod" GOOS=linux   GOARCH=amd64 go build -C "${LAUNCHER_DIR}" -ldflags='-s -w' -o "${WORK_DIR}/launcher-linux"   .
GOFLAGS="-mod=mod" GOOS=windows GOARCH=amd64 go build -C "${LAUNCHER_DIR}" -ldflags='-s -w' -o "${WORK_DIR}/launcher-win.exe" .

echo "[5/6] Building Linux x64 single-file binary..."
# Add linux node binary to payload
rm -rf "${WORK_DIR}/node-linux"
mkdir -p "${WORK_DIR}/node-linux"
tar -xJf "/tmp/node-cache/${NODE_LINUX_TARBALL}" -C "${WORK_DIR}/node-linux" --strip-components=1
cp "${WORK_DIR}/node-linux/bin/node" "${PAYLOAD_DIR}/node"
chmod +x "${PAYLOAD_DIR}/node"

# Pack payload
LINUX_TAR="${WORK_DIR}/payload-linux.tar.gz"
tar -czf "${LINUX_TAR}" -C "${PAYLOAD_DIR}" .

# Assemble: launcher + marker + base64(payload)
# Use -w 0 to emit a single line (no 76-char wrapping); Go's
# StrictDecoder rejects wrapped base64 otherwise.
LINUX_OUT="${OUT_DIR}/zerexa-video-server-linux-x64"
cp "${WORK_DIR}/launcher-linux" "${LINUX_OUT}"
{
  echo
  echo "===ZEREXA-VIDEO-SERVER-PAYLOAD-BELOW-THIS-LINE-V1==="
  base64 -w 0 "${LINUX_TAR}"
} >> "${LINUX_OUT}"
chmod +x "${LINUX_OUT}"

echo "[6/6] Building Windows x64 single-file binary..."
# Add win node binary to payload (replace linux node)
rm -rf "${WORK_DIR}/node-win"
mkdir -p "${WORK_DIR}/node-win"
unzip -q -o "/tmp/node-cache/${NODE_WIN_ZIP}" -d "${WORK_DIR}/node-win"
cp "${WORK_DIR}/node-win/node-${NODE_VERSION}-win-x64/node.exe" "${PAYLOAD_DIR}/node.exe"

WIN_TAR="${WORK_DIR}/payload-win.tar.gz"
tar -czf "${WIN_TAR}" -C "${PAYLOAD_DIR}" .

WIN_OUT="${OUT_DIR}/zerexa-video-server-win-x64.exe"
cp "${WORK_DIR}/launcher-win.exe" "${WIN_OUT}"
{
  echo
  echo "===ZEREXA-VIDEO-SERVER-PAYLOAD-BELOW-THIS-LINE-V1==="
  base64 -w 0 "${WIN_TAR}"
} >> "${WIN_OUT}"

# --- Final stats ---
echo
echo "Done. Version: ${VERSION}"
ls -lh "${LINUX_OUT}" "${WIN_OUT}"
echo
echo "Test:"
echo "  PORT=3100 ${LINUX_OUT}"
