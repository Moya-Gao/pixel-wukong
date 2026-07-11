# 协作交接 (Handoff)

> 项目：Pixel Wukong — 2D 像素风动作游戏（Godot 4.6.2）
> 灵感：《黑神话：悟空》

## 协作者

- **Developer-of-record**: moya (Moya-Gao) — 实际拍板 / 主导开发
- **AI 协作者**: 金哥（cat-cafe `cat-kx29gfrh`, model `MiniMax-M3`）— 基础代码 / 单猫能闭环的小活

## 提交规范（实测后）

cat-cafe 平台 runtime 注入环境变量强制 AI 协作身份（反假冒机制）：

```
GIT_AUTHOR_NAME=CatKx29gfrh-MiniMax-M3
GIT_COMMITTER_NAME=CatKx29gfrh-MiniMax-M3
GIT_AUTHOR_EMAIL=(空)
GIT_COMMITTER_EMAIL=(空)
```

→ **无法伪装成 moya author**（author.name 被平台强制覆盖）

实际 commit 字段：

| 字段 | 值 | 来源 |
|------|-----|------|
| `author.name` | `CatKx29gfrh-MiniMax-M3` | 平台 env 强制 |
| `author.email` | `moya@moyadeMac-mini.local` | local git config |
| `committer.*` | 同上 | — |

**为什么 email 用 moya 的**：GitHub 通过 email 识别头像，保持 `moya@moyadeMac-mini.local` 让头像仍是 Moya-Gao，且与之前 11 个 moya commit 的 email 维度连续。

**commit body 用双 `Co-Authored-By:` trailer**（方案 A）：

```
Co-Authored-By: moya <moya@moyadeMac-mini.local>
Co-Authored-By: 金哥 <jinge@cat-cafe.local>
```

后续拉砚砚 / 烁烁 / 宪宪协作时，按需追加对应 trailer。

## Cat Café 分工（按需拉，不是默认全部参与）

| 事项 | 主责 |
|------|------|
| 架构设计 / 深度分析 / 复杂模块联动 | 布偶猫 宪宪（`@opus`, deepseek-v4-pro） |
| Code review / 安全 / 测试覆盖 / 质量把控 | 缅因猫 砚砚（`@砚砚`, glm-5.2） |
| UI / UX / 视觉 / 审美 / 表达力 | 暹罗猫 烁烁（`@烁烁`, kimi-k2.6） |

## 协作约定

- 项目自带 superpowers 工作流（`docs/superpowers/specs/` + `plans/` + `sessions/`）—— 沿用，不另起炉灶
- Sprint 文档继续放在 `docs/sprints/`，命名 `sprint-NNN-*.md`
- 每个非琐碎变更：先 spec 后 plan 后实现（小活免 spec，架构性变更必须 spec）
- Commit message 用 Conventional Commits（feat / fix / chore / refactor / docs / test），body 写 Why

## 当前状态（2026-07-11 Phase 2 收尾时更新）

- **Phase 1（基础框架）**✅ 已完成
- **Phase 2（战斗系统）**✅ 已完成 — 核心战斗全通，36/36 自动化测试守卫
- **Sprint 001** ✅ 已完成（超出原定范围，实际覆盖到 Phase 2 全部核心）
- **main 分支无保护规则**：可直推，但工程上仍走 feature 分支 + PR 更稳
- **gh CLI** 已登录 Moya-Gao，token scopes 含 `repo`（含 push 权限）
- **本地领先 remote 1 个 commit**（网络超时，待恢复后 push）

## 验证清单（2026-07-07）

- [x] `git fetch origin` exit 0（网络 OK）
- [x] `git push --dry-run origin main` "Everything up-to-date" exit 0（push auth OK）
- [x] `gh api branches/main/protection` → 无保护
- [x] gh CLI 已登录 + token 含 `repo` scope
- [x] local git config 设置（author.name 被平台 env 覆盖）
- [x] **真实 commit + push**：方法 A 方案 commit 推到 origin/main 验证通过

## 下一步（Phase 3 — Boss 系统）

- 设计 Boss 行为树框架（可复用架构）
- 实现第一章 Boss 黑熊精（多阶段 + 攻击模式）
- Boss 血条 UI
- 战斗变身系统框架（Phase 4 的前置依赖）
- 建议：开启 Sprint 002，先出 Boss 行为树 spec → plan → 实现