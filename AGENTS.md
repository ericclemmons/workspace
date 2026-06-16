# Agent workspace

This is a public **workspace repo** that coordinates multiple normal Git clones. Source repos live as local clones under `repos/`, and per-task Git worktrees live under `worktrees/<task>/<repo>`.

## Layout

```
repos/<repo>/                 ← base clone, read-only cache of the default branch
worktrees/<task>/<repo>/      ← task checkout, branch name matches <task>
```

Agents should do repo work only inside `worktrees/<task>/<repo>/`. Never edit, commit, or push from `repos/<repo>/`.

## Workflow

### 0. Discover Repos

```bash
mise run list
```

This shows the repos already supported by the workspace and existing task worktrees. Check this before cloning anything outside the workspace.

Prefer local clones for repository inspection and search. If a GitLab/GitHub repo is needed for code search, CODEOWNERS lookup, or MR investigation and it is not listed, add it with `mise run add <name> <url> [branch]` and search the local clone instead of using `glab api` for broad repository scans. Use API calls for metadata, MR state, approvals, comments, or small targeted lookups where local files are not enough.

For internal GitLab repos, derive the SSH URL directly from the project URL when possible. For example, `https://gitlab.cfdata.org/cloudflare/backstage/backstage` becomes `git@gitlab.cfdata.org:cloudflare/backstage/backstage.git`, then add it with `mise run add backstage git@gitlab.cfdata.org:cloudflare/backstage/backstage.git`. If the repo path is unknown, use GitLab project search only to identify the repo and its `ssh_url_to_repo`, for example `glab api 'projects?search=backstage&simple=true&per_page=100'` or `glab api 'groups/cloudflare/projects?search=backstage&include_subgroups=true&simple=true&per_page=100'`. Then run `mise run add <name> <ssh_url_to_repo>` and search the local clone; do not use `glab api` for code/content searches.

If a needed repo is not listed, add it to the workspace instead of cloning it manually:

```bash
mise run add workers-sdk git@github.com:cloudflare/workers-sdk.git
```

Use the repo name that should appear under `repos/<repo>`. The add task creates the base clone under `repos/` and records the default branch for future task stripes.

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

## Merge Requests

- Do not create a branch unless the user asks for code changes that need one. For documentation-only workspace updates, edit the workspace file directly unless asked to branch or commit.
- Before creating an MR, inspect `git status`, `git diff`, recent commits, and the target branch diff. Stage only intended files.
- Use `glab mr create` or `glab mr update` directly for GitLab MRs.
- Create GitLab MRs as drafts first with `glab mr create --draft ...` unless the user explicitly asks for a ready MR.
- Do not post comments or replies on MRs as the user unless the user explicitly asks you to comment. Updating MR titles and descriptions is allowed when it follows the guidance below or the user's direct instructions.
- MR descriptions must be concise and product-focused. Avoid generated summaries or long implementation notes unless the user explicitly asks for them.
- Use the standard multiline MR format when creating or updating MRs. Do not collapse it to one line unless the user explicitly asks for a one-line description.
- Describe the customer/product outcome, not just the code change.
- If a changeset is supported, use the same concise product-focused format as the MR description.
- Do not pass escaped newlines like `\n` in `glab --description` values. This renders literal `\n` text in GitLab.
- For multiline MR descriptions, do not use `glab mr create --description` or `glab mr update --description`; those can collapse line breaks or render escaped newlines incorrectly. Write the description to a temporary markdown file under `/tmp`, then update with `glab api projects/:fullpath/merge_requests/<iid> -X PUT -F description=@/tmp/description.md`. Verify with `glab mr view <iid>` that GitLab shows real line breaks.
- Do not use one-line MR descriptions for normal MR creation or updates. Only use a one-line description if the user explicitly requests one.

Preferred MR description format:

```markdown
**tl;dr – <what this does>**

<why this is needed>

<resulting behavior or customer/product outcome>

---

References: <links or issue references>
```

Use inline backticks for code identifiers, alert names, receivers, config keys, statuses, commands, and similarly exact values. Use markdown links for URLs when a short label is clearer than a raw URL.

Example:

```markdown
**tl;dr – Route `Workers CI` preview build alerts to `blackhole`.**

`Workers CI` preview builds are not currently monitored as live services, so `WCI_Preview_High_Build_Failure_Rate` and `WCI_Preview_Build_Completion_Rate_Low` are non-actionable when they fire in `chat-banda`.

The alerts remain visible in `Alertmanager`/`Karma`, but no longer post to `chat-banda` or trigger escalation notifications.

---

References: [`chat-banda` thread](https://chat.google.com/room/example)
```

## Mise Tasks

| Goal | Use |
|---|---|
| Add a repo clone | `mise run add <name> <url> [branch]` |
| List repos and tasks | `mise run list` |
| Pull workspace and base repos | `mise run pull [repo...]` |
| Create a task stripe | `mise run branch <task> [repo...]` |
| Aggregate status | `mise run status [repo...]` |
| Aggregate diff | `mise run diff [repo...]` |
| Push task branches | `mise run push [repo...]` |
| Remove clean task worktrees | `mise run clean <task>` |

Raw Git is fine inside `worktrees/<task>/<repo>`. Prefer mise tasks for cross-repo operations.
