#!/usr/bin/env bash
# PreToolUse hook for Edit/Write/MultiEdit/NotebookEdit.
# Blocks edits outside task worktrees or to meta-infrastructure files.
set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty')
[[ -z "$file_path" ]] && exit 0

block() {
  jq -nc --arg reason "$1" '{decision:"block", reason:$reason}' >&2
  exit 2
}

# Resolve to absolute path
if [[ "$file_path" = /* ]]; then
  abs="$file_path"
else
  abs="$(pwd)/$file_path"
fi
abs=$(readlink -f "$abs" 2>/dev/null \
  || python3 -c "import os,sys;print(os.path.realpath(sys.argv[1]))" "$abs" 2>/dev/null \
  || echo "$abs")

# Workspace root is based on this guard's location so nested repos cannot hide it.
meta_root=$(cd "$(dirname "$0")/.." && pwd -P)

if [[ "$abs" != "$meta_root/.worktrees/"*/* ]]; then
  block "Edit blocked: $abs is outside ./.worktrees/<task>/<repo>/. Create a task worktree first:
  mise run branch <name>
  cd .worktrees/<name>
then make edits there."
fi

# Protect meta-infrastructure even within worktrees
case "$abs" in
  "$meta_root"/.githooks/*|"$meta_root"/AGENTS.md|"$meta_root"/.claude/settings.json|"$meta_root"/opencode.json|"$meta_root"/mise.toml|"$meta_root"/hk.pkl|"$meta_root"/.gitconfig|"$meta_root"/mise-tasks/*|"$meta_root"/.gitignore)
    block "Edit blocked: $abs is meta-repo infrastructure. Modifying it changes the rules for all agents. Ask the user to confirm and edit it themselves."
    ;;
esac

exit 0
