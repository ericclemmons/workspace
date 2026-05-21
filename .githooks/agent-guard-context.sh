#!/usr/bin/env bash
# UserPromptSubmit hook. Stdout is injected into the agent's context.
set -euo pipefail

cwd=$(pwd -P)
meta_root=$(cd "$(dirname "$0")/.." && pwd -P)

# If cwd is the workspace root, nudge the agent into a task worktree.
if [[ "$cwd" == "$meta_root" ]]; then
  cat <<EOF
<system-reminder>
You are in the workspace root ($cwd), not a task worktree.

Do not edit repo files or commit here. Before doing repo task work, run:

  mise run branch <descriptive-name>
  cd worktrees/<descriptive-name>

Then edit files inside worktrees/<descriptive-name>/<repo>/.
</system-reminder>
EOF
fi

# If cwd is a base repo, remind the agent it is read-only.
if [[ "$cwd" == "$meta_root/repos/"* ]]; then
  cat <<EOF
<system-reminder>
You are inside repos/, which contains read-only base clones. Do not edit or commit here.

Use a task worktree instead:
  mise run branch <descriptive-name>
  cd worktrees/<descriptive-name>
</system-reminder>
EOF
fi

exit 0
