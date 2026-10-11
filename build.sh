#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
app="build/有活词典.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc src/Main.swift -target "$(uname -m)-apple-macos15.0" -O -o "build/YouhuoDictionary.new" -framework Cocoa -framework WebKit -framework PDFKit -framework Vision -framework Security -framework SwiftUI -framework Translation -framework AVFoundation -lsqlite3
mv -f "build/YouhuoDictionary.new" "$app/Contents/MacOS/YouhuoDictionary"
for file in src/*; do case "$file" in *.swift) ;; *) cp "$file" "$app/Contents/Resources/" ;; esac; done
if [ -f data/dictionary.sqlite.gz ]; then gzip -dc data/dictionary.sqlite.gz > "$app/Contents/Resources/dictionary.sqlite"; fi
if [ -f data/ECDICT-LICENSE.txt ]; then cp data/ECDICT-LICENSE.txt "$app/Contents/Resources/"; fi
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleName</key><string>有活词典</string><key>CFBundleDisplayName</key><string>有活词典</string><key>CFBundleIdentifier</key><string>com.mario.youhuo</string><key>CFBundleExecutable</key><string>YouhuoDictionary</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleShortVersionString</key><string>1.0</string><key>CFBundleVersion</key><string>1</string><key>NSHighResolutionCapable</key><true/><key>LSMinimumSystemVersion</key><string>15.0</string><key>CFBundleIconFile</key><string>AppIcon</string></dict></plist>
PLIST
codesign --force --deep --sign - "$app"
echo "$app"
