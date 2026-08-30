#!/usr/bin/env bash
set -euo pipefail

if xcrun --find xctest >/dev/null 2>&1; then
    exec swift test "$@"
fi

developer_dir="$(xcode-select -p)"
frameworks_dir="$developer_dir/Library/Developer/Frameworks"
interop_dir="$developer_dir/Library/Developer/usr/lib"

if [[ ! -d "$frameworks_dir/Testing.framework" || ! -f "$interop_dir/lib_TestingInterop.dylib" ]]; then
    echo "Swift Testing is unavailable. Install or select a complete Xcode toolchain." >&2
    exit 1
fi

exec swift test --enable-swift-testing \
    -Xswiftc -F \
    -Xswiftc "$frameworks_dir" \
    -Xlinker "-F$frameworks_dir" \
    -Xlinker -rpath \
    -Xlinker "$frameworks_dir" \
    -Xlinker -rpath \
    -Xlinker "$interop_dir" \
    "$@"
