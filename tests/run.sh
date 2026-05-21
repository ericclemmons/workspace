#!/usr/bin/env bash
# tests/run.sh — validates hooks and mise tasks end-to-end.
#
# Usage:
#   tests/run.sh        # run all
#   tests/run.sh -v     # verbose: show failure details
set -uo pipefail

VERBOSE=${VERBOSE:-0}
[[ "${1:-}" == "-v" ]] && VERBOSE=1

TEMPLATE_ROOT=$(cd "$(dirname "$0")/.." && pwd)
SCRATCH=$(mktemp -d -t agent-meta-tests.XXXXXX)
trap 'rm -rf "$SCRATCH"' EXIT

PASS=0; FAIL=0
FAILED_TESTS=()

if [[ -t 1 ]]; then
  GREEN=$'\033[32m'; RED=$'\033[31m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  GREEN=""; RED=""; DIM=""; RESET=""
fi

pass() { PASS=$((PASS + 1)); echo "  ${GREEN}✓${RESET} $1"; }
fail() {
  FAIL=$((FAIL + 1))
  FAILED_TESTS+=("$1")
  echo "  ${RED}✗${RESET} $1"
  [[ $VERBOSE -eq 1 ]] && [[ -n "${2:-}" ]] && echo "${DIM}$2${RESET}" | sed 's/^/      /'
}

assert_exit_code() {
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3" "expected exit $1, got $2${4:+$'\n'output: $4}"; fi
}
assert_contains() {
  if echo "$2" | grep -q -- "$1"; then pass "$3"; else fail "$3" "expected: $1"$'\n'"got: $2"; fi
}
section() { echo; echo "$1"; }

fresh_meta() {
  local dir; dir=$(mktemp -d -p "$SCRATCH" meta.XXXXXX)
  local path base
  for path in README.md AGENTS.md Brewfile mise.toml hk.pkl .gitconfig .gitignore opencode.json \
              .claude .githooks mise-tasks tests repos; do
    [[ -e "$TEMPLATE_ROOT/$path" ]] || continue
    base=$(basename "$path")
    cp -R "$TEMPLATE_ROOT/$path" "$dir/$base"
  done
  cd "$dir"
  git init -q -b main
  git config user.email "test@test"
  git config user.name "Test"
  git config core.hooksPath .githooks
  chmod +x .githooks/*.sh .githooks/pre-commit mise-tasks/*
  git add .
  META_ALLOW_COMMIT=1 git commit -q -m "scaffold"
  echo "$dir"
}

run_hook() {
  local out_file err_file
  out_file=$(mktemp); err_file=$(mktemp)
  echo "$2" | "$1" >"$out_file" 2>"$err_file"
  HOOK_EXIT=$?
  HOOK_STDOUT=$(cat "$out_file")
  HOOK_STDERR=$(cat "$err_file")
  rm -f "$out_file" "$err_file"
}

# ──────────────────────────────────────────────────────────────────────────────
# Structural
# ──────────────────────────────────────────────────────────────────────────────

test_structural() {
  section "structural"

  for f in README.md AGENTS.md Brewfile mise.toml hk.pkl .gitconfig .gitignore \
           opencode.json .claude/settings.json \
           .githooks/pre-commit .githooks/agent-guard-edit.sh \
           .githooks/agent-guard-bash.sh .githooks/agent-guard-context.sh \
           mise-tasks/_lib mise-tasks/add mise-tasks/branch \
           mise-tasks/pull mise-tasks/push mise-tasks/test \
           ; do
    [[ -f "$TEMPLATE_ROOT/$f" ]] && pass "exists: $f" || fail "exists: $f"
  done

  if jq empty "$TEMPLATE_ROOT/.claude/settings.json" 2>/dev/null; then
    pass ".claude/settings.json is valid JSON"
  else fail ".claude/settings.json is valid JSON"; fi
  if jq empty "$TEMPLATE_ROOT/opencode.json" 2>/dev/null; then
    pass "opencode.json is valid JSON"
  else fail "opencode.json is valid JSON"; fi
  [[ -s "$TEMPLATE_ROOT/mise.toml" ]] && pass "mise.toml exists and is non-empty" \
    || fail "mise.toml exists and is non-empty"

  for sh in "$TEMPLATE_ROOT"/.githooks/* "$TEMPLATE_ROOT"/mise-tasks/* "$TEMPLATE_ROOT"/tests/*.sh; do
    [[ -f "$sh" ]] || continue
    if bash -n "$sh" 2>/dev/null; then pass "syntax: ${sh#$TEMPLATE_ROOT/}"
    else fail "syntax: ${sh#$TEMPLATE_ROOT/}"; fi
  done
}

# ──────────────────────────────────────────────────────────────────────────────
# pre-commit
# ──────────────────────────────────────────────────────────────────────────────

test_pre_commit() {
  section "pre-commit hook"
  local meta; meta=$(fresh_meta); cd "$meta"

  # Blocks commit on main
  touch foo.txt && git add foo.txt
  out=$(git commit -m "should fail" 2>&1); rc=$?
  assert_exit_code 1 $rc "blocks commit on main"
  assert_contains "Direct commits to main" "$out" "main commit reason present"
  git reset -q HEAD foo.txt; rm foo.txt

  # Bootstrap escape hatch
  touch bar.txt && git add bar.txt
  out=$(META_ALLOW_COMMIT=1 git commit -m "bootstrap" 2>&1); rc=$?
  assert_exit_code 0 $rc "META_ALLOW_COMMIT=1 bypasses main block"

  # Allows commit from worktree on a feature branch
  git worktree add -q -b feat-x worktrees/feat-x
  cd worktrees/feat-x
  git config user.email "t@t"; git config user.name "t"
  echo hi > repos/test.txt && git add repos/test.txt
  out=$(git commit -m "from worktree" 2>&1); rc=$?
  assert_exit_code 0 $rc "allows commit from worktree on feature branch"

  # Allows arbitrary branch names (no task/* prefix required)
  cd "$meta"
  git worktree add -q -b jira-123 worktrees/jira-123
  cd worktrees/jira-123
  git config user.email "t@t"; git config user.name "t"
  echo hello > repos/jira.txt && git add repos/jira.txt
  out=$(git commit -m "jira commit" 2>&1); rc=$?
  assert_exit_code 0 $rc "allows commit on arbitrary branch name (jira-123)"
}

# ──────────────────────────────────────────────────────────────────────────────
# Agent edit guard
# ──────────────────────────────────────────────────────────────────────────────

test_agent_edit_guard() {
  section "agent-guard-edit.sh"
  local meta; meta=$(fresh_meta); cd "$meta"
  local hook="$meta/.githooks/agent-guard-edit.sh"

  run_hook "$hook" "{\"tool_input\":{\"file_path\":\"$meta/repos/foo.txt\"}}"
  assert_exit_code 2 "$HOOK_EXIT" "blocks edit outside worktrees/"
  assert_contains "outside ./worktrees/" "$HOOK_STDERR" "outside-worktree reason includes path hint"

  mkdir -p "$meta/worktrees/feat-x/repos"
  run_hook "$hook" "{\"tool_input\":{\"file_path\":\"$meta/worktrees/feat-x/repos/foo.txt\"}}"
  assert_exit_code 0 "$HOOK_EXIT" "allows edit inside worktree"

  run_hook "$hook" "{\"tool_input\":{\"file_path\":\"$meta/worktrees/feat-x/AGENTS.md\"}}"
  assert_exit_code 2 "$HOOK_EXIT" "blocks edit to AGENTS.md"

  run_hook "$hook" "{\"tool_input\":{\"file_path\":\"$meta/worktrees/feat-x/.githooks/pre-commit\"}}"
  assert_exit_code 2 "$HOOK_EXIT" "blocks edit to .githooks/"

  run_hook "$hook" "{\"tool_input\":{\"file_path\":\"$meta/worktrees/feat-x/.claude/settings.json\"}}"
  assert_exit_code 2 "$HOOK_EXIT" "blocks edit to .claude/settings.json"

  run_hook "$hook" "{\"tool_input\":{\"file_path\":\"$meta/worktrees/feat-x/opencode.json\"}}"
  assert_exit_code 2 "$HOOK_EXIT" "blocks edit to opencode.json"

  run_hook "$hook" "{\"tool_input\":{\"file_path\":\"$meta/worktrees/feat-x/mise.toml\"}}"
  assert_exit_code 2 "$HOOK_EXIT" "blocks edit to mise.toml"

  run_hook "$hook" "{\"tool_input\":{\"file_path\":\"$meta/worktrees/feat-x/mise-tasks/push\"}}"
  assert_exit_code 2 "$HOOK_EXIT" "blocks edit to mise-tasks/"

  run_hook "$hook" "{\"tool_input\":{\"file_path\":\"$meta/worktrees/feat-x/hk.pkl\"}}"
  assert_exit_code 2 "$HOOK_EXIT" "blocks edit to hk.pkl"

  run_hook "$hook" "{\"tool_input\":{\"file_path\":\"$meta/worktrees/feat-x/.gitconfig\"}}"
  assert_exit_code 2 "$HOOK_EXIT" "blocks edit to .gitconfig"

  # Supports both .file_path and .path
  run_hook "$hook" "{\"tool_input\":{\"path\":\"$meta/worktrees/feat-x/repos/foo.txt\"}}"
  assert_exit_code 0 "$HOOK_EXIT" "supports .path key"

  # Pass through when no path
  run_hook "$hook" '{"tool_input":{}}'
  assert_exit_code 0 "$HOOK_EXIT" "passes through when no path provided"
}

# ──────────────────────────────────────────────────────────────────────────────
# Agent bash guard
# ──────────────────────────────────────────────────────────────────────────────

test_agent_bash_guard() {
  section "agent-guard-bash.sh"
  local meta; meta=$(fresh_meta); cd "$meta"
  local hook="$meta/.githooks/agent-guard-bash.sh"

  # From main checkout
  run_hook "$hook" '{"tool_input":{"command":"git commit -m foo"}}'
  assert_exit_code 2 "$HOOK_EXIT" "blocks git commit from main checkout"
  assert_contains "meta main checkout" "$HOOK_STDERR" "main-checkout reason mentions checkout"

  run_hook "$hook" '{"tool_input":{"command":"git push origin main"}}'
  assert_exit_code 2 "$HOOK_EXIT" "blocks git push from main checkout"

  run_hook "$hook" '{"tool_input":{"command":"git add foo.txt"}}'
  assert_exit_code 2 "$HOOK_EXIT" "blocks git add from main checkout"

  run_hook "$hook" '{"tool_input":{"command":"git status"}}'
  assert_exit_code 0 "$HOOK_EXIT" "allows git status from main checkout"

  run_hook "$hook" '{"tool_input":{"command":"git log --oneline"}}'
  assert_exit_code 0 "$HOOK_EXIT" "allows git log from main checkout"

  # Allows arbitrary branch names in worktree add (no task/* prefix)
  run_hook "$hook" '{"tool_input":{"command":"git worktree add -b jira-123 worktrees/jira-123"}}'
  assert_exit_code 0 "$HOOK_EXIT" "allows arbitrary branch name (jira-123)"

  run_hook "$hook" '{"tool_input":{"command":"git worktree add -b feat-x worktrees/feat-x"}}'
  assert_exit_code 0 "$HOOK_EXIT" "allows arbitrary branch name (feat-x)"

  # --no-verify and hooksPath
  run_hook "$hook" '{"tool_input":{"command":"git commit --no-verify -m sneaky"}}'
  assert_exit_code 2 "$HOOK_EXIT" "blocks --no-verify"

  run_hook "$hook" '{"tool_input":{"command":"git config core.hooksPath /tmp"}}'
  assert_exit_code 2 "$HOOK_EXIT" "blocks core.hooksPath modification"

  run_hook "$hook" '{"tool_input":{"command":"git worktree remove --force worktrees/feat-x"}}'
  assert_exit_code 2 "$HOOK_EXIT" "blocks --force worktree remove"

  run_hook "$hook" '{"tool_input":{"command":"git worktree remove worktrees/feat-x"}}'
  assert_exit_code 0 "$HOOK_EXIT" "allows regular worktree remove"

  # From worktree
  git worktree add -q -b jira-123 worktrees/jira-123
  cd worktrees/jira-123

  run_hook "$hook" '{"tool_input":{"command":"git commit -m good"}}'
  assert_exit_code 0 "$HOOK_EXIT" "allows git commit on feature branch in worktree"

  run_hook "$hook" '{"tool_input":{"command":""}}'
  assert_exit_code 0 "$HOOK_EXIT" "passes through empty command"

  run_hook "$hook" '{"tool_input":{"command":"ls -la"}}'
  assert_exit_code 0 "$HOOK_EXIT" "passes through non-git command"
}

# ──────────────────────────────────────────────────────────────────────────────
# Agent context guard
# ──────────────────────────────────────────────────────────────────────────────

test_agent_context_guard() {
  section "agent-guard-context.sh"
  local meta; meta=$(fresh_meta); cd "$meta"
  local hook="$meta/.githooks/agent-guard-context.sh"

  out=$("$hook")
  if echo "$out" | grep -q "MAIN checkout"; then pass "emits reminder from main checkout"
  else fail "emits reminder from main checkout" "got: $out"; fi

  git worktree add -q -b feat-x worktrees/feat-x
  cd worktrees/feat-x
  out=$("$hook")
  [[ -z "$out" ]] && pass "silent from inside worktree" || fail "silent from inside worktree" "got: $out"
}

# ──────────────────────────────────────────────────────────────────────────────
# Mise tasks
# ──────────────────────────────────────────────────────────────────────────────

test_mise_tasks() {
  section "mise tasks"
  local meta; meta=$(fresh_meta); cd "$meta"

  # branch
  bash mise-tasks/branch jira-123 >/dev/null 2>&1; rc=$?
  assert_exit_code 0 $rc "branch creates a worktree"
  [[ -d "$meta/worktrees/jira-123" ]] && pass "branch created worktrees/jira-123" \
    || fail "branch created worktrees/jira-123"
  git -C "$meta" show-ref --verify --quiet refs/heads/jira-123 \
    && pass "branch created refs/heads/jira-123" \
    || fail "branch created refs/heads/jira-123"

  # branch idempotent
  out=$(bash mise-tasks/branch jira-123 2>&1); rc=$?
  assert_exit_code 0 $rc "branch idempotent on existing"
  assert_contains "already exists" "$out" "branch reports existing worktree"

  # branch input validation
  out=$(bash mise-tasks/branch 2>&1 || true)
  assert_contains "usage:" "$out" "branch shows usage with no args"
  out=$(bash mise-tasks/branch "bad name" 2>&1 || true)
  assert_contains "invalid branch name" "$out" "branch rejects names with spaces"
  out=$(bash mise-tasks/branch "main" 2>&1 || true)
  assert_contains "won't create" "$out" "branch refuses 'main'"

  # add input validation
  out=$(bash mise-tasks/add 2>&1 || true)
  assert_contains "usage:" "$out" "add shows usage with no args"
  out=$(bash mise-tasks/add "bad name" "https://x.git" 2>&1 || true)
  assert_contains "invalid name" "$out" "add rejects bad names"

  # push from main checkout rejected
  out=$(bash mise-tasks/push 2>&1 || true)
  assert_contains "run this from inside a worktree" "$out" "push rejects main checkout"

  # pull prunes local branches with deleted upstreams
  local remote; remote=$(mktemp -d -p "$SCRATCH" remote.XXXXXX)
  git init -q --bare "$remote"
  git remote add origin "$remote"
  git push -q -u origin main
  git worktree add -q -b prune-me worktrees/prune-me
  (
    cd worktrees/prune-me
    git config user.email "t@t"; git config user.name "t"
    echo prune > repos/prune.txt
    git add repos/prune.txt && git commit -q -m "prune me"
  )
  git push -q -u origin prune-me
  git push -q origin --delete prune-me
  out=$(bash mise-tasks/pull 2>&1); rc=$?
  assert_exit_code 0 $rc "pull prunes gone-upstream branch"
  [[ ! -d "$meta/worktrees/prune-me" ]] && pass "pull removed pruned worktree" \
    || fail "pull removed pruned worktree"
  git show-ref --verify --quiet refs/heads/prune-me \
    && fail "pull deleted pruned branch" \
    || pass "pull deleted pruned branch"

  # pull keeps local branches when the upstream branch remains
  git worktree add -q -b prune-kept worktrees/prune-kept
  (
    cd worktrees/prune-kept
    git config user.email "t@t"; git config user.name "t"
    echo kept > repos/prune-kept.txt
    git add repos/prune-kept.txt && git commit -q -m "prune kept"
  )
  git push -q -u origin prune-kept
  out=$(bash mise-tasks/pull 2>&1); rc=$?
  assert_exit_code 0 $rc "pull keeps branch with live upstream"
  [[ -d "$meta/worktrees/prune-kept" ]] && pass "pull kept live-upstream worktree" \
    || fail "pull kept live-upstream worktree"
  git show-ref --verify --quiet refs/heads/prune-kept \
    && pass "pull kept live-upstream branch" \
    || fail "pull kept live-upstream branch"
}

# ──────────────────────────────────────────────────────────────────────────────
# End-to-end: add + branch + push against a local upstream
# ──────────────────────────────────────────────────────────────────────────────

test_end_to_end() {
  section "end-to-end (local upstream)"
  local meta; meta=$(fresh_meta)

  local upstream; upstream=$(mktemp -d -p "$SCRATCH" upstream.XXXXXX)
  (
    cd "$upstream"
    git init -q -b main
    git config user.email "u@u"; git config user.name "u"
    echo "# fake" > README.md
    git add . && git commit -q -m init
  )

  cd "$meta"
  bash mise-tasks/add fakerepo "$upstream" main >/dev/null 2>&1; rc=$?
  assert_exit_code 0 $rc "add mounts a fresh subtree"
  [[ -d "$meta/repos/fakerepo" ]] && pass "add created repos/fakerepo" \
    || fail "add created repos/fakerepo"

  # Duplicate
  out=$(bash mise-tasks/add fakerepo "$upstream" main 2>&1 || true)
  assert_contains "already exists" "$out" "add rejects duplicate"

  # branch + commit + push
  bash mise-tasks/branch e2e >/dev/null
  cd "$meta/worktrees/e2e"
  git config user.email "t@t"; git config user.name "t"
  echo "change" >> repos/fakerepo/README.md
  git add . && git commit -q -m "test change"

  out=$(bash "$meta/mise-tasks/push" 2>&1); rc=$?
  assert_exit_code 0 $rc "push pushes touched subtrees"
  assert_contains "pushed fakerepo" "$out" "push reports pushed subtree"

  git -C "$upstream" show-ref --verify --quiet refs/heads/e2e \
    && pass "upstream received branch e2e" \
    || fail "upstream received branch e2e"

  # pull works too
  cd "$meta"
  # Add an upstream change so pull has something to do
  (
    cd "$upstream"
    echo "v2" >> README.md
    git add . && git commit -q -m "v2"
  )
  out=$(bash mise-tasks/pull fakerepo 2>&1); rc=$?
  assert_exit_code 0 $rc "pull syncs from upstream"
}

# ──────────────────────────────────────────────────────────────────────────────
# Run
# ──────────────────────────────────────────────────────────────────────────────

echo "agent-meta tests"
echo "template: $TEMPLATE_ROOT"
echo "scratch:  $SCRATCH"

missing=()
for tool in git jq bash; do
  command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo
  echo "${RED}missing tools:${RESET} ${missing[*]}"
  echo "install via: brew bundle"
  exit 1
fi

test_structural
test_pre_commit
test_agent_edit_guard
test_agent_bash_guard
test_agent_context_guard
test_mise_tasks
test_end_to_end

echo
echo "─────────────────────────────────────"
total=$((PASS + FAIL))
if [[ $FAIL -eq 0 ]]; then
  echo "${GREEN}All $total tests passed.${RESET}"
  exit 0
else
  echo "${RED}$FAIL of $total failed:${RESET}"
  for t in "${FAILED_TESTS[@]}"; do echo "  - $t"; done
  echo
  echo "Re-run with -v for failure details."
  exit 1
fi
