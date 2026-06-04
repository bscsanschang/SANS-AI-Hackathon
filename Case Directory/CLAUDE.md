# CLAUDE.md

This file provides case-specific guidance for Claude Code when working in this case directory.

## Case Overview

| Field | Value |
|------|-------|
| Case ID | CASE-002 |
| Case Name | Test3 |
| Case Type | Unknown / blind DFIR triage |
| Client / Organization | Not provided |
| Incident Declared | Not provided |
| Analyst Role | External DFIR analyst |
| Timezone for Reporting | UTC |
| Evidence Mode | Strict read-only |

---

## Case Scope

The provided evidence consists of forensic disk image files only.

No incident narrative, known attacker, known malware family, known compromised host, known IOCs, or answer key has been provided.

The analyst must not infer incident facts from the filename, directory name, course context, or assumptions. All findings must be derived from forensic artifacts generated during analysis.

---

## Evidence Files

| Evidence ID | File Path | Type | Suspected System | Notes |
|------------|----------|------|------------------|-------|
| EVID-001 | `/cases/<case_name>/base-wkstn-01-c-drive.E01` | E01 disk image | Unknown until verified | Read-only evidence |

# Add more rows as needed:

#| Evidence ID | File Path | Type | Suspected System | Notes |
#|------------|----------|------|------------------|-------|
#| EVID-002 | `/cases/<case_name>/<second_image>.E01` | E01 disk image | Unknown until verified | Read-only evidence |

---

## Evidence Handling

- Do not modify evidence files.
- Do not write into `/cases/`, `/media/`, evidence source directories, or mounted evidence filesystems.
- Creating empty mount-point directories under `/mnt/` is allowed only when required for read-only mounting.
- Mount disk images read-only.
- Output all generated files only to:
  - `./analysis/`
  - `./exports/`
  - `./logs/`
  - `./reports/`
- Use UTC for all timestamps.

---

## Required Output Directories

Create these before analysis if they do not exist:

```bash
mkdir -p ./analysis ./exports ./logs ./reports
