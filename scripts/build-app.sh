#!/bin/bash
# Build Ding.app bundle
# Usage: ./scripts/build-app.sh [--release]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="Ding"
BUNDLE_NAME="${APP_NAME}.app"

# Determine build configuration
if [[ "$1" == "--release" ]] || [[ "$1" == "-r" ]]; then
    CONFIG="release"
    BUILD_FLAGS="-c release"
else
    CONFIG="debug"
    BUILD_FLAGS=""
fi

echo "Building Ding.app (${CONFIG})..."

cd "$PROJECT_DIR"

# Build the Swift binary
echo "→ Compiling Swift..."
swift build $BUILD_FLAGS

# Determine binary path
BINARY_PATH=".build/${CONFIG}/ding"

if [[ ! -f "$BINARY_PATH" ]]; then
    echo "Error: Binary not found at $BINARY_PATH"
    exit 1
fi

# Create app bundle structure
echo "→ Creating app bundle..."
rm -rf "$BUNDLE_NAME"
mkdir -p "${BUNDLE_NAME}/Contents/MacOS"
mkdir -p "${BUNDLE_NAME}/Contents/Resources/icons"

# Copy binary
cp "$BINARY_PATH" "${BUNDLE_NAME}/Contents/MacOS/ding"

# Copy Info.plist (update version from VERSION file)
VERSION=$(cat VERSION 2>/dev/null || echo "1.0.0")
sed "s/1.0.0/${VERSION}/g" Resources/Info.plist > "${BUNDLE_NAME}/Contents/Info.plist"

# Copy icons
cp Resources/icons/*.png "${BUNDLE_NAME}/Contents/Resources/icons/"

# Copy VERSION file
cp VERSION "${BUNDLE_NAME}/Contents/Resources/"

# Make binary executable
chmod +x "${BUNDLE_NAME}/Contents/MacOS/ding"

# Show result
echo ""
echo "✓ Built ${BUNDLE_NAME}"
echo "  Binary: ${BUNDLE_NAME}/Contents/MacOS/ding"
echo "  Size: $(du -h "${BUNDLE_NAME}/Contents/MacOS/ding" | cut -f1)"
echo ""
echo "To install:"
echo "  cp -r ${BUNDLE_NAME} /Applications/"
echo "  sudo ln -sf /Applications/${BUNDLE_NAME}/Contents/MacOS/ding /usr/local/bin/ding"
echo ""
echo "To test:"
echo "  ./${BUNDLE_NAME}/Contents/MacOS/ding \"Hello\" -t \"Test\""
