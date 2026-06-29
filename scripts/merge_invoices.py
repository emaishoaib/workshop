#!/usr/bin/env python3
"""
merge_invoices.py

Scan a directory for paired PDF files:
  - Base:    <name>.pdf
  - Invoice: <name> Invoice.pdf

Merges each pair (base pages first, invoice pages appended),
overwrites the base file in place, and deletes the Invoice file.

Usage:
  python merge_invoices.py <directory> [--dry-run]

Options:
  --dry-run   Preview which pairs would be merged without making any changes.
"""

import sys
from pathlib import Path


def find_pairs(directory: Path) -> list[tuple[Path, Path]]:
    """Return list of (base_pdf, invoice_pdf) tuples."""
    pdfs = {p.stem: p for p in directory.glob("*.pdf")}
    pairs = []
    for stem, base_path in sorted(pdfs.items()):
        if stem.endswith(" Invoice"):
            continue
        invoice_stem = f"{stem} Invoice"
        if invoice_stem in pdfs:
            pairs.append((base_path, pdfs[invoice_stem]))
    return pairs


def merge_pair(base: Path, invoice: Path) -> None:
    try:
        from pypdf import PdfWriter, PdfReader
    except ImportError:
        print("pypdf not installed. Run: pip install pypdf")
        sys.exit(1)

    try:
        from send2trash import send2trash
    except ImportError:
        print("send2trash not installed. Run: pip install send2trash")
        sys.exit(1)

    writer = PdfWriter()
    for path in (base, invoice):
        reader = PdfReader(str(path))
        for page in reader.pages:
            writer.add_page(page)

    with open(base, "wb") as f:
        writer.write(f)

    send2trash(str(invoice))


def main():
    args = sys.argv[1:]
    dry_run = "--dry-run" in args
    paths = [a for a in args if not a.startswith("--")]

    if not paths:
        print(__doc__)
        sys.exit(1)

    directory = Path(paths[0]).expanduser().resolve()
    if not directory.is_dir():
        print(f"Error: '{directory}' is not a directory.")
        sys.exit(1)

    pairs = find_pairs(directory)
    if not pairs:
        print("No matched pairs found.")
        return

    label = "[DRY RUN] " if dry_run else ""
    print(f"{label}Found {len(pairs)} pair(s) in {directory}:\n")

    for base, invoice in pairs:
        print(f"  {base.name}")
        print(f"  + {invoice.name}")
        print(f"  → {base.name} (merged, invoice deleted)")
        if not dry_run:
            merge_pair(base, invoice)
            print(f"  ✓ Done")
        print()

    print("Done." if not dry_run else "Dry run complete — no files were changed.")


if __name__ == "__main__":
    main()
