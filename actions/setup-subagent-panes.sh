#!/usr/bin/env bash
# Claude Code 훅 설치: claude 세션이 서브에이전트를 띄우면 그 transcript를 tail하는
# 뷰어 판을 같은 탭 아래에 자동으로 열고, 끝나면 닫는다 (claude-hooks/ 스크립트 참조).
# 하는 일:
#   1. claude-hooks/*.sh 2개를 ~/.claude/hooks/ 에 복사 (+x)
#   2. ~/.claude/settings.json 의 hooks.SubagentStart/SubagentStop 에 등록
# 멱등: 이미 등록된 이벤트는 건드리지 않는다(경로가 달라도 스크립트명으로 인식).
# settings.json 을 바꿀 때만 .bak-타임스탬프 백업을 남긴다. 새 claude 세션부터 적용.
set -u
ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
. "$ROOT/actions/lib.sh"

CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"

mkdir -p "$CLAUDE_DIR/hooks"
install -m 0755 "$ROOT/claude-hooks/herdr-subagent-pane.sh" "$CLAUDE_DIR/hooks/" \
  && install -m 0755 "$ROOT/claude-hooks/herdr-subagent-view.sh" "$CLAUDE_DIR/hooks/" \
  || { echo "plan-code-review: 훅 스크립트 복사 실패" >&2; exit 1; }

created=0
[ -f "$SETTINGS" ] || { printf '{}\n' > "$SETTINGS"; created=1; }
jq -e . "$SETTINGS" >/dev/null 2>&1 \
  || { echo "plan-code-review: $SETTINGS 가 유효한 JSON이 아닙니다 — 손대지 않고 중단합니다" >&2; exit 1; }

entry='{"hooks":[{"command":"bash ~/.claude/hooks/herdr-subagent-pane.sh","timeout":10,"type":"command"}],"matcher":"*"}'
tmp=$(mktemp) || exit 1
jq --argjson e "$entry" '
  def has_hook: [.[]?.hooks[]?.command // ""] | any(contains("herdr-subagent-pane.sh"));
  .hooks = (.hooks // {})
  | .hooks.SubagentStart = (if (.hooks.SubagentStart | has_hook) then .hooks.SubagentStart else (.hooks.SubagentStart // []) + [$e] end)
  | .hooks.SubagentStop  = (if (.hooks.SubagentStop  | has_hook) then .hooks.SubagentStop  else (.hooks.SubagentStop  // []) + [$e] end)
' "$SETTINGS" > "$tmp" \
  || { rm -f "$tmp"; echo "plan-code-review: settings.json 병합 실패" >&2; exit 1; }

# 비교는 시맨틱으로 — 포맷 차이만으로 파일을 다시 쓰지 않는다.
if jq . "$SETTINGS" | cmp -s - "$tmp"; then
  rm -f "$tmp"
  echo "훅 스크립트 갱신 완료 — settings.json 은 이미 등록돼 있어 그대로 둠"
else
  # 방금 만든 빈 파일이면 백업할 내용이 없다
  [ "$created" = "1" ] || cp "$SETTINGS" "$SETTINGS.bak-$(date +%Y%m%d-%H%M%S)"
  mv "$tmp" "$SETTINGS"
  echo "설치 완료: ~/.claude/hooks/ 스크립트 2개 + settings.json 훅 등록 (기존 파일은 .bak-* 백업)"
fi
echo "새 claude 세션부터 적용됩니다. 특정 에이전트만 보려면 settings.json 의 matcher 를 좁히고, 종료 후 판을 남기려면 SubagentStop 항목을 빼세요."
