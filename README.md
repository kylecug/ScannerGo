# scannerGo

一个极简 iOS 扫码 App（Objective-C + UIKit + AVFoundation）：打开摄像头，自动识别二维码 / 条形码，结果追加到文本框并本地保存。

## 功能

- 实时摄像头预览，自动识别，无需按键
- 支持 QR、EAN-13/8、UPC-E、Code128/39/93、PDF417、Aztec、DataMatrix、ITF
- 每条结果格式：`[HH:mm:ss 类型] 内容`；同一个码 3 秒内不重复记录
- 识别成功震动 + 绿框提示；文本框内容自动保存，可编辑、清空、一键复制
- 最低 iOS 15

## 安装（LiveContainer）

直接把仓库里的 `HelloWorldLong.ipa` 导入 LiveContainer 即可（未签名，LiveContainer 会自行签名）。
如果预览黑屏，到 iOS 设置 → LiveContainer 打开相机权限。

## 编译（Linux / macOS 都行，不需要 Xcode）

需要 clang + ld64.lld（LLVM 18 测试通过）、zip，以及 iPhoneOS SDK（例如 [theos/sdks](https://github.com/theos/sdks) 的 iPhoneOS16.5.sdk）。

```bash
SDK=/path/to/iPhoneOS16.5.sdk ./build.sh
# 输出 ./HelloWorldLong.ipa
```
