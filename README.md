# agent-meta

An opinionated way to use `git subtree` to work across multiple repositories as one, with worktrees for per-task isolation and hooks to keep AI coding agents on the rails.

```
repos/<name>/        ← upstream repos mounted as subtrees
worktrees/<branch>/  ← per-task worktrees, each a full checkout of the meta-repo
```

A few thin shell scripts wrap the `git subtree` invocations so the right form is discoverable. The hooks make sure agents (Claude Code, OpenCode, …) follow the workflow.

## Setup

```bash
brew bundle          # installs mise + bash 4
mise install         # installs jq, gh
mise run setup       # configures hooks, creates bootstrap commit
```

Then mount each upstream repo:

```bash
mise run add dashboard git@gitlab.com:you/dashboard.git
mise run add api       git@gitlab.com:you/api.git
mise run add infra     git@gitlab.com:you/infra.git
```

This is a one-time thing — `add` is rare.

## Daily workflow

```bash
mise run branch jira-123        # creates worktrees/jira-123 on branch jira-123
cd worktrees/jira-123
claude                          # or opencode, or your editor

# inside the worktree, the agent sees:
#   repos/dashboard/  repos/api/  repos/infra/
# edit files anywhere, commit normally.

mise run push                   # detects touched subtrees, pushes branches, opens PRs

cd ../..
git worktree remove worktrees/jira-123
git branch -d jira-123
```

That's three commands during a task: `branch`, `push`, and the two-step cleanup (or skip cleanup until later).

## Staying in sync

```bash
mise run pull           # all subtrees
mise run pull dashboard # one subtree
```

Run this when an upstream has moved meaningfully since your last pull. For high-velocity repos, you might run it daily; for stable ones, weekly is fine. `mise run push` will tell you with a non-fast-forward error if you've waited too long — recovery is `pull`, then `git rebase main` in the worktree, then `push` again.

## All tasks

| Task | Where to run | What it does |
|---|---|---|
| `setup` | anywhere | Configure hooks, verify tooling. Idempotent. |
| `add <name> <url> [branch]` | main checkout | Mount upstream as subtree at `repos/<name>/`. |
| `branch <name>` | anywhere | Create `worktrees/<name>` on branch `<name>`. |
| `pull [name]` | main checkout | `git subtree pull` for all subtrees, or just one. |
| `push [--draft] [--no-pr]` | worktree | Push touched subtrees, open PRs via `gh`. |
| `test` | anywhere | Run the hook + task validation suite. |

Run `mise tasks` to list them. All tasks fail fast with clear errors when run from the wrong context.

## How `push` works

1. Detects which subtrees you touched by diffing your branch against the merge-base with `main`. (We could push every subtree — it's a no-op for unchanged ones — but detecting lets us skip empty PR creation.)
2. For each touched subtree, runs `git subtree push --prefix=repos/<name> <name> <branch>`. This extracts your commits that touched `repos/<name>/`, rewrites paths so `repos/<name>/src/foo.ts` becomes `src/foo.ts`, and pushes a synthetic branch to the upstream.
3. For each push, runs `gh pr create` against the upstream's GitHub/GitLab repo.

A single commit touching multiple subtrees is fine — `git subtree push` splits it correctly across the per-repo PRs.

## What the hooks enforce

**Git hooks** (`.githooks/pre-commit`) catch direct git use:
- No commits on `main`
- No commits from the meta main checkout (always work in a worktree)

**Agent hooks** (`.claude/settings.json`, `opencode.json` → `.githooks/agent-guard-*.sh`) catch agent tool calls before they execute:
- Edits must be inside `worktrees/*/`
- No git mutations from the main checkout
- No commits/pushes on `main`
- Meta-infrastructure (`.githooks/`, `AGENTS.md`, agent configs, `mise.toml`, `mise-tasks/*`) is write-protected
- `--no-verify`, `core.hooksPath` reconfiguration, and `worktree remove --force` are blocked

When blocked, the agent gets a JSON `decision: "block"` with a `reason` it reads and acts on.

## Layout

```
.
├── README.md              # this file
├── AGENTS.md              # agent-facing workflow doc, auto-loaded by Claude/OpenCode
├── Brewfile               # `brew bundle` → mise + bash
├── mise.toml              # pinned tools (jq, gh)
├── .gitignore             # ignores /worktrees
├── mise-tasks/            # task scripts; filename = task name
│   ├── _lib               # shared helpers (not a task)
│   ├── setup, add, branch, pull, push, test
├── .githooks/
│   ├── pre-commit
│   └── agent-guard-{edit,bash,context}.sh
├── .claude/settings.json  # Claude Code hook wiring
├── opencode.json          # OpenCode hook wiring
├── tests/run.sh           # hook + task validation suite
├── repos/                 # subtrees mount here
└── worktrees/             # gitignored
```

## Notes

- The `META_ALLOW_COMMIT=1` env var bypasses pre-commit for one command; `setup` uses it for the bootstrap commit. Don't `export` it.
- Worktree cleanup is the two-step `git worktree remove worktrees/<name>` then `git branch -d <name>`. Git refuses to delete a branch with a live worktree, which enforces the order.
- If `mise run push` is ever slow, cache subtree history once: `git subtree split --prefix=repos/<name> --rejoin` from the main checkout. Rarely needed.
- Drop into raw git any time the tasks don't fit. The tasks are wrappers, not a separate system.

## Tests

```bash
mise run test    # or: bash tests/run.sh
```

Covers hooks (blocking and allowing correctly) and tasks (happy paths plus error cases). Spins up fresh meta repos in `$TMPDIR` per test group; no state leaks.
