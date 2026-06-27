#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
configuration="${CONFIGURATION:-debug}"
bundle_name="Mac Workspace Switcher"
bundle_id="com.frittlechasm.mac-workspace-switcher"
executable_name="AppSwitcher"
build_dir="$repo_root/.build/$configuration"
bundle_path="$build_dir/$bundle_name.app"

swift build --configuration "$configuration" >&2

rm -rf "$bundle_path"
mkdir -p "$bundle_path/Contents/MacOS" "$bundle_path/Contents/Resources"

cp "$build_dir/$executable_name" "$bundle_path/Contents/MacOS/$executable_name"

cat > "$bundle_path/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$bundle_name</string>
    <key>CFBundleExecutable</key>
    <string>$executable_name</string>
    <key>CFBundleIdentifier</key>
    <string>$bundle_id</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$bundle_name</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>Mac Workspace Switcher needs Accessibility permission to list and focus windows.</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$bundle_path/Contents/PkgInfo"

echo "$bundle_path"
