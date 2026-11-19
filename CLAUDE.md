# ScannerGo 工作约定

## 改完代码自动推送并发版（仓库主人的长期要求，无需再确认）

每次功能/修复改完：

1. `./build.sh` 本地编译，必须零 warning、零 error
2. 提交并推送到工作分支
3. 开 PR 合并到 `main`（直接 push main 会被代理拒绝，用 GitHub MCP 的 create/merge pull request）
4. 手动触发 `build.yml` 工作流（ref=`main`），`version` 填新版本号：
   - 新功能升 minor（1.2.0 → 1.3.0），纯修复升 patch（1.2.0 → 1.2.1）
   - 现有版本号用 `git ls-remote --tags origin` 查
5. 等工作流跑完，确认 release `vX.Y.Z` 和 `source.json` 已更新

只改文档 / CI 配置、不影响 App 的改动：合并即可，不发版。

## 项目备注

- 单文件 Objective-C：`main.m`；新增 framework 记得同步改 `build.sh`
- 没有真机，UI / 手感类改动要提醒用户真机验证
