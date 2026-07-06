#!/bin/bash
# herdr pane 안에서 실행되는 서브에이전트 transcript 뷰어
# usage: herdr-subagent-view.sh <agent-transcript.jsonl> [label]
f="$1"
printf '━━ %s ━━\n' "${2:-subagent}"
i=0
until [ -e "$f" ] || [ "$i" -ge 150 ]; do sleep 0.2; i=$((i + 1)); done
[ -e "$f" ] || { echo "transcript 없음: $f"; sleep 10; exit 1; }
exec tail -n +1 -F "$f" 2>/dev/null | jq -r --unbuffered '
  select(.type == "assistant") | .message.content[]? |
  if .type == "tool_use" then "→ \(.name) \(.input | tostring | .[0:160])"
  elif .type == "text" then "\n\(.text)\n"
  else empty end'
