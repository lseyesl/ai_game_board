# Commit 规范

## 格式

```
<type>: <subject>
```

- **subject**：简短描述改了什么，用英文，不加句号，不超过 72 字符
- 不写 body 除非改动确实需要额外说明

## Type 清单

| Type | 用途 | 示例 |
|------|------|------|
| `feat` | 新功能 | `feat: add wave visualization debug overlay` |
| `fix` | 修复 bug | `fix: smooth ship landing transition from wave launch to bob` |
| `refactor` | 重构（不改行为） | `refactor: extract wave height calculation into utility` |
| `test` | 添加/修改测试 | `test: add wave spawner pool reuse tests` |
| `docs` | 文档变更 | `docs: add camera rig design` |
| `chore` | 杂务（归档、配置等） | `chore: archive design docs to docs/archive/plans` |
| `perf` | 性能优化 | `perf: reduce wave zone collision checks` |

## 规则

1. **一个 commit 做一件事** — 不混合 feat 和 fix，不混合不相关的改动
2. **时态用现在时** — `add` 不是 `added`，`fix` 不是 `fixed`
3. **feat/fix 类 commit 必须可验证** — 跑过测试或手动验证后再提交
4. **不要提交破坏的代码** — 测试不过 = 不提交
5. **docs/chore 类 commit 可以独立于测试** — 纯文档/归档不需要跑测试
