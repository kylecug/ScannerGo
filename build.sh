#!/usr/bin/env bash
# 在 Linux 上用 clang + ld64.lld 交叉编译 iOS app，打包成未签名 IPA（LiveContainer 会自己签）
# 用法: SDK=/path/to/iPhoneOS16.5.sdk ./build.sh
set -euo pipefail
cd "$(dirname "$0")"
: "${SDK:?请设置 SDK=iPhoneOS.sdk 路径（可从 github.com/theos/sdks 下载）}"
APP=HelloWorldLong
rm -rf build && mkdir -p build/Payload/$APP.app
clang -target arm64-apple-ios15.0 -isysroot "$SDK" -fobjc-arc -O2 \
  -fuse-ld=lld -Wl,-adhoc_codesign \
  -framework UIKit -framework Foundation -framework AVFoundation \
  main.m -o build/Payload/$APP.app/$APP
cp Info.plist build/Payload/$APP.app/
printf 'APPL????' > build/Payload/$APP.app/PkgInfo
(cd build && zip -qr ../$APP.ipa Payload)
echo "搞掂: $(pwd)/$APP.ipa"
