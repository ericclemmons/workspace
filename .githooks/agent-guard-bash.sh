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

if [[ "$cwd" == "$meta_root"/.worktrees/* ]]; then
  if [[ -d "$cwd/.git" || -f "$cwd/.git" ]]; then
    if echo "$cmd" | grep -qE '\bgit[[:space:]]+push\b'; then
      block "Refusing raw git push from a workspace task worktree. Use 'mise run push' so repo prefixes are split and pushed to their own upstream repos."
    fi
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
