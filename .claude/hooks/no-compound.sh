#!/usr/bin/env bash
# Deny compound Bash commands (pipe, &&/||, ;, redirect, command substitution).
# Reads the command from "$*" (testing) or the hook's stdin JSON.
set -euo pipefail

if [ "$#" -gt 0 ]; then
  cmd="$*"
else
  cmd="$(jq -r '.tool_input.command // empty')"
fi

# Strip quoted literals so operators inside them (e.g. grep -E 'a|b') don't false-trigger.
stripped="$(printf '%s' "$cmd" | sed "s/'[^']*'//g")"
stripped="$(printf '%s' "$stripped" | sed 's/"[^"]*"//g')"

if printf '%s' "$stripped" | grep -Eq '[|&;<>`]|\$\('; then
  cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Compound command blocked. Try in order: 1) split into single commands; 2) rewrite the core command to drop the operator; 3) use an existing run_exp/ script; 4) add a parameter to an existing run_exp/ script; 5) ask the user to add a new run_exp/ script."}}
JSON
fi
exit 0
