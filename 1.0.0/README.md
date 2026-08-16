# FullscreenClock
全屏时钟

一个专注于查看时间的极简全屏时钟应用。支持 **Android** 与 **Windows (x64)**,提供标准数字时钟与圆盘(表盘)时钟,深/浅主题、丰富配色、多字体与沉浸式全屏体验。

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

### 🎛️ 显示与交互
- 时钟缩放 **10%~1000%**,字体粗细 100~900
- 屏幕常亮(唤醒锁),长时间查看不断屏
- 点击屏幕进入设置,所有设置**实时生效并自动持久化**

### 📱 平台特性
- **Android**:沉浸式全屏、陀螺仪自动横竖屏、横屏锁定按钮、帧率变化省电(标准模式无操作自动降频,触摸恢复)
- **Windows**:默认窗口模式,`F11` / `ESC` 切换全屏,右上角全屏按钮(无操作自动隐藏)

## 📦 安装包

### Android
| 文件 | 架构 | 说明 |
| --- | --- | --- |
| `FullscreenClock_1.0.0_arm64-v8a.apk` | arm64-v8a | 64 位 ARM 设备(推荐) |
| `FullscreenClock_1.0.0_armeabi-v7a.apk` | armeabi-v7a | 32 位 ARM 旧设备 |
| `FullscreenClock_1.0.0_x86_64.apk` | x86_64 | x86_64 模拟器 |
| `FullscreenClock_1.0.0_all-abi.apk` | 全 ABI | 通用包 |

### Windows (x64)
- `FullscreenClock_1.0.0_windows-x64_setup.exe` — 标准安装向导(开始菜单 / 桌面快捷方式)
- `FullscreenClock_1.0.0_windows-x64.zip` — 免安装便携版,解压即用

## 🚀 快速开始
- **Android**:安装对应 ABI 的 APK 后打开,即为全屏时钟;点击屏幕进入设置
- **Windows**:运行 `fullscreen_clock.exe`,按 `F11` 进入全屏,`ESC` 退出

## ⚙️ 设置项一览
| 分组 | 设置项 |
| --- | --- |
| 显示模式 | 时钟模式(标准 / 圆盘) |
| 外观 | 明暗模式、主题配色方案、自定义配色 |
| 时钟设置 | 字体、字体颜色、背景颜色、字体粗细、时钟缩放 |
| 圆盘表盘 | 表盘样式、圆盘缩放 |
| 时间 | 24 小时制、显示秒 |
| 其他 | 屏幕常亮、配色参考 |

## 🧱 技术栈
- **框架**:Flutter 3.47 / Dart 3.13
- **依赖**:`shared_preferences`(设置持久化)、`wakelock_plus`(屏幕常亮)、`window_manager`(Windows 全屏)、`url_launcher`、`file_selector`、`path_provider`、`package_info_plus`
- **平台能力**:Android 沉浸式、MethodChannel(刷新率 / 方向)、Windows 全屏窗口

## 🔨 从源码构建
```bash
flutter pub get

# Android release(按 ABI 拆分 + 混淆)
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols

# Windows release
flutter build windows --release
```
> 国内网络建议配置镜像:
> ```
> PUB_HOSTED_URL=https://pub.flutter-io.cn
> FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
> ```

## 📁 项目结构
```
lib/
├── main.dart                入口:加载设置与导入字体
├── app.dart                 应用根组件
├── models/                  设置数据模型
├── providers/               状态管理(ChangeNotifier)
├── screens/                 时钟显示页 / 设置页
├── services/                窗口、方向、字体、刷新率服务
├── theme/                   配色方案解析
├── utils/                   时间格式化
└── widgets/                 标准时钟 / 圆盘时钟
```

## 📄 许可证
本项目基于 MIT 许可证发布。

## 🙏 字体声明
- **HarmonyOS Sans**：版权 © 2021 华为终端有限公司。
- **MiSans**：版权 © 小米科技有限责任公司。
