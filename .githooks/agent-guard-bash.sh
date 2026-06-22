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

# Workspace root is based on this guard's location so nested repos cannot hide it.
meta_root=$(cd "$(dirname "$0")/.." && pwd -P)

cwd=$(pwd -P)

# Dangerous workspace-root git commands are blocked. Workspace maintenance commits
# are allowed, but pre-commit prevents committing .worktrees/ content.
if [[ "$cwd" == "$meta_root" ]]; then
  if echo "$cmd" | grep -qE '\bgit[[:space:]]+(push|merge|rebase|cherry-pick|reset|restore|stash)\b'; then
    block "Refusing dangerous git command from the workspace root. Use mise tasks for repo work, or a normal workspace branch for tooling/docs changes."
  fi
fi

if [[ "$cwd" == "$meta_root"/.worktrees/* ]]; then
  if [[ -d "$cwd/.git" || -f "$cwd/.git" ]]; then
    if echo "$cmd" | grep -qE '\bgit[[:space:]]+push\b'; then
      block "Refusing raw git push from a workspace task worktree. Use 'mise run push' so repo prefixes are split and pushed to their own upstream repos."
    fi
  fi
fi

# Block commits/pushes when HEAD is main (works in any cwd)
branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
if [[ "$branch" == "main" ]]; then
  if echo "$cmd" | grep -qE '\bgit[[:space:]]+(commit|push)\b'; then
    block "HEAD is on main. Switch to a task branch in a worktree:
  mise run branch <name>
  cd .worktrees/<name>"
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
