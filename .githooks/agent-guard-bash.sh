#!/usr/bin/env bash
# PreToolUse hook for Bash. Blocks shell commands that violate the workflow.
set -euo pipefail

input=$(cat)
[[ "$input" == *'"command"'* ]] || exit 0
cmd=$input

block() {
  local reason=${1//\\/\\\\}
  reason=${reason//"/\\"}
  printf '{"decision":"block","reason":"%s"}\n' "$reason" >&2
  exit 2
}

# Workspace root is based on this guard's location so nested repos cannot hide it.
meta_root=$(cd "$(dirname "$0")/.." && pwd -P)

cwd=$(pwd -P)

if [[ "$cwd" == "$meta_root"/.worktrees/* ]]; then
  if [[ -d "$cwd/.git" || -f "$cwd/.git" ]]; then
    if [[ "$cmd" == *"git push"* ]]; then
      block "Refusing raw git push from a workspace task worktree. Use 'mise run push' so repo prefixes are split and pushed to their own upstream repos."
    fi
  fi
fi

# Block disabling hooks
if [[ "$cmd" == *"core.hooksPath"* || "$cmd" == *"--no-verify"* ]]; then
  block "Refusing to disable or reconfigure git hooks. These enforce the meta-repo workflow."
fi

# Block --force worktree remove
if [[ "$cmd" == *"git worktree remove"* && "$cmd" == *"--force"* ]]; then
  block "Refusing 'git worktree remove --force'. If there are uncommitted changes, deal with them explicitly (commit, stash, or discard) then re-run without --force."
fi

exit 0
