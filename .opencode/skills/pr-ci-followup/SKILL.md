---
name: pr-ci-followup
description: Use when pushing code to a GitHub PR or GitLab MR, opening/updating a PR/MR, checking CI pipelines, or responding to PR/MR review comments; continue monitoring until CI and actionable comments are resolved.
---

# PR CI Follow-Up

Use this skill after pushing code to a branch that has, or should have, an open GitHub pull request or GitLab merge request.

Do not stop immediately after `git push`. Continue until the PR/MR is in a stable handoff state: CI is passing or externally blocked, and all actionable reviewer or bot comments have been handled.

## Required Loop

1. Identify the PR/MR for the current branch.
2. Check CI pipeline/check status.
3. Check PR/MR comments, review threads, approvals, requested changes, and bot feedback.
4. If CI failed, inspect logs enough to identify the cause, make the smallest correct fix, run relevant local verification, commit, and push again.
5. If comments request changes, make the smallest correct fix or respond with a concise explanation when no code change is appropriate.
6. Repeat CI and comment checks after every push or response.
7. Stop only when CI is green and no actionable comments remain, or when progress is blocked by an external dependency that the agent cannot resolve.

If the user explicitly asked only to push and not to watch, still perform at least one CI/comment check after the push unless they told you not to.

## GitHub Workflow

Prefer `gh` when available.

Useful commands:

```sh
git branch --show-current
gh pr status
gh pr view --json number,url,headRefName,baseRefName,state,isDraft,mergeStateStatus,reviewDecision,statusCheckRollup,comments,reviews,latestReviews
gh pr checks --watch
gh pr checks
gh run list --branch "$(git branch --show-current)" --limit 5
gh run view <run-id> --log-failed
gh pr view --comments
```

When a check fails, inspect the failed job log with `gh run view --log-failed` before editing. If `gh pr checks --watch` times out or cannot stream, poll `gh pr checks` periodically.

For comments:

- Treat requested changes, unresolved review threads, and bot comments about tests, lint, formatting, security, type errors, or broken links as actionable.
- Reply only when useful. Prefer fixing code over explaining around a valid issue.
- If a comment is stale after a new push, verify the latest diff or thread state before responding.

## GitLab Workflow

Prefer `glab` when available. Load the `gitlab` skill for GitLab-specific tool details when needed.

Useful commands:

```sh
git branch --show-current
glab mr status
glab mr view
glab mr view --comments
glab ci status
glab ci view
glab pipeline list --branch "$(git branch --show-current)"
glab pipeline ci view
```

If `glab` cannot expose enough detail, use the GitLab MCP tools or GitLab web/API tooling available in the current environment. Inspect failed jobs before editing.

For discussions:

- Treat unresolved threads, reviewer change requests, and bot findings about tests, lint, formatting, security, type errors, or broken links as actionable.
- Resolve threads only when the requested change was actually addressed or the response explains why no change is appropriate.
- Re-check discussions after each push because new bot comments can appear after pipelines finish.

## Polling Discipline

Keep polling practical and bounded:

- Wait for checks that are pending or running instead of declaring success early.
- Poll every 30-60 seconds for normal CI unless the platform command has a native watch mode.
- If CI takes longer than about 20 minutes, provide a brief progress update and continue polling unless the user redirects.
- If a pipeline is stuck, cancelled by someone else, waiting for manual approval, missing secrets, or blocked by permissions, report the blocker clearly and stop.

When Solo timers are available, use them for long waits instead of busy-waiting in the active turn. Schedule a self-contained reminder to re-check CI and comments for the PR/MR.

## Completion Criteria

Before final response, confirm:

- The latest pushed commit is the one CI evaluated.
- CI/checks are passing, or the remaining failure is externally blocked and documented.
- There are no unresolved actionable review comments or bot comments known to the agent.
- Any fixes were committed and pushed.

Final response should include the PR/MR URL when known, CI state, comment state, and any remaining blocker.
