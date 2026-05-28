---
name: diascan-code
description: 貂蝉编程工作流 — 编码规范、验证要求、提交审核、上传GitHub、版本号管理
trigger: 收到编程任务后
used_by: [diascan(opencode)]
---

# 貂蝉编程执行

## 前置规则（强制执行）

**收到编程任务 → 必须先加载本 Skill**，再开始编码。

## 编码规则

- 修改代码前先理解文件现有风格
- 使用现有库和工具，不引入新的外部依赖
- 修改后用 Node.js 做语法验证
- 写清楚版本号注释 `<!-- V5 v2026.05.28.1 -->`

## 编码完成硬性规则（五条确认）

编码完成 ≠ 代码写好。必须满足以下五条：

1. ✅ 代码编码完成
2. ✅ 工作日志写完
3. ✅ 将交付物 + 工作日志提交给司马懿审核
4. ✅ 通知甄宓(main)「编码完成，已提交司马懿审核」，抄送曹操
5. ✅ 通知甄宓更新 status.json 并 ACP 推送至 GitHub

## 提交司马懿审核

- 编码完成后等待司马懿审貂蝉
- 退回修改 → 修复 → 重新提交
- 同一问题退回两次 → 卡点，上报甄宓(main)

## GitHub 上传

**优先方式**：默认使用 `coordinator.sh upload` 子命令自动上传。仅新建仓库/自定义 Release body 等需编码生成文件的场景由貂蝉直接执行。

**令牌**：ghp_nq…DR1p（主公授权，不得泄露）

**上传前先查已有tag**：`git tag -l` 确认版本号不重复

**版本号格式**：`v2026.05.27`（年月日），同天多发加序号：`.1` `.2` `.3`

**上传步骤**：
1. **如仓库不存在，用 GitHub API 创建**：`curl -u puerkafei:$GITHUB_TOKEN https://api.github.com/user/repos -d '{"name":"仓库名"}'`
2. 初始化 git 并设置远程：`git init && git remote add origin https://puerkafei:$GITHUB_TOKEN@github.com/puerkafei/仓库名.git`
3. `git add . && git commit -m "description" && git tag v2026.xx.xx`
4. `git push origin main --tags`
5. 创建 GitHub Release（英文更新说明，不可省略）

**全英文规则**：GitHub 所有内容必须用英文（描述、README、Release 正文）

**上传完成后**：写工作日志 → 通知甄宓(main)「已上传 GitHub，请更新状态」，抄送曹操

**权限不足时**：视为卡点，上报甄宓(main)，不得让曹操替补上传

## 不越界

- ❌ 不做技术调研（归诸葛亮）
- ❌ 不做内容润色（归曹植）
- ❌ 不做审核（归司马懿）

## 卡点规则

- 同一问题退回两次 → 卡点，上报甄宓(main)
- 工具调用失败 → 重试1次，仍失败 → 上报甄宓(main)
