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

# 2. Build or Archive (Loop per architecture)
for TARGET_ARCH in "arm64" "x86_64"; do
    echo "=================================================="
    echo "==> Starting build process for architecture: ${TARGET_ARCH}"
    echo "=================================================="
    
    ARCH_APP_BUNDLE="${ROOT}/${PROJECT_NAME}_${TARGET_ARCH}.app"
    ARCH_ARCHIVE_PATH="${ROOT}/.build/archive/${PROJECT_NAME}_${TARGET_ARCH}.xcarchive"
    
    if [[ "$XCODE_CONF" == "Debug" ]]; then
        echo "==> Building project (${XCODE_CONF}) for ${TARGET_ARCH}..."
        xcodebuild build \
            -project "${PROJECT_NAME}.xcodeproj" \
            -scheme "${SCHEME}" \
            -configuration "${XCODE_CONF}" \
            -destination "generic/platform=macOS" \
            -scmProvider xcode \
            MARKETING_VERSION="${MARKETING_VERSION}" \
            CURRENT_PROJECT_VERSION="${BUILD_NUMBER}" \
            ARCHS="${TARGET_ARCH}" \
            CODE_SIGNING_ALLOWED=NO
        
        # Locate products using default DerivedData paths
        echo "==> Locating built app..."
        BUILT_PRODUCTS_DIR=$(xcodebuild -showBuildSettings -project "${PROJECT_NAME}.xcodeproj" -scheme "${SCHEME}" -configuration "${XCODE_CONF}" ARCHS="${TARGET_ARCH}" | grep -m 1 " BUILT_PRODUCTS_DIR =" | awk '{print $3}')
        
        if [[ -z "$BUILT_PRODUCTS_DIR" || ! -d "$BUILT_PRODUCTS_DIR/${APP_NAME}" ]]; then
            echo "ERROR: Could not locate built app in ${BUILT_PRODUCTS_DIR:-unknown}"
            exit 1
        fi
        
        rm -rf "${ARCH_APP_BUNDLE}"
        cp -R "${BUILT_PRODUCTS_DIR}/${APP_NAME}" "${ARCH_APP_BUNDLE}"
    else
        echo "==> Archiving project (${XCODE_CONF}) for ${TARGET_ARCH}..."
        xcodebuild archive \
            -project "${PROJECT_NAME}.xcodeproj" \
            -scheme "${SCHEME}" \
            -configuration "${XCODE_CONF}" \
            -archivePath "${ARCH_ARCHIVE_PATH}" \
            -destination "generic/platform=macOS" \
            -scmProvider xcode \
            MARKETING_VERSION="${MARKETING_VERSION}" \
            CURRENT_PROJECT_VERSION="${BUILD_NUMBER}" \
            ARCHS="${TARGET_ARCH}" \
            SKIP_INSTALL=NO \
            CODE_SIGNING_ALLOWED=NO
        
        echo "==> Exporting app bundle from archive for ${TARGET_ARCH}..."
        rm -rf "${ARCH_APP_BUNDLE}"
        cp -R "${ARCH_ARCHIVE_PATH}/Products/Applications/${APP_NAME}" "${ARCH_APP_BUNDLE}"
    fi

    # 3. Post-processing (Signing)
    SIGNING_IDENTITY="-"
    echo "==> Signing app bundle (Ad-hoc) for ${TARGET_ARCH}..."
    codesign --force --deep --sign "${SIGNING_IDENTITY}" "${ARCH_APP_BUNDLE}"

    echo "==> Successfully created ${ARCH_APP_BUNDLE}"

    # 4. Create DMG
    if command -v create-dmg &> /dev/null; then
        echo "==> Creating DMG with create-dmg for ${TARGET_ARCH}..."
        DMG_DIR="$ROOT/releases"
        mkdir -p "$DMG_DIR"
        
        # Target name for release.sh
        DMG_FINAL_NAME="${PROJECT_NAME}_${MARKETING_VERSION}_${TARGET_ARCH}.dmg"
        DMG_FINAL_PATH="$DMG_DIR/$DMG_FINAL_NAME"
        rm -f "$DMG_FINAL_PATH"
        
        # Temp app name inside DMG
        TEMP_APP_DIR="$ROOT/.build/tmp_${TARGET_ARCH}"
        mkdir -p "$TEMP_APP_DIR"
        cp -R "${ARCH_APP_BUNDLE}" "${TEMP_APP_DIR}/${APP_NAME}"
        
        # Run create-dmg in the DMG_DIR
        cd "$DMG_DIR"
        create-dmg "${TEMP_APP_DIR}/${APP_NAME}" "$DMG_DIR" || true
        cd "$ROOT"
        
        # Handle the generated DMG name ("App Version.dmg" or similar)
        if [[ -f "$DMG_DIR/${PROJECT_NAME} ${MARKETING_VERSION}.dmg" ]]; then
            mv "$DMG_DIR/${PROJECT_NAME} ${MARKETING_VERSION}.dmg" "$DMG_FINAL_PATH"
        elif [[ -f "$DMG_DIR/${PROJECT_NAME}.dmg" ]]; then
            mv "$DMG_DIR/${PROJECT_NAME}.dmg" "$DMG_FINAL_PATH"
        else
            # Fallback wildcard move if needed
            mv "$DMG_DIR"/${PROJECT_NAME}*.dmg "$DMG_FINAL_PATH" 2>/dev/null || true
        fi
        
        # Cleanup temp app dir
        rm -rf "$TEMP_APP_DIR"
        
        if [[ -f "$DMG_FINAL_PATH" ]]; then
            echo "==> Successfully created $DMG_FINAL_PATH"
        else
            echo "==> Warning: DMG creation might have failed or naming is unexpected for ${TARGET_ARCH}."
        fi
    else
        echo "==> Warning: create-dmg not found. Skipping DMG creation."
    fi
done
