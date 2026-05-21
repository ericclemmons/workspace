#!/usr/bin/env bash
# UserPromptSubmit hook. Stdout is injected into the agent's context.
set -euo pipefail

cwd=$(pwd)
meta_root=""
if common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
  meta_root=$(dirname "$common")
fi
[[ -z "$meta_root" ]] && exit 0

# If cwd is the meta main checkout, nudge the agent into a worktree
if [[ "$cwd" == "$meta_root" ]]; then
  cat <<EOF
<system-reminder>
You are in the meta-repo MAIN checkout ($cwd), not a worktree.

Do not edit files or commit here. Before doing any task work, run:

  mise run branch <descriptive-name>
  cd worktrees/<descriptive-name>

Then proceed. See AGENTS.md for the workflow.
</system-reminder>
EOF
fi

# If we're in a worktree but on main (defensive)
branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
if [[ "$cwd" != "$meta_root" ]] && [[ "$branch" == "main" ]]; then
  cat <<EOF
<system-reminder>
You are in a worktree but HEAD is on main. Commits will be blocked. Switch to a task branch:
  git checkout -b <name>
</system-reminder>
EOF
fi

exit 0
