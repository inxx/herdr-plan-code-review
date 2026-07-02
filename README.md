# Plan → Code → Review (herdr plugin)

Opus가 계획, Sonnet이 코딩, Claude(Opus)+Codex가 리뷰하는 레이아웃을 herdr
액션으로 연다. herdr은 판과 상태(`idle`/`working`/`blocked`)만 관리하고,
모델·역할은 각 판의 실행 커맨드가 정한다. 판 사이 핸드오프는 파일시스템
(`plan.md`, `git diff`)으로 한다.

| 판        | 위치         | 실행                                          | 역할           |
| --------- | ------------ | --------------------------------------------- | -------------- |
| `planner` | 현재 탭      | `claude --permission-mode plan --model opus`  | 계획 → plan.md |
| `coder`   | 현재 탭      | `claude --model sonnet`                        | plan.md 구현   |
| `rev-cc`  | review 탭    | `claude --model opus`                          | git diff 리뷰  |
| `rev-cx`  | review 탭    | `codex`                                        | git diff 리뷰  |

## 설치

```bash
herdr plugin install inxx/herdr-plan-code-review
```

로컬에서 고쳐 쓸 땐 clone 후 link:

```bash
git clone https://github.com/inxx/herdr-plan-code-review
herdr plugin link ./herdr-plan-code-review
```

## 액션

- **`layout`** — 판 4개를 연다(멱등: 이미 있는 판은 다시 안 만듦).
  - UI: 워크스페이스/탭 우클릭 → "Plan → Code → Review layout"
  - CLI: `herdr plugin action invoke plan-code-review.layout`
- **`review`** — 리뷰 핸드오프. rev-cc/rev-cx를 확보하고 리뷰 프롬프트를 두 판에
  **주입**한다. `agent send`는 Enter를 안 누르므로, 각 판에서 diff를 확인하고
  직접 Enter로 실행한다(안전 체크포인트).
  - CLI: `herdr plugin action invoke plan-code-review.review`

## 워크플로

1. `planner`에서 계획 → `plan.md` 저장 (plan mode라 파일 안 건드림).
2. `coder`(`herdr agent attach coder`)에서 "plan.md 읽고 구현, 끝나면 `git add -A`".
3. `review` 액션 실행 → rev-cc/rev-cx에 프롬프트 주입 → 각 판에서 Enter.
4. 아무 판에서 두 리뷰 합쳐 중복 제거 + 심각도순 정렬.

herdr이 `blocked` 판을 탭에 하이라이트하므로 4개 터미널을 폴링할 필요 없이
기다리는 판만 attach하면 된다.

## 자동 핸드오프 (opt-in)

`coder`가 idle이 되고 diff가 바뀌면 `review` 액션을 자동 호출한다. claude의
idle은 "사용자 입력 대기"라서 자주 뜨므로 **기본 꺼짐**이며, 켜도 review는
프롬프트를 *주입만* 하므로(자동 실행 아님) 오발화해도 무해하다.

```bash
# 켜기
touch "$(herdr plugin config-dir plan-code-review)/autohandoff.on"
# 끄기
rm    "$(herdr plugin config-dir plan-code-review)/autohandoff.on"
```

같은 diff에는 재발화하지 않는다(state dir에 지문 저장).

## 오버라이드 (env)

```bash
PLANNER_MODEL=opus CODER_MODEL=sonnet REVIEW_MODEL=opus \
HERDR_REPO=/path/to/repo PCR_REVIEW_PROMPT="..." \
  herdr plugin action invoke plan-code-review.layout
```

- repo 결정 순서: `HERDR_REPO` → `coder` 판의 cwd → context JSON cwd → `$PWD`.
  UI에서 엉뚱한 경로로 뜨면 `HERDR_REPO` 지정.

## 커스터마이즈

판 배치·모델·리뷰 프롬프트·plan mode 여부는 `actions/lib.sh`와 `actions/*.sh`
에서 수정. 자동 핸드오프 게이트는 `events/on-status.sh`.
