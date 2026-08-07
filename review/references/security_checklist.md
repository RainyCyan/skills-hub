# 安全问题判定规则

仅当变更涉及外部输入、权限边界、命令或查询执行、文件访问、反序列化、HTML 渲染、日志或响应数据时加载本文件。

## 报告门槛

Only report a security finding when the changed code introduces or exposes a complete risky path:

1. 指出不可信来源或敏感数据来源。
2. 指出危险 sink 或越权操作。
3. 指出保护措施为何缺失、可绕过或放置在错误边界。
4. 给出可达路径和实际影响。

只有危险 API、关键词或扫描器命中而没有完整路径时，不得直接定为漏洞；将其作为待核查候选。无法确认调用路径时，将审查判定为“信息不足”，不要制造确定性结论。

## 分类证据

| 类别 | 阻塞所需证据 | 常见非问题 |
|------|--------------|------------|
| 命令注入 | 外部数据进入 shell 解释的命令字符串，且没有严格枚举映射 | 固定命令；参数数组直接传给可执行文件且未启用 shell |
| SQL 注入 | 外部数据参与 SQL 语法拼接；动态表名、列名或排序字段未做枚举映射 | 值通过驱动参数绑定；ORM 仍使用参数绑定 |
| XSS | 攻击者可控数据进入 HTML/脚本/URL sink，且对应上下文没有编码或净化 | 框架默认转义的文本插值；仅渲染固定常量 |
| 路径遍历 | 外部路径片段经规范化后仍未校验其位于允许根目录内，或符号链接可逃逸 | 固定路径；规范化后按路径边界做 containment 校验 |
| 硬编码凭证 | 提交内容包含可用或高度疑似真实凭证 | 明确占位符、测试假值、环境变量名、扫描规则本身 |
| 不安全反序列化 | 不可信字节进入可实例化对象或执行代码的反序列化器，且无类型白名单 | 仅解析普通 JSON 不等同于代码执行；后续缺少 schema 校验属于独立正确性问题 |
| 认证或授权绕过 | 受保护操作存在一条不经过服务端认证/授权检查的可达路径 | 仅前端隐藏不是保护；中央中间件已覆盖全部入口时不要求 handler 重复检查 |
| 敏感数据泄露 | 密钥、认证材料、个人敏感字段或内部机密进入日志、错误响应或越权响应 | 普通内部路径或堆栈仅在明确的生产暴露路径上构成安全问题 |

## 边界检查

- Always trace protection to the authoritative server-side boundary. 前端校验、调用方约定和注释不能替代服务端强制检查。
- Always inspect failure and fallback paths. `catch`、默认分支、重试、缓存命中和降级路径可能绕过主路径保护。
- Only treat allowlists as protection when matching is exact and defaults to deny.
- Only treat path-prefix checks as protection when they respect path-component boundaries and symlink behavior.
- Never print a complete suspected credential in the report. 只报告文件、行号、凭证类型和必要的掩码片段。

## 严重程度

- **阻塞**：路径可达且可导致越权、代码/命令执行、数据泄露、数据篡改或凭证暴露。
- **警告**：保护存在但边界不完整，风险需要特定部署条件或非默认配置才能触发。
- **信息不足**：缺少运行时配置、调用方、权限模型或数据来源证据，无法证明或排除风险。
