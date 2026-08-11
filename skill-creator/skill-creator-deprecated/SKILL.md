---
name: skill-creator
description: 创建、重构或优化 Skill 时使用（create / update / refactor / optimize a skill）。触发场景：用户要求新建 Skill、修改已有 Skill、精简 Skill、排查 Skill 不触发或行为不稳定（new skill, edit existing skill, write SKILL.md, skill not triggering, unstable skill behavior, skill frontmatter/description）。产出符合规范、能被系统加载并稳定触发的 Skill。
---

# Skill Creator

## 判据：一段内容是否该进入 Skill

只保留满足两条的内容：

1. 模型的参数或当前上下文里没有这段信息。
2. 模型无法从任务本身可靠推断出这段信息。

因此 Skill 携带两类内容，缺一不可：

- **约束**：模型倾向于做错、需要被限制的行为（顺序、停止条件、禁止项）。
- **知识**：模型无法自行推断的私有信息（内部 API 契约、私有 schema、业务规则、可复用脚本/模板）。

删除依据：删掉某段后，另一个模型执行同类任务的结果不变，则删除。

不要写：基础知识、通用最佳实践、语言/框架的公共用法、模型已能规划的步骤拆解。

## Skill 的物理形态

```
skill-name/
├── SKILL.md          (必需)
├── scripts/          (可选：确定性代码，可不读入上下文直接执行)
├── references/       (可选：按需读入的文档，如 schema、API 契约)
└── assets/           (可选：产物中使用的文件，如模板、字体、样板工程)
```

三级加载，决定内容该放哪一层：

1. **frontmatter（name + description）**：常驻上下文。这是唯一的触发依据。
2. **SKILL.md 正文**：仅在触发后加载，目标 < 500 行。
3. **scripts/references/assets**：按需加载；脚本可不读入上下文直接执行，故不占预算。

推论：
- 触发相关信息（when to use）只能写在 `description`。写进正文无效——正文触发后才加载。
- 大块细节（schema、变体、长示例）移入 `references/`，正文只留导航和选择逻辑。同一信息不得同时存在于正文和 reference。
- 反复重写的相同代码固化为 `scripts/`，正文只写调用方式。

## frontmatter 规范

只允许 `name` 和 `description` 两个字段。

- `name`：小写字母、数字、连字符；≤ 64 字符；动词开头短语；文件夹名与之完全一致。工具相关时加命名空间前缀（`gh-address-comments`）。
- `description`：同时写清 **做什么（what）** 和 **何时触发（when）**，含具体触发词/场景。这是决定 Skill 是否被选中的唯一文本，写不清即不触发。

## 自由度分级：决定用指令还是脚本

按任务的脆弱性和可变性选择形态：

- **高自由度（自然语言指令）**：多种解法都对、决策依赖上下文时用。
- **中自由度（带参脚本 / 伪代码）**：存在偏好模式、允许有限变化时用。
- **低自由度（固定脚本，少参数）**：操作脆弱易错、必须严格顺序、一致性关键时用。

判断标准是路径宽窄，不是"能少写脚本就少写"。悬崖边的窄桥要护栏（低自由度），开阔地不要（高自由度）。

## 创建流程

按序执行，仅在明确不适用时跳过。

1. **明确三要素**：触发条件、要改变的行为、成功判据。任一不清则先与用户对齐，不动手。
2. **规划可复用资源**：对每个具体用例，判断哪些代码会被反复重写（→ scripts）、哪些信息需被反复查询（→ references）、哪些文件出现在产物里（→ assets）。
3. **初始化**：新建时运行 `scripts/init_skill.py <name> --path <dir>`（默认 `${TRAE_HOME:-$HOME/.trae}/skills`）。改已有 Skill 则跳过。
4. **实现资源**：先写 scripts/references/assets。脚本必须实际运行验证输出，不能仅凭阅读判定正确。
5. **写 SKILL.md**：祈使句。frontmatter 按上节规范；正文只写模型执行任务时需要、且非显然的程序性知识与约束。
6. **校验**：运行 `scripts/quick_validate.py <dir>`，修复报出的 frontmatter/命名问题。
7. **前向测试与迭代**：见下。

## 编写约束

- 每条规则至少实现一项：防错、消歧、强制顺序、指定停止条件、保证输出一致。删掉不改变行为的规则。
- 一条规则只表达一个约束。
- 优先 Always / Never / Only if / Before / After / Unless，而非编号步骤——除非该任务属于低自由度（必须严格顺序）。
- 只在规则无法准确表达、或存在易误解边界时加示例；示例优于冗长解释。
- 不创建 README、CHANGELOG、安装文档等辅助文件——只保留模型执行任务所需的内容。

## 前向测试

改动较大或 Skill 逻辑复杂时，用 subagent 在真实任务上验证。

- subagent **不应知道自己在测 Skill**，按普通用户请求下发：`Use $skill-x at /path 来完成任务 y`。
- 只传原始产物（prompt、输出、diff、日志），**不传**你的诊断、疑似 bug、预期修复或结论。
- 每次迭代用全新线程重建上下文；清理上一轮遗留产物，避免污染。

若 Skill 仅在 subagent 看到泄漏上下文时才通过，说明 Skill 或测试设置仍需收紧。

## 迭代原则

针对真实失败演化，不为假想问题加规则。

```
真实失败 → 定位单一原因 → 最小修改 → 重新测试
```

一次只改一个问题。

## 完成前自检

- `description` 是否同时含 what 和触发场景？
- 命名是否合规、文件夹名是否与 name 一致？
- 三级加载是否放对层：触发信息在 description、细节在 references、复用代码在 scripts？
- 每条规则删掉后是否会改变模型行为？
- 是否存在跨层或同层的重复信息？
- 脚本是否已实际运行验证？

任一不满足则继续修，直到全部通过。
