---
name: babysit
description: Use when asked to babysit, monitor, or follow up on a GitLab MR/GitHub PR after pushing; prioritize new OpenCode AI review comments before pipelines.
---

# Babysit MR/PR

Use this skill when the user asks to babysit, monitor, or follow up on a GitLab MR or GitHub PR, especially after pushing commits or addressing review feedback.

The goal is to leave the MR/PR in a stable handoff state: fresh AI review feedback is fully addressed, required CI is green or externally blocked, and flaky checks are understood.

## Priority Order

Always handle feedback in this order:

1. Fresh AI reviewer comments.
2. Required formatting, linting, typecheck, build, and unit/integration pipeline failures.
3. Known flaky or expensive checks, such as E2E.

Do not chase pipelines before resolving fresh AI review feedback. A later commit can invalidate both review comments and CI results, so get the review loop clean first.

## OpenCode AI Review Loop

For GitLab MRs, watch specifically for comments containing `🤖 OpenCode Code Review` from the AI reviewer.

After every push:

1. Get the latest commit SHA on the MR branch.
2. Poll MR notes/discussions every 10 seconds for a new `🤖 OpenCode Code Review` comment whose reviewed commit is at or after that latest pushed commit.
3. Continue polling until one of these is true:
   - A fresh AI review comment appears for the latest commit.
   - The AI review job completes and its trace clearly reports zero findings for the latest commit.
   - The AI review job is skipped, cancelled, externally blocked, or unavailable.
4. If the fresh AI review contains a `Fix in your Agent` prompt, run that prompt as the work plan.
5. Apply every recommended fix unless it is factually wrong, unsafe, or conflicts with explicit user direction.
6. If a recommendation is not applied, leave a concise MR comment explaining why.
7. Commit and push fixes, then repeat this loop from step 1.

Treat stale AI review comments as non-actionable only after verifying they reference an older commit than the current MR head and a newer review/job has cleared the latest commit.

## Pipeline Loop

Only after fresh AI review feedback is fully resolved:

1. Check required CI pipelines/checks for the latest commit.
2. If formatting, linting, typecheck, build, OpenAPI validation, unit tests, or integration tests fail, inspect failed job logs and make the smallest correct fix.
3. Run the closest local verification that is practical.
4. Commit and push fixes.
5. Return to the AI review loop before checking pipelines again.

## Flaky Or Expensive Checks

After AI review is clean and deterministic CI is green, handle flaky or expensive checks.

- For known flakes, retry once if the failure signature is familiar and unrelated to the diff.
- If the retry fails with the same diff-related issue, inspect logs and fix it.
- If a check is externally blocked, waiting for capacity, missing secrets, or requires manual approval, report that blocker clearly and stop.

## GitLab Commands

Prefer `glab` for GitLab work.

Useful commands:

```sh
git branch --show-current
git rev-parse HEAD
glab mr view <iid>
glab mr view <iid> --comments
glab api projects/:id/merge_requests/<iid>
glab api projects/:id/merge_requests/<iid>/discussions
glab api projects/:id/pipelines/<pipeline_id>/jobs
glab api projects/:id/jobs/<job_id>/trace
```

When `glab` output is insufficient, use available GitLab MCP tools or `glab api` for targeted metadata and logs.

## Completion Criteria

Before final response, confirm:

- Latest AI review for the current MR head has no actionable findings, or the AI review path is externally blocked and documented.
- Required CI for the latest commit is passing, or the remaining failure is externally blocked and documented.
- Flaky checks have been retried or identified as unrelated/external.
- No actionable reviewer, bot, or unresolved thread remains.
- Local branch status is clean and pushed.

Final response should include the MR/PR URL, latest commit, AI review state, CI state, and any remaining blocker.
