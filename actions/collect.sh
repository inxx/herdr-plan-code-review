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

# 리뷰어가 하나도 없으면 빈 파일로 "성공"하지 말고 명확히 실패한다.
if ! agent_exists rev-cc && ! agent_exists rev-cx; then
  echo "plan-code-review: rev-cc/rev-cx 판이 없습니다. 먼저 layout 또는 review 액션을 실행하세요." >&2
  exit 1
fi

# $1=에이전트 이름 → recent 출력 텍스트(없으면 빈 값). 읽기 전 idle 대기(best effort).
read_agent() {
  "$HB" agent wait "$1" --status idle --timeout 20000 >/dev/null 2>&1 || true
  "$HB" agent read "$1" --source recent --lines "$LINES" 2>/dev/null \
    | jq -j '.result.read.text // ""' 2>/dev/null
}

# 리뷰 본문에 ```가 들어와도 안 깨지게 4중 백틱 펜스를 쓴다.
{
  echo "# Plan → Code → Review — 수집된 리뷰"
  echo
  echo "## rev-cc (claude)"
  echo '````'
  read_agent rev-cc
  echo '````'
  echo
  echo "## rev-cx (codex)"
  echo '````'
  read_agent rev-cx
  echo '````'
} > "$OUT"

echo "리뷰 수집 완료 → $OUT"
echo "병합: 아무 판에서 이 파일을 열어 두 리뷰를 dedupe + 심각도순으로 정리."
