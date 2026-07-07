#!/usr/bin/env python3
"""
rename_from_pdf.py

Rename PDFs by extracting a field (date, money amount, or any custom
regex) directly from their content and using it in the new filename.

Built for cases where downloaded filenames carry no useful information
(invoice.pdf, invoice (1).pdf, invoice (2).pdf, ...) but the file itself
has everything you'd want in the name.

Usage:
  rename_from_pdf.py <directory> --template "{date} - Service ({money}).pdf"
  rename_from_pdf.py <directory> --fields date --template "{date} - Statement.pdf"
  rename_from_pdf.py <directory> --dry-run ...

Options:
  --glob PATTERN     File glob to match (default: *.pdf)
  --fields LIST      Comma-separated fields to extract (default: date)
                      Built-in: date, money
                      Custom:   name=REGEX  (e.g. invno=Invoice\\s*#\\s*(\\d+))
  --template STR     Filename template, e.g. "{date} - Adobe ({money} EGP).pdf"
                      (omit to just inspect extracted fields, no renaming)
  --confirm-each     Always prompt, even if a field was auto-resolved
  --dry-run          Preview renames without making any changes
"""

import argparse
import difflib
import re
import shutil
import subprocess
from pathlib import Path

from pypdf import PdfReader

MONTHS = {
    "jan": 1, "january": 1, "feb": 2, "february": 2, "mar": 3, "march": 3,
    "apr": 4, "april": 4, "may": 5, "jun": 6, "june": 6, "jul": 7, "july": 7,
    "aug": 8, "august": 8, "sep": 9, "sept": 9, "september": 9, "oct": 10,
    "october": 10, "nov": 11, "november": 11, "dec": 12, "december": 12,
}

LABEL_MATCH_THRESHOLD = 0.72

DATE_PATTERNS = [
    # 2024-01-30 or 2024/01/30 or 2024.01.30
    (re.compile(r"\b(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})\b"),
     lambda m: (int(m.group(1)), int(m.group(2)), int(m.group(3)))),
    # 30 January 2024 / 30 Jan 2024 / 30-Jan-2024
    (re.compile(r"\b(\d{1,2})[\s\-]+([A-Za-z]{3,9})[\s\-,]+(\d{4})\b"),
     lambda m: (int(m.group(3)), MONTHS.get(m.group(2).lower()), int(m.group(1)))),
    # January 30, 2024 / Jan 30 2024
    (re.compile(r"\b([A-Za-z]{3,9})\s+(\d{1,2}),?\s+(\d{4})\b"),
     lambda m: (int(m.group(3)), MONTHS.get(m.group(1).lower()), int(m.group(2)))),
    # 30/01/2024 -- day-first assumed; revisit if your invoices are month-first
    (re.compile(r"\b(\d{1,2})/(\d{1,2})/(\d{4})\b"),
     lambda m: (int(m.group(3)), int(m.group(2)), int(m.group(1)))),
    # 30.01.2024 -- day-first assumed
    (re.compile(r"\b(\d{1,2})\.(\d{1,2})\.(\d{4})\b"),
     lambda m: (int(m.group(3)), int(m.group(2)), int(m.group(1)))),
]

MONEY_PATTERN = re.compile(r"\d{1,3}(?:,\d{3})*\.\d{2}(?!\s*%)")


class FieldMatch:
    def __init__(self, field, raw, formatted, start, end, label):
        self.field = field
        self.raw = raw              # exact substring matched in the PDF text
        self.formatted = formatted  # normalized value used in the filename
        self.start = start
        self.end = end
        self.label = label          # short bit of text just before the match


def _make_label(text, start, lead_chars=48):
    lead = text[max(0, start - lead_chars):start]
    lead = re.sub(r"\s+", " ", lead).strip()
    for sep in (":", "\u2013", "-", "|", "\n"):
        if sep in lead:
            lead = lead.rsplit(sep, 1)[-1].strip() or lead
    return lead[-40:].strip()


def _context_line(fm, text, trail_chars=24):
    trailing = re.sub(r"\s+", " ", text[fm.end:fm.end + trail_chars]).strip()
    return f'"{fm.label}" -> {fm.raw} {trailing}'.strip()


def _valid_date(y, mo, d):
    return bool(mo) and 1 <= mo <= 12 and 1 <= d <= 31 and 1990 <= y <= 2100


def extract_dates(text):
    matches = []
    seen_spans = []
    for pattern, parse in DATE_PATTERNS:
        for m in pattern.finditer(text):
            span = m.span()
            if any(s < span[1] and span[0] < e for s, e in seen_spans):
                continue  # already claimed by an earlier pattern
            try:
                y, mo, d = parse(m)
            except Exception:
                continue
            if not _valid_date(y, mo, d):
                continue
            seen_spans.append(span)
            formatted = f"{y:04d}{mo:02d}{d:02d}"
            label = _make_label(text, span[0])
            matches.append(FieldMatch("date", m.group(0), formatted, span[0], span[1], label))
    matches.sort(key=lambda fm: fm.start)
    return matches


def extract_money(text):
    matches = []
    for m in MONEY_PATTERN.finditer(text):
        label = _make_label(text, m.start())
        matches.append(FieldMatch("money", m.group(0), m.group(0), m.start(), m.end(), label))
    matches.sort(key=lambda fm: fm.start)
    return matches


def extract_field(field_name, text):
    if field_name == "date":
        return extract_dates(text)
    if field_name == "money":
        return extract_money(text)
    raise ValueError(f"unknown field type: {field_name}")


def read_pdf_text(path):
    reader = PdfReader(str(path))
    return "\n".join((page.extract_text() or "") for page in reader.pages)


def pick_with_fzf(field_name, candidates, text, filename):
    lines = [f"{i}\t{fm.formatted}\t{_context_line(fm, text)}" for i, fm in enumerate(candidates)]
    proc = subprocess.run(
        ["fzf", "--with-nth=2..", "--delimiter=\t",
         "--prompt", f"{field_name} in {filename} > ",
         "--header", f"pick the {field_name} to use (esc to skip this file)"],
        input="\n".join(lines), capture_output=True, text=True,
    )
    if proc.returncode != 0 or not proc.stdout.strip():
        return None
    idx = int(proc.stdout.split("\t", 1)[0])
    return candidates[idx]


def pick_with_prompt(field_name, candidates, text, filename):
    print(f"\n  {field_name} candidates in {filename}:")
    for i, fm in enumerate(candidates):
        print(f"    {i + 1}) {fm.formatted:<12} {_context_line(fm, text)}")
    while True:
        choice = input(f"  Pick {field_name} [1-{len(candidates)}, s=skip]: ").strip().lower()
        if choice == "s":
            return None
        if choice.isdigit() and 1 <= int(choice) <= len(candidates):
            return candidates[int(choice) - 1]
        print("  Not a valid choice, try again.")


def pick_candidate(field_name, candidates, text, filename):
    if shutil.which("fzf"):
        return pick_with_fzf(field_name, candidates, text, filename)
    return pick_with_prompt(field_name, candidates, text, filename)


def find_by_label(candidates, learned_label):
    """Try to auto-resolve a field using a previously learned label."""
    if not candidates:
        return None
    scored = [
        (difflib.SequenceMatcher(None, fm.label.lower(), learned_label.lower()).ratio(), fm)
        for fm in candidates
    ]
    scored.sort(key=lambda t: t[0], reverse=True)
    best_ratio, best = scored[0]
    if best_ratio < LABEL_MATCH_THRESHOLD:
        return None
    if len(scored) > 1 and (best_ratio - scored[1][0]) < 0.08:
        return None  # too close to call -- don't guess, ask instead
    return best


def resolve_field(field_name, candidates, text, filename, learned, confirm_each):
    if not candidates:
        print(f"  no {field_name} candidates found -- skipping")
        return None

    if not confirm_each and field_name in learned:
        auto = find_by_label(candidates, learned[field_name])
        if auto is not None:
            print(f"  auto-picked {field_name}: {auto.formatted}   ({_context_line(auto, text)})")
            return auto

    chosen = pick_candidate(field_name, candidates, text, filename)
    if chosen is None:
        return None
    learned[field_name] = chosen.label
    return chosen


def unique_target(target):
    if not target.exists():
        return target
    stem, suffix = target.stem, target.suffix
    i = 2
    while True:
        candidate = target.with_name(f"{stem} ({i}){suffix}")
        if not candidate.exists():
            return candidate
        i += 1


def main():
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("directory")
    parser.add_argument("--glob", default="*.pdf")
    parser.add_argument("--fields", default="date")
    parser.add_argument("--template")
    parser.add_argument("--confirm-each", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    directory = Path(args.directory).expanduser().resolve()
    if not directory.is_dir():
        print(f"Error: '{directory}' is not a directory.")
        return

    field_names = [f.strip() for f in args.fields.split(",") if f.strip()]

    files = sorted(directory.glob(args.glob))
    if not files:
        print(f"No files matching {args.glob} in {directory}.")
        return

    learned = {}
    renamed, skipped = 0, 0
    for path in files:
        text = read_pdf_text(path)
        print(f"\n{path.name}")

        values = {}
        for field_name in field_names:
            candidates = extract_field(field_name, text)
            chosen = resolve_field(field_name, candidates, text, path.name, learned, args.confirm_each)
            if chosen is None:
                values = None
                break
            values[field_name] = chosen.formatted

        if values is None:
            print("  skipped")
            skipped += 1
            continue

        if not args.template:
            print(f"  fields: {values}")
            continue

        try:
            new_name = args.template.format(**values)
        except KeyError as e:
            print(f"  ! template references unknown field {e} -- check --fields matches --template")
            skipped += 1
            continue

        target = unique_target(directory / new_name)
        print(f"  -> {target.name}")
        if not args.dry_run:
            path.rename(target)
            print("  done")
        renamed += 1

    if args.template:
        verb = "would rename" if args.dry_run else "renamed"
        print(f"\n{verb} {renamed} file(s), skipped {skipped}.")


if __name__ == "__main__":
    main()