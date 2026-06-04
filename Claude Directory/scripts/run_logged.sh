#!/usr/bin/env bash
set -u

mkdir -p ./logs

LEDGER="./logs/command_ledger.csv"

if [ ! -f "$LEDGER" ]; then
  python3 - <<'PY'
import csv

with open("./logs/command_ledger.csv", "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow([
        "UTC Time",
        "Working Directory",
        "Command",
        "Stdout Path",
        "Stderr Path",
        "Exit Code",
        "Notes",
    ])
PY
fi

run_logged() {
  local note="$1"
  shift

  local ts
  local id
  local cwd
  local stdout_path
  local stderr_path
  local cmd
  local exit_code

  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  id="$(date -u +"%Y%m%dT%H%M%SZ")_${RANDOM}"
  cwd="$PWD"
  stdout_path="./logs/${id}_stdout.log"
  stderr_path="./logs/${id}_stderr.log"
  cmd="$*"

  "$@" >"$stdout_path" 2>"$stderr_path"
  exit_code=$?

  python3 - "$LEDGER" "$ts" "$cwd" "$cmd" "$stdout_path" "$stderr_path" "$exit_code" "$note" <<'PY'
import csv
import sys

ledger, ts, cwd, cmd, stdout_path, stderr_path, exit_code, note = sys.argv[1:]

with open(ledger, "a", newline="") as f:
    writer = csv.writer(f)
    writer.writerow([ts, cwd, cmd, stdout_path, stderr_path, exit_code, note])
PY

  return "$exit_code"
}

run_logged "$@"
