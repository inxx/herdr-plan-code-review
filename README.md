# Plan → Code → Review (herdr plugin)

Opens a four-agent workflow with one herdr action: **Opus plans, Sonnet codes,
Claude (Opus) + Codex review.** herdr manages only the panes and their state
(`idle` / `working` / `blocked`); the model and role of each pane are set by its
launch command. Handoff between panes happens through the filesystem
(`plan.md`, `git diff`).

![herdr plan → code → review layout](docs/layout.png)

| Pane      | Location    | Command                                        | Role            |
| --------- | ----------- | ---------------------------------------------- | --------------- |
| `planner` | current tab | `claude --permission-mode plan --model opus`   | plan → plan.md  |
| `coder`   | current tab | `claude --model sonnet`                          | implement plan  |
| `rev-cc`  | review tab  | `claude --model opus`                            | review git diff |
| `rev-cx`  | review tab  | `codex`                                          | review git diff |

Two independent reviewers (Claude + Codex) on the same diff catch different
classes of issues — coverage, not redundancy. Running them in separate panes
also keeps their contexts independent, which avoids the self-review bias of
asking the coding session to review its own work.

## Install

```bash
herdr plugin install inxx/herdr-plan-code-review
```

To hack on it locally, clone and link:

```bash
git clone https://github.com/inxx/herdr-plan-code-review
herdr plugin link ./herdr-plan-code-review
```

## Actions

- **`layout`** — opens the four panes (idempotent: existing panes are reused).
  - UI: right-click a workspace/tab → "Plan → Code → Review layout"
  - CLI: `herdr plugin action invoke plan-code-review.layout`
- **`review`** — the review handoff. Ensures `rev-cc` / `rev-cx` exist and
  **types** the review prompt into both panes. `agent send` does not press
  Enter, so you eyeball the diff and hit Enter yourself (a safety checkpoint).
  - CLI: `herdr plugin action invoke plan-code-review.review`

## Workflow

1. In `planner`, produce a plan and save it to `plan.md` (plan mode never edits files).
2. In `coder` (`herdr agent attach coder`): "read plan.md, implement it, then `git add -A`".
3. Run the `review` action → the prompt is typed into `rev-cc` / `rev-cx` → hit Enter in each.
4. In any pane, merge both reviews: dedupe and sort by severity.

herdr highlights whichever pane is `blocked` in the tab bar, so you attach to
the one that needs you instead of polling four terminals.

## Auto-handoff (opt-in)

When `coder` goes `idle` and the diff has changed, the `review` action is
invoked automatically. Because Claude's `idle` really means "waiting for your
input" (it fires constantly), this is **off by default**; and even when on, the
`review` action only *types* the prompt (it doesn't submit), so a spurious fire
is harmless.

```bash
# enable
touch "$(herdr plugin config-dir plan-code-review)/autohandoff.on"
# disable
rm    "$(herdr plugin config-dir plan-code-review)/autohandoff.on"
```

It won't re-fire on the same diff (a fingerprint is stored in the state dir).

## Overrides (env)

```bash
PLANNER_MODEL=opus CODER_MODEL=sonnet REVIEW_MODEL=opus \
HERDR_REPO=/path/to/repo PCR_REVIEW_PROMPT="..." \
  herdr plugin action invoke plan-code-review.layout
```

Repo resolution order: `HERDR_REPO` → the `coder` pane's cwd → context JSON cwd
→ `$PWD`. If panes open in the wrong directory from the UI, set `HERDR_REPO`.

## Customize

Pane placement, models, the review prompt, and plan mode all live in
`actions/lib.sh` and `actions/*.sh`. The auto-handoff gate is in
`events/on-status.sh`.

> The screenshot is a real herdr capture; project names and paths have been
> replaced with mock data.
