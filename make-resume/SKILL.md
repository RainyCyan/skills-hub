---
name: make-resume
description: 制作可编辑的中文 HTML 简历并支持打印导出 PDF。触发场景：用户输入"/make-resume"、要求制作/生成/优化/修改/复刻简历或 CV、根据个人经历排版简历、把简历截图重建为可编辑网页、或需要一份能在浏览器里继续改字改色的简历文件。Create an editable Chinese HTML resume/CV with print-to-PDF; use when the user asks to build, edit, restyle, or clone a resume.
---

# Resume：制作可编辑简历

生成**真正可编辑**的 HTML 简历：正文用 `contenteditable`，用户在浏览器里点击即可改字、加粗、换主题色、替换照片，再用浏览器打印导出 PDF。绝不用截图或图片嵌入冒充可编辑简历。

## 资源定位

模板与数据结构位于本 skill 的 `assets/`（相对本 `SKILL.md` 解析，不要假设目标仓库里有 `assets/`）：

- `assets/templates-html/slate.html`：单栏模板，顶部抬头 + 主题色下划线，信息量适中，通用首选。
- `assets/templates-html/aside.html`：左深色侧栏 + 右主栏双栏模板，适合技能/联系方式需要突出、信息密度更高的情况。
- `assets/resume-data-template.json`：匿名简历内容结构，作为收集与填充信息的字段清单。

若这些文件缺失，先向上层目录定位 `assets/`；**Never 凭空捏造模板文件名或声称存在未提供的模板。**

## 工作流程

1. 收集：姓名、联系方式、教育、实习/工作、项目、技能、目标岗位、期望页数。信息缺失时用 `resume-data-template.json` 的匿名占位，**Never 捏造用户没给的经历、公司或指标**。
2. 若用户上传简历截图：先拆解栏位、间距、字体层级、颜色、照片位置和分页，再选最接近的模板重建为可编辑 HTML；不要把截图直接贴进页面。
3. 选模板：内容偏经历叙述→`slate.html`；需要突出技能栏或信息密集→`aside.html`。以模板为基准填入内容，保持结构，只改文本节点。
4. 产出一个独立 `.html` 文件（默认写到用户工作目录，文件名如 `resume-<name>.html`），所有正文保留 `contenteditable="true"`，工具栏保留在纸张之外。
5. 自检产物：见下「产出后必检」。
6. 用户要 PDF 时，说明浏览器打印路径（`Ctrl/Cmd+P` → 目标"另存为 PDF" → 边距选"无" → 双栏模板勾选"背景图形"以保留侧栏底色）；**Never 用截图或渲染图替代可编辑源文件交付**。

## 硬约束

- 页面所有正文必须可选中、可编辑、可复制；工具栏用 `contenteditable="false"` 且 `@media print` 下 `display:none`。
- 页面里**所有图像**（证件照、公司/学校 logo、图标、品牌横幅）一律内嵌为 dataURL（`FileReader.readAsDataURL`）或内联 `<svg>`，Never 用外链或本地文件路径——导出 PDF 会丢图。需要放大 logo 时按比例控制 `height`、`width:auto`，勿拉伸变形。
- 主题色收敛到单一 CSS 变量（`--accent`），换色只改这一处，Never 在多处硬编码颜色。
- 分页契约（多页时）：每页一个 `.page` 容器，且**打印态**下每个 `.page` 必须 `width:210mm; min-height:297mm` 并加 `break-inside: avoid-page; page-break-inside: avoid;`，页间用 `.page + .page { page-break-before: always; }`。Never 在打印态把 `.page` 降为 `min-height:auto`——页高不确定时浏览器会忽略断页规则或产生空白页。条目用 `page-break-inside: avoid` 防跨页截断，子标题用 `page-break-after: avoid` 防与正文分离。停止条件：单个 `.page` 的实际内容超过 297mm 时，先减内容/密度，Never 靠断页规则硬撑。
- 导出 PDF 时在 `@media print` 内用 `* { -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }` 强制保留主题色块、渐变、侧栏底色与 SVG，不依赖打印对话框的"背景图形"勾选。
- 内容溢出目标页数时，按此顺序恢复，Never 用 `overflow:hidden` 裁掉内容：① 先删重复、空泛、失衡的文案；② 确认目标页数与逻辑分页点（如"第一页在某段经历后结束"）；③ 收紧 padding、`section`/`.item`/bullet 间距；④ 最后再降 `--font-base`，且设可读下限（正文不低于约 9pt）；⑤ 改完重新核验每一页。`slate` 的密度旋钮是 `--pad` 和 `--font-base`；`aside` 无 `--pad`，改左右栏 `.side`/`.main` 的 padding。
- 用户未提供真实照片时保留占位图，并提醒替换；Never 把用户真实个人信息写回 `assets/` 里的模板或 JSON。

## 产出后必检

产物写出后逐项确认（无浏览器环境时至少做结构核验：标签闭合、JSON 合法、`contenteditable` 与打印隐藏规则存在）：

- 单页内容是否溢出到第二页；长文本 bullet 是否被截断。
- 中文字体是否命中字体栈（`Noto Sans SC` / `PingFang SC` / `Microsoft YaHei` 回退链）。
- 打印预览下工具栏是否消失、双栏底色是否保留、A4 边距是否正确。
- 照片比例是否变形（`object-fit: cover`）。

## 交付内容

默认交付：可编辑 `.html` 文件 + 所用模板说明 + 浏览器内编辑方法 + PDF 导出步骤。若用户还需要改写经历文案，先完成文字再填入简历，不要在排版阶段顺手编造成就。
