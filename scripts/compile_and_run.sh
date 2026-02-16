#!/usr/bin/env bash

# MotrixMac Compile, Package, and Run Script (Refined)
# Inspired by reference scripts with structured logging and safety checks.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MotrixMac"
APP_BUNDLE="${ROOT_DIR}/${APP_NAME}.app"
APP_PROCESS_PATTERN="${APP_NAME}.app/Contents/MacOS/${APP_NAME}"

# Structured logging
log()  { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

run_step() {
  local label="$1"; shift
  log "==> ${label}"
  if ! "$@"; then
    fail "${label} failed"
  fi
}

kill_all_instances() {
  log "==> Killing existing ${APP_NAME} instances"
  # Phase 1: Request termination
  for _ in {1..10}; do
    pkill -x "${APP_NAME}" 2>/dev/null || true
    if ! pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done
  # Phase 2: Force kill
  pkill -9 -x "${APP_NAME}" 2>/dev/null || true
  sleep 0.5
}

# --- Execution ---

# 1) Build
run_step "Building ${APP_NAME} (debug)" "${ROOT_DIR}/scripts/build.sh" debug

# 2) Cleanup
kill_all_instances

# 3) Launch
log "==> Launching app"
if ! open "${APP_BUNDLE}"; then
  fail "Failed to launch ${APP_BUNDLE}"
fi

# 4) Verify
log "==> Verifying application state"
for _ in {1..10}; do
  if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
    log "OK: ${APP_NAME} is running (PID: $(pgrep -x "${APP_NAME}"))"
    log "==> All development loop steps completed successfully."
    exit 0
  fi
  sleep 0.5
done

fail "App exited immediately or failed to start."
