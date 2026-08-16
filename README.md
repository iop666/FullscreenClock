# FullscreenClock
全屏时钟

一个从"极简全屏时钟"进化到「**时钟 + 日程管理**」一体的跨平台应用,支持 **Android** 与 **Windows (x64)**。

## ✨ 功能特性

### 🕐 时钟

<img width="2181" height="1094" alt="image" src="https://github.com/user-attachments/assets/96e75770-519d-47e2-94e1-9a4cccdda551" />

<img width="1387" height="757" alt="image" src="https://github.com/user-attachments/assets/19d23182-e964-40c3-911f-5e2283bbe0c2" />

<img width="2044" height="984" alt="image" src="https://github.com/user-attachments/assets/84e53d84-2fd6-40af-a48c-54d75ecd111e" />

- **标准数字时钟** — 超大字号,支持 12/24 小时制、AM/PM 标记、显示秒

<img width="1664" height="1331" alt="image" src="https://github.com/user-attachments/assets/e67b789c-e6ec-476f-a1d4-f4d927e522a0" />

<img width="1667" height="1332" alt="image" src="https://github.com/user-attachments/assets/41dd7a6a-12c9-493f-a650-c75bf2429dc4" />

- **圆盘时钟** — 极简 / 经典 / 罗马数字 / 圆点四种表盘样式,支持独立缩放

### 🎨 主题与配色

<img width="1082" height="952" alt="image" src="https://github.com/user-attachments/assets/928fcf15-6f1c-4478-b49a-fbeb96417229" />

- 明暗模式:**白天 / 黑夜 / 跟随系统**
- 内置 **6 套配色方案**:经典、墨蓝、翡翠、暖阳、紫罗兰、中国红
- **自定义配色**:背景 / 文字 / 强调三色自由组合,最多保存 10 套
- 字体颜色、背景颜色可独立自定义,白天与黑夜分别设置

### 🔤 字体

<img width="1080" height="1124" alt="image" src="https://github.com/user-attachments/assets/b78f67cf-1ff2-4ba0-a036-0fb4cf6d5e33" />

- 内置 **5 类字体**:默认、等宽、衬线、HarmonyOS Sans、MiSans
- 支持 **运行时导入** .ttf / .otf 自定义字体,无需重新编译

### 📅 计划管理(核心)

<img width="1162" height="903" alt="image" src="https://github.com/user-attachments/assets/439bd1c6-9496-4715-bdad-9e5ef7df734d" />

- **三级标签**:类型 → 主题 → 单元,结构化分类与检索
- **完整状态机**:未开始 → 进行中 → 暂停 → 超时 → 完成 / 跳过,支持撤销
- **冲突拦截**:同一时间段不允许并存计划(新建 / 编辑 / 提前延后 / 导入均拦截)
- **自动顺延**:当前计划进行中时,后续计划自动顺延、不被误启动
- **候选清单**:类型 → 主题 → 单元 → 标题四层结构,文件管理器式逐级浏览、按层级添加、导入 / 粘贴导入 / 导出
- **计划列表 / 查看全部**:今日 / 明日 / 本周 / 本月,三级筛选 + 搜索 + 日期
- **通知系统**:开始 / 超时 / 提前提醒、常驻通知(预计结束 + 下一计划)、精确闹钟、灵动岛兼容
- **统计与历史**:完成率、实际投入、历史记录、导出统计报告
- **AI 辅助**:一键生成计划 JSON / 候选清单 JSON 的规范提示词

### 🎛️ 主界面计划显示

<img width="1847" height="1015" alt="image" src="https://github.com/user-attachments/assets/2daf1b13-d05e-476e-859b-db75a7e778e2" />

<img width="1963" height="995" alt="image" src="https://github.com/user-attachments/assets/04e8110f-d050-428f-97b6-5ccc7986175a" />

<img width="1271" height="1260" alt="image" src="https://github.com/user-attachments/assets/3cbf1633-3bc0-46f0-80d1-202809197b8b" />

- 当前计划卡片:多行标题、已执行 / 剩余时间、进度环、颜色条、图标
- 加时 / 减时、撤销、超时显示、位置预设与布局模式

### 📱 平台特性
- **Android**:沉浸式全屏、陀螺仪自动横竖屏、横屏锁定按钮、帧率变化省电(标准模式无操作自动降频,触摸恢复)
- **Windows**:默认窗口模式,`F11` / `ESC` 切换全屏,右上角全屏按钮(无操作自动隐藏)

---

## 📂 仓库结构

```
FullscreenClock/
├── 1.0.0/          v1.0.0 源码(纯全屏时钟)
├── 1.2.0/          v1.2.0 源码(时钟 + 计划管理,含 skill/ AI 生成)
└── Releases       各版本安装包(APK + Windows 安装版 / 便携版)
```

每个版本目录均为**完整可重建的 Flutter 工程**(`lib/`、`android/`、`windows/`、`assets/`、`test/`)。

---

## 📥 下载与安装

请前往 **[Releases](https://github.com/iop666/FullscreenClock/releases)** 下载对应版本:

- **Android**:按设备架构选择 APK
  - `arm64-v8a`(64 位,推荐)· `armeabi-v7a`(32 位旧机)· `x86_64`(模拟器)· `all-abi`(通用)
- **Windows (x64)**
  - `windows-x64_setup.exe` — 安装版(Inno Setup),自动安装并创建快捷方式
  - `windows-x64.zip` — 便携版,解压即用

---

## 🔨 从源码构建

```bash
flutter pub get
flutter build apk --release --split-per-abi   # Android
flutter build windows --release               # Windows
```

> 国内网络建议配置镜像:
> ```
> PUB_HOSTED_URL=https://pub.flutter-io.cn
> FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
> ```

## 🧪 测试
```bash
flutter analyze   # 0 issues
flutter test      # 全部通过
```

---

## 🧱 技术栈

- **框架**:Flutter 3.47 / Dart 3.13
- **状态管理**:原生 `ChangeNotifier` + `ListenableBuilder`(无第三方状态管理)
- **主要依赖**:`shared_preferences`、`wakelock_plus`、`window_manager`、`flutter_local_notifications`、`url_launcher`、`file_selector`、`path_provider`、`package_info_plus`、`flutter_localizations`
- **平台能力**:Android 沉浸式 / 通知 / 前台服务 / 精确闹钟 / MethodChannel,Windows 全屏窗口

---

## 📄 许可证

本项目基于 **MIT** 许可证发布。

## 🙏 致谢

- 配色灵感参考 [zhongguose.com](https://zhongguose.com)
- 内置字体版权归原厂商所有,官方许可协议随源码附于 `assets/fonts/`:
  - **HarmonyOS Sans**(华为 · HarmonyOS Sans Fonts License Agreement)
  - **MiSans**(小米 · MiSans Font Intellectual Property License Agreement)
