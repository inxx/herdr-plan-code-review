#!/bin/bash
# SubagentStart → 이 claude가 떠 있는 herdr 탭에 transcript 뷰어 pane 생성
# SubagentStop  → 해당 pane 닫기
# herdr pane 밖(Claude Code Desktop, 일반 터미널)에서는 no-op —
# herdr가 pane에 주입하는 env(HERDR_ENV/HERDR_PANE_ID)로 판별 (herdr-agent-state.sh와 동일 가드)
[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_PANE_ID:-}" ] || exit 0
command -v herdr >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
evt=$(jq -r '.hook_event_name' <<<"$input")
sid=$(jq -r '.session_id' <<<"$input")
aid=$(jq -r '.agent_id // empty' <<<"$input")
[ -n "$aid" ] || exit 0
atype=$(jq -r '.agent_type // "agent"' <<<"$input")
tpath=$(jq -r '.transcript_path' <<<"$input")

# 이름은 Start/Stop 양쪽에서 동일하게 재계산 (상태 파일 불필요)
label=$(printf '%s' "$atype" | tr -c 'a-zA-Z0-9' '-' | cut -c1-14)
name="sub-${label}-${aid:0:5}"

case "$evt" in
SubagentStart)
  file="$(dirname "$tpath")/$sid/subagents/agent-$aid.jsonl"
  tab=$(herdr pane get "$HERDR_PANE_ID" 2>/dev/null | jq -r '.result.pane.tab_id // empty')
  [ -n "$tab" ] || exit 0
  herdr agent start "$name" --tab "$tab" --split down --no-focus -- \
    bash "$HOME/.claude/hooks/herdr-subagent-view.sh" "$file" "$atype" \
    >/dev/null 2>&1
  ;;
SubagentStop)
  pane=$(herdr agent get "$name" 2>/dev/null | jq -r '.result.agent.pane_id // empty')
  [ -n "$pane" ] && herdr pane close "$pane" >/dev/null 2>&1
  ;;
esac
exit 0
