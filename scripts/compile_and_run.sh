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
  
  # Phase 1: Graceful termination (+ handle both process name and path pattern)
  for _ in {1..5}; do
    pkill -x "${APP_NAME}" 2>/dev/null || true
    pkill -f "${APP_PROCESS_PATTERN}" 2>/dev/null || true
    
    if ! pgrep -f "${APP_PROCESS_PATTERN}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.3
  done

  # Phase 2: Force termination if still alive
  if pgrep -f "${APP_PROCESS_PATTERN}" >/dev/null 2>&1; then
    log "WARNING: ${APP_NAME} did not exit gracefully, forcing kill..."
    pkill -9 -x "${APP_NAME}" 2>/dev/null || true
    pkill -9 -f "${APP_PROCESS_PATTERN}" 2>/dev/null || true
    sleep 1
  fi
}

# --- Execution ---

# 1) Build
run_step "Building ${APP_NAME} (debug)" "${ROOT_DIR}/scripts/build.sh" debug

# 2) Cleanup
kill_all_instances

# 3) Launch
log "==> Launching app"
# Use direct binary execution instead of 'open' to keep stdout in terminal
"${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" &
APP_PID=$!
log "Launched ${APP_NAME} (PID: ${APP_PID})"

# 4) Verify
log "==> Verifying application state"
for _ in {1..10}; do
  if ps -p ${APP_PID} > /dev/null; then
    log "OK: ${APP_NAME} is running"
    log "==> All development loop steps completed successfully."
    exit 0
  fi
  sleep 0.5
done

fail "App exited immediately or failed to start."
