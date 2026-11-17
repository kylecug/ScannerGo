#!/usr/bin/env python3
"""根据 GitHub Releases 生成 LiveContainer / AltStore 源 (source.json)。

用法: gh api repos/OWNER/REPO/releases --paginate | python3 scripts/gen_source.py OWNER/REPO > source.json
只收录 tag 为 v* 的正式版本（不含 latest 预览版），新版本排在前面。
"""
import json
import sys

repo = sys.argv[1]
raw = sys.stdin.read()
# gh --paginate 会把多页 JSON 数组直接拼在一起，逐个解析
releases, dec, i = [], json.JSONDecoder(), 0
while i < len(raw):
    if raw[i].isspace():
        i += 1
        continue
    obj, i = dec.raw_decode(raw, i)
    releases.extend(obj)

versions = []
for r in releases:
    tag = r.get("tag_name", "")
    if r.get("draft") or not tag.startswith("v"):
        continue
    ipa = next((a for a in r.get("assets", []) if a["name"].endswith(".ipa")), None)
    if not ipa:
        continue
    v = tag[1:]
    versions.append({
        "version": v,
        "buildVersion": v,   # AltStore 用这个
        "buildNumber": v,    # LiveContainer 用这个
        "date": r.get("published_at") or r.get("created_at"),
        "localizedDescription": (r.get("body") or "").strip() or f"scannerGo {v}",
        "downloadURL": ipa["browser_download_url"],
        "size": ipa["size"],
        "minOSVersion": "15.0",
    })
versions.sort(key=lambda x: x["date"], reverse=True)

desc = ("打开摄像头自动识别二维码 / 条形码，结果追加到文本框并本地保存；"
        "识别到网址时提供「打开链接」按钮（不会自动打开）。")
app = {
    "name": "scannerGo",
    "bundleIdentifier": "com.kylecug.scannergo",
    "developerName": repo.split("/")[0],
    "subtitle": "二维码 / 条形码扫描",
    "localizedDescription": desc,
    "tintColor": "#007AFF",
    "category": "utilities",
    "screenshotURLs": [],
    "versions": versions,
    "appPermissions": {
        "entitlements": [],
        "privacy": {"NSCameraUsageDescription": "用摄像头扫描二维码和条形码"},
    },
}
if versions:  # 旧版客户端只认这几个字段
    app.update(version=versions[0]["version"], versionDate=versions[0]["date"],
               versionDescription=versions[0]["localizedDescription"],
               downloadURL=versions[0]["downloadURL"], size=versions[0]["size"])

source = {
    "name": "scannerGo 源",
    "identifier": "com.kylecug.scannergo.source",
    "subtitle": "kylecug 的自建源",
    "description": desc,
    "website": f"https://github.com/{repo}",
    "tintColor": "#007AFF",
    "apps": [app],
    "news": [],
}
json.dump(source, sys.stdout, ensure_ascii=False, indent=2)
sys.stdout.write("\n")
