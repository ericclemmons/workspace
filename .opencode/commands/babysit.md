---
description: Babysit a GitLab MR or GitHub PR until AI review and CI are resolved
agent: build
---

Load and follow the `babysit` skill.

If the target is a GitLab MR, also load and follow the `gitlab` skill.

Use `$ARGUMENTS` as the MR/PR URL, number, branch, or description of what to babysit.

If `$ARGUMENTS` is empty, infer the MR/PR from the current branch. If that is ambiguous, ask for the MR/PR URL or number.

Follow the babysit priority order:

1. Poll every 10 seconds for a fresh `🤖 OpenCode Code Review` comment or review-job result for the latest commit.
2. Run any `Fix in your Agent` prompt and apply all valid recommended fixes.
3. Once AI review feedback is fully resolved, check required formatting, linting, validation, build, and test pipelines.
4. Finally handle flaky or expensive checks, such as E2E.

Continue until the MR/PR is ready for human approval/merge or an external blocker remains.
