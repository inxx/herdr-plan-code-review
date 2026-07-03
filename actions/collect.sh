#!/usr/bin/env bash
# 리뷰 수집: rev-cc/rev-cx 두 판의 최근 출력을 읽어 한 파일로 합친다(병합/정리용).
# herdr agent read = article의 "pane read". 이걸로 수동 복붙 단계(README step 4)를 없앤다.
#
# 대기 전략: herdr의 'done'은 UI attention 상태라 CLI로 대기할 수 없다
# ("use idle for CLI agent completion waits"). 그래서 읽기 전 best-effort로 idle을
# 기다려(생성 중이면 부분 캡처 방지) 대기가 안 되면 그냥 지금 보이는 걸 읽는다.
set -u
ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
. "$ROOT/actions/lib.sh"

LINES="${PCR_COLLECT_LINES:-400}"
OUT="${HERDR_PLUGIN_STATE_DIR:-/tmp}/reviews.md"

# $1=에이전트 이름 → recent 출력 텍스트(없으면 빈 값). 읽기 전 idle 대기(best effort).
read_agent() {
  "$HB" agent wait "$1" --status idle --timeout 20000 >/dev/null 2>&1 || true
  "$HB" agent read "$1" --source recent --lines "$LINES" 2>/dev/null | python3 -c 'import sys,json
try:
    print(json.load(sys.stdin)["result"]["read"]["text"], end="")
except Exception:
    pass'
}

{
  echo "# Plan → Code → Review — 수집된 리뷰"
  echo
  echo "## rev-cc (claude)"
  echo '```'
  read_agent rev-cc
  echo '```'
  echo
  echo "## rev-cx (codex)"
  echo '```'
  read_agent rev-cx
  echo '```'
} > "$OUT"

echo "리뷰 수집 완료 → $OUT"
echo "병합: 아무 판에서 이 파일을 열어 두 리뷰를 dedupe + 심각도순으로 정리."
