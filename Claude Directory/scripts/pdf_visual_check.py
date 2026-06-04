#!/usr/bin/env python3
import argparse
import sys
from pathlib import Path

parser = argparse.ArgumentParser(description="Basic PDF visual sanity check using PyMuPDF when available.")
parser.add_argument("pdf", help="PDF file to inspect")
parser.add_argument("--margin", type=float, default=2.0, help="Allowed point overflow margin")
parser.add_argument("--min-font", type=float, default=5.5, help="Minimum readable font size threshold")
args = parser.parse_args()

pdf_path = Path(args.pdf)
if not pdf_path.exists() or pdf_path.stat().st_size == 0:
    print(f"ERROR: PDF missing or empty: {pdf_path}")
    sys.exit(1)

try:
    import fitz
except Exception as exc:
    print(f"ERROR: PyMuPDF is not available: {exc}")
    print("Install PyMuPDF or perform a manual rendered-page review before finalizing.")
    sys.exit(1)

errors = []
try:
    doc = fitz.open(pdf_path)
except Exception as exc:
    print(f"ERROR: could not open PDF: {exc}")
    sys.exit(1)

for page_index, page in enumerate(doc, start=1):
    rect = page.rect
    text = page.get_text("dict")
    for block in text.get("blocks", []):
        bbox = block.get("bbox")
        if bbox:
            x0, y0, x1, y1 = bbox
            if x0 < rect.x0 - args.margin or y0 < rect.y0 - args.margin or x1 > rect.x1 + args.margin or y1 > rect.y1 + args.margin:
                errors.append(f"Page {page_index}: text block outside page bounds: {bbox}")
        for line in block.get("lines", []):
            for span in line.get("spans", []):
                size = span.get("size", 0)
                if size and size < args.min_font:
                    sample = span.get("text", "")[:80].replace("\n", " ")
                    errors.append(f"Page {page_index}: tiny font {size:.2f} pt near text: {sample!r}")

if errors:
    print("ERROR: PDF visual sanity check failed")
    for error in errors[:200]:
        print(error)
    if len(errors) > 200:
        print(f"... {len(errors) - 200} additional errors omitted")
    sys.exit(1)

print(f"PDF visual sanity check passed: {pdf_path} ({len(doc)} pages)")
