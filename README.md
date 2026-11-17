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

## 安装方式一：LiveContainer 添加源（推荐，一刷新就有新版）

正式版统一发布在 [kylecug/ipa-release](https://github.com/kylecug/ipa-release)（所有 IPA 都在那里，跟 exe 分开）。
在 LiveContainer 的 **Sources（源）** 页点 **+**，填入：

```
https://raw.githubusercontent.com/kylecug/ipa-release/main/ipa/source.json
```

或者在 iPhone 上点：`livecontainer://source?url=https%3A%2F%2Fraw.githubusercontent.com%2Fkylecug%2Fipa-release%2Fmain%2Fipa%2Fsource.json`

## 安装方式二：手动下载

- 正式版：[ipa-release 的 Releases](https://github.com/kylecug/ipa-release/releases)，或本仓库 [Releases](https://github.com/kylecug/ScannerGo/releases) 里的 `scannerGo-vX.Y.Z.ipa`
- 开发预览版：[Releases → latest](https://github.com/kylecug/ScannerGo/releases/tag/latest)（每次 push 到 `main` 自动更新，不进源）

用 Safari 下载后存到"文件"，在 LiveContainer 里点 **+** 导入。未签名，LiveContainer 会自行签名。
如果预览黑屏，到 iOS 设置 → LiveContainer 打开相机权限。

## 发布新版本

```bash
git tag v1.1.0 && git push origin v1.1.0
```

GitHub Actions 会自动编译（版本号写进 App）并发布 release `v1.1.0`（附 `scannerGo-v1.1.0.ipa`，自动生成更新说明）。
`ipa-release` 每小时同步一次，把它搬过去并更新源；想立刻同步就去 ipa-release 的 Actions 手动运行 **Sync IPA**。

## 本地编译（Linux / macOS，不需要 Xcode）

需要 clang + ld64.lld（LLVM 18 测试通过）、curl、zip。

```bash
./build.sh                         # 自动下载 iPhoneOS16.5.sdk 到 .sdk/
SDK=/path/to/iPhoneOS.sdk ./build.sh   # 或者用自己的 SDK
VERSION=1.2.0 ./build.sh               # 指定版本号
# 输出 ./scannerGo.ipa
```

Ubuntu 上装依赖：`sudo apt-get install -y clang lld zip`
