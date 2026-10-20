#!/bin/bash
# Demonstration 3: the session record tells you about refusals and about crashes,
# and tells you NOTHING about approvals.
#
# WHAT IT SHOWS. Four runs, one hook each, all of them present and readable --
# unlike demo 02, nothing here is missing. The hook exits 2, exits 0, crashes,
# then crashes with `"onFailure": "block"` set.
#
#   exits 2   -> the call is REFUSED and the hook is NAMED in the record
#   exits 0   -> the call RUNS and the record does not mention the hook AT ALL
#   crashes   -> the call RUNS, and the hook IS named
#   crashes + onFailure -> the call is REFUSED
#
# THE CONSEQUENCE, WHICH IS THE WHOLE POINT. A quiet record means one of two
# things and cannot tell you which: nothing was attempted, or everything was
# approved. So you can audit what your guards blocked, and you can never audit
# what they let through. Any report that shows no refusals is compatible with a
# guard that approved every call and with a guard that was never consulted.
#
# AND A CRASHING GUARD PERMITS BY DEFAULT. It is at least visible after the
# fact on this version -- that was not always so -- but visible-afterwards is
# not a control. `"onFailure": "block"` is what makes a crash refuse, and the
# fourth arm is here to show the fix rather than only the flaw.
#
# ABOUT READING THE RECORD. This script does not parse session transcripts and
# does not contain a transcript reader. It asks one question -- does the hook's
# own filename appear anywhere in the files THIS RUN just produced -- with a
# hard check that the directory it searches is inside the scratch tree it
# created. Shipping something that reads a reader's whole session history would
# be a much larger decision than this demonstration needs.
#
# MEASURED 2026-10-20 on 2.1.304. Exits non-zero and names the arm if any of the
# eight predictions below moves.
#
# COSTS. Four short model calls. Requires `claude` and `python3` on PATH.

set -uo pipefail

SB="${TMPDIR:-/tmp}/never-fired-demo-03"
HOME_DIR="$SB/config"
WORK="$SB/work"
HOOKS="$SB/config/hooks"

command -v claude >/dev/null 2>&1 || { echo "claude is not on PATH" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is not on PATH" >&2; exit 2; }

rm -rf "$SB"
mkdir -p "$HOOKS" "$WORK"

printf '#!/usr/bin/env python3\nimport sys\nprint("refused by the rule", file=sys.stderr)\nsys.exit(2)\n' > "$HOOKS/refuses.py"
printf '#!/usr/bin/env python3\nimport sys\nsys.exit(0)\n' > "$HOOKS/allows.py"
printf '#!/usr/bin/env python3\nraise RuntimeError("the guard itself is broken")\n' > "$HOOKS/crashes.py"

# `Bash(touch *)` is allowed so the only thing that can stop the command is the
# hook under test -- without it a headless run has nobody to answer a prompt and
# every arm refuses for an unrelated reason, which would read as a successful
# demonstration while proving nothing.
write_settings() {  # $1 = hook filename, $2 = extra JSON or empty
  cat > "$HOME_DIR/settings.json" <<JSON
{
  "permissions": { "defaultMode": "default", "allow": ["Bash(touch *)"] },
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash",
        "hooks": [ { "type": "command", "command": "python3 $HOOKS/$1"$2 } ] }
    ]
  }
}
JSON
}

# The narrowest thing that answers the question. It greps for one filename, and
# it refuses to look anywhere that is not inside the tree this script made.
hook_is_named_in_the_record() {  # $1 = hook filename
  local dir="$HOME_DIR/projects"
  case "$dir" in
    "$SB"/*) : ;;
    *) echo "refusing to search outside the scratch tree: $dir" >&2; return 2 ;;
  esac
  [ -d "$dir" ] || return 1
  grep -rql -- "$1" "$dir" 2>/dev/null
}

fail=0
check() {  # $1 label, $2 hook file, $3 extra json, $4 expect RAN|REFUSED, $5 expect NAMED|SILENT
  write_settings "$2" "$3"
  rm -rf "$HOME_DIR/projects"; rm -f "$WORK/marker.txt"
  ( cd "$WORK" && CLAUDE_CONFIG_DIR="$HOME_DIR" claude -p \
      "Run this shell command: touch $WORK/marker.txt -- then stop." >/dev/null 2>&1 )

  local did named
  [ -f "$WORK/marker.txt" ] && did=RAN || did=REFUSED
  if hook_is_named_in_the_record "$2"; then named=NAMED; else named=SILENT; fi

  printf '%-34s call %-8s record %-7s' "$1" "$did" "$named"
  if [ "$did" = "$4" ] && [ "$named" = "$5" ]; then
    printf '  as predicted\n'
  else
    printf '  MOVED (predicted %s / %s)\n' "$4" "$5"; fail=1
  fi
}

echo "Demonstration 3 -- what the record shows, and what it never shows"
echo "scratch tree: $SB"
echo "every hook here EXISTS and is readable; only its exit behaviour differs"
echo

check "hook exits 2 (refuses)"        refuses.py ""                         REFUSED NAMED
check "hook exits 0 (approves)"       allows.py  ""                         RAN     SILENT
check "hook crashes"                  crashes.py ""                         RAN     NAMED
check "hook crashes + onFailure"      crashes.py ', "onFailure": "block"'   REFUSED NAMED

echo
if [ "$fail" -eq 0 ]; then
  cat <<'TEXT'
All four arms as predicted.

The approval is the one event that leaves no trace. So a record showing no
refusals is equally consistent with a guard that approved every call, a guard
that crashed, and a guard that was never consulted at all -- and nothing in the
record distinguishes them. Whatever else you do, do not read a quiet report as
a clean run.

A crashing guard permits unless onFailure is set. The fourth arm is the fix.
TEXT
  rm -rf "$SB"
  exit 0
fi
echo "AT LEAST ONE ARM MOVED. Scratch tree left at $SB for inspection." >&2
exit 1
