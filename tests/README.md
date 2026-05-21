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
- **Pre-commit hook:** blocks `main`, allows arbitrary feature branches, honors `META_ALLOW_COMMIT=1`.
- **Agent edit guard:** blocks edits outside `worktrees/*`, blocks meta-infrastructure (`.githooks/`, `AGENTS.md`, `.claude/`, `opencode.json`, `mise.toml`, `hk.pkl`, `.gitconfig`, `mise-tasks/*`), allows valid paths.
- **Agent bash guard:** blocks mutating git from main checkout, allows arbitrary branch names, blocks `--no-verify`/`core.hooksPath`/`--force worktree remove`, allows reads.
- **Agent context guard:** emits reminder from main checkout, silent from worktree.
- **Mise tasks:** validation, idempotency, error paths.
- **End-to-end:** real `add → branch → edit → push → pull` against a local fake upstream.

Each test group spins up a fresh meta repo in `$TMPDIR`. Cleanup on exit.
