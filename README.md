# LifeSense

每日生活状态监测助手，帮你量化记录心情、睡眠、精力等维度，自动计算 Life Score 并给出建议。

## 功能

- **每日打卡** — 记录心情、精力、压力、专注、睡眠、饮水、活动和备注
- **Life Score** — 本地规则引擎自动评分，生成状态标签与改善建议
- **历史记录** — 浏览、查看详情、删除单条记录
- **7 天趋势图** — 可视化近一周各维度变化，连续打卡天数统计
- **访客模式** — 无需账号，数据存本机，即装即用
- **云同步** — 注册账号后自动同步，多端一致，卸载重装可恢复
- **头像 & 昵称** — 个人资料云同步

## 技术栈

Flutter 3 · Dart · 华为 AGConnect (Auth / CloudDB / Cloud Storage) · Material 3

---

## 普通用户：直接下载安装

> **本应用为 Android 手机应用**，需要 Android 手机安装使用。

前往 [Releases](https://github.com/myzane678/LifeSense/releases) 下载最新 APK，安装后即可使用。

### 安装步骤

1. 在手机浏览器打开本页面，点击 APK 文件下载；或在电脑下载后通过数据线 / 微信 / QQ 传到手机
2. 在手机文件管理器找到下载的 APK 文件，点击安装
3. 若出现「安装未知应用」或「来源未知」提示，点击「仍然安装」或在设置中允许该来源即可，这是 Android 对非应用商店安装包的正常提示
4. 安装完成后打开 LifeSense，可选择注册账号或以访客身份直接使用

- **无需任何配置**，安装完直接打开
- 支持**访客模式**：不注册账号，数据仅存本机，也能完整使用所有记录功能
- 注册邮箱账号后，数据自动云同步，换机或重装后可恢复

---

## 开发者：本地构建

本项目云同步基于华为 AGConnect。自行构建时需完成以下步骤：

1. 在 [AGConnect 控制台](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html) 创建 Android 应用（包名 `com.example.life_sense`）
2. 开通 Auth、CloudDB、Cloud Storage 三项服务
3. 下载 `agconnect-services.json`，放至以下两处：
   - `android/app/agconnect-services.json`
   - `android/app/src/main/assets/agconnect-services.json`
4. 在 CloudDB 创建 zone `lifeSense`，导入 object type（见 `packages/agconnect_clouddb/android/.../objecttypes/`）

```bash
flutter pub get
flutter run
flutter build apk --release
```

---

## Changelog

### v1.1.0 (2026-07-09)

- **访客模式**：无需注册账号，安装即用；登录页新增「暂不登录，以访客身份使用」入口
- 设置页针对访客/已登录分别展示不同 UI，访客模式下提供注册引导
- 首页同步状态条新增访客模式标识「访客模式 · 数据仅存本机」
- README 区分普通用户（下载APK）和开发者（自行部署 AGC）两条路径

### v1.0.0 (2026-07-09)

首个正式发布版本，包含完整打卡、评分、历史记录和 AGConnect 云同步功能。
