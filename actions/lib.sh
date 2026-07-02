# 공유 헬퍼 — actions/*.sh, events/*.sh에서 source 한다.
HB="${HERDR_BIN_PATH:-herdr}"
PLANNER_MODEL="${PLANNER_MODEL:-opus}"
CODER_MODEL="${CODER_MODEL:-sonnet}"
REVIEW_MODEL="${REVIEW_MODEL:-opus}"
REVIEW_PROMPT="${PCR_REVIEW_PROMPT:-현재 git diff (git diff HEAD) 를 리뷰해줘. 정확성 버그 우선, 심각도순으로 정리.}"

# 에이전트들이 작업할 repo. 우선순위:
#   $HERDR_REPO → coder 판의 foreground_cwd → context JSON의 cwd → $PWD
# (coder가 떠 있으면 그 판의 cwd가 "지금 작업 중인 repo"의 가장 신뢰할 신호)
resolve_repo() {
  if [ -n "${HERDR_REPO:-}" ]; then printf '%s' "$HERDR_REPO"; return; fi
  local c
  c=$("$HB" agent list 2>/dev/null | python3 -c 'import sys,json
a=json.load(sys.stdin).get("result",{}).get("agents",[])
print(next((x.get("foreground_cwd") or x.get("cwd") or "" for x in a if x.get("name")=="coder"), ""))' 2>/dev/null)
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
  "$HB" agent list 2>/dev/null | python3 -c 'import sys,json
n=sys.argv[1]; a=json.load(sys.stdin).get("result",{}).get("agents",[])
sys.exit(0 if any(x.get("name")==n for x in a) else 1)' "$1"
}

# pane_id → 에이전트 이름
name_of_pane() {
  "$HB" agent list 2>/dev/null | python3 -c 'import sys,json
p=sys.argv[1]; a=json.load(sys.stdin).get("result",{}).get("agents",[])
print(next((x.get("name") for x in a if x.get("pane_id")==p), ""))' "$1"
}

# rev-cc(claude), rev-cx(codex)를 별도 review 탭에 띄운다. 이미 있으면 재사용.
ensure_reviewers() {
  local repo="$1" tab
  if agent_exists rev-cc || agent_exists rev-cx; then return 0; fi
  tab=$("$HB" tab create --cwd "$repo" --label review --no-focus \
    | python3 -c 'import sys,json;print(json.load(sys.stdin)["result"]["tab"]["tab_id"])') || return 1
  # --tab은 탭 cwd를 상속하지 않으므로 --cwd를 명시해야 리뷰어가 repo에서 뜬다.
  "$HB" agent start rev-cc --cwd "$repo" --tab "$tab" --no-focus              -- claude --model "$REVIEW_MODEL"
  "$HB" agent start rev-cx --cwd "$repo" --tab "$tab" --split down --no-focus -- codex
}
