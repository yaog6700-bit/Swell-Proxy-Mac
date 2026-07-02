#!/bin/bash
# Clean build, deep codesign with entitlements, and package Swell Proxy for distribution.
set -e

PROJECT_DIR="/Users/dododook/Downloads/BaoLianDeng-main"
APP_NAME="Swell Proxy"
ENTITLEMENTS_PATH="${PROJECT_DIR}/BaoLianDeng/BaoLianDeng.entitlements"
DERIVED_DATA_DIR="${PROJECT_DIR}/BuildDerivedData"
OUTPUT_APP="${PROJECT_DIR}/${APP_NAME}.app"
OUTPUT_ZIP="${PROJECT_DIR}/Swell_Proxy_Release.zip"

cd "$PROJECT_DIR"

echo "=== Step 1: Clean build environment ==="
rm -rf "$DERIVED_DATA_DIR"
rm -rf "$OUTPUT_APP"
rm -f "$OUTPUT_ZIP"

echo "=== Step 2: Build SingBox FFI Framework ==="
make singbox-framework

echo "=== Step 3: Compile main application in Release mode ==="
xcodebuild clean build \
  -project BaoLianDeng.xcodeproj \
  -scheme BaoLianDeng \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY="" \
  | grep -E "error:|warning:|Succeeded" || true

echo "=== Step 4: Extract built application bundle ==="
BUILT_APP="${DERIVED_DATA_DIR}/Build/Products/Release/${APP_NAME}.app"
if [ ! -d "$BUILT_APP" ]; then
    echo "ERROR: Compiled application not found at ${BUILT_APP}!"
    exit 1
fi

cp -R "$BUILT_APP" "$OUTPUT_APP"
echo "Successfully copied application to ${OUTPUT_APP}."

echo "=== Step 5: Perform Deep Ad-Hoc Codesigning ==="
# 1. Sign nested bundles
if [ -d "${OUTPUT_APP}/Contents/Resources" ]; then
    find "${OUTPUT_APP}/Contents/Resources" -name "*.bundle" -exec codesign --force --sign - --options runtime {} \; 2>/dev/null || true
fi

# 2. Sign nested frameworks
if [ -d "${OUTPUT_APP}/Contents/Frameworks" ]; then
    find "${OUTPUT_APP}/Contents/Frameworks" -name "*.framework" -exec codesign --force --sign - --options runtime {} \; 2>/dev/null || true
fi

# 3. Sign the main application executable with the proper network entitlements file
codesign --force --sign - --entitlements "$ENTITLEMENTS_PATH" --options runtime "$OUTPUT_APP"

echo "=== Step 6: Verify Code Signature ==="
codesign --verify --deep --strict --verbose=2 "$OUTPUT_APP"
echo "--- Embedded Entitlements ---"
codesign -d --entitlements - "$OUTPUT_APP"

echo "=== Step 7: Clear Gatekeeper quarantine attributes ==="
xattr -cr "$OUTPUT_APP"

echo "=== Step 8: Register app with Launch Services ==="
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Support/lsregister -f "$OUTPUT_APP"

echo "=== Step 9: Package into ZIP file ==="
zip -qy -r "$OUTPUT_ZIP" "./${APP_NAME}.app"

echo "=== SUCCESS! Swell Proxy is ready! ==="
echo "App location: ${OUTPUT_APP}"
echo "Zip location: ${OUTPUT_ZIP}"
