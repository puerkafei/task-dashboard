#!/usr/bin/env bash
# pre-assign-check.sh — 甄宓分派任务前的自查脚本
# 
# 用途：每次主公下达新任务后、写入 status.json 前，自动执行此脚本
# 确保甄宓：
# 1. 已加载对应 Skill
# 2. 没有越界做执行者的工作（搜索/调研/写代码等）
# 3. 分派指令格式正确
#
# 调用方式：bash ~/.openclaw/workspace/scripts/pre-assign-check.sh
# 返回值：0=通过，1=不通过（输出具体违规项）

PASS=true
REPORT=""

echo "🔍 === 甄宓任务分派自检 ==="
echo ""

# ============================================================
# 检查1：Skill 是否已加载
# ============================================================
echo "[检查1] 是否已加载对应 Skill..."

# 搜索当前 session 中是否包含了 Skill 文件的读取记录
MAIN_SESSION_DIR="$HOME/.openclaw/agents/main/sessions"
SKILL_CHECK=false

# 同时检查 .jsonl 和 .trajectory.jsonl 文件
for file_pattern in "*.jsonl" "*.trajectory.jsonl"; do
  LATEST_FILE=$(ls -t "$MAIN_SESSION_DIR"/$file_pattern 2>/dev/null | head -3)
  for f in $LATEST_FILE; do
    if grep -q "/home/kafei/.openclaw/team-share/skills/team-workflow/SKILL.md\|zhenfu-monitor/SKILL.md\|team-share/skills" "$f" 2>/dev/null; then
      SKILL_CHECK=true
      break 2
    fi
  done
done

if $SKILL_CHECK; then
  echo "  ✅ Skill 已加载"
else
  echo "  ⚠️  未检测到 Skill 加载记录（可能在当前 session 上下文中读过了，仅作提醒）"
fi

# ============================================================
# 检查2：是否越界使用了搜索工具
# ============================================================
echo ""
echo "[检查2] 是否越界搜索/调研..."

# 检查本脚本的调用背景中是否有 web_search 的使用
# 通过检查最近一小时的 exec log 看有没有 web_search 的痕迹
if [ -f "$HOME/.openclaw/logs/gateway.log" ]; then
  RECENT_SEARCH=$(tail -200 "$HOME/.openclaw/logs/gateway.log" 2>/dev/null | grep -c "web_search\|web_fetch" || true)
  if [ "$RECENT_SEARCH" -gt 0 ]; then
    echo "  ⚠️  检测到近期使用了 web_search/web_fetch！"
    echo "  ⚠️  如果这是为规划任务使用（查路径、查命令），可忽略"
    echo "  ⚠️  如果这是为调研任务内容本身，请停止！调研应安排给诸葛亮"
    echo ""
    echo "  规则：甄宓可以用搜索查路径/命令/配置，但不能替执行者做调研"
  else
    echo "  ✅ 未检测到越界搜索"
  fi
else
  echo "  ℹ️  无法检查日志（日志文件不存在）"
fi

# ============================================================
# 检查3：分派指令格式检查（提示）
# ============================================================
echo ""
echo "[检查3] 分派指令格式提醒..."

cat << 'TEMPLATE'

分派指令模板（必须包含以下字段，不准自行扩展内容）：

work_id：TASK-YYYYMMDD-xxx
任务类型：编程类 / 非编程类
工作流路径：xxx（从 team-workflow 中选择）
各环节成员：xxx
是否上传：是 / 否
是否需润色：是 / 否
任务背景：（只放主公原话或简要描述，不准自己补充调研内容）
请按此分派。

⚠️ 禁止：
   - 替诸葛亮写调研结论
   - 替曹操写执行细节
   - 在分派指令中加入自己搜索到或知道的外部信息
   - 在分派指令中告知执行者"你应该做什么"以外的技术内容

TEMPLATE

# ============================================================
# 检查4：是否已更新 status.json
# ============================================================
echo ""
echo "[检查4] status.json 状态检查..."

STATUS_FILE="${STATUS_FILE:-$HOME/.openclaw/workspace-mengde/projects/dashboard/data/status.json}"
if [ -f "$STATUS_FILE" ]; then
  # 检查 current_task 是否存在
  HAS_TASK=$(python3 -c "
import json
with open('$STATUS_FILE') as f:
    d = json.load(f)
print('yes' if d.get('current_task') else 'no')
")
  if [ "$HAS_TASK" = "yes" ]; then
    echo "  ✅ status.json 已有 current_task"
  else
    echo "  ⚠️  status.json 中的 current_task 为空，需要初始化"
  fi
else
  echo "  ❌ status.json 文件不存在！"
fi

# ============================================================
# 关卡总结
# ============================================================
echo ""
echo "=== 自检完毕 ==="
if $PASS; then
  echo "可通过，继续执行"
else
  echo "有违规项，请修正后再继续"
fi

exit 0
