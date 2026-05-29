#!/usr/bin/env bash
# validate-status.sh — 校验 status.json 状态一致性
# 检测：矛盾状态（completed 但未汇报）、步骤不连续（跳步完成）
# 甄宓每次更新 status.json 后必须运行此脚本
# <!-- V7 v2026.05.29.2 -->
#
# 使用: bash scripts/validate-status.sh
# 环境变量: STATUS_FILE, DELIVERABLES_BASE, MAIN_SESSION_DIR

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

STATUS_FILE="${STATUS_FILE:-${REPO_ROOT}/data/status.json}"

if [ ! -f "$STATUS_FILE" ]; then
  echo "❌ status.json 不存在: $STATUS_FILE"
  exit 1
fi

DELIVERABLES_BASE="${DELIVERABLES_BASE:-$HOME/.openclaw/deliverables}"

# =====================================================================
# 强制Skill加载检查：验证当前主会话是否已加载工作流Skill
# 检查方法：扫描主会话最新trajectory文件的finalPromptText/assistantTexts
# =====================================================================
SKILL_INDEX="team-share/skills/_index/SKILL.md"
SKILL_WORKFLOW="team-share/skills/team-workflow/SKILL.md"
MAIN_SESSION_DIR="$HOME/.openclaw/agents/main/sessions"

python3 -c "
import json, os, sys

sk_index = '$SKILL_INDEX'
sk_workflow = '$SKILL_WORKFLOW'
session_dir = '$MAIN_SESSION_DIR'

if not os.path.isdir(session_dir):
    print('⚠️ 警告：主会话日志目录不存在（$MAIN_SESSION_DIR），跳过Skill加载检查')
    sys.exit(0)

# 找到最新的trajectory文件
import glob
traj_files = sorted(glob.glob(os.path.join(session_dir, '*.trajectory.jsonl')), key=os.path.getmtime, reverse=True)

if not traj_files:
    print('⚠️ 警告：未找到主会话trajectory文件，跳过Skill加载检查')
    sys.exit(0)

# 只检查最新10个trajectory文件（避免扫描全部）
found_index = False
found_workflow = False
checked_count = 0

for f in traj_files[:10]:
    checked_count += 1
    try:
        with open(f, 'r') as fh:
            for line in fh:
                line = line.strip()
                if not line: continue
                try:
                    d = json.loads(line)
                except:
                    continue
                data = d.get('data', {})
                if not isinstance(data, dict): continue
                
                # 检查finalPromptText和assistantTexts
                prompt = str(data.get('finalPromptText', ''))
                texts = data.get('assistantTexts', [])
                texts_str = ' '.join(str(t) for t in texts) if isinstance(texts, list) else str(texts)
                
                if sk_index in prompt or sk_index in texts_str:
                    found_index = True
                if sk_workflow in prompt or sk_workflow in texts_str:
                    found_workflow = True
    except Exception as e:
        pass

loaded_skills = []
if found_index:
    loaded_skills.append('总纲(_index/SKILL.md)')
if found_workflow:
    loaded_skills.append('工作流模板(team-workflow/SKILL.md)')

if not found_index and not found_workflow:
    print('❌ 未检测到工作流Skill加载记录')
    print('   请先加载以下Skill文件：')
    print(f'   - {sk_index}（总纲）')
    print(f'   - {sk_workflow}（工作流模板）')
    print('   排查范围：最近10个主会话trajectory文件')
    sys.exit(1)
elif not found_index:
    print(f'⚠️ 警告：未检测到总纲Skill({sk_index})加载记录')
    loaded_skills.append('未找到')
elif not found_workflow:
    print(f'⚠️ 警告：未检测到工作流模板({sk_workflow})加载记录')
    loaded_skills.append('未找到')
else:
    print(f'✅ Skill加载检查通过：已加载{" + ".join(loaded_skills)}')
    sys.exit(0)
" 2>&1
SKILL_CHECK_EXIT=$?

if [ $SKILL_CHECK_EXIT -ne 0 ]; then
  echo ""
  echo "请先使用 read 工具加载对应 Skill 文件，然后重新运行此脚本。"
  echo ""
  # 非0退出但如果是warning(exit=0但打印了warning)则继续
  # 注意：python3脚本exit(0)=通过, exit(1)=阻止
fi

export STATUS_FILE="$STATUS_FILE"
export DELIVERABLES_BASE="$DELIVERABLES_BASE"
python3 <<'PYEOF' 2>&1
import json, sys, os

STATUS_FILE = os.environ['STATUS_FILE']
DELIVERABLES_BASE = os.environ['DELIVERABLES_BASE']

with open(STATUS_FILE, 'r', encoding='utf-8') as f:
    data = json.load(f)

steps = data.get('steps', [])
errors = []
warnings = []
work_id = data.get('current_task', {}).get('work_id', 'unknown')

# 收集有效步骤（未取消的步骤）
active_steps = [s for s in steps if s.get('status') not in ('已取消',)]
active_ids = [s['id'] for s in active_steps]

# 检查1: 矛盾检测 — 基于新架构字段（reported_next / reported_at）
for s in steps:
    sid = s['id']
    status = s.get('status', '')
    reported_next = s.get('reported_next', None)
    reported_at = s.get('reported_at', None)
    completed_at = s.get('completed_at', None)
    name = s.get('name', '')

    if status == 'completed' and not completed_at:
        errors.append(f'第{sid}步 \"{name}\": status=completed 但缺少 completed_at → 缺少完成时间戳')

    if status == 'completed' and completed_at and reported_next == False:
        warnings.append(f'第{sid}步 \"{name}\": status=completed 但 reported_next=False → 已完成但未 relay 接力')

    if status == 'completed' and reported_next == True and not reported_at:
        errors.append(f'第{sid}步 \"{name}\": reported_next=True 但缺少 reported_at → 标记了已接力但没有时间戳')

    if status != 'completed' and reported_next == True:
        errors.append(f'第{sid}步 \"{name}\": status=\"{status}\" 但 reported_next=True → 矛盾（未完成却标记已接力）')

    if reported_at and completed_at and reported_at < completed_at:
        errors.append(f'第{sid}步 \"{name}\": reported_at({reported_at}) 早于 completed_at({completed_at}) → 时间矛盾')

    old_reported = s.get('reported_to', '')
    old_notified = s.get('notified_main_at', None)
    if old_reported or old_notified:
        warnings.append(f'第{sid}步 \"{name}\": 使用了旧字段 (reported_to/notified_main_at) → 建议迁移到新字段 (reported_next/reported_at)')

    if reported_next is not None and not isinstance(reported_next, bool):
        errors.append(f'第{sid}步 \"{name}\": reported_next=\"{reported_next}\" 类型错误 → 必须为 true/false')

    if status != 'completed' and reported_next is None:
        pass

# 检查3: 非编程类任务必须包含曹植润色步骤
task_type = data.get('current_task', {}).get('type', '')
if task_type == '非编程类':
    has_caozhi = any(
        '曹植' in s.get('name', '') or '曹植' in s.get('assignee', '')
        for s in steps
    )
    if not has_caozhi:
        errors.append(f'任务类型为"非编程类"但未找到曹植相关步骤 → 非编程类任务必须包含曹植润色→司马懿审曹植环节')

# 编程类任务专属检查 — 按 name/assignee 关键词语义检测
if task_type == '编程类':
    keyword_rules = [
        (['编码'], '貂蝉（OpenCode）'),
        (['上传', 'GitHub', 'Release'], '貂蝉（OpenCode）'),
        (['汇总', '呈报'], '曹操'),
    ]
    for s in steps:
        step_name = s.get('name', '')
        actual_assignee = s.get('assignee', '')
        for keywords, expected in keyword_rules:
            if any(kw in step_name for kw in keywords):
                if actual_assignee != expected:
                    errors.append(
                        f'第{s["id"]}步 "{step_name}": '
                        f'assignee="{actual_assignee}" 应为"{expected}"'
                        f' → 含关键词 {keywords} 的步骤必须由 {expected} 执行'
                    )

# 检查4: 汇总步骤的 relay 接力验证（新架构 — relay auto-advance 替代 sessions_send）
for s in steps:
    sid = s['id']
    status = s.get('status', '')
    reported_next = s.get('reported_next', None)
    reported_at = s.get('reported_at', None)
    name = s.get('name', '')
    is_summary = '汇总' in name or '呈报' in name

    if is_summary and status == 'completed' and reported_next == True and reported_at:
        deliverable_dir = os.path.join(DELIVERABLES_BASE, work_id)
        if not os.path.isdir(deliverable_dir):
            warnings.append(f'第{sid}步 \"{name}\": status=completed, reported_at={reported_at} 但交付物目录 {deliverable_dir} 不存在 → 请核查是否有交付物')
        else:
            if not os.listdir(deliverable_dir):
                warnings.append(f'第{sid}步 \"{name}\": 交付物目录 {deliverable_dir} 为空 → 可能未保存交付物')

# 检查2: 步骤连续性检测 — 有效步骤必须按顺序推进
for i in range(1, len(active_steps)):
    prev = active_steps[i-1]
    curr = active_steps[i]
    prev_status = prev.get('status', '')
    curr_status = curr.get('status', '')
    prev_name = prev.get('name', '')
    curr_name = curr.get('name', '')

    # 如果前一步不是 completed，当前步却是 completed，说明跳步
    if curr_status == 'completed' and prev_status not in ('completed', '已取消'):
        is_summary_step = '汇总' in curr_name or '呈报' in curr_name
        if is_summary_step:
            errors.append(f'第{curr["id"]}步 \"{curr_name}\" status=completed 但前一步（第{prev["id"]}步 \"{prev_name}\"）status={prev_status} → 跳步错误：汇总步骤在前一步未完成时不得提前标记 completed')
        else:
            warnings.append(f'第{curr["id"]}步 \"{curr_name}\" status=completed 但前一步（第{prev["id"]}步 \"{prev_name}\"）status={prev_status} → 跳步告警')

# 输出结果
if errors:
    print('❌ 校验失败（以下问题必须修复）：')
    for e in errors:
        print(f'  {e}')
    print()
    print('请修正 status.json 后重新运行此脚本。')
    sys.exit(1)

if warnings:
    print('⚠️ 校验通过但有告警（建议核查）：')
    for w in warnings:
        print(f'  {w}')
    print()
    sys.exit(0)

print('✅ 校验通过：状态一致性无异常')
sys.exit(0)
PYEOF

EXIT_CODE=$?
exit $EXIT_CODE
