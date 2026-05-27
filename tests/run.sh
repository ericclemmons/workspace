#!/usr/bin/env bash
# tests/run.sh — validates hooks and mise tasks end-to-end.
set -uo pipefail
unset MISE_TASK_DIR

VERBOSE=${VERBOSE:-0}
[[ "${1:-}" == "-v" ]] && VERBOSE=1

TEMPLATE_ROOT=$(cd "$(dirname "$0")/.." && pwd)
SCRATCH=$(mktemp -d -t agent-workspace-tests.XXXXXX)
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
  local dir path base
  dir=$(mktemp -d -p "$SCRATCH" meta.XXXXXX)
  for path in README.md AGENTS.md Brewfile mise.toml hk.pkl .gitconfig .gitignore opencode.json \
              .claude .githooks .opencode mise-tasks tests; do
    [[ -e "$TEMPLATE_ROOT/$path" ]] || continue
    base=$(basename "$path")
    cp -R "$TEMPLATE_ROOT/$path" "$dir/$base"
  done
  mkdir -p "$dir/repos" "$dir/worktrees"
  cd "$dir"
  git init -q -b main
  git config user.email "test@test"
  git config user.name "Test"
  git config core.hooksPath .githooks
  git config include.path ../.gitconfig
  chmod +x .githooks/*.sh .githooks/pre-commit mise-tasks/*
  git add .
  META_ALLOW_COMMIT=1 git commit -q -m "scaffold"
  echo "$dir"
}

fake_upstream() {
  local name=${1:-fake} bare seed
  bare=$(mktemp -d -p "$SCRATCH" "$name.git.XXXXXX")
  git init -q --bare "$bare"
  seed=$(mktemp -d -p "$SCRATCH" "$name.seed.XXXXXX")
  git -C "$seed" init -q -b main
  git -C "$seed" config user.email "u@u"
  git -C "$seed" config user.name "Upstream"
  printf '# %s\n' "$name" > "$seed/README.md"
  git -C "$seed" add .
  git -C "$seed" commit -q -m init
  git -C "$seed" remote add origin "$bare"
  git -C "$seed" push -q -u origin main
  git -C "$bare" symbolic-ref HEAD refs/heads/main
  echo "$bare"
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

test_structural() {
  section "structural"

  for f in README.md AGENTS.md Brewfile mise.toml hk.pkl .gitconfig .gitignore \
           opencode.json .claude/settings.json \
           .githooks/pre-commit .githooks/agent-guard-edit.sh \
           .githooks/agent-guard-bash.sh .githooks/agent-guard-context.sh \
           mise-tasks/_lib mise-tasks/add mise-tasks/branch mise-tasks/clean \
           mise-tasks/diff mise-tasks/list mise-tasks/pull mise-tasks/push \
           mise-tasks/status mise-tasks/test tests/run.sh; do
    [[ -f "$TEMPLATE_ROOT/$f" ]] && pass "exists: $f" || fail "exists: $f"
  done

  jq empty "$TEMPLATE_ROOT/.claude/settings.json" 2>/dev/null && pass ".claude/settings.json is valid JSON" || fail ".claude/settings.json is valid JSON"
  jq empty "$TEMPLATE_ROOT/opencode.json" 2>/dev/null && pass "opencode.json is valid JSON" || fail "opencode.json is valid JSON"

  for sh in "$TEMPLATE_ROOT"/.githooks/* "$TEMPLATE_ROOT"/mise-tasks/* "$TEMPLATE_ROOT"/tests/*.sh; do
    [[ -f "$sh" ]] || continue
    bash -n "$sh" 2>/dev/null && pass "syntax: ${sh#$TEMPLATE_ROOT/}" || fail "syntax: ${sh#$TEMPLATE_ROOT/}"
  done
}

test_pre_commit() {
  section "pre-commit hook"
  local meta out rc
  meta=$(fresh_meta); cd "$meta"

  touch foo.txt && git add foo.txt
  out=$(git commit -m "should fail" 2>&1); rc=$?
  assert_exit_code 1 $rc "blocks commit on main"
  assert_contains "Direct commits to main" "$out" "main commit reason present"
  git reset -q HEAD foo.txt; rm foo.txt

  git switch -q -c workspace-change
  echo hi > docs.txt && git add docs.txt
  out=$(git commit -m "workspace docs" 2>&1); rc=$?
  assert_exit_code 0 $rc "allows workspace maintenance commit on branch"

  mkdir -p repos/private worktrees/task/private
  echo secret > repos/private/file.txt
  git add -f repos/private/file.txt
  out=$(git commit -m "should fail" 2>&1); rc=$?
  assert_exit_code 1 $rc "blocks committing repos content"
  assert_contains "cannot include repos/ or worktrees/" "$out" "repos block reason present"
  git reset -q HEAD repos/private/file.txt
}

test_agent_edit_guard() {
  section "agent-guard-edit.sh"
  local meta hook
  meta=$(fresh_meta); cd "$meta"
  hook="$meta/.githooks/agent-guard-edit.sh"

  run_hook "$hook" "{\"tool_input\":{\"file_path\":\"$meta/repos/fake/README.md\"}}"
  assert_exit_code 2 "$HOOK_EXIT" "blocks edit inside repos/"
  assert_contains "Base repos are read-only" "$HOOK_STDERR" "repos edit reason present"

  mkdir -p "$meta/worktrees/feat-x/fake"
  run_hook "$hook" "{\"tool_input\":{\"file_path\":\"$meta/worktrees/feat-x/fake/README.md\"}}"
  assert_exit_code 0 "$HOOK_EXIT" "allows edit inside task repo worktree"

  run_hook "$hook" "{\"tool_input\":{\"file_path\":\"$meta/README.md\"}}"
  assert_exit_code 2 "$HOOK_EXIT" "blocks edit outside task worktrees"

  run_hook "$hook" "{\"tool_input\":{\"file_path\":\"$meta/opencode.json\"}}"
  assert_exit_code 2 "$HOOK_EXIT" "blocks edit to workspace config"

  run_hook "$hook" "{\"tool_input\":{\"path\":\"$meta/worktrees/feat-x/fake/file.txt\"}}"
  assert_exit_code 0 "$HOOK_EXIT" "supports .path key"
}

test_agent_bash_guard() {
  section "agent-guard-bash.sh"
  local meta hook upstream out rc
  meta=$(fresh_meta); cd "$meta"
  hook="$meta/.githooks/agent-guard-bash.sh"

  run_hook "$hook" '{"tool_input":{"command":"git add README.md"}}'
  assert_exit_code 0 "$HOOK_EXIT" "allows workspace git add"

  run_hook "$hook" '{"tool_input":{"command":"git push origin main"}}'
  assert_exit_code 2 "$HOOK_EXIT" "blocks workspace git push"

  run_hook "$hook" '{"tool_input":{"command":"git status"}}'
  assert_exit_code 0 "$HOOK_EXIT" "allows git status from workspace root"

  run_hook "$hook" '{"tool_input":{"command":"git commit --no-verify -m sneaky"}}'
  assert_exit_code 2 "$HOOK_EXIT" "blocks --no-verify"

  run_hook "$hook" '{"tool_input":{"command":"git config core.hooksPath /tmp"}}'
  assert_exit_code 2 "$HOOK_EXIT" "blocks core.hooksPath modification"

  run_hook "$hook" '{"tool_input":{"command":"git worktree remove --force worktrees/feat-x/fake"}}'
  assert_exit_code 2 "$HOOK_EXIT" "blocks --force worktree remove"

  upstream=$(fake_upstream fake)
  bash mise-tasks/add fake "$upstream" >/dev/null
  cd repos/fake
  run_hook "$hook" '{"tool_input":{"command":"git commit -m bad"}}'
  assert_exit_code 2 "$HOOK_EXIT" "blocks git commit inside repos/"

  cd "$meta"
  bash mise-tasks/branch feat-x fake >/dev/null
  cd worktrees/feat-x/fake
  run_hook "$hook" '{"tool_input":{"command":"git commit -m good"}}'
  assert_exit_code 0 "$HOOK_EXIT" "allows git commit inside task repo worktree"
}

test_agent_context_guard() {
  section "agent-guard-context.sh"
  local meta hook out upstream
  meta=$(fresh_meta); cd "$meta"
  hook="$meta/.githooks/agent-guard-context.sh"

  out=$("$hook")
  echo "$out" | grep -q "workspace root" && pass "emits reminder from workspace root" || fail "emits reminder from workspace root" "got: $out"

  upstream=$(fake_upstream fake)
  bash mise-tasks/add fake "$upstream" >/dev/null
  cd repos/fake
  out=$("$hook")
  echo "$out" | grep -q "read-only base clones" && pass "emits reminder from repos/" || fail "emits reminder from repos/" "got: $out"
}

test_mise_tasks() {
  section "mise tasks"
  local meta upstream out rc
  meta=$(fresh_meta); cd "$meta"
  upstream=$(fake_upstream fake)

  out=$(bash mise-tasks/add fake "$upstream" 2>&1); rc=$?
  assert_exit_code 0 $rc "add clones a base repo"
  [[ -d "$meta/repos/fake/.git" ]] && pass "add created repos/fake clone" || fail "add created repos/fake clone"

  out=$(bash mise-tasks/add fake "$upstream" 2>&1 || true)
  assert_contains "already exists" "$out" "add rejects duplicate"

  out=$(bash mise-tasks/branch jira-123 2>&1); rc=$?
  assert_exit_code 0 $rc "branch creates task repo worktree"
  [[ -f "$meta/worktrees/jira-123/fake/.git" ]] && pass "branch created worktrees/jira-123/fake" || fail "branch created worktrees/jira-123/fake"
  [[ "$(git -C "$meta/worktrees/jira-123/fake" symbolic-ref --short HEAD)" == "jira-123" ]] && pass "branch name matches task" || fail "branch name matches task"

  out=$(bash mise-tasks/branch jira-123 2>&1); rc=$?
  assert_exit_code 0 $rc "branch idempotent on existing"
  assert_contains "already exists" "$out" "branch reports existing repo worktree"

  out=$(bash mise-tasks/status 2>&1); rc=$?
  assert_exit_code 0 $rc "status works from workspace root"

  cd worktrees/jira-123
  out=$(bash "$meta/mise-tasks/status" 2>&1); rc=$?
  assert_exit_code 0 $rc "status works from task root"

  out=$(bash "$meta/mise-tasks/diff" 2>&1); rc=$?
  assert_exit_code 0 $rc "diff works from task root"

  cd "$meta"
  out=$(bash mise-tasks/list 2>&1); rc=$?
  assert_exit_code 0 $rc "list works"
  assert_contains "fake" "$out" "list shows repo"
}

test_end_to_end() {
  section "end-to-end (local upstream)"
  local meta upstream out rc seed
  meta=$(fresh_meta); cd "$meta"
  upstream=$(fake_upstream fakerepo)

  bash mise-tasks/add fakerepo "$upstream" >/dev/null
  bash mise-tasks/branch clean-only >/dev/null
  out=$(bash mise-tasks/clean clean-only 2>&1); rc=$?
  assert_exit_code 0 $rc "clean removes clean task worktrees"
  [[ ! -e "$meta/worktrees/clean-only/fakerepo" ]] && pass "clean removed repo worktree" || fail "clean removed repo worktree"

  bash mise-tasks/branch e2e >/dev/null
  cd worktrees/e2e/fakerepo
  git config user.email "t@t"
  git config user.name "Task"
  echo change >> README.md
  git add README.md
  git commit -q -m "test change"

  cd "$meta/worktrees/e2e"
  out=$(bash "$meta/mise-tasks/push" 2>&1); rc=$?
  assert_exit_code 0 $rc "push pushes changed repo branch"
  assert_contains "pushed fakerepo" "$out" "push reports repo"
  git -C "$upstream" show-ref --verify --quiet refs/heads/e2e && pass "upstream received branch e2e" || fail "upstream received branch e2e"

  seed=$(mktemp -d -p "$SCRATCH" fakerepo.update.XXXXXX)
  git clone -q "$upstream" "$seed"
  git -C "$seed" config user.email "u@u"
  git -C "$seed" config user.name "Upstream"
  git -C "$seed" switch -q main
  git -C "$seed" fetch -q origin e2e
  git -C "$seed" merge -q --ff-only origin/e2e
  echo upstream >> "$seed/README.md"
  git -C "$seed" add README.md
  git -C "$seed" commit -q -m upstream
  git -C "$seed" push -q origin main

  cd "$meta"
  out=$(bash mise-tasks/pull fakerepo 2>&1); rc=$?
  assert_exit_code 0 $rc "pull fast-forwards base repo"
  git -C repos/fakerepo log --oneline -1 | grep -q upstream && pass "base repo received upstream commit" || fail "base repo received upstream commit"
  [[ ! -e "$meta/worktrees/e2e/fakerepo" ]] && pass "pull removed merged repo worktree" || fail "pull removed merged repo worktree"
}

echo "agent-workspace tests"
echo "template: $TEMPLATE_ROOT"
echo "scratch:  $SCRATCH"

missing=()
for tool in git jq bash; do
  command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo
  echo "${RED}missing tools:${RESET} ${missing[*]}"
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
