#!/usr/bin/env python3
import argparse
import json
import sys
from pathlib import Path

parser = argparse.ArgumentParser(description="Validate DFIR finding_register.jsonl records.")
parser.add_argument("--require-findings", action="store_true", help="Exit nonzero if no findings are present.")
parser.add_argument("path", nargs="?", default="./analysis/finding_register.jsonl")
args = parser.parse_args()

path = Path(args.path)
if not path.exists():
    print(f"ERROR: missing finding register: {path}")
    sys.exit(1)

required = [
    "finding_id",
    "claim",
    "claim_type",
    "confidence",
    "evidence_ids",
    "artifact_refs",
    "tool_output_paths",
    "supporting_evidence",
    "contradictory_evidence",
    "missing_evidence",
    "alternative_explanations",
    "disproof_conditions",
    "limitations",
    "report_ready",
]

valid_claim_types = {"Direct Observation", "Supported Inference", "Speculative Inference"}
valid_confidence = {"Confirmed", "Corroborated", "Probable", "Hypothesis", "Rejected"}

errors = []
count = 0

with path.open(encoding="utf-8") as f:
    for line_no, line in enumerate(f, start=1):
        line = line.strip()
        if not line:
            continue
        count += 1
        try:
            record = json.loads(line)
        except Exception as exc:
            errors.append(f"Line {line_no}: invalid JSON: {exc}")
            continue
        for field in required:
            if field not in record:
                errors.append(f"Line {line_no}: missing field {field}")
        if record.get("claim_type") not in valid_claim_types:
            errors.append(f"Line {line_no}: invalid claim_type {record.get('claim_type')!r}")
        if record.get("confidence") not in valid_confidence:
            errors.append(f"Line {line_no}: invalid confidence {record.get('confidence')!r}")
        for list_field in [
            "evidence_ids",
            "artifact_refs",
            "tool_output_paths",
            "supporting_evidence",
            "alternative_explanations",
            "limitations",
        ]:
            if list_field in record and not record.get(list_field):
                errors.append(f"Line {line_no}: {list_field} is empty")

if args.require_findings and count == 0:
    errors.append("No findings present and --require-findings was set")

if errors:
    print("ERROR: claim validation failed")
    for error in errors:
        print(error)
    sys.exit(1)

print(f"Claim validation passed. Findings checked: {count}")
