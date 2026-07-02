#!/usr/bin/env bash
# 계획→코딩→리뷰 판을 연다. planner/coder=현재 탭, rev-cc/rev-cx=별도 review 탭.
# 핸드오프는 파일시스템(plan.md, git diff)으로. herdr는 판과 상태만 관리한다.
set -u
ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
. "$ROOT/actions/lib.sh"

REPO="$(resolve_repo)"
echo "plan→code→review  repo=$REPO"

# 계획(Opus, plan mode) + 코딩(Sonnet) — 현재 탭. 이미 있으면 안 만든다(멱등).
agent_exists planner || "$HB" agent start planner --cwd "$REPO" --split right \
  -- claude --permission-mode plan --model "$PLANNER_MODEL"
agent_exists coder   || "$HB" agent start coder   --cwd "$REPO" --split down --no-focus \
  -- claude --model "$CODER_MODEL"

# 리뷰(Claude Opus + Codex) — 별도 review 탭.
ensure_reviewers "$REPO"

echo "coder 끝나면 리뷰 핸드오프:  $HB plugin action invoke plan-code-review.review"
