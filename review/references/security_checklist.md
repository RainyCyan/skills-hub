# 安全检查清单

按需加载。当静态审查遇到特定语言/框架时，参照对应规则。

## 命令注入

检测模式：外部输入直接或间接传入以下函数且未做白名单校验。

| 语言 | 危险函数 | 安全替代 |
|------|---------|---------|
| JavaScript/Node | `exec()`, `spawn()`, `execSync()`, `eval()`, `Function()` | `execFile()` 带参数数组，避免 shell 模式 |
| Python | `os.system()`, `os.popen()`, `subprocess.call(shell=True)`, `eval()`, `exec()` | `subprocess.run([...])` 不带 `shell=True` |
| Go | `exec.Command("sh", "-c", ...)` | `exec.Command("binary", arg1, arg2)` 直接传参 |
| Bash | 变量直接拼接到命令字符串 | 使用 `"$@"` 或数组参数 |

判断标准：
- 阻塞：用户输入未经任何清洗/校验直接进入命令字符串
- 警告：使用了白名单但未做转义
- 放行：仅使用固定常量，无外部输入参与

## SQL 注入

检测模式：SQL 字符串由拼接构成，且拼接片段包含变量。

| 语言 | 危险模式 | 安全模式 |
|------|---------|---------|
| 通用 | `"SELECT * FROM users WHERE id = " + userId` | 参数化查询 / ORM |
| JavaScript | 字符串模板 `` `SELECT * FROM users WHERE id = ${id}` `` | `db.query("SELECT * FROM users WHERE id = ?", [id])` |
| Python | `f"SELECT * FROM users WHERE id = {user_id}"` | `cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))` |
| Go | `fmt.Sprintf("SELECT * FROM users WHERE id = %s", id)` | `db.Query("SELECT * FROM users WHERE id = $1", id)` |
| Java | `"SELECT * FROM users WHERE id = " + id` | `PreparedStatement` |

特殊情况：
- ORDER BY / GROUP BY / 表名/列名无法参数化 → 必须用白名单映射
- LIKE 子句中的通配符 `%` `_` 需转义

## XSS (跨站脚本)

检测模式：用户数据直接渲染到 HTML，未经过转义。

| 框架 | 危险模式 | 安全模式 |
|------|---------|---------|
| React | `dangerouslySetInnerHTML` | JSX 自动转义 |
| Vue | `v-html` | `{{ }}` 模板插值 |
| 原生 JS | `element.innerHTML = userInput` | `element.textContent = userInput` |
| 服务端渲染 | 模板中 `{{{ }}}` (Handlebars/Mustache 三重括号) | `{{ }}` 双重括号 |
| jQuery | `.html()` | `.text()` |

附加检查：
- `href` 属性中的 `javascript:` URL
- `src` 属性中的 `data:` URL
- `postMessage` 的 `targetOrigin` 为 `*`

## 路径遍历

检测模式：文件路径由用户输入拼接，未做规范化和边界检查。

危险模式：
```python
open(f"/data/{user_input}")        # 无校验
fs.readFileSync(`./data/${req.query.file}`)  # 无校验
```

安全模式：
```python
import os
base = "/data/"
safe_path = os.path.normpath(os.path.join(base, user_input))
if not safe_path.startswith(base):
    raise ValueError("路径越界")
```

关键检查：
- 是否做了 `normpath` / `realpath` 规范化
- 是否检查了结果路径仍在允许的基目录内
- 是否过滤了 `..` 和符号链接

## 硬编码密钥

检测模式：以下模式出现在代码中（非配置文件或环境变量）。

关键词搜索：
- `password = "`, `passwd = "`
- `api_key = "`, `apikey = "`, `API_KEY = "`
- `secret = "`, `SECRET = "`
- `token = "`
- `private_key = "`, `-----BEGIN RSA PRIVATE KEY-----`
- `-----BEGIN EC PRIVATE KEY-----`
- `Authorization: Basic`, `Authorization: Bearer` 后跟硬编码字符串

放行条件：
- 值来自环境变量：`os.environ.get("KEY")`, `process.env.KEY`
- 值来自配置文件且配置文件在 `.gitignore` 中
- 值明确为测试/示例占位符：`"your-api-key-here"`, `"test_key"`

## 不安全的反序列化

| 语言 | 危险函数 | 安全替代 |
|------|---------|---------|
| Python | `pickle.loads(user_data)`, `yaml.load(user_data)` | `json.loads()`, `yaml.safe_load()` |
| JavaScript | `eval()` 对用户输入 | `JSON.parse()` |
| Java | `ObjectInputStream.readObject()` 无白名单 | 配置 `ObjectInputFilter` |
| PHP | `unserialize($user_input)` | `json_decode()` |

## 认证/授权绕过

- 路由 handler 前缺少认证中间件
- 中间件有提前 return 路径导致认证被跳过
- JWT token 验证不检查签名算法（`alg: none` 攻击）
- 权限检查仅在前端，后端无校验
- 敏感操作无二次确认（删库、改权限、转账）

## 敏感数据泄露

- 日志中打印 token、密码、身份证号、银行卡号
- 错误消息中暴露堆栈跟踪或内部路径
- 响应中返回多余字段（如 password hash）
- 注释中包含真实凭证或内部 IP
- 调试端点在生产环境可用（`/debug`, `/phpinfo`, `/actuator`）