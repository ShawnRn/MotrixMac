#!/usr/bin/env bash

# MotrixMac Compile, Package, and Run Script (Refined)
# Inspired by reference scripts with structured logging and safety checks.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MotrixMac"
CURRENT_ARCH="$(uname -m)"
APP_BUNDLE="${ROOT_DIR}/${APP_NAME}_${CURRENT_ARCH}.app"
APP_PROCESS_PATTERN="${APP_NAME}.*app/Contents/MacOS/${APP_NAME}"
APP_SUPPORT_DIR="${HOME}/Library/Application Support/${APP_NAME}"
ARIA2_CONFIG="${APP_SUPPORT_DIR}/aria2.conf"
ARIA2_PROCESS_PATTERN="aria2c .*Application Support/${APP_NAME}/aria2.conf"

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

shutdown_aria2_gracefully() {
  [[ -f "${ARIA2_CONFIG}" ]] || return 0

  local port secret
  port="$(awk -F= '/^rpc-listen-port=/{print $2}' "${ARIA2_CONFIG}" | tail -n 1)"
  secret="$(awk -F= '/^rpc-secret=/{print $2}' "${ARIA2_CONFIG}" | tail -n 1)"
  [[ -n "${port}" && -n "${secret}" ]] || return 0

  local endpoint="http://127.0.0.1:${port}/jsonrpc"
  curl -sS --max-time 2 "${endpoint}" \
    -H 'Content-Type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":\"save\",\"method\":\"aria2.saveSession\",\"params\":[\"token:${secret}\"]}" >/dev/null || true
  curl -sS --max-time 2 "${endpoint}" \
    -H 'Content-Type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":\"shutdown\",\"method\":\"aria2.shutdown\",\"params\":[\"token:${secret}\"]}" >/dev/null || true
}

kill_all_instances() {
  log "==> Killing existing ${APP_NAME} instances"
  shutdown_aria2_gracefully
  
  # Phase 1: Graceful termination (+ handle both process name and path pattern)
  for _ in {1..20}; do
    pkill -x "${APP_NAME}" 2>/dev/null || true
    pkill -f "${APP_PROCESS_PATTERN}" 2>/dev/null || true
    
    if ! pgrep -f "${APP_PROCESS_PATTERN}" >/dev/null 2>&1 &&
       ! pgrep -f "${ARIA2_PROCESS_PATTERN}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
  done

  # Phase 2: Force termination if still alive
  if pgrep -f "${APP_PROCESS_PATTERN}" >/dev/null 2>&1 ||
     pgrep -f "${ARIA2_PROCESS_PATTERN}" >/dev/null 2>&1; then
    log "WARNING: ${APP_NAME} did not exit gracefully, forcing kill..."
    pkill -9 -x "${APP_NAME}" 2>/dev/null || true
    pkill -9 -f "${APP_PROCESS_PATTERN}" 2>/dev/null || true
    pkill -9 -f "${ARIA2_PROCESS_PATTERN}" 2>/dev/null || true
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
open -n "${APP_BUNDLE}"

# 4) Verify
log "==> Verifying application state"
for _ in {1..10}; do
  if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
    log "OK: ${APP_NAME} is running"
    log "==> All development loop steps completed successfully."
    exit 0
  fi
  sleep 0.5
done

fail "App exited immediately or failed to start."
