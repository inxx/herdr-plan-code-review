#!/usr/bin/env bash
# 결정적 리뷰 핸드오프: rev-cc/rev-cx 확보 후 리뷰 프롬프트를 두 판에 주입한다.
# agent send는 Enter를 누르지 않는다 — 프롬프트만 미리 채워두고 사람이 Enter로
# 실행한다(리뷰를 실제로 시작하기 전 diff를 눈으로 확인하는 안전 체크포인트).
set -u
ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
. "$ROOT/actions/lib.sh"

ensure_reviewers "$(resolve_repo)"

# 방금 생성된 경우 TUI가 입력받을 준비(idle)가 될 때까지 잠깐 대기 — best effort.
"$HB" agent wait rev-cc --status idle --timeout 20000 >/dev/null 2>&1 || true
"$HB" agent wait rev-cx --status idle --timeout 20000 >/dev/null 2>&1 || true

"$HB" agent send rev-cc "$REVIEW_PROMPT"
"$HB" agent send rev-cx "$REVIEW_PROMPT"
echo "리뷰 프롬프트 주입 완료(rev-cc, rev-cx). 각 판에서 Enter로 실행."
