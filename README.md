# Plan → Code → Review (herdr plugin)

Opus가 계획, Sonnet이 코딩, Claude(Opus)+Codex가 리뷰하는 4-판 레이아웃을
herdr 액션 하나로 연다. herdr은 판과 상태(`idle`/`working`/`blocked`)만
관리하고, 모델·역할은 각 판의 실행 커맨드가 정한다. 판 사이 핸드오프는
파일시스템(`plan.md`, `git diff`)으로 한다.

| 판        | 실행                                          | 역할            |
| --------- | --------------------------------------------- | --------------- |
| `planner` | `claude --permission-mode plan --model opus`  | 계획 → plan.md  |
| `coder`   | `claude --model sonnet`                        | plan.md 구현    |
| `rev-cc`  | `claude --model opus`                          | git diff 리뷰   |
| `rev-cx`  | `codex`                                        | git diff 리뷰   |

## 설치

```bash
herdr plugin link /Users/mediquitous/herdr-plan-code-review
```

## 실행

- **UI**: 워크스페이스/탭 우클릭 메뉴 → "Plan → Code → Review layout"
- **CLI** (repo 디렉터리에서):
  ```bash
  herdr plugin action invoke plan-code-review.layout
  ```

## 모델/경로 오버라이드 (env)

```bash
PLANNER_MODEL=opus CODER_MODEL=sonnet REVIEW_MODEL=opus \
HERDR_REPO=/path/to/repo \
  herdr plugin action invoke plan-code-review.layout
```

- `HERDR_REPO` 미지정 시: context JSON의 `cwd` → `$PWD` 순으로 결정.
  UI 메뉴에서 열었을 때 판이 엉뚱한 디렉터리에서 뜨면 `HERDR_REPO`를 지정.

## 워크플로

1. `planner`에서 계획 세우고 `plan.md`로 저장 (plan mode라 파일 안 건드림).
2. `coder`(`herdr agent attach coder`)에서 "plan.md 읽고 구현, 끝나면 git add -A".
3. `rev-cc` / `rev-cx` 각각에서 "현재 git diff 리뷰" — 서로 안 보여주고 독립적으로.
4. 아무 판에서 두 리뷰 합쳐 중복 제거 + 심각도순 정렬.

herdr이 `blocked` 판을 탭에 하이라이트하므로, 4개 터미널을 폴링할 필요 없이
기다리는 판만 attach하면 된다.

## 커스터마이즈

판 배치·모델·plan mode 여부는 전부 `actions/layout.sh` 한 파일에서 수정한다.
