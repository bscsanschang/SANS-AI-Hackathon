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

All forensic commands must be executed through `/home/sansforensics/.claude/scripts/run_logged.sh`.

Commands using pipes, redirection, globbing, shell variables, or heredocs must be wrapped with `bash -o pipefail -lc` so pipeline failures are not hidden.

Raw, unlogged forensic commands are protocol violations.

## Evidence Path Precision

Final reports must use exact paths for evidence, parser output, exported files, logs, and command output.

Do not use:
- `...`
- `./exports/...`
- `./logs/...`
- shortened paths
- placeholder paths

If a path is too long for a table, move the full path to an appendix and reference the appendix row ID.

---

## Claim Validation Rules

Before asserting any conclusion, classify the statement:

### Direct Observation
Artifact explicitly shows the fact.
Examples:
- File exists
- Process executed
- Event ID recorded
- Registry key present

### Supported Inference
Conclusion derived from one or more artifacts using accepted DFIR reasoning.
Must include:
- why the inference is reasonable
- what evidence supports it
- what alternative explanations exist

### Speculative Inference
Plausible but unproven interpretation.
Must:
- be labeled Hypothesis
- include validation steps
- never appear in Executive Summary as fact

---
## Escalation
Never escalate:

- artifact -> attribution
- artifact -> intent
- artifact -> compromise
- artifact -> attacker capability
- artifact -> exfiltration
- artifact -> credential theft
- artifact -> pass-the-hash
- artifact -> persistence
- artifact -> insider threat
- authentication event -> host compromise
- staged file -> confirmed outbound transfer
- AV detection -> independently confirmed malware family
- script block content -> confirmed successful payload execution

without explicit supporting evidence.

## Alternative Explanation Requirement

For every major finding:

- Identify at least one alternative explanation.
- Explain why the preferred interpretation is stronger.
- State what evidence would disprove the current hypothesis.

## Evidence Weighting

High-weight evidence:
- process creation logs
- PowerShell transcripts
- memory artifacts
- recovered malware
- registry persistence artifacts

Medium-weight evidence:
- Prefetch
- Amcache
- SRUM
- Jump Lists

Low-weight evidence:
- Shimcache alone
- filename matches
- orphaned LNKs
- single IOC hit

## Restricted Conclusions

Do not use these terms unless evidence threshold is met:

"Compromised host"
Requires:
- malware
- credential theft
- persistence
- attacker execution
OR
multiple corroborating attacker artifacts

"Pass-the-hash"
Requires:
- NTLM auth pattern
PLUS
supporting lateral movement or credential-theft evidence

"Exfiltration confirmed"
Requires:
- outbound transfer evidence
OR
remote possession evidence

"Attacker"
Use "operator" or "activity" unless malicious intent is established.

## Contradictory Evidence Handling

For every finding:
- identify supporting evidence
- identify missing evidence
- identify contradictory evidence if present

Absence of expected artifacts must be noted.

Do not suppress contradictory artifacts to preserve narrative consistency.

## Mandatory Unknowns Section

Every report must include:
- what is known
- what is unknown
- what cannot be determined from available evidence
- what evidence would resolve uncertainty

## Narrative Discipline

Do not optimize for narrative coherence.

Independent artifacts may:
- conflict
- be incomplete
- reflect unrelated activity

Prefer fragmented truth over coherent but unsupported attack stories.

## Reporting Language Standards

Use:
- "consistent with"
- "suggests"
- "supported by"
- "corroborated by"
- "cannot exclude"

Avoid:
- "proves" unless directly observed
- "definitely"
- "clearly"
- "obviously"
- "must have"

## Confidence Downgrade Conditions

Downgrade confidence when:
- evidence is indirect
- only one artifact supports a claim
- artifacts are user-generated
- timestamps conflict
- interpretation depends on assumptions
- alternative explanations remain plausible

## Finding Completeness Checklist

Before finalizing a finding, verify:
- who
- what
- when
- where
- how
- supporting artifact
- corroborating artifact
- alternative explanation
- limitation
- confidence level

## Sensitive Data Handling

Do not reproduce plaintext passwords, API keys, private keys, tokens, or full secrets in the final report unless explicitly required.

Use redaction by default:

- show username or account name,
- show file path,
- show hash of the credential file,
- show only partial secret if necessary, e.g. first 2 and last 2 characters,
- store full secret values only in a restricted appendix or export file.

## Claim Support Matrix
Final report must include a Claim Support Matrix for all major findings.

| Finding ID | Claim | Claim Type | Confidence | Supporting Evidence | Tool Output Path | Alternative Explanation | Limitation |
|-----------|-------|------------|------------|---------------------|------------------|--------------------------|------------|

Claim Type must be one of:

- Direct Observation
- Supported Inference
- Speculative Inference

## Mount Tracking

Maintain `./analysis/mounts.csv` with:

| Evidence ID | EWF Mount Path | Filesystem Mount Path | Offset | Mount Options | Mounted UTC | Unmounted UTC | Status |
|-------------|----------------|-----------------------|--------|---------------|-------------|---------------|--------|

Rules:
- Mount read-only.
- Record every mount and unmount.
- Verify mounted paths are read-only.
- Unmount evidence before final report when analysis is complete.
- If unmount fails, document the reason and the command output.

## Final Artifact Manifest

Before reporting, create `./reports/artifact_manifest.csv` with:

| Path | Type | Size Bytes | SHA256 | Created UTC | Purpose |
|------|------|------------|--------|-------------|---------|

Include reports, parsed CSVs, IOC registers, timelines, scripts, and command logs.

## AV Detection Interpretation

An antivirus log is direct evidence that the AV product detected, classified, quarantined, or deleted an object.

It is not by itself direct proof of malware family or execution.

Use:
- "McAfee detected X as Y"
- "AV-classified trojan"
- "probable malware based on repeated AV detections and context"

Avoid:
- "confirmed trojan"
- "confirmed malware family"

unless the file was recovered and independently analyzed.

## PowerShell Script Block Interpretation

PowerShell EID 4104 is direct evidence that script block content was logged.

Do not claim payload success, beacon check-in, or second-stage execution unless corroborated by:
- process creation,
- network telemetry,
- memory evidence,
- module/pipeline execution artifacts,
- recovered payload output,
- or other independent artifacts.

## Hash Column Data Integrity

Any table column labeled MD5, SHA1, SHA-1, SHA256, or SHA-256 must contain only:

- a valid hash of the correct length and character set,
- `NOT_COMPUTED`,
- `NOT_AVAILABLE`,
- `DELETED_NOT_RECOVERED`,
- or `SEE_APPENDIX`.

Never place comments, descriptions, interpretations, or evidence notes in a hash column.

If explanatory text is needed, create a separate `Notes` column.

If multiple files are listed, each file must receive its own row. Do not combine multiple files into one row when any hash column is present.

If a hash is visually shortened for readability, the column header must say `SHA-256 (truncated)`, and the report must point to the full hash source, such as `./analysis/ioc_register.csv` or an appendix.

## On-Disk Component Table Requirements

For every on-disk component table, use this schema:

| File Path | Size Bytes | MD5 | SHA-256 | Evidence Source | Notes |
|----------|------------|-----|---------|-----------------|-------|

Rules:

- one file per row,
- full path preferred,
- full SHA-256 preferred,
- comments go only in `Notes`,
- deleted AV-only files must be listed separately from residual on-disk files,
- if a file was deleted and not recovered, do not invent SHA-256.

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
- Source `/home/sansforensics//.claude/scripts/run_logged.sh` before running forensic commands.

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

Create `./analysis/evidence_inventory.csv` with:

| Evidence ID | Source Path | Evidence Type | Size Bytes | MD5 | SHA1/SHA256 if available | Verification Status | Notes |
|-------------|-------------|---------------|------------|-----|--------------------------|---------------------|-------|

Every finding must reference an Evidence ID.

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

### Phase 5 — Claim and Hallucination Check

Before the final report:

1. Break every major finding into atomic claims.
2. For each claim, classify it as:
   - Direct Observation
   - Supported Inference
   - Speculative Inference
3. Confirm every claim has:
   - supporting evidence,
   - tool output path,
   - confidence level,
   - limitation or caveat.
4. Remove or rewrite any claim that is unsupported.
5. Downgrade any claim that is only partially supported.
6. Label unresolved but plausible claims as Hypothesis and include the next validation step.
7. Do not include unsupported claims in the Executive Summary.
8. Do not convert absence of evidence into evidence of absence unless the searched scope is documented.

Final reporting may include Confirmed, Corroborated, Probable, Hypothesis, and Rejected findings, but each must be clearly labeled.

---

### Phase 6 — Command Ledger Audit

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
6. Use `/home/sansforensics/.claude/scripts/audit_command_ledger.py` to audit `./logs/command_ledger.csv`

---

### Phase 7 — Reporting

Use `/home/sansforensics/.claude/scripts/generate_pdf_report.py` to generate the final PDF report

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

Never mention 'find evil' in the report, instead call 'Digital forensic analysis of {evidence file}

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
- The PDF has no visual mistakes such as:
    - Tables broken between pages
    - Tables or text being written outside the margin
    - The PDF does not pass `./.claude/scripts/pdf_visual_check.py`

If the final report is deemed to be invalid, fix what is invalid.

The final Markdown report and any generated PDF report must include this section at the bottom:

## Confidence Level Definitions

| Confidence | Definition |
|-----------|------------|
| Confirmed | Directly supported by raw or parsed forensic artifact. |
| Corroborated | Supported by two or more independent artifacts. |
| Probable | Supported by one artifact plus strong contextual evidence. |
| Hypothesis | Plausible but not yet proven; must include the next validation step. |
| Rejected | Tested and unsupported. |
