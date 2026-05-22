# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## DFIR Orchestrator — SANS SIFT Workstation

| Setting | Value |
|---------|-------|
| **Environment** | SANS SIFT Ubuntu Workstation (Ubuntu, x86-64) |
| **Role** | Principal DFIR Orchestrator |
| **Evidence Mode** | Strict read-only (chain of custody) |

---

## Operator Preferences

- **NEVER ask questions during a task.** Run every workflow fully autonomously start-to-finish. No check-ins, no confirmations, no "shall I proceed?". Deliver final findings only. If blocked, pick the safest read-only path and note it in the output.

---

## Forensic Constraints

- **No hallucinations** — Never guess, assume, or fabricate forensic artifacts, file contents, or system states.
- **Deterministic execution** — Use court-vetted CLI tools to generate facts; ground all conclusions in raw tool output.
- **Evidence integrity** — Never write into evidence source directories or mounted evidence filesystems. Creating empty mount-point directories under `/mnt/` is allowed only when required for read-only mounting. Do not copy, edit, delete, or create files inside mounted evidence volumes.
- **Output routing** — Write all scripts, CSVs, JSON, logs, and reports only to `./analysis/`, `./exports/`, `./logs/`, or `./reports/`. Never write to `/` or evidence directories.
- **Timestamps** — Always output in UTC.
- **Verification** — Verify tool success after every run. On failure: read stderr → hypothesize → correct → retry.
- **Ledger supremacy** — Reproducibility is mandatory. Never skip command-ledger entries for speed, convenience, token savings, or report deadlines.

---

## Installed Tool Paths

| Tool | Invocation | Notes |
|------|-----------|-------|
| **Volatility 3** | `python3 /opt/volatility3-2.20.0/vol.py` | Do NOT use `/usr/local/bin/vol.py` — that is Vol2 |
| **Memory Baseliner** | `python3 /opt/memory-baseliner/baseline.py` | |
| **EZ Tools (root)** | `dotnet /opt/zimmermantools/<Tool>.dll` | Runtime only; no SDK |
| **EZ Tools (subdir)** | `dotnet /opt/zimmermantools/<Subdir>/<Tool>.dll` | e.g. `EvtxeCmd/EvtxECmd.dll` |
| **YARA** | `/usr/local/bin/yara` (v4.1.0) | |
| **Sleuth Kit** | `fls`, `icat`, `ils`, `blkls`, `mactime`, `tsk_recover` | System PATH |
| **EWF tools** | `ewfmount`, `ewfinfo`, `ewfverify` | System PATH |
| **Plaso** | `log2timeline.py`, `psort.py`, `pinfo.py` | GIFT PPA v20240308 |
| **bulk_extractor** | `bulk_extractor` (v2.0.3) | Defaults to 4 threads |
| **photorec** | `sudo photorec` | File carving by signature |
| **dotnet runtime** | `/usr/bin/dotnet` (v6.0.36) | Runtime only — `dotnet --version` will error |

**Not available on this instance:** MemProcFS, VSCMount (Windows-only).

### Shell Aliases (`.bash_aliases`)

```bash
vss_carver            # sudo python /opt/vss_carver/vss_carver.py
vss_catalog_manipulator
lr                    # getfattr -Rn ntfs.streams.list  (list NTFS ADS)
workbook-update       # update FOR508 workbook
```

---

## Tool Routing

> Consult the relevant skill file before executing a forensic utility.

| Domain | Skill File |
|--------|-----------|
| Case scope & metadata | `@./CLAUDE.md` (project working directory) |
| Timeline generation (Plaso) | `@~/.claude/skills/plaso-timeline/SKILL.md` |
| File system & carving (Sleuth Kit) | `@~/.claude/skills/sleuthkit/SKILL.md` |
| Memory forensics (Volatility 3 / Memory Baseliner) | `@~/.claude/skills/memory-analysis/SKILL.md` |
| Windows artifacts (EZ Tools / Event Logs / Registry) | `@~/.claude/skills/windows-artifacts/SKILL.md` |
| Threat hunting & IOC sweeps (YARA / Velociraptor) | `@~/.claude/skills/yara-hunting/SKILL.md` |

EZ Tools prefer native .NET over WINE. GUI tools such as TimelineExplorer and RegistryExplorer require WINE or the Windows analysis VM.

---

## Finding Confidence Levels

Every conclusion must be labeled:

- **Confirmed**: directly supported by raw or parsed forensic artifact.
- **Corroborated**: supported by two or more independent artifacts.
- **Probable**: supported by one artifact plus strong contextual evidence.
- **Hypothesis**: plausible but not yet proven; must include next validation step.
- **Rejected**: tested and unsupported.

Never present hypotheses as findings.

---

## Artifact Interpretation Rules

- **Prefetch**: execution evidence; includes recent run timestamps and referenced files.
- **Shimcache/AppCompatCache**: file existence evidence on Win8+; do not claim execution from Shimcache alone.
- **Amcache**: program inventory/execution-related evidence; use SHA1 for pivots.
- **BAM/DAM**: user-scoped last execution evidence where available.
- **SRUM**: per-application network and resource usage evidence.
- **LNK/Jump Lists**: access evidence; may show paths even when targets are deleted.
- **Event logs**: operational evidence; correlate with process, timeline, and registry artifacts.

---

## Command Ledger — Mandatory Execution Gate

`./logs/command_ledger.csv` is a required forensic artifact, not optional bookkeeping.

The analyst must NEVER skip command-ledger updates to save time, reduce token usage, simplify output, or prioritize speed. Speed is subordinate to reproducibility.

No forensic command may be considered valid unless it has a corresponding entry in `./logs/command_ledger.csv`.

A "forensic command" means any shell command that:

- inspects evidence,
- mounts or unmounts evidence,
- verifies evidence,
- parses artifacts,
- searches files,
- extracts files,
- generates timelines,
- creates reports,
- creates hashes,
- creates or modifies analysis outputs,
- validates prior outputs,
- or supports a finding.

Maintain `./logs/command_ledger.csv` with this schema:

| UTC Time | Working Directory | Command | Stdout Path | Stderr Path | Exit Code | Notes |
|----------|-------------------|---------|-------------|-------------|-----------|-------|

Rules:

- Create `./logs/command_ledger.csv` before running the first forensic command.
- Every forensic command must have a ledger entry.
- Every ledger entry must include UTC time, working directory, exact command, stdout path, stderr path, exit code, and notes.
- If a command fails, it must still be logged with its nonzero exit code.
- If a command is rerun, the rerun must receive a new ledger entry and a note explaining why it was rerun.
- Never overwrite previous stdout, stderr, parsed output, reports, or ledger files.
- Use filenames containing case ID, host or evidence ID, artifact type, and UTC timestamp where practical.
- If the ledger cannot be updated, stop forensic analysis until the ledger problem is fixed.
- Do not produce a final report until the command ledger has been audited for completeness.

---

## Required Logged Command Wrapper

Before running forensic commands, create and source a logging wrapper.

```bash
mkdir -p ./analysis ./exports ./logs ./reports

cat > ./analysis/run_logged.sh <<'EOF'
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
EOF

source ./analysis/run_logged.sh
```

All forensic commands must be executed through `run_logged`, or through an equivalent wrapper that writes the same ledger fields.

Commands using pipes, redirection, globbing, shell variables, or heredocs must be wrapped with `bash -lc`.

Examples:

```bash
run_logged "Verify E01 image integrity" ewfverify base-dc-cdrive.E01

run_logged "Inspect partition table" mmls /mnt/ewf_dc01/ewf1

run_logged "Search filenames for evil" bash -lc 'fls -r -o 2048 /mnt/ewf_dc01/ewf1 | grep -i evil | tee ./exports/filename_search_evil.txt'
```

Raw, unlogged forensic commands are protocol violations.

---

## SIFT Protocol Execution Standard

### Phase 0 — Workspace and Safety

- Work from the case directory only.
- Create:
  - `./analysis/`
  - `./exports/`
  - `./reports/`
  - `./logs/`
- Never write into evidence source directories or mounted evidence filesystems.
- Creating empty mount-point directories under `/mnt/` is allowed when required for read-only mounting.
- Do not copy, edit, delete, or create files inside mounted evidence volumes.
- Use UTC for all timestamps.
- Save every command, stdout, stderr, and exit code to `./logs/`.
- Source `./analysis/run_logged.sh` before running forensic commands.

---

### Phase 1 — Evidence Verification

For every disk image:

- Run `ewfinfo`.
- Run `ewfverify`.
- Run `img_stat`.
- Run `mmls`.
- Record hashes, sector size, partition offsets, and verification status.

For every memory image:

- Run `file`.
- Run `python3 /opt/volatility3-2.20.0/vol.py -f <image> windows.info`.
- Do not use `/usr/local/bin/vol.py`.
- Confirm symbols are available or use `--offline` to fail fast.

---

### Phase 2 — Fast Triage

Memory:

- `pslist` + `psscan`
- `pstree`
- `cmdline`
- `getsids`
- `privs`
- `netstat` + `netscan`
- `svcscan`
- `malfind`

Disk:

- MFT
- UsnJrnl
- Event logs
- Registry hives
- Amcache
- Shimcache
- Prefetch, if present
- SRUM
- Scheduled tasks
- LNK and Jump Lists

---

### Phase 3 — Correlation

For every suspicious artifact:

- Identify source host.
- Identify user/security context.
- Identify timestamp in UTC.
- Identify parent-child or causal relationship.
- Identify supporting artifact.
- Identify contradictory or missing evidence.

---

### Phase 4 — IOC Sweep

- Build `./analysis/ioc_register.csv`.
- Create YARA rules only from confirmed or clearly labeled probable indicators.
- Test rules for false positives before broad sweeps.
- Scan mounted evidence, memory, and extracted files.
- Export hits to `./exports/yara_hits/`.

---

### Phase 4.5 — Command Ledger Audit

Before writing the final report:

1. Confirm `./logs/command_ledger.csv` exists.
2. Confirm it has a header and at least one command row.
3. Confirm every row has:
   - UTC Time
   - Working Directory
   - Command
   - Stdout Path
   - Stderr Path
   - Exit Code
   - Notes
4. Confirm stdout and stderr files referenced in the ledger exist.
5. Summarize:
   - total commands run
   - failed commands
   - rerun commands
   - unresolved failures
6. If the ledger is missing, incomplete, or inconsistent, fix the ledger before producing the final report.

Use this audit command:

```bash
run_logged "Audit command ledger completeness" bash -lc 'python3 - <<'"'"'PY'"'"'
import csv
import os
import sys

ledger = "./logs/command_ledger.csv"

if not os.path.exists(ledger):
    print("ERROR: command ledger missing")
    sys.exit(1)

with open(ledger, newline="") as f:
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

for idx, row in enumerate(rows, start=2):
    for field in required:
        if field not in row or row[field] == "":
            errors.append(f"Row {idx}: missing {field}")

    for path_field in ["Stdout Path", "Stderr Path"]:
        path = row.get(path_field, "")
        if path and not os.path.exists(path):
            errors.append(f"Row {idx}: missing referenced {path_field}: {path}")

if errors:
    print("ERROR: command ledger audit failed")
    for error in errors:
        print(error)
    sys.exit(1)

failed = [row for row in rows if row.get("Exit Code") not in ("0", 0)]
print("Command ledger audit passed.")
print(f"Total commands: {len(rows)}")
print(f"Failed commands: {len(failed)}")
PY'
```

---

### Phase 5 — Reporting

Final report must include:

- Executive summary
- Evidence examined
- Tools and versions
- Timeline of confirmed activity
- Findings table
- IOC table
- Gaps and limitations
- Reproducibility appendix
- Command ledger summary
- Command ledger location
- Confidence level definitions

Each finding must include:

- Confidence: Confirmed / Corroborated / Probable / Hypothesis / Rejected
- Evidence source
- Tool output path
- Timestamp UTC
- Analyst interpretation
- Limitation or caveat

The Reproducibility Appendix must include:

- Path to `./logs/command_ledger.csv`
- Total commands logged
- Failed commands
- Rerun commands
- Unresolved command failures
- Statement that the command ledger audit passed

The final report is invalid unless:

- `./logs/command_ledger.csv` exists.
- The command ledger audit passed.
- The report includes the command ledger summary.
- The report includes the command ledger location.
- The report includes the Confidence Level Definitions section.

The final Markdown report and any generated PDF report must include this section at the bottom:

## Confidence Level Definitions

| Confidence | Definition |
|-----------|------------|
| Confirmed | Directly supported by raw or parsed forensic artifact. |
| Corroborated | Supported by two or more independent artifacts. |
| Probable | Supported by one artifact plus strong contextual evidence. |
| Hypothesis | Plausible but not yet proven; must include the next validation step. |
| Rejected | Tested and unsupported. |
