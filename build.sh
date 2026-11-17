#!/usr/bin/env bash
# 用 clang + ld64.lld 交叉编译 iOS app，打包成未签名 IPA（LiveContainer 会自己签）
# 用法: ./build.sh            （没设 SDK 时自动下载 iPhoneOS16.5.sdk 到 .sdk/）
#       SDK=/path/to/iPhoneOS.sdk ./build.sh
#       VERSION=1.2.0 ./build.sh   （写入版本号）
set -euo pipefail
cd "$(dirname "$0")"
APP=scannerGo
SDK_URL="https://github.com/theos/sdks/releases/download/master-146e41f/iPhoneOS16.5.sdk.tar.xz"

if [ -z "${SDK:-}" ]; then
  SDK="$PWD/.sdk/iPhoneOS16.5.sdk"
  if [ ! -d "$SDK" ]; then
    echo "下载 iOS SDK ..."
    mkdir -p .sdk
    curl -fsSL "$SDK_URL" | tar -xJ -C .sdk
  fi
fi

rm -rf build "$APP.ipa" && mkdir -p "build/Payload/$APP.app"
clang -target arm64-apple-ios15.0 -isysroot "$SDK" -fobjc-arc -O2 -Wall \
  -fuse-ld=lld -Wl,-adhoc_codesign \
  -framework UIKit -framework Foundation -framework AVFoundation \
  main.m -o "build/Payload/$APP.app/$APP"
cp Info.plist "build/Payload/$APP.app/"
# 可选: VERSION=1.2.0 ./build.sh 会把版本号写进 App
if [ -n "${VERSION:-}" ]; then
  sed -i.bak -E "s#(<key>CFBundleShortVersionString</key><string>)[^<]*#\1$VERSION#; s#(<key>CFBundleVersion</key><string>)[^<]*#\1$VERSION#" "build/Payload/$APP.app/Info.plist"
  rm -f "build/Payload/$APP.app/Info.plist.bak"
fi
printf 'APPL????' > "build/Payload/$APP.app/PkgInfo"
(cd build && zip -qr "../$APP.ipa" Payload)
echo "搞掂: $(pwd)/$APP.ipa"
