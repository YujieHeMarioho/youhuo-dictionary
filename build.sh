#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
app="build/有活词典.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc src/Main.swift -target "$(uname -m)-apple-macos15.0" -O -o "build/YouhuoDictionary.new" -framework Cocoa -framework WebKit -framework PDFKit -framework Vision -framework Security -framework SwiftUI -framework Translation -framework AVFoundation -framework Speech -framework ApplicationServices -lsqlite3
mv -f "build/YouhuoDictionary.new" "$app/Contents/MacOS/YouhuoDictionary"
for file in src/*; do case "$file" in *.swift) ;; *) cp "$file" "$app/Contents/Resources/" ;; esac; done
if [ -f data/dictionary.sqlite.gz ]; then gzip -dc data/dictionary.sqlite.gz > "$app/Contents/Resources/dictionary.sqlite"; fi
if [ -f data/ECDICT-LICENSE.txt ]; then cp data/ECDICT-LICENSE.txt "$app/Contents/Resources/"; fi
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleName</key><string>有活词典</string><key>CFBundleDisplayName</key><string>有活词典</string><key>CFBundleIdentifier</key><string>com.mario.youhuo</string><key>CFBundleExecutable</key><string>YouhuoDictionary</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleShortVersionString</key><string>1.0</string><key>CFBundleVersion</key><string>1</string><key>NSMicrophoneUsageDescription</key><string>仅在你点击语音输入时使用麦克风，进行本地语音识别。</string><key>NSSpeechRecognitionUsageDescription</key><string>将你主动提供的语音或音频在设备上识别为文字。</string><key>NSServices</key><array><dict><key>NSMenuItem</key><dict><key>default</key><string>用有活词典查询</string></dict><key>NSMessage</key><string>lookupSelection</string><key>NSPortName</key><string>有活词典</string><key>NSSendTypes</key><array><string>public.utf8-plain-text</string></array></dict></array><key>NSHighResolutionCapable</key><true/><key>LSMinimumSystemVersion</key><string>15.0</string><key>CFBundleIconFile</key><string>AppIcon</string></dict></plist>
PLIST
codesign --force --deep --sign - "$app"
echo "$app"
