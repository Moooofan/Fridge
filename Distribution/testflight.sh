#!/bin/zsh
# 一鍵 Archive + 上傳 TestFlight。前置：Xcode 已登入 Apple 開發者帳號、project.yml 的 DEVELOPMENT_TEAM 已填、
# App Store Connect 已建立 Bundle ID 為 com.moooofan.fridge 的 App。
set -e
cd "$(dirname "$0")/.."
xcodegen generate
ARCHIVE=build/Fridge.xcarchive
xcodebuild -project Fridge.xcodeproj -scheme Fridge -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist Distribution/ExportOptions.plist -exportPath build/export \
  -allowProvisioningUpdates
echo "✅ 已上傳，到 App Store Connect > TestFlight 等待處理（約 10–30 分鐘）。"
