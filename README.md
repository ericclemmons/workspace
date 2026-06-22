# workspace

An opinionated local workspace for working across multiple repositories as if they were one monorepo, without turning the upstream repos into a monorepo.

The workspace repo is configuration and coordination only. It should be installed like dotfiles with `tiged` or a tarball download, then used as a local-only Git repo. Do not clone it as the repo you push feature branches to.

```txt
<prefix>/             # first-class subtree folder imported from an upstream repo
.worktrees/<task>/    # one local workspace git worktree, branch == task
.worktrees/<task>/<prefix>/  # task copy of a subtree folder
```

## Install

Install `mise` once, then create the workspace from the template without preserving its Git remote:

```bash
npx tiged ericclemmons/workspace ~/workspace
cd ~/workspace
mise bootstrap
```

`tiged` matters because the top-level Git repo is local coordination state. It will contain subtree commits for private/source repos and is not meant to be pushed back to `ericclemmons/workspace`.

`mise bootstrap` is the onboarding command. It installs the configured tools, installs hooks, initializes the local workspace Git repo if needed, and creates the first local commit. If tools are already installed, rerunning it is safe.

## Add Repos

Add each upstream repo once from the workspace root:

```bash
mise run add dashboard git@github.com:you/dashboard.git
mise run add api       git@github.com:you/api.git
mise run add ui        git@github.com:you/ui.git packages/ui
```

Arguments:

```txt
add <name> <url> [prefix]
```

`add` registers a `workspace-<name>` remote, records the upstream default branch and subtree prefix in Git config, and imports the default branch into local `main` with `git subtree`. If `prefix` is omitted, the repo appears at `<name>`.

## Daily Workflow

Sync local `main` with all default upstream branches:

```bash
mise run pull
```

Start a cohesive feature branch/worktree:

```bash
mise run branch wire-api-me
cd .worktrees/wire-api-me
```

Now edit across repo prefixes in one checkout:

```txt
dashboard/
api/
packages/ui/
```

Commit once at the workspace worktree root:

```bash
git add dashboard api packages/ui
git commit -m "Wire up /api/me"
```

Review the combined change:

```bash
mise run status
mise run diff
```

Push PR branches back to each repo:

```bash
mise run push
```

`mise run push` checks which repo prefixes changed and runs `git subtree push --prefix <prefix> <remote> wire-api-me` for each changed repo.

Clean up the local workspace worktree after merge:

```bash
cd ../..
mise run pull
mise run clean wire-api-me
```

## Branch Names

The task name, workspace branch, workspace worktree name, and per-repo pushed branch all match:

```txt
.worktrees/wire-api-me
workspace branch: wire-api-me
dashboard branch: wire-api-me
api branch: wire-api-me
ui branch: wire-api-me
```

That consistency is the point of the workflow: treat a multi-repo feature as one monorepo-style branch while keeping upstream repos separate.

## Commands

| Task | Where | What it does |
|---|---|---|
| `add <name> <url> [prefix]` | workspace root | Register `workspace-<name>`, record metadata, and add a subtree prefix to local `main`. |
| `pull [repo...]` | workspace root on `main` | Fetch upstream remotes and subtree-pull repo defaults into local `main`. |
| `branch <task> [repo...]` | workspace root | Create `.worktrees/<task>` as one workspace Git worktree on branch `<task>`. |
| `status [repo...]` | root or task root | Show workspace or per-prefix task status. |
| `diff [repo...] [-- args]` | task root | Show per-prefix diffs against `main`, plus uncommitted diffs. |
| `push [repo...]` | task root | Push changed prefixes to branch `<task>` in each repo. |
| `clean <task>` | workspace root | Remove a clean workspace task worktree. |
| `list` | workspace root | List configured repos, prefixes, and task worktrees. |
| `test` | anywhere | Run the validation suite. |

## Rules

- Top-level subtree folders are first-class source snapshots.
- Source edits happen in `.worktrees/<task>/<prefix>/*`.
- Commit task work from `.worktrees/<task>`.
- Use `mise run pull` instead of root `git pull` for repo sync.
- Use `mise run push` instead of root `git push` for repo PR branches.
- The workspace root is local-only and should not be pushed.
- `--no-verify`, `core.hooksPath` reconfiguration, and `git worktree remove --force` are blocked.

## Tests

```bash
mise run test
```

The tests create temporary local upstream repos and exercise add, branch, subtree commit, subtree push, pull, and cleanup.
