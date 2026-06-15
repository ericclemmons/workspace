---
name: babysit
description: Use when asked to babysit, monitor, or follow up on a GitLab MR/GitHub PR after pushing; delegate polling to a sub-agent and prioritize new OpenCode AI review comments before pipelines.
---

# Babysit MR/PR

Use this skill when the user asks to babysit, monitor, or follow up on a GitLab MR or GitHub PR, especially after pushing commits or addressing review feedback.

The goal is to leave the MR/PR in a stable handoff state: fresh AI review feedback has zero findings and zero recommended changes, required CI is green or externally blocked, and flaky checks are understood.

## Delegation Model

Babysitting is polling-heavy and should not pollute the main conversation context.

When this skill is loaded in the main agent, immediately delegate the monitoring loop to a sub-agent using the `task` tool unless the user explicitly asks you to perform each poll inline. Use a prompt that includes:

- The MR/PR URL, number, or branch to monitor.
- The priority order from this skill.
- A requirement to poll every 10 seconds for fresh OpenCode review feedback on the latest commit before checking CI.
- A requirement to make code fixes when valid review or CI failures are found, run focused verification, commit, and push.
- A requirement to return only concise status summaries to the main agent: actionable findings, fixes pushed, success state, or external blockers.

While the sub-agent is running, the main agent should not duplicate polling. Wait for the sub-agent result or continue only with unrelated user work. If the sub-agent reports actionable code changes are needed and did not already make them, the main agent should decide whether to implement directly or resume/delegate the sub-agent with the specific fix instructions.

If this skill is loaded inside a sub-agent, run the monitoring loop directly and keep intermediate output concise. Do not return raw API payloads unless they are necessary to explain a blocker.

## Priority Order

Always handle feedback in this order:

1. Fresh AI reviewer comments, findings, and recommended changes.
2. Required formatting, linting, typecheck, build, and unit/integration pipeline failures.
3. Known flaky or expensive checks, such as E2E.

Do not chase pipelines before resolving fresh AI review feedback to zero findings and zero recommended changes. A later commit can invalidate both review comments and CI results, so get the review loop clean first.

## OpenCode AI Review Loop

For GitLab MRs, watch specifically for comments containing `🤖 OpenCode Code Review` from the AI reviewer.

After every push:

1. Get the latest commit SHA on the MR branch.
2. Poll MR notes/discussions every 10 seconds for a new `🤖 OpenCode Code Review` comment whose reviewed commit is at or after that latest pushed commit.
3. Continue polling until one of these is true:
   - A fresh AI review comment appears for the latest commit and reports zero findings and zero recommended changes.
   - The AI review job completes and its trace clearly reports zero findings for the latest commit.
   - The AI review job is skipped, cancelled, externally blocked, or unavailable.
4. If the fresh AI review contains a `Fix in your Agent` prompt, run that prompt as the work plan.
5. Apply every finding, recommendation, and `Fix in your Agent` item unless it is factually wrong, unsafe, conflicts with explicit user direction, or you strongly disagree with its correctness assessment.
6. Do not treat `Approved`, `Approved with Comments`, or non-blocking INFO/SUGGESTION findings as clean if the review still lists findings or recommended changes. Optional severity only means it is merge-permitted; babysitting still drives the review to zero findings/recommended changes unless there is a correctness-based reason not to.
7. If a recommendation is not applied, leave a concise MR comment explaining the correctness-based disagreement or explicit conflict, then continue only after verifying no other findings remain.
8. Commit and push fixes, then repeat this loop from step 1.

Treat stale AI review comments as non-actionable only after verifying they reference an older commit than the current MR head and a newer review/job has cleared the latest commit.

## Pipeline Loop

Only after fresh AI review feedback is fully resolved to zero findings and zero recommended changes, or any remaining recommendation has a documented correctness-based disagreement:

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

- Latest AI review for the current MR head has zero findings and zero recommended changes, or every remaining recommendation has a documented correctness-based disagreement and the AI review path is otherwise clean.
- Required CI for the latest commit is passing, or the remaining failure is externally blocked and documented.
- Flaky checks have been retried or identified as unrelated/external.
- No actionable reviewer, bot, or unresolved thread remains.
- Local branch status is clean and pushed.

Final response should include the MR/PR URL, latest commit, AI review state, CI state, and any remaining blocker.

When a sub-agent performed the babysitting, the main agent final response should summarize the sub-agent result rather than replaying the polling log.
