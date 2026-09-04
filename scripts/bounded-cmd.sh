#!/usr/bin/env bash
# Run a command with stdout/stderr byte ceilings and TERM-then-KILL.
# Usage: bounded-cmd.sh MAX_BYTES TERM_SECS KILL_AFTER_SECS -- CMD [ARGS...]
# Exit 124: deadline (GNU timeout)
# Exit 125: stdout or stderr exceeded MAX_BYTES (output is discarded)
# CMD is executed via env so it is not a timeout option and not a shell builtin.
set -u

if [[ $# -lt 5 ]]; then
  echo "bounded-cmd.sh: usage: MAX_BYTES TERM_SECS KILL_AFTER_SECS -- CMD [ARGS...]" >&2
  exit 2
fi

max=$1
term_secs=$2
kill_after=$3
shift 3
if [[ "${1:-}" == "--" ]]; then
  shift
fi
if [[ $# -lt 1 ]]; then
  exit 2
fi
case "$max" in *[!0-9]*|"") exit 2 ;; esac
case "$term_secs" in *[!0-9]*|"") exit 2 ;; esac
case "$kill_after" in *[!0-9]*|"") exit 2 ;; esac

out=$(mktemp -p "${TMPDIR:-/tmp}" omamessage.XXXXXX) || exit 2
err=$(mktemp -p "${TMPDIR:-/tmp}" omamessage.XXXXXX) || exit 2
chmod 600 -- "$out" "$err" 2>/dev/null || true
cleanup() { rm -f -- "$out" "$err"; }
trap cleanup EXIT

lim=$((max + 1))
ec=0
timeout --signal=TERM --kill-after="${kill_after}s" "${term_secs}s" env -- "$@" \
  > >(head -c "$lim" > "$out") \
  2> >(head -c "$lim" > "$err") || ec=$?
wait 2>/dev/null || true

os=$(wc -c < "$out")
es=$(wc -c < "$err")
os=${os// /}
es=${es// /}
if (( os > max || es > max )); then
  exit 125
fi
cat -- "$out"
exit "$ec"
