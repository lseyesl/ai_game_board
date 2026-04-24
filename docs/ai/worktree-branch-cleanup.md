# Worktree 分支流程

## 概述

使用 git worktree 隔离功能开发，避免在主工作区切换分支。本项目的 worktree 存放在 `.worktrees/`（已在 `.gitignore` 中排除）。

## 创建 Worktree

```bash
# 从 main 创建新功能分支 + worktree
git worktree add .worktrees/<branch-name> -b feat/<branch-name>
```

命名规则：
- 目录名 = 分支名（不含 `feat/` 前缀）
- 分支统一用 `feat/` 前缀

示例：
```bash
git worktree add .worktrees/wave-visualization -b feat/wave-visualization
```

## 在 Worktree 中开发

```bash
# 进入 worktree 目录工作
cd .worktrees/<branch-name>

# 正常开发、提交...
git add ... && git commit -m "feat: ..."

# 推送到远程（如需 PR）
git push -u origin feat/<branch-name>
```

## 合并到主分支

回到主工作区执行合并：

```bash
# 1. 回到主工作区
cd /Users/q/panel/test/test_ai/board

# 2. 确保主分支最新
git checkout main
git merge main  # 如果有远程变更先 pull

# 3. 合并功能分支
git merge feat/<branch-name>

# 4. 运行测试验证
godot --headless --path . -s res://tests/run_tests.gd
```

如果合并冲突：
```bash
# 解决冲突后
git add <冲突文件>
git commit
```

## 合并后清理 ⚠️

**合并完成后必须询问用户：**

> "分支 `feat/<branch-name>` 已合并到 main。是否清理 worktree 和分支？"

- 用户确认 → 执行以下步骤
- 用户拒绝 → 保留不动

### 清理步骤

```bash
# 1. 移除 worktree
git worktree remove .worktrees/<branch-name>

# 2. 删除功能分支
git branch -d feat/<branch-name>

# 3. 如已推送到远程，也删除远程分支
git push origin --delete feat/<branch-name>  # 可选
```

### 验证清理完成

```bash
git worktree list   # 应只剩主工作区
git branch          # feat/<branch-name> 应已消失
ls .worktrees/      # 对应目录应已消失
```

## 注意事项

- **不要在主工作区 `git checkout` 到功能分支** — 用 worktree 隔离
- **不要手动 `rm -rf .worktrees/<name>`** — 用 `git worktree remove` 避免状态残留
- **合并前确保功能分支测试通过** — 不合并红色代码
- **一个 worktree 对应一个分支** — 完成后及时清理，避免 worktree 堆积
