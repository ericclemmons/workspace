#!/usr/bin/env bash
# PreToolUse hook for Bash. Blocks shell commands that violate the workflow.
set -euo pipefail

input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // empty')
[[ -z "$cmd" ]] && exit 0

block() {
  jq -nc --arg reason "$1" '{decision:"block", reason:$reason}' >&2
  exit 2
}

# Resolve meta root if we're inside the meta repo
meta_root=""
if common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
  meta_root=$(dirname "$common")
  meta_root=$(cd "$meta_root" && pwd -P)
fi

cwd=$(pwd -P)

# Mutating git commands from meta main checkout → block (use a worktree)
if [[ -n "$meta_root" ]] && [[ "$cwd" == "$meta_root" ]]; then
  if echo "$cmd" | grep -qE '\bgit[[:space:]]+(commit|add|push|merge|rebase|cherry-pick|reset|restore|stash)\b'; then
    block "Refusing mutating git command from the meta main checkout. cd into worktrees/<branch>/ first, or create one:
  mise run branch <name>
  cd worktrees/<name>"
  fi
fi

# Block commits/pushes when HEAD is main (works in any cwd)
branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
if [[ "$branch" == "main" ]]; then
  if echo "$cmd" | grep -qE '\bgit[[:space:]]+(commit|push)\b'; then
    block "HEAD is on main. Switch to a task branch in a worktree:
  mise run branch <name>
  cd worktrees/<name>"
  fi
fi

# Block disabling hooks
if echo "$cmd" | grep -qE 'core\.hooksPath|--no-verify'; then
  block "Refusing to disable or reconfigure git hooks. These enforce the meta-repo workflow."
fi

# Block --force worktree remove
if echo "$cmd" | grep -qE '\bgit[[:space:]]+worktree[[:space:]]+remove\b.*--force\b'; then
  block "Refusing 'git worktree remove --force'. If there are uncommitted changes, deal with them explicitly (commit, stash, or discard) then re-run without --force."
fi

exit 0
