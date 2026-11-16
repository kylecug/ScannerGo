# scannerGo

[![Build IPA](https://github.com/kylecug/scannerGo/actions/workflows/build.yml/badge.svg)](https://github.com/kylecug/scannerGo/actions/workflows/build.yml)

一个极简 iOS 扫码 App（Objective-C + UIKit + AVFoundation）：打开摄像头，自动识别二维码 / 条形码，结果追加到文本框并本地保存。

## 功能

- 实时摄像头预览，自动识别，无需按键
- 支持 QR、EAN-13/8、UPC-E、Code128/39/93、PDF417、Aztec、DataMatrix、ITF
- 每条结果格式：`[HH:mm:ss 类型] 内容`；同一个码 3 秒内不重复记录
- 识别成功震动 + 绿框提示；文本框内容自动保存，可编辑、清空、一键复制
- 识别到 http/https 网址时右上角出现「打开链接」按钮，**不会自动打开**，点了还会再确认一次
- 最低 iOS 15

## 下载 & 安装（LiveContainer）

到 [Releases → latest](https://github.com/kylecug/scannerGo/releases/tag/latest) 下载 `scannerGo.ipa`，导入 LiveContainer 即可（未签名，LiveContainer 会自行签名）。
每次 push 到 `main`，GitHub Actions 会自动重新编译并更新这个 release；每次运行的 Artifacts 里也有一份。

如果预览黑屏，到 iOS 设置 → LiveContainer 打开相机权限。

## 本地编译（Linux / macOS，不需要 Xcode）

需要 clang + ld64.lld（LLVM 18 测试通过）、curl、zip。

```bash
./build.sh                         # 自动下载 iPhoneOS16.5.sdk 到 .sdk/
SDK=/path/to/iPhoneOS.sdk ./build.sh   # 或者用自己的 SDK
# 输出 ./scannerGo.ipa
```

Ubuntu 上装依赖：`sudo apt-get install -y clang lld zip`
