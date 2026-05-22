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

- **NEVER ask questions during a task.** Run every workflow fully autonomously start-to-finish. No check-ins, no confirmations, no "shall I proceed?". Deliver final findings only. If blocked, pick the most reasonable path and note it in the output.

---

## Forensic Constraints

- **No hallucinations** — Never guess, assume, or fabricate forensic artifacts, file contents, or system states.
- **Deterministic execution** — Use court-vetted CLI tools to generate facts; ground all conclusions in raw tool output.
- **Evidence integrity** — Never modify files in `/cases/`, `/mnt/`, `/media/`, or any `evidence/` directory.
- **Output routing** — Write all scripts, CSVs, JSON, and reports to `./analysis/`, `./exports/`, `./logs/`, or `./reports/`. Never write to `/` or evidence directories.
- **Timestamps** — Always output in UTC.
- **Verification** — Verify tool success after every run. On failure: read stderr → hypothesize → correct → retry.

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

EZ Tools prefer native .NET over WINE. GUI tools (TimelineExplorer, RegistryExplorer) require WINE or the Windows analysis VM.

## Finding Confidence Levels

Every conclusion must be labeled:

- Confirmed: directly supported by raw or parsed forensic artifact.
- Corroborated: supported by two or more independent artifacts.
- Probable: supported by one artifact plus strong contextual evidence.
- Hypothesis: plausible but not yet proven; must include next validation step.
- Rejected: tested and unsupported.

Never present hypotheses as findings.

## Artifact Interpretation Rules

- Prefetch: execution evidence; includes recent run timestamps and referenced files.
- Shimcache/AppCompatCache: file existence evidence on Win8+; do not claim execution from Shimcache alone.
- Amcache: program inventory/execution-related evidence; use SHA1 for pivots.
- BAM/DAM: user-scoped last execution evidence where available.
- SRUM: per-application network and resource usage evidence.
- LNK/Jump Lists: access evidence; may show paths even when targets are deleted.
- Event logs: operational evidence; correlate with process, timeline, and registry artifacts.

## Command Ledger

Maintain `./logs/command_ledger.csv` with:

| UTC Time | Working Directory | Command | Stdout Path | Stderr Path | Exit Code | Notes |
|----------|-------------------|---------|-------------|-------------|-----------|-------|

Every forensic command must have a ledger entry.
- Never overwrite previous outputs.
- Use filenames containing case ID, host, artifact type, and UTC timestamp.
- If rerunning a tool, write to a new file and record why it was rerun.

## SIFT Protocol Execution Standard

### Phase 0 — Workspace and Safety

- Work from the case directory only.
- Create:
  - ./analysis/
  - ./exports/
  - ./reports/
  - ./logs/
- Never write to evidence paths, mounted evidence paths, /cases/, /mnt/, /media/, or evidence/.
- Use UTC for all timestamps.
- Save every command, stdout, stderr, and exit code to ./logs/.

### Phase 1 — Evidence Verification

For every disk image:
- Run ewfinfo.
- Run ewfverify.
- Run img_stat.
- Run mmls.
- Record hashes, sector size, partition offsets, and verification status.

For every memory image:
- Run `file`.
- Run `python3 /opt/volatility3-2.20.0/vol.py -f <image> windows.info`.
- Do not use `/usr/local/bin/vol.py`.
- Confirm symbols are available or use `--offline` to fail fast.

### Phase 2 — Fast Triage

Memory:
- pslist + psscan
- pstree
- cmdline
- getsids
- privs
- netstat + netscan
- svcscan
- malfind

Disk:
- MFT
- UsnJrnl
- Event logs
- Registry hives
- Amcache
- Shimcache
- Prefetch if present
- SRUM
- Scheduled tasks
- LNK and Jump Lists

### Phase 3 — Correlation

For every suspicious artifact:
- Identify source host.
- Identify user/security context.
- Identify timestamp in UTC.
- Identify parent-child or causal relationship.
- Identify supporting artifact.
- Identify contradictory or missing evidence.

### Phase 4 — IOC Sweep

- Build ./analysis/ioc_register.csv.
- Create YARA rules only from confirmed or clearly labeled probable indicators.
- Test rules for false positives before broad sweeps.
- Scan mounted evidence, memory, and extracted files.
- Export hits to ./exports/yara_hits/.

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
- Command ledger location

Each finding must include:
- Confidence: Confirmed / Corroborated / Probable / Hypothesis / Rejected
- Evidence source
- Tool output path
- Timestamp UTC
- Analyst interpretation
