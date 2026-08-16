---
name: Fullscreen_Clock_PlanGeneration
description: 生成 Fullscreen Clock 全屏时钟应用可导入的「计划 JSON」与「候选清单 JSON」。当用户要求「生成计划」「帮我列计划」「生成候选清单」「把口语化计划转成 JSON」「把计划/课程/知识清单转成候选结构」,或提供计划列表/表格/描述并要求转换为 Fullscreen Clock 格式时使用。产出严格符合 schema 的 JSON:计划可在「计划列表 → 粘贴计划」导入,候选清单可在「候选清单 → ⋮ → 粘贴导入」导入。
---

# Fullscreen Clock 计划生成

为 Fullscreen Clock(全屏时钟)生成符合其导入规范的 JSON。与「设置 → 计划 → 计划生成帮助」的两项 AI 辅助一致:

1. **计划 JSON** —— 「借助 AI 生成计划」,在 **计划列表 → 粘贴计划** 导入。
2. **候选清单 JSON** —— 「借助 AI 生成计划结构清单」,在 **候选清单 → ⋮ → 粘贴导入** 导入。

---

## 一、计划 JSON(对应「粘贴计划」)

### 1.1 输出格式

只输出一个 JSON 对象,顶层含 `schemaVersion` 与 `plans` 数组:

```json
{
  "schemaVersion": "1.0.0",
  "plans": [
    {
      "id": "plan-001",
      "type": "学习",
      "topic": "行测",
      "unit": "判断推理",
      "title": "图形推理练习",
      "startDate": "2026-08-20T10:00:00",
      "durationMinutes": 45,
      "notes": "完成 20 道真题并订正",
      "color": 4283216694,
      "iconName": "schedule",
      "tags": ["行测"],
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

### 1.2 字段规则

| 字段 | 必填 | 类型 | 说明 |
| --- | --- | --- | --- |
| `id` | ✅ | string | 计划唯一标识,任意非空且不重复的字符串(如 `plan-001`) |
| `type` | 否 | string | 计划类型(一级),如 `学习` |
| `topic` | 否 | string | 计划主题(二级),如 `行测` |
| `unit` | 否 | string | 计划单元(三级),如 `判断推理` |
| `title` | ✅ | string | 计划标题,简洁明确 |
| `startDate` | ✅ | string | 开始时间,**写本地时间、不要带时区后缀 Z 或 +08:00**(如 `2026-08-20T10:00:00`);用户未给年份时默认当年 |
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

### 1.3 计划生成规则

1. **严格格式**:只输出 JSON,不输出解释文字。
2. **时间**:`startDate` 一律为**本地时间且不带时区后缀**;用户给「早上 7 点半」这类口语化描述时转换为具体时刻。
3. **多条计划的时间段不能重叠**:一条计划的开始到结束区间内不允许出现另一条计划,避免导入时被冲突拦截。
4. **三级标签**:用户描述含分类/科目/模块时,分别填 `type`(类型)、`topic`(主题)、`unit`(单元);没有分类信息时这些字段可省略。
5. **时长**:`5~300` 分钟;口语如「半小时」→ 30。
6. **重复**:「每天」「每周一三五」「工作日」「每月 1 号和 15 号」对应设置 `repeat`;无重复则 `frequency: "none"`。
7. **提醒**:默认 `[0, 10]`;用户没提提醒就用默认。
8. **多计划/表格**:多条计划放进同一 `plans` 数组;表格/列表按行/行数据逐条转换,标题取自第一列或表头。

---

## 二、候选清单 JSON(对应「粘贴导入」候选清单)

### 2.1 输出格式

只输出一个 JSON 对象,顶层含 `schemaVersion` 与 `candidates` 数组:

```json
{
  "schemaVersion": "1.0.0",
  "candidates": [
    { "type": "学习", "topic": "行测", "unit": "判断推理", "title": "图形推理练习" },
    { "type": "学习", "topic": "行测", "unit": "判断推理", "title": "逻辑论证专项" },
    { "type": "学习", "topic": "申论", "unit": "归纳概括", "title": "提炼要点训练" }
  ]
}
```

### 2.2 字段规则

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `type` | ✅ | 计划类型(一级) |
| `topic` | ✅ | 计划主题(二级) |
| `unit` | ✅ | 计划单元(三级) |
| `title` | ✅ | 标题(四级) |

### 2.3 候选清单生成规则

1. **结构为四层**:类型(一级)→ 主题(二级)→ 单元(三级)→ 标题(四级),app 内按文件夹层级逐级浏览。
2. **四条字段均不能为空**;同一 type/topic/unit 下可以有多条 title(对应同一文件夹下的多个"文件")。
3. 用户给出口语化清单时,按层级归类生成;**不要臆造用户未提到的层级**(用户没说主题时,主题字段用用户原话或合理的空结构)。
4. 用户给「课程 / 章节 / 知识点」这类结构化内容时,天然映射为 类型→主题→单元→标题。

---

## 三、口语化需求转换示例

**场景 1 — 生成计划**

用户描述:「我每天上午 10 点做一套图形推理 45 分钟,分到 学习/行测/判断推理 下;今晚 8 点有个 1 小时健身。」

转换:
```json
{
  "schemaVersion": "1.0.0",
  "plans": [
    {
      "id": "plan-001",
      "type": "学习",
      "topic": "行测",
      "unit": "判断推理",
      "title": "图形推理练习",
      "startDate": "2026-08-20T10:00:00",
      "durationMinutes": 45,
      "progressType": "automatic",
      "remindersMinBefore": [0, 10],
      "repeat": { "frequency": "daily", "interval": 1, "daysOfWeek": [], "daysOfMonth": [], "endType": "never", "untilDate": null, "repeatCount": null }
    },
    {
      "id": "plan-002",
      "type": "",
      "topic": "",
      "unit": "",
      "title": "健身锻炼",
      "startDate": "2026-08-20T20:00:00",
      "durationMinutes": 60,
      "iconName": "fitness",
      "progressType": "automatic",
      "remindersMinBefore": [0, 10],
      "repeat": { "frequency": "none", "interval": 1, "daysOfWeek": [], "daysOfMonth": [], "endType": "never", "untilDate": null, "repeatCount": null }
    }
  ]
}
```

**场景 2 — 生成候选清单**

用户描述:「给我行测的复习结构,判断推理下面有图形推理和逻辑论证,资料分析下面有速算技巧。」

转换:
```json
{
  "schemaVersion": "1.0.0",
  "candidates": [
    { "type": "学习", "topic": "行测", "unit": "判断推理", "title": "图形推理" },
    { "type": "学习", "topic": "行测", "unit": "判断推理", "title": "逻辑论证" },
    { "type": "学习", "topic": "行测", "unit": "资料分析", "title": "速算技巧" }
  ]
}
```

---

## 四、验证提示

- **计划 JSON**:让用户把 JSON 复制后,在 Fullscreen Clock「计划列表 → 右下角 + → 粘贴计划」导入;应用会校验必填字段、时间格式、重复规则与重叠冲突。
- **候选清单 JSON**:让用户在「候选清单 → 右上角 ⋮ → 粘贴导入」导入;四层结构会按文件夹层级展示。
- 若用户描述含糊(如未给日期/层级),给出合理默认(当年当天、最小必要层级)并在回复中说明假设。
