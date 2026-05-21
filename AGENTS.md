# Agent workspace

This is a public **workspace repo** that coordinates multiple normal Git clones. Source repos live as local clones under `repos/`, and per-task Git worktrees live under `worktrees/<task>/<repo>`.

## Layout

```
repos/<repo>/                 ← base clone, read-only cache of the default branch
worktrees/<task>/<repo>/      ← task checkout, branch name matches <task>
```

Agents should do repo work only inside `worktrees/<task>/<repo>/`. Never edit, commit, or push from `repos/<repo>/`.

## Workflow

### 1. Sync

```bash
mise run pull
```

This fast-forwards the workspace repo and each base clone in `repos/*`.

### 2. Start A Task

```bash
mise run branch JIRA-123
cd worktrees/JIRA-123
```

This creates one Git worktree per configured repo. Each checkout uses branch `JIRA-123`, so PR/MR branches are consistent across repos.

### 3. Work

- Edit files under `worktrees/<task>/<repo>/`.
- Commit inside each repo worktree as usual.
- Use `mise run status` and `mise run diff` from `worktrees/<task>` for aggregated views.
- Do not commit from `repos/*`; those are base clones only.

### 4. Ship

```bash
mise run push
```

Run this from `worktrees/<task>`. It pushes branch `<task>` for each repo with commits.

### 5. Clean Up

```bash
mise run clean JIRA-123
```

This removes clean repo worktrees for the task.

## Rules

- `repos/*` is read-only for agents.
- Repo edits happen in `worktrees/<task>/<repo>/*`.
- Task name and branch name are the same across repos.
- The workspace repo should only commit tooling, docs, hooks, and config.
- Workspace commits must not include `repos/*` or `worktrees/*`.
- `--no-verify`, `core.hooksPath` reconfiguration, and `git worktree remove --force` are blocked.

## Mise Tasks

| Goal | Use |
|---|---|
| Add a repo clone | `mise run add <name> <url> [branch]` |
| Pull workspace and base repos | `mise run pull [repo...]` |
| Create a task stripe | `mise run branch <task> [repo...]` |
| Aggregate status | `mise run status [repo...]` |
| Aggregate diff | `mise run diff [repo...]` |
| Push task branches | `mise run push [repo...]` |
| Remove clean task worktrees | `mise run clean <task>` |
| List repos and tasks | `mise run list` |

Raw Git is fine inside `worktrees/<task>/<repo>`. Prefer mise tasks for cross-repo operations.
