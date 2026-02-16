#!/usr/bin/env bash

# MotrixMac One-click Build & Run (Xcode-free)
# Usage: ./scripts/run.sh

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

APP_NAME="MotrixMac.app"
APP_BUNDLE="$ROOT/${APP_NAME}"

# 1. Build the app (Debug mode for faster dev loop)
./scripts/build.sh debug

# 2. Kill existing instance
echo "==> Killing existing instances..."
pkill -x MotrixMac || true

# 3. Launch the app
echo "==> Launching ${APP_NAME}..."
open "${APP_BUNDLE}"

echo "==> MotrixMac is running!"
