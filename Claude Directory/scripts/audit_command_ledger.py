#!/usr/bin/env python3
import csv
import os
import sys
from pathlib import Path

ledger = Path("./logs/command_ledger.csv")

if not ledger.exists():
    print("ERROR: command ledger missing")
    sys.exit(1)

with ledger.open(newline="", encoding="utf-8") as f:
    rows = list(csv.DictReader(f))

required = [
    "UTC Time",
    "Working Directory",
    "Command",
    "Stdout Path",
    "Stderr Path",
    "Exit Code",
    "Notes",
]

if not rows:
    print("ERROR: command ledger has no command rows")
    sys.exit(1)

errors = []
failed = []
reruns = []

for idx, row in enumerate(rows, start=2):
    for field in required:
        if field not in row or row[field] == "":
            errors.append(f"Row {idx}: missing {field}")

    for path_field in ["Stdout Path", "Stderr Path"]:
        path = row.get(path_field, "")
        if path and not os.path.exists(path):
            errors.append(f"Row {idx}: missing referenced {path_field}: {path}")

    if row.get("Exit Code") not in ("0", 0):
        failed.append((idx, row))

    if "rerun" in row.get("Notes", "").lower() or "retry" in row.get("Notes", "").lower():
        reruns.append((idx, row))

if errors:
    print("ERROR: command ledger audit failed")
    for error in errors:
        print(error)
    sys.exit(1)

print("Command ledger audit passed.")
print(f"Total commands: {len(rows)}")
print(f"Failed commands: {len(failed)}")
print(f"Rerun or retry commands noted: {len(reruns)}")

if failed:
    print("Failed command rows:")
    for idx, row in failed:
        print(f"- CSV row {idx}: exit={row.get('Exit Code')} note={row.get('Notes')} command={row.get('Command')}")
