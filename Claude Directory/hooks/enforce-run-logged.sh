#!/usr/bin/env bash
set -euo pipefail

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
cat > "$tmp"

python3 - "$tmp" <<'PYHOOK'
import json
import re
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    raw = f.read()

try:
    data = json.loads(raw)
except Exception as exc:
    print(f"Blocked: could not parse Claude Code hook JSON input: {exc}", file=sys.stderr)
    sys.exit(2)

cmd = data.get("tool_input", {}).get("command", "")
cmd = cmd.strip()
normalized = " ".join(cmd.split())

if not cmd:
    sys.exit(0)

blocked_patterns = [
    (r"(^|\s)rm\s+(-[^\s]*r[^\s]*f|-rf|-fr)\s+/(\s|$)", "recursive deletion from filesystem root"),
    (r"(^|\s)rm\s+(-[^\s]*r[^\s]*f|-rf|-fr)\s+/(mnt|media|evidence)(/|\s|$)", "recursive deletion in protected evidence area"),
    (r"(^|\s)(mkfs|wipefs|shred)(\s|$)", "destructive filesystem command"),
    (r"(^|\s)dd\s+.*\bof=/dev/", "dd write to block device"),
    (r"(^|\s)dd\s+.*\bof=/(mnt|media|evidence)/", "dd write to protected evidence area"),
    (r"(^|\s)(>|>>)\s*/(mnt|media|evidence)/", "shell redirection into protected evidence area"),
    (r"(^|\s)tee\s+/(mnt|media|evidence)/", "tee write into protected evidence area"),
    (r"(^|\s)(chmod|chown)\s+-R\s+/(mnt|media|evidence)(/|\s|$)", "recursive permission change in protected evidence area"),
]

for pattern, reason in blocked_patterns:
    if re.search(pattern, normalized):
        print(f"Blocked: {reason}. Command: {cmd}", file=sys.stderr)
        sys.exit(2)

bootstrap_exact = {
    "mkdir -p ./analysis ./exports ./logs ./reports",
    "chmod +x ./.claude/hooks/*.sh ./.claude/scripts/*.sh",
    "pwd",
    "ls"
}

if normalized in bootstrap_exact:
    sys.exit(0)

allowed_wrapped = [
    r"^\/home/sansforensics/.claude/scripts/run_logged.sh(\s|$)",
    r"^env\s+TZ=UTC\s+\/home/sansforensics/.claude/scripts/run_logged.sh(\s|$)",
    r"^bash\s+-[a-zA-Z]*c\s+['\"]\/home/sansforensics/.claude/scripts/run_logged.sh(\s|$)",
    r"^bash\s+-o\s+pipefail\s+-lc\s+['\"]\/home/sansforensics/.claude/scripts/run_logged.sh(\s|$)",
]

if any(re.search(pattern, normalized) for pattern in allowed_wrapped):
    sys.exit(0)

print("Blocked: all forensic Bash commands must run through /home/sansforensics/.claude/scripts/run_logged.sh. Bootstrap is limited to workspace/logging setup only.", file=sys.stderr)
print(f"Command attempted: {cmd}", file=sys.stderr)
sys.exit(2)
PYHOOK
