# Fullscreen Clock 全屏时钟

一个专注查看时间、兼具**计划管理**的极简全屏时钟应用。支持 **Android** 与 **Windows (x64)**,提供标准数字时钟与圆盘(表盘)时钟,以及基于类型/主题/单元三级标签的日程计划系统。

> 当前版本:**v1.2.0**

---

## ✨ 功能特性

### 🕐 时钟
- **标准数字时钟** — 超大字号、自动适配屏幕,支持 12/24 小时制、AM/PM 标记、显示秒
- **圆盘时钟** — 极简 / 经典 / 罗马数字 / 圆点四种表盘样式,支持独立缩放(10%~300%)

### 🎨 主题与配色
- 明暗模式:**白天 / 黑夜 / 跟随系统**(根据系统亮度自动切换)
- 内置 **6 套配色**:经典、墨蓝、翡翠、暖阳、紫罗兰、中国红(每套含白天/黑夜两版)
- **自定义配色**:背景 / 文字 / 强调三色自由组合,最多保存 10 套
- 字体颜色、背景颜色可独立自定义,白天与黑夜分别记忆

### 🔤 字体
- 内置 **5 类字体**:默认、等宽、衬线、HarmonyOS Sans(6 字重)、MiSans(8 字重)
- 支持**运行时导入** `.ttf` / `.otf` 自定义字体,持久化保存、启动自动加载

### 📅 计划管理(核心)
- **三级标签**:类型(一级)→ 主题(二级)→ 单元(三级),计划的每一层都可检索、筛选
- **完整状态机**:未开始 → 进行中 → 暂停 → 超时 → 完成 / 跳过,支持撤销
- **冲突拦截**:不允许同一时间段的多个计划并存(新建 / 编辑 / 提前延后 / 导入均拦截)
- **自动顺延**:当前计划进行中且越过下一计划开始点,下一计划自动顺延、不会被误启动
- **候选清单**:类型→主题→单元→标题四层结构,**文件管理器式逐级浏览**,支持导入 / 粘贴导入 / 导出
- **计划列表**:今日 / 明日 / 本周 / 本月切换,时间正倒序,详情展开,提前 / 延后 / 删除
- **查看全部 / 所有未完成**:按类型、主题、单元三级筛选 + 关键字搜索 + 日期挑选
- **通知系统**:开始提醒、超时提醒、提前 10 分钟提醒、常驻通知(预计结束 + 下一计划)、精确闹钟
- **统计与历史**:今日 / 本周完成率、实际投入时长、历史记录、导出统计报告
- **导入 / 导出**:标准 JSON 格式,支持 AI 辅助生成计划

### 🎛️ 主界面计划显示
- 当前计划卡片:标题(可多行)、已执行 / 剩余时间、进度环、计划颜色条、图标
- **加时 / 减时**、**撤销**操作;超时显示「超时 xx」
- 模块位置预设(居中 / 左下 / 右下 / 两端)与布局模式(底部横条 / 时钟靠左 + 计划靠右)

### 📱 平台特性
- **Android**:沉浸式全屏、陀螺仪自动横竖屏、横屏锁定按钮、帧率变化省电、通知 / 前台服务 / 精确闹钟
- **Windows**:默认窗口模式,`F11` / `ESC` 切换全屏,右上角全屏按钮(无操作自动隐藏);UI 中文统一用系统字体渲染

---

## 📦 安装包

### Android

| 文件 | 架构 | 说明 |
| --- | --- | --- |
| `FullscreenClock_1.2.0_arm64-v8a.apk` | arm64-v8a | 64 位 ARM 设备(推荐) |
| `FullscreenClock_1.2.0_armeabi-v7a.apk` | armeabi-v7a | 32 位 ARM 旧设备 |
| `FullscreenClock_1.2.0_x86_64.apk` | x86_64 | x86_64 模拟器 |
| `FullscreenClock_1.2.0_all-abi.apk` | 全 ABI | 通用包 |

### Windows (x64)
- `FullscreenClock_1.2.0_windows-x64_setup.exe` — 安装版(Inno Setup 构建,约 12MB)
- `FullscreenClock_1.2.0_windows-x64.zip` — 免安装便携版,解压即用

---

## 🚀 快速开始
- **Android**:安装对应 ABI 的 APK 后打开,即为全屏时钟;点击屏幕进入设置
- **Windows**:运行安装版 `FullscreenClock_1.2.0_windows-x64_setup.exe` 安装,或解压便携版后运行 `fullscreen_clock.exe`;按 `F11` 进入全屏,`ESC` 退出
- **启用计划**:设置 → 计划 → 启用计划功能 → 进入计划列表创建计划

---

## ⚙️ 设置项一览

| 分组 | 设置项 |
| --- | --- |
| 外观 | 明暗模式、主题配色方案、自定义配色 |
| 显示设置 | 时钟显示设置(时钟样式 / 标准与圆盘参数 / 时间格式)、计划显示设置(计划模块参数) |
| 计划 | 启用计划功能、计划列表、候选清单、通知设置、统计与历史、计划生成帮助 |
| 其他 | 屏幕常亮、配色参考、恢复默认设置 |
| 关于 | 当前版本 |

---

## 📅 计划功能详解

### 状态机
计划实例在以下状态间流转:

```
unstarted ──到点自动/手动开始──▶ active ──暂停──▶ paused
    │                           │  │              │ 恢复(顺延)
    │                           │  └──结束时间到──▶ overdue(不自动完成)
    │                           │
    └──手动跳过────────────────▶ skipped
        active/overdue ──手动完成/减时到 0──▶ completed
```

- **进行中**(active):实时累计已执行时间,支持加时 / 减时 / 暂停 / 撤销
- **超时**(overdue):超过结束时间仍可继续执行,完成时记录实际完成时间点
- **跳过**(skipped):未开始直接放弃,或超时后放弃

### 冲突规则
同一时间段内不允许存在多个计划。新建、修改时间、提前 / 延后、导入都会检测冲突并**阻塞**;仅修改内容(时间不变)不触发冲突检测。

### 自动顺延
当某个计划正在进行且实际结束时间越过下一计划的开始点时,下一计划**自动顺延**(不弹窗、不会被误启动),直到当前计划完成;若顺延又越过更后面的计划,则持续向后顺延。

### 候选清单(四级结构)
候选清单用于沉淀常用计划结构,便于快速创建:

```
类型(一级) → 主题(二级) → 单元(三级) → 标题(四级)
例:学习    → 行测      → 判断推理   → 图形推理练习
```

- **文件管理器式逐级浏览**:面包屑路径可点击回上级,文件夹 / 文件图标区分层级
- **按层级添加**:在类型层只添加类型,进入某主题下只添加主题,依此类推
- **导入 / 粘贴导入 / 导出**:支持标准 JSON,可粘贴 AI 生成的候选清单
- 新建计划页可从候选清单**逐级浏览选择**,自动填充 类型 / 主题 / 单元 / 标题

### 导入 / 导出 JSON 格式

**计划**(顶层 `plans` 数组,`schemaVersion: "1.0.0"`):

```json
{
  "schemaVersion": "1.0.0",
  "plans": [
    {
      "id": "unique-id",
      "title": "晨间阅读",
      "type": "学习",
      "topic": "行测",
      "unit": "判断推理",
      "notes": "",
      "startDate": "2026-08-18T07:30:00",
      "durationMinutes": 45,
      "color": 4294198070,
      "iconName": "menu_book",
      "tags": [],
      "repeat": { "frequency": "daily", "interval": 1, "daysOfWeek": [], "daysOfMonth": [], "endType": "never", "untilDate": null, "repeatCount": null },
      "remindersMinBefore": [0, 10],
      "progressType": "automatic"
    }
  ]
}
```

**候选清单**(顶层 `candidates` 数组):

```json
{
  "schemaVersion": "1.0.0",
  "candidates": [
    { "type": "学习", "topic": "行测", "unit": "判断推理", "title": "图形推理练习" }
  ]
}
```

> 时间字段为本地时间(不带时区后缀);`startDate` 使用 ISO 8601 格式。

### AI 辅助生成
设置 → 计划 → **计划生成帮助**,可一键复制规范提示词:
- **借助 AI 生成计划**:粘贴口语化计划描述,AI 返回标准计划 JSON → 计划列表「粘贴计划」导入
- **借助 AI 生成计划结构清单**:生成四层候选清单 JSON → 候选清单「粘贴导入」

---

## 🧱 技术栈
- **框架**:Flutter 3.47 / Dart 3.13
- **状态管理**:原生 `ChangeNotifier` + `ListenableBuilder`(无第三方状态管理)
- **主要依赖**:`shared_preferences`(持久化)、`wakelock_plus`(屏幕常亮)、`window_manager`(Windows 全屏)、`flutter_local_notifications`(通知)、`url_launcher`、`file_selector`、`path_provider`、`package_info_plus`、`flutter_localizations`(中文界面)
- **平台能力**:Android 沉浸式 / 通知 / 前台服务 / 精确闹钟、MethodChannel(刷新率 / 方向 / 文件保存)、Windows 全屏窗口

---

## 🔨 从源码构建

```bash
# 安装依赖
flutter pub get

# Android release(按 ABI 拆分)
flutter build apk --release --split-per-abi

# Windows release
flutter build windows --release
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

## 📁 项目结构
```
lib/
├── main.dart                入口:加载设置、字体与计划数据
├── app.dart                 应用根组件(主题 / 本地化)
├── models/                  数据模型(时钟设置 / 计划 / 候选 / 重复规则 / 冲突 / 历史)
├── providers/               状态管理(设置 / 计划 ChangeNotifier)
├── screens/                 时钟页、设置页、计划列表 / 编辑 / 全部 / 候选清单 / 统计
├── services/                窗口、方向、字体、通知、告警、导入导出、备份服务
├── theme/                   配色方案解析
├── utils/                   时间 / JSON 工具
└── widgets/                 标准时钟、圆盘时钟、计划覆盖层、候选选择器
test/                        单元测试(计划状态机 / 冲突 / JSON / 时区)
```

---

## 📄 许可证
本项目基于 MIT 许可证发布。

## 🙏 致谢
- 配色灵感参考 [zhongguose.com](https://zhongguose.com)
- 内置字体版权归原厂商所有,官方许可协议随源码附于 `assets/fonts/` 下:
  - **HarmonyOS Sans**(华为,HarmonyOS Sans Fonts License Agreement,见 `assets/fonts/HarmonyOS_Sans/LICENSE`)
  - **MiSans**(小米,MiSans Font Intellectual Property License Agreement,见 `assets/fonts/MiSans/LICENSE`)
