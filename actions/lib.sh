# shellcheck shell=bash
# 공유 헬퍼 — actions/*.sh, events/*.sh에서 source 한다.
HB="${HERDR_BIN_PATH:-herdr}"
PLANNER_MODEL="${PLANNER_MODEL:-opus}"
CODER_MODEL="${CODER_MODEL:-sonnet}"
REVIEW_MODEL="${REVIEW_MODEL:-opus}"
# shellcheck disable=SC2034  # review.sh가 source 후 사용
REVIEW_PROMPT="${PCR_REVIEW_PROMPT:-현재 git diff (git diff HEAD) 를 리뷰해줘. 정확성 버그 우선, 심각도순으로 정리.}"

# 필수 CLI 확인 — 없으면 조용히 오작동하지 말고 명확한 메시지로 죽는다.
for _dep in "$HB" jq; do
  command -v "$_dep" >/dev/null 2>&1 || {
    echo "plan-code-review: 필수 도구 '$_dep' 를 찾을 수 없습니다. 설치 후 다시 시도하세요." >&2
    exit 1
  }
done

# sha1 해시 — macOS(shasum)/linux(sha1sum) 중 존재하는 것을 쓴다.
_sha1() { if command -v shasum >/dev/null 2>&1; then shasum; else sha1sum; fi; }

# 에이전트들이 작업할 repo. 우선순위:
#   $HERDR_REPO → coder 판의 foreground_cwd → context JSON의 cwd → $PWD
# (coder가 떠 있으면 그 판의 cwd가 "지금 작업 중인 repo"의 가장 신뢰할 신호)
resolve_repo() {
  if [ -n "${HERDR_REPO:-}" ]; then printf '%s' "$HERDR_REPO"; return; fi
  local c
  c=$("$HB" agent list 2>/dev/null \
    | jq -r 'first((.result.agents[]? | select(.name=="coder") | (.foreground_cwd, .cwd)) | select(. != null and . != "")) // ""' 2>/dev/null)
  if [ -n "$c" ]; then printf '%s' "$c"; return; fi
  if [ -n "${HERDR_PLUGIN_CONTEXT_JSON:-}" ]; then
    c=$(printf '%s' "$HERDR_PLUGIN_CONTEXT_JSON" \
      | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    [ -n "$c" ] && { printf '%s' "$c"; return; }
  fi
  printf '%s' "$PWD"
}

# 이름으로 에이전트 존재 확인 (exit 0=있음)
agent_exists() {
  "$HB" agent list 2>/dev/null \
    | jq -e --arg n "$1" 'any(.result.agents[]?; .name==$n)' >/dev/null 2>&1
}

# pane_id → 에이전트 이름
name_of_pane() {
  "$HB" agent list 2>/dev/null \
    | jq -r --arg p "$1" 'first(.result.agents[]? | select(.pane_id==$p) | .name) // ""'
}

# 에이전트 이름 → tab_id (없으면 빈 값)
tab_of_agent() {
  "$HB" agent list 2>/dev/null \
    | jq -r --arg n "$1" 'first(.result.agents[]? | select(.name==$n) | .tab_id) // ""'
}

# rev-cc(claude), rev-cx(codex)를 별도 review 탭에 띄운다. 이미 있으면 재사용.
# 한쪽만 살아 있으면(판을 닫은 경우) 생존자의 탭에 없는 쪽만 다시 띄운다.
ensure_reviewers() {
  local repo="$1" tab
  agent_exists rev-cc && agent_exists rev-cx && return 0
  tab=$(tab_of_agent rev-cc); [ -n "$tab" ] || tab=$(tab_of_agent rev-cx)
  if [ -z "$tab" ]; then
    # 파이프라인 exit code는 jq 것 — tab create 실패는 값 검증으로 잡는다.
    tab=$("$HB" tab create --cwd "$repo" --label review --no-focus \
      | jq -r '.result.tab.tab_id // ""')
    { [ -n "$tab" ] && [ "$tab" != "null" ]; } \
      || { echo "plan-code-review: review 탭 생성 실패" >&2; return 1; }
  fi
  # --tab은 탭 cwd를 상속하지 않으므로 --cwd를 명시해야 리뷰어가 repo에서 뜬다.
  agent_exists rev-cc || "$HB" agent start rev-cc --cwd "$repo" --tab "$tab" --no-focus              -- claude --model "$REVIEW_MODEL"
  agent_exists rev-cx || "$HB" agent start rev-cx --cwd "$repo" --tab "$tab" --split down --no-focus -- codex
}
