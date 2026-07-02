#!/usr/bin/env bash
# 자동 핸드오프(opt-in): coder 판이 idle이 되고 diff가 바뀌었을 때 review 액션을 부른다.
# review 액션은 프롬프트를 "주입만" 하므로(자동 실행 아님) 헛발화해도 무해하다.
# 켜기:  touch "$(herdr plugin config-dir plan-code-review)/autohandoff.on"
# 끄기:  rm    "$(herdr plugin config-dir plan-code-review)/autohandoff.on"
set -u
ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
. "$ROOT/actions/lib.sh"

# opt-in 아니면 즉시 종료 (footgun 방지: claude의 idle = "사용자 입력 대기"라 자주 뜬다)
[ -f "${HERDR_PLUGIN_CONFIG_DIR:-/nonexistent}/autohandoff.on" ] || exit 0

CTX="${HERDR_PLUGIN_CONTEXT_JSON:-}"; [ -n "$CTX" ] || exit 0
pid=$(printf '%s' "$CTX" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("data",{}).get("pane_id") or "")' 2>/dev/null)
st=$(printf  '%s' "$CTX" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("data",{}).get("agent_status") or "")' 2>/dev/null)
[ "$st" = "idle" ] || exit 0
[ "$(name_of_pane "$pid")" = "coder" ] || exit 0   # coder가 idle 됐을 때만

REPO="$(resolve_repo)"
# 변경 지문(tracked diff + working state). HEAD 없거나 repo 아니면 빈 값 → skip.
h=$( { git -C "$REPO" diff HEAD 2>/dev/null; git -C "$REPO" status --porcelain 2>/dev/null; } | shasum | cut -d' ' -f1)
empty=$(printf '' | shasum | cut -d' ' -f1)
[ -n "$h" ] && [ "$h" != "$empty" ] || exit 0      # 변경 없으면 skip

mark="${HERDR_PLUGIN_STATE_DIR:-/tmp}/pcr-last-reviewed"
[ "$(cat "$mark" 2>/dev/null)" = "$h" ] && exit 0   # 같은 diff면 재발화 안 함
printf '%s' "$h" > "$mark"

"$HB" plugin action invoke plan-code-review.review
