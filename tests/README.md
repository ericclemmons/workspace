# Tests

Validates that the hooks and mise tasks behave as `AGENTS.md` claims.

## Run

```bash
mise run test       # or: bash tests/run.sh
bash tests/run.sh -v  # show failure details
```

Exits 0 on success, non-zero on any failure.

## Coverage

- **Structural:** all files exist, JSON parses, shell scripts pass `bash -n`.
- **Pre-commit hook:** blocks `main`, allows workspace-maintenance commits on branches, and blocks `.worktrees/` content.
- **Agent edit guard:** blocks edits outside task worktrees and allows valid `.worktrees/<task>/<repo>` paths.
- **Agent bash guard:** blocks dangerous workspace-root Git commands, blocks `--no-verify`/`core.hooksPath`/`--force worktree remove`, and allows normal worktree commits.
- **Agent context guard:** emits reminders from the workspace root.
- **Mise tasks:** validation and subtree/worktree task behavior.
- **End-to-end:** real `add → branch → edit → push → sync → clean` against a local fake upstream.

Each test group spins up a fresh meta repo in `$TMPDIR`. Cleanup on exit.
