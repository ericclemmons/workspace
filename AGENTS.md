# Agent workspace

This is a local **workspace repo** that coordinates multiple normal Git repos with `git subtree`. Upstream repos are imported as first-class subtree folders at the project root. Per-task workspace worktrees live under `.worktrees/<task>`.

When asked to inspect or work on source code, default to this project root (the directory containing this `AGENTS.md`), not `~` or a hard-coded workspace path. Search/read top-level subtree folders directly. Make source edits only in your own branch's workspace worktree under `.worktrees/`.

## Layout

```text
<prefix>/                       <- repo contents imported with git subtree
.worktrees/<task>/              <- one workspace checkout, branch name matches <task>
.worktrees/<task>/<prefix>/     <- task copy of the subtree folder to edit
```

Most prefixes are the repo name, but `mise run add <name> <url> [prefix]` can register a different subtree path when needed.

Agents should do repo task work only inside `.worktrees/<task>/<prefix>/`. The top-level subtree folders are source snapshots for reading/searching and for subtree sync commits; do not edit them directly for feature work.

Do not put checkout files under `.git/worktrees/`. Git owns `.git/worktrees/` for internal metadata about linked worktrees; actual working tree directories live outside `.git`, currently under `.worktrees/<task>/`.

## Workflow

### 0. Discover Repos

```bash
mise run list
```

This shows the repos already registered as subtree remotes and existing task worktrees. Check this before adding anything.

If a GitLab/GitHub repo is needed for code search, CODEOWNERS lookup, or MR investigation and it is not listed, add it with `mise run add <name> <url> [prefix]` and search the imported subtree instead of using `glab api` for broad repository scans. Use API calls for metadata, MR state, approvals, comments, or small targeted lookups where local files are not enough.

For internal GitLab repos, derive the SSH URL directly from the project URL when possible. For example, `https://gitlab.cfdata.org/cloudflare/backstage/backstage` becomes `git@gitlab.cfdata.org:cloudflare/backstage/backstage.git`, then add it with `mise run add backstage git@gitlab.cfdata.org:cloudflare/backstage/backstage.git`. If the repo path is unknown, use GitLab project search only to identify the repo and its `ssh_url_to_repo`, for example `glab api 'projects?search=backstage&simple=true&per_page=100'` or `glab api 'groups/cloudflare/projects?search=backstage&include_subgroups=true&simple=true&per_page=100'`. Then run `mise run add <name> <ssh_url_to_repo>` and search the imported subtree; do not use `glab api` for code/content searches.

If a needed repo is not listed, add it to the workspace instead of cloning it manually:

```bash
mise run add workers-sdk git@github.com:cloudflare/workers-sdk.git
```

Use the repo name that should identify the upstream. The add task registers a `workspace-<repo>` remote, records the default branch and subtree prefix in Git config, and imports the repo into local `main` with `git subtree`.

### 1. Sync

```bash
mise run sync
```

This fetches each registered `workspace-*` remote, updates the corresponding top-level prefixes as snapshots on local `main`, prunes stale Git state, and removes clean task worktrees whose repo branches have merged.

Use `mise run pull [repo...]` when you only need to refresh snapshots. Use `mise run clean` when you only need cleanup.

### 2. Start A Task

```bash
mise run branch JIRA-123
cd .worktrees/JIRA-123
```

This creates one Git worktree for the whole workspace. The worktree branch is `JIRA-123`, and `mise run push` will push `JIRA-123` to each changed repo.

### 3. Work

- Edit files under `.worktrees/<task>/<prefix>/`.
- Commit once from `.worktrees/<task>` when the change spans repos.
- Use `mise run status` and `mise run diff` from `.worktrees/<task>` for aggregated views.
- Do not edit top-level subtree folders directly for feature work.

### 4. Ship

```bash
mise run push
```

Run this from `.worktrees/<task>`. It runs `git subtree push` for changed prefixes and pushes branch `<task>` to each repo's origin.

Do not use raw `git push` from a task worktree.

### 5. Clean Up

```bash
mise run clean JIRA-123
```

This removes the clean workspace worktree for the task. Running `mise run clean` with no task prunes stale Git state and removes clean task worktrees whose repo branches have merged.

## Rules

- Top-level subtree folders are first-class source snapshots.
- Repo task edits happen in `.worktrees/<task>/<prefix>/*`.
- Task name and branch name are the same across repos.
- The top-level workspace repo is coordination state. Committing root snapshot updates is normal; upstream source changes should happen in task worktrees.
- Use `mise run pull` and `mise run push` for cross-repo Git operations.
- `--no-verify`, `core.hooksPath` reconfiguration, and `git worktree remove --force` are blocked.

## Merge Requests

- Do not create a branch unless the user asks for code changes that need one. For documentation-only workspace updates, edit the workspace file directly unless asked to branch or commit.
- Before creating an MR, inspect `git status`, `git diff`, recent commits, and the target branch diff. Stage only intended files.
- Use `glab mr create` or `glab mr update` directly for GitLab MRs.
- Create GitLab MRs as drafts first with `glab mr create --draft ...` unless the user explicitly asks for a ready MR.
- Do not post comments, notes, or replies on MRs as the user unless the user explicitly asks you to comment/post/reply on GitLab. Asking for links, code references, review text, or wording to use is not permission to post; provide the text/link in chat instead. Updating MR titles and descriptions is allowed when it follows the guidance below or the user's direct instructions.
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
| Register a repo remote and add its subtree | `mise run add <name> <url> [prefix]` |
| List repos and tasks | `mise run list` |
| Sync snapshots and cleanup | `mise run sync [repo...]` |
| Pull subtree defaults only | `mise run pull [repo...]` |
| Create a task workspace worktree | `mise run branch <task> [repo...]` |
| Aggregate status | `mise run status [repo...]` |
| Aggregate diff | `mise run diff [repo...]` |
| Push task branches | `mise run push [repo...]` |
| Clean task worktrees and stale state | `mise run clean [task|--merged|--prune]` |

Raw Git commit/status/diff is fine inside `.worktrees/<task>`. Prefer mise tasks for cross-repo pull/push operations.
