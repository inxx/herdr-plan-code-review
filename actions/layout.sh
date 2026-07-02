#!/usr/bin/env bash
# herdr plan→code→review: 현재 워크스페이스에 에이전트 판 4개를 연다.
#   planner  = claude (Opus) plan mode
#   coder    = claude (Sonnet)
#   rev-cc   = claude (Opus) 리뷰
#   rev-cx   = codex 리뷰
# 판 사이 핸드오프는 파일시스템(plan.md, git diff)으로 한다 — herdr는 판과
# "누가 blocked인지" 상태 표시만 담당하고 모델/역할은 이 실행 커맨드가 정한다.
set -u

HB="${HERDR_BIN_PATH:-herdr}"

# 에이전트들이 작업할 repo 경로.
# ponytail: $HERDR_REPO → context JSON의 "cwd" → $PWD 순으로 고른다.
# herdr context 스키마가 다르면 HERDR_REPO로 직접 지정하면 됨.
resolve_repo() {
  if [ -n "${HERDR_REPO:-}" ]; then printf '%s' "$HERDR_REPO"; return; fi
  if [ -n "${HERDR_PLUGIN_CONTEXT_JSON:-}" ]; then
    local c
    c=$(printf '%s' "$HERDR_PLUGIN_CONTEXT_JSON" \
      | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    [ -n "$c" ] && { printf '%s' "$c"; return; }
  fi
  printf '%s' "$PWD"
}

REPO="$(resolve_repo)"
PLANNER_MODEL="${PLANNER_MODEL:-opus}"
CODER_MODEL="${CODER_MODEL:-sonnet}"
REVIEW_MODEL="${REVIEW_MODEL:-opus}"

echo "herdr plan→code→review"
echo "  repo:    $REPO"
echo "  planner: claude --permission-mode plan --model $PLANNER_MODEL"
echo "  coder:   claude --model $CODER_MODEL"
echo "  rev-cc:  claude --model $REVIEW_MODEL"
echo "  rev-cx:  codex"

# planner에 포커스를 두고 나머지는 --no-focus로 열어 포커스가 계획 판에 남게 한다.
"$HB" agent start planner --cwd "$REPO" --split right \
  -- claude --permission-mode plan --model "$PLANNER_MODEL"
"$HB" agent start coder   --cwd "$REPO" --split down  --no-focus \
  -- claude --model "$CODER_MODEL"
"$HB" agent start rev-cc  --cwd "$REPO" --split right --no-focus \
  -- claude --model "$REVIEW_MODEL"
"$HB" agent start rev-cx  --cwd "$REPO" --split down  --no-focus \
  -- codex

echo "done — 판 경계는 드래그로 정리. attach: $HB agent attach planner"
