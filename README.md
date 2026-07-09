# LifeSense

每日生活状态监测助手，帮你量化记录心情、睡眠、精力等维度，自动计算 Life Score 并给出建议。

## 功能

- **每日打卡** — 记录心情、精力、压力、专注、睡眠、饮水、活动和备注
- **Life Score** — 本地规则引擎自动评分，生成状态标签与改善建议
- **历史记录** — 浏览、查看详情、删除单条记录
- **7 天趋势图** — 可视化近一周各维度变化，连续打卡天数统计
- **云同步** — 华为 AGConnect CloudDB，多端数据一致，卸载重装自动恢复
- **头像 & 昵称** — AGConnect Cloud Storage + CloudDB 云同步

## 技术栈

Flutter 3 · Dart · 华为 AGConnect (Auth / CloudDB / Cloud Storage) · Material 3

## 下载

前往 [Releases](https://github.com/myzane678/LifeSense/releases) 下载最新 APK。

> 需要华为 AGConnect 配置文件（`agconnect-services.json`）才能使用云同步功能。自行部署时请在 AGC 控制台创建应用并下载配置文件放至 `android/app/` 及 `android/app/src/main/assets/`。

## 本地构建

```bash
# 依赖
flutter pub get

# 放置 agconnect-services.json（见上方说明）

# 调试
flutter run

# Release APK
flutter build apk --release
```

## Changelog

### v1.0.0 (2026-07-09)

首个正式发布版本，包含完整打卡、评分、历史记录和 AGConnect 云同步功能。
