#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build/cache .build/modules
export CLANG_MODULE_CACHE_PATH="$PWD/.build/modules"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/modules"
swift build -c release -debug-info-format none --disable-sandbox --cache-path "$PWD/.build/cache"
bin_dir=$(swift build -c release -debug-info-format none --disable-sandbox --cache-path "$PWD/.build/cache" --show-bin-path)
app="$PWD/dist/Mac Authenticator.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/MacAuthenticator" "$app/Contents/MacOS/MacAuthenticator"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.lam.mac-authenticator</string>
<key>CFBundleName</key><string>Mac Authenticator</string>
<key>CFBundleDisplayName</key><string>Mac Authenticator</string>
<key>CFBundleExecutable</key><string>MacAuthenticator</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - --identifier local.lam.mac-authenticator "$app"
printf '\nBuilt: %s\n' "$app"
