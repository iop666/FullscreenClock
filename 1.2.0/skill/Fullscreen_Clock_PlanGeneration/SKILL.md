---
name: Fullscreen_Clock_PlanGeneration
description: 生成 Fullscreen Clock 全屏时钟应用可导入的计划 JSON。当用户要求「生成计划」「帮我列计划」「把口语化计划转成 JSON」或提供计划列表/表格/描述并要求转换为 Fullscreen Clock 计划格式时使用。产出严格符合 schema 的 JSON,可直接在应用的「计划列表 → 粘贴计划」中导入。
---

# Fullscreen Clock 计划生成

为 Fullscreen Clock(全屏时钟)生成符合其导入规范的 **计划 JSON**。应用侧「计划列表 → 粘贴计划」会读取剪贴板文本并校验该格式。

## 1. 输出格式

只输出一个 JSON 对象,顶层含 `schemaVersion` 与 `plans` 数组:

```json
{
  "schemaVersion": "1.0.0",
  "plans": [
    {
      "title": "晨间阅读",
      "startDate": "2026-08-20T07:30:00+08:00",
      "durationMinutes": 30,
      "notes": "阅读《系统之美》第 3 章",
      "color": 4283216694,
      "iconName": "book",
      "tags": ["学习", "早晨"],
      "progressType": "automatic",
      "remindersMinBefore": [0, 10],
      "repeat": {
        "frequency": "daily",
        "interval": 1,
        "daysOfWeek": [],
        "daysOfMonth": [],
        "endType": "never",
        "untilDate": null,
        "repeatCount": null
      }
    }
  ]
}
```

## 2. 字段规则

| 字段 | 必填 | 类型 | 说明 |
| --- | --- | --- | --- |
| `title` | ✅ | string | 计划标题,简洁明确 |
| `startDate` | ✅ | string | 开始时间,ISO 8601 **带时区**(如 `2026-08-20T07:30:00+08:00`);用户未给年份时默认当年 |
| `durationMinutes` | ✅ | int | 时长(分钟),`5~300` 正整数 |
| `notes` | 否 | string | 备注 |
| `color` | 否 | int | 颜色 = `0xFFRRGGBB` 的十进制整数(如 `0xFF3B6EF6` = 4283216694);省略默认 4283216694 |
| `iconName` | 否 | string | `schedule/book/fitness/sleep/work/school/coffee/home/music/flag/star/target/restaurant/directions_run` 之一 |
| `tags` | 否 | string[] | 标签数组 |
| `progressType` | 否 | string | `automatic`(按时间自动)/ `manual`(开始后手动)/ `none`(不设置进度);默认 automatic |
| `remindersMinBefore` | 否 | int[] | 开始前提醒分钟数组;建议 `[0, 10]`(准时+提前10分钟),不需要则 `[]` |
| `repeat.frequency` | 否 | string | `none`/`daily`/`weekly`/`workdays`/`monthly`;默认 none |
| `repeat.interval` | 否 | int | 每 N 天/周/月重复,默认 1 |
| `repeat.daysOfWeek` | 否 | int[] | weekly 用,`1..7`(1=周一) |
| `repeat.daysOfMonth` | 否 | int[] | monthly 用,如 `[1, 15]`,负数表示从月末倒数 |
| `repeat.endType` | 否 | string | `never`/`until`/`count`;默认 never |
| `repeat.untilDate` | 否 | string\|null | endType=until 时给日期(可只到日,如 `2026-12-31`) |
| `repeat.repeatCount` | 否 | int\|null | endType=count 时给重复次数 |

## 3. 生成规则

1. **严格格式**:只输出 JSON,不输出解释文字、markdown 代码块外内容。
2. **时间**:`startDate` 一律 ISO 8601 带 `+08:00`(中国大陆时区);若用户给的是「早上 7 点半」这类口语化描述,转换为具体时刻。
3. **时长**:`5~300` 分钟;口语如「半小时」→ 30。
4. **重复**:用户说「每天」「每周一三五」「工作日」「每月 1 号和 15 号」时对应设置 `repeat`;无重复则 `frequency: "none"`。
5. **提醒**:默认 `[0, 10]`;用户没提提醒就用默认。
6. **多计划**:用户描述多条计划时,放进同一 `plans` 数组。
7. **表格/列表**:用户给表格或列表时,按行/行数据逐条转换,标题取自第一列或表头。

## 4. 从口语化需求转换示例

用户描述:「我每天早上 7 点半读 30 分钟书,每周一三五下午 3 点健身 45 分钟;今天上午 10 点有个 1 小时会议。」

转换:
```json
{
  "schemaVersion": "1.0.0",
  "plans": [
    {
      "title": "晨间阅读",
      "startDate": "2026-08-20T07:30:00+08:00",
      "durationMinutes": 30,
      "progressType": "automatic",
      "remindersMinBefore": [0, 10],
      "repeat": { "frequency": "daily", "interval": 1, "daysOfWeek": [], "daysOfMonth": [], "endType": "never", "untilDate": null, "repeatCount": null }
    },
    {
      "title": "健身锻炼",
      "startDate": "2026-08-20T15:00:00+08:00",
      "durationMinutes": 45,
      "iconName": "fitness_center",
      "progressType": "automatic",
      "remindersMinBefore": [0, 10],
      "repeat": { "frequency": "weekly", "interval": 1, "daysOfWeek": [1, 3, 5], "daysOfMonth": [], "endType": "never", "untilDate": null, "repeatCount": null }
    },
    {
      "title": "会议",
      "startDate": "2026-08-20T10:00:00+08:00",
      "durationMinutes": 60,
      "progressType": "automatic",
      "remindersMinBefore": [0, 10],
      "repeat": { "frequency": "none", "interval": 1, "daysOfWeek": [], "daysOfMonth": [], "endType": "never", "untilDate": null, "repeatCount": null }
    }
  ]
}
```

## 5. 验证提示

- 若用户需要校验,可提示:把 JSON 复制后,在 Fullscreen Clock「设置 → 计划列表 → 右下角 + → 粘贴计划」导入;应用会校验必填字段、时间格式与重复规则。
- 若用户描述含糊(如未给日期),给出合理默认(当年当天)并在回复中说明假设。
