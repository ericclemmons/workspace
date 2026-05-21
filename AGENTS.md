# Agent workspace

This is a **meta-repo** that mounts multiple repositories as git subtrees under `repos/`. You work across all of them as if they were one monorepo. When you're done, `mise run push` pushes one branch per upstream repo you touched.

## What you see

Inside any worktree (where you should always be), the layout is:

```
repos/<name-1>/     ← full source of upstream repo 1
repos/<name-2>/     ← full source of upstream repo 2
repos/<name-3>/     ← full source of upstream repo 3
```

`git status`, `git diff`, `git log` work across all of them in one view. Edit files anywhere; commit normally.

## Workflow

### 1. Start a task

```bash
mise run branch <name>          # e.g. jira-123, fix-webhook, feat-auth
cd worktrees/<name>
```

This creates a worktree on a new branch with the same name. Use any branch name your team's conventions call for — there's no required prefix.

### 2. Work

- Edit files anywhere under `repos/<name>/`.
- Commit one logical change per commit. Commits that span multiple subtrees are fine — `mise run push` splits them correctly into per-repo upstream branches.
- Write commit messages from each touched repo's perspective. The `repos/` structure is invisible upstream — don't reference those paths.

### 3. Stay in sync (when needed)

If you notice a subtree is far behind upstream (`git log HEAD..<remote>/main` shows lots of commits), tell the user. They'll run `mise run pull <name>` from the meta main checkout. After that, you `git rebase main` in your worktree and continue.

### 4. Ship

```bash
mise run push           # detects touched subtrees and pushes each upstream branch
```

If push fails with "non-fast-forward," upstream moved during your work. Same recovery as above: ask the user to `mise run pull <name>`, then rebase, then re-push.

## Rules (enforced by hooks)

- Edits must be inside `worktrees/*/`
- No git mutations from the meta main checkout
- No commits or pushes on `main`
- `.githooks/`, `AGENTS.md`, `.claude/`, `opencode.json`, `mise.toml`, `hk.pkl`, `.gitconfig`, and `mise-tasks/*` are write-protected unless the user explicitly asks
- `--no-verify` and `core.hooksPath` reconfiguration are blocked
- `git worktree remove --force` is blocked

When a hook blocks you, read the reason and adjust. Don't try to circumvent it.

## Use mise tasks over raw git for these

| Goal | Use | Not |
|---|---|---|
| Start work | `mise run branch <name>` | `git worktree add ...` |
| Push subtree branches | `mise run push` | manual `git subtree push` invocations |
| Pull meta/subtree changes and prune merged worktrees | (tell user) `mise run pull` | `git pull` + `git subtree pull` |

Raw git is the right tool for everything else: `git status`, `git diff`, `git log`, `git add`, `git commit`, `git rebase`, `git checkout`.

## Where am I?

`git rev-parse --show-toplevel`:
- ends in `/worktrees/<something>` → you're in a worktree, good.
- equals the meta root → you're in the main checkout; `cd` into a worktree first.
