# agent-meta

An opinionated workspace for working across multiple repositories with normal Git clones and per-task worktrees.

```
repos/<repo>/                 # base clone, default branch, read-only cache
worktrees/<task>/<repo>/      # task worktree, branch name == task name
```

The workspace repo stays public and only tracks rules, tasks, hooks, and config. Private source code in `repos/*` and `worktrees/*` is ignored.

## Setup

```bash
brew bundle
mise install
```

Add upstream repos once:

```bash
mise run add funfetti git@gitlab.example.com:team/funfetti.git
mise run add api      git@github.com:you/api.git
```

## Daily Workflow

```bash
mise run pull
mise run branch JIRA-123
cd worktrees/JIRA-123

# edit and commit inside repo directories, e.g. ./funfetti
mise run status
mise run diff
mise run push

cd ../..
mise run clean JIRA-123
```

`mise run branch JIRA-123` creates one repo worktree per configured repo:

```
worktrees/JIRA-123/funfetti   # branch JIRA-123 in funfetti
worktrees/JIRA-123/api        # branch JIRA-123 in api
```

## Tasks

| Task | Where | What it does |
|---|---|---|
| `add <name> <url> [branch]` | workspace root | Clone an upstream repo into `repos/<name>`. |
| `pull [repo...]` | workspace root | Fast-forward workspace and base repos. |
| `branch <task> [repo...]` | workspace root | Create `worktrees/<task>/<repo>` checkouts on branch `<task>`. |
| `status [repo...]` | root or task root | Show aggregated status. |
| `diff [repo...] [-- args]` | task root | Show aggregated diffs. |
| `push [repo...]` | task root | Push branch `<task>` for repos with commits. |
| `clean <task>` | workspace root | Remove clean repo worktrees for a task. |
| `list` | workspace root | List configured repos and task worktrees. |
| `test` | anywhere | Run the validation suite. |

## Guard Rails

Git and agent hooks enforce the workflow:

- Agents cannot edit `repos/*`.
- Agents can edit repo files under `worktrees/<task>/<repo>/*`.
- Mutating Git commands are blocked in `repos/*` and at the workspace root.
- Workspace commits cannot include `repos/*` or `worktrees/*`.
- `--no-verify`, `core.hooksPath`, and forced worktree removal are blocked.

## Tests

```bash
mise run test
```

The tests spin up temporary workspace clones and local fake upstream repos.
