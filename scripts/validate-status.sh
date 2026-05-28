#!/usr/bin/env bash
# validate-status.sh — 校验 status.json 状态一致性
# 检测：矛盾状态（completed 但未汇报）、步骤不连续（跳步完成）
# 甄宓每次更新 status.json 后必须运行此脚本
# 使用: bash ~/.openclaw/workspace-mengde/scripts/validate-status.sh

STATUS_FILE="$HOME/.openclaw/workspace-mengde/projects/dashboard/data/status.json"

if [ ! -f "$STATUS_FILE" ]; then
  echo "❌ status.json 不存在"
  exit 1
fi

DELIVERABLES_BASE="$HOME/.openclaw/workspace-mengde/deliverables"

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

# 检查1: 矛盾检测 — completed 但 reported_to 不是已汇报（仅对汇总步骤强制）
for s in steps:
    sid = s['id']
    status = s.get('status', '')
    reported = s.get('reported_to', '')
    notified = s.get('notified_main_at', None)
    name = s.get('name', '')

    # 条件1: notified_main_at 不为空但 reported_to 不是已汇报
    if notified and notified != 'null' and notified != 'None' and reported != '已汇报':
        errors.append(f'第{sid}步 \"{name}\": notified_main_at={notified} 但 reported_to=\"{reported}\" → 矛盾（有时间戳却未标记已汇报）')

    # 条件2: status 为 completed 但 reported_to 是"未完成"（常规步骤的特殊情况）
    if status == 'completed' and reported == '未完成':
        errors.append(f'第{sid}步 \"{name}\": status=completed 但 reported_to=\"未完成\" → 矛盾（已完成却未汇报）')

    # 条件3: status 不是 completed 但 reported_to 是"已汇报"（流程伪造：未完成却标记已汇报）
    if status in ('待分配', '执行中', '审核中', '待开始', '') and reported == '已汇报':
        errors.append(f'第{sid}步 \"{name}\": status=\"{status}\" 但 reported_to=\"已汇报\" → 矛盾（未完成却标记已汇报，可能是流程伪造）')

    # 条件4: status 不是 completed 但 notified_main_at 不为空（流程伪造：未完成却写时间戳）
    if status in ('待分配', '执行中', '审核中', '待开始', '') and notified and notified != 'null' and notified != 'None':
        errors.append(f'第{sid}步 \"{name}\": status=\"{status}\" 但 notified_main_at=\"{notified}\" → 矛盾（未完成却写时间戳，可能是流程伪造）')

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

# 检查4: 曹操汇总步骤的 sessions_send 佐证文件验证
for s in steps:
    sid = s['id']
    status = s.get('status', '')
    notified = s.get('notified_main_at', None)
    name = s.get('name', '')
    is_summary = '汇总' in name or '呈报' in name

    if is_summary and status == 'completed' and notified and notified != 'null' and notified != 'None':
        sentinel_path = os.path.join(DELIVERABLES_BASE, work_id, '.sent_to_main')
        if not os.path.exists(sentinel_path):
            errors.append(f'第{sid}步 \"{name}\": status=completed, notified_main_at={notified} 但佐证文件 .sent_to_main 不存在 → 可能未实际调用 sessions_send')
        else:
            with open(sentinel_path, 'r') as sf:
                content = sf.read().strip()
            if notified not in content:
                warnings.append(f'第{sid}步 \"{name}\": 佐证文件内容 \"{content}\" 与 notified_main_at \"{notified}\" 不一致 → 请核查')

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
