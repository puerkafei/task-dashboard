---
name: caocao-status
description: status.json 维护规范（由甄宓执行） — 更新规则、校验脚本、ACP推送、禁止规则
trigger: 甄宓初始化任务 / 收到Agent状态变更通知
used_by: [zhenfu(main)]
---

# status.json 维护规范

> **维护者：甄宓（main）唯一维护。** 曹操不得写入 status.json。

## 唯一数据源

`projects/dashboard/data/status.json` 是唯一工作流状态数据源。

## Step 结构规范

每个 step 必须包含以下字段（缺 `id` 会导致 Dashboard 点击失效）：

```json
{
  "id": 1,
  "step": 1,
  "name": "环节名",
  "assignee": "执行人",
  "status": "待分配",
  "content": "工作内容描述"
}
```

- `id` 必须与 `step` 相同（Dashboard JS 通过 id 做点击匹配）
- `status` 取值：`待分配` / `已分配` / `执行中` / `审核中` / `退回修改` / `completed`

创建新任务初始化 steps 时，必须同时写入 `id` 和 `step`。

## Archived Tasks 结构

已归档任务记录在 `archived_tasks` 字段中：

```json
{
  "work_id": "TASK-YYYYMMDD-xxx",
  "title": "任务标题",
  "progress": 数字,
  "status": "状态描述",
  "note": "备注"
}
```

## 更新规则

1. **逐步骤更新，禁止批量** — 每次只更新一步
2. **以 Agent 通知为依据** — 收到 Agent 通知甄宓后更新
3. **更新后立即校验** — `bash ~/.openclaw/workspace-mengde/scripts/validate-status.sh`
4. **校验通过后立即 ACP 推送** — commit + push（Dashboard 5 秒内可见）

## 禁止规则（违者上报主公）

- ❌ status 不是 completed 时写入 reported_to="已汇报"
- ❌ status 不是 completed 时写入 notified_main_at
- ❌ 先写时间戳再发 sessions_send
- ❌ 跳步标记完成
- ❌ 填写与 sessions_send 调用时间不符的 notified_main_at
- ❌ 非编程类任务缺少曹植步骤

## 司马懿审曹植通过后限时响应

收到通知后 2 分钟内完成：确认 status.json → 校验 → ACP 推送 → 通知曹操（汇总）。
超时视为「甄宓响应延迟」上报主公。

## 通知曹操汇总（四步缺一不可）

① sessions_send(agentId="caocao") — 告知曹操「全流程审核通过，请汇总交付」
② 创建 `.sent_to_caocao` 佐证文件
③ 写入 caocao_notified_at 时间戳
④ 写入汇总步骤 status = completed

佐证文件路径：`deliverables/{work_id}/.sent_to_main`，写入调用时间和 work_id。
