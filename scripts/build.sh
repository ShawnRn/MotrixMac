#!/usr/bin/env bash

# MotrixMac Build & Package Script (Xcode-free)
# Usage: ./scripts/build.sh [debug|release]

set -euo pipefail

CONF=${1:-release}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

PROJECT_NAME="MotrixMac"
SCHEME="MotrixMac"
APP_NAME="MotrixMac.app"
ARCHIVE_PATH="$ROOT/.build/archive/${PROJECT_NAME}.xcarchive"
APP_BUNDLE="$ROOT/${APP_NAME}"

# Detect version from Xcode project if not set
echo "==> Detecting version from project settings..."
# Run without pipefail to avoid SIGPIPE (141) if grep exits early
XCODE_SETTINGS=$(set +o pipefail; xcodebuild -showBuildSettings -project "${PROJECT_NAME}.xcodeproj" -scheme "${SCHEME}" -configuration "${CONF}" 2>/dev/null)
MARKETING_VERSION=$(echo "$XCODE_SETTINGS" | grep " MARKETING_VERSION =" | head -n 1 | awk '{print $3}')
BUILD_NUMBER=$(echo "$XCODE_SETTINGS" | grep " CURRENT_PROJECT_VERSION =" | head -n 1 | awk '{print $3}')

# Use version.env as an override if it exists
if [[ -f "$ROOT/version.env" ]]; then
    echo "==> Applying version.env overrides..."
    source "$ROOT/version.env"
fi

echo "==> Version: ${MARKETING_VERSION} (Build: ${BUILD_NUMBER})"

# Detect architecture
ARCH=$(uname -m)
SDK="macosx"

if [[ "$CONF" == "debug" ]]; then
    XCODE_CONF="Debug"
else
    XCODE_CONF="Release"
fi

# 1. Resolve dependencies
echo "==> Resolving package dependencies..."
xcodebuild -resolvePackageDependencies -project "${PROJECT_NAME}.xcodeproj" -scheme "${SCHEME}" -scmProvider xcode

# 2. Build or Archive
if [[ "$XCODE_CONF" == "Debug" ]]; then
    echo "==> Building project (${XCODE_CONF}) for ${ARCH}..."
    xcodebuild build \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "${SCHEME}" \
        -configuration "${XCODE_CONF}" \
        -destination "generic/platform=macOS" \
        -scmProvider xcode \
        MARKETING_VERSION="${MARKETING_VERSION}" \
        CURRENT_PROJECT_VERSION="${BUILD_NUMBER}" \
        CODE_SIGNING_ALLOWED=NO
    
    # Locate products using default DerivedData paths
    echo "==> Locating built app..."
    BUILT_PRODUCTS_DIR=$(xcodebuild -showBuildSettings -project "${PROJECT_NAME}.xcodeproj" -scheme "${SCHEME}" -configuration "${XCODE_CONF}" | grep -m 1 " BUILT_PRODUCTS_DIR =" | awk '{print $3}')
    
    if [[ -z "$BUILT_PRODUCTS_DIR" || ! -d "$BUILT_PRODUCTS_DIR/${APP_NAME}" ]]; then
        echo "ERROR: Could not locate built app in ${BUILT_PRODUCTS_DIR:-unknown}"
        exit 1
    fi
    
    rm -rf "${APP_BUNDLE}"
    cp -R "${BUILT_PRODUCTS_DIR}/${APP_NAME}" "${ROOT}/"
else
    echo "==> Archiving project (${XCODE_CONF}) for ${ARCH}..."
    xcodebuild archive \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "${SCHEME}" \
        -configuration "${XCODE_CONF}" \
        -archivePath "${ARCHIVE_PATH}" \
        -destination "generic/platform=macOS,name=Any Mac" \
        -scmProvider xcode \
        MARKETING_VERSION="${MARKETING_VERSION}" \
        CURRENT_PROJECT_VERSION="${BUILD_NUMBER}" \
        SKIP_INSTALL=NO
    
    echo "==> Exporting app bundle from archive..."
    rm -rf "${APP_BUNDLE}"
    cp -R "${ARCHIVE_PATH}/Products/Applications/${APP_NAME}" "${ROOT}/"
fi

# 3. Post-processing (Signing)
SIGNING_IDENTITY="-"
echo "==> Signing app bundle (Ad-hoc)..."
codesign --force --deep --sign "${SIGNING_IDENTITY}" "${APP_BUNDLE}"

echo "==> Successfully created ${APP_BUNDLE}"
