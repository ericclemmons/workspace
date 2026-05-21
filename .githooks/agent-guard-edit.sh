#!/usr/bin/env bash
# PreToolUse hook for Edit/Write/MultiEdit/NotebookEdit.
# Blocks edits outside worktrees or to meta-infrastructure files.
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

# Find meta repo root via git-common-dir
if ! common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
  block "Edit blocked: not inside a git repo. Edits must happen inside a worktree under <meta>/worktrees/."
fi
meta_root=$(dirname "$common")
meta_root=$(cd "$meta_root" && pwd -P)

# Edits must be inside a worktree
if [[ "$abs" != "$meta_root/worktrees/"*/* ]]; then
  block "Edit blocked: $abs is outside ./worktrees/. Create a worktree first:
  mise run branch <name>
  cd worktrees/<name>
then make edits there."
fi

# Protect meta-infrastructure even within worktrees
case "$abs" in
  */.githooks/*|*/AGENTS.md|*/.claude/settings.json|*/opencode.json|*/mise.toml|*/hk.pkl|*/.gitconfig|*/mise-tasks/*|*/.gitignore)
    block "Edit blocked: $abs is meta-repo infrastructure. Modifying it changes the rules for all agents. Ask the user to confirm and edit it themselves."
    ;;
esac

exit 0
