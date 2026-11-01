#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
build_file=$(mktemp "${TMPDIR:-/tmp}/PPTTimer.XXXXXX")
trap 'rm -f "$build_file"' EXIT
swiftc main.swift -target arm64-apple-macos13.0 -o "$build_file" -framework AppKit -module-cache-path "${TMPDIR:-/tmp}/ppt-timer-module-cache"
mkdir -p 'PPT倒计时.app/Contents/MacOS' 'PPT倒计时.app/Contents/Resources'
cp packaging/Info.plist 'PPT倒计时.app/Contents/Info.plist'
cp assets/AppIcon.icns 'PPT倒计时.app/Contents/Resources/AppIcon.icns'
chmod +x "$build_file"
mv -f "$build_file" 'PPT倒计时.app/Contents/MacOS/PPTTimer'
codesign --force --sign - 'PPT倒计时.app'
