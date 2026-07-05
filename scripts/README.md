# scripts/

Standalone utility scripts for day-to-day tasks. All scripts here are on
`$PATH` automatically via `shell/init.zsh`.

## `merge_invoices.py`

Merges paired PDF files that follow this naming convention:

```
20250121 - Amazon Echo Dot.pdf           ← order details
20250121 - Amazon Echo Dot Invoice.pdf   ← invoice
```

### How it works

For each pair sharing a base name (`<name>.pdf` + `<name> Invoice.pdf`), it
appends the invoice pages onto the order-details PDF, overwrites the base
file in place, and moves the separate invoice file to Trash.

### Usage

```bash
# Preview without making changes
python scripts/merge_invoices.py ~/path/to/pdfs --dry-run

# Merge all pairs in a directory
python scripts/merge_invoices.py ~/path/to/pdfs
```

The `mergeinv` shell alias runs this against the current directory for quick
use after opening a folder via `⌘⇧T`.

### Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Preview which pairs would be merged without making any changes |

Requires: `pypdf`, `send2trash` (both installed by `setup.sh`)

## `rename_from_pdf.py`

Renames PDFs by extracting a field (date, money amount, or any custom
regex you define) directly from their content, and using it in the new
filename.

Built for the case where downloaded filenames carry no useful information
(`invoice.pdf`, `invoice (1).pdf`, `invoice (2).pdf`, ...) but the file
itself has everything you'd want in the name.

### How it works

For each PDF, it finds every match for the field(s) you asked for, along
with the text immediately preceding each match (its "label" — e.g. the
`"Invoice Date:"` in front of a date). You're shown the candidates (via
`fzf` if it's on `$PATH`, otherwise a plain numbered prompt) and pick the
right one.

From the second file onward, it tries to auto-resolve each field using
the label you picked last time (fuzzy-matched, not exact — small template
variations between documents are expected). If a confident match is
found, it's applied with no prompt; if the label vanishes or two
candidates look equally plausible, it falls back to asking again and
re-learns from whatever you pick.

Once every field is resolved for a file, the new name is built from
`--template` (e.g. `"{date} - Service ({money} EGP).pdf"`)
and the file is renamed, with automatic `(2)`, `(3)`... suffixes if the
target name is already taken.

### Usage

```bash
# Inspect what would be extracted, without renaming anything
python3 scripts/rename_from_pdf.py ~/Downloads/adobe-invoices --fields date,money

# Preview renames
python3 scripts/rename_from_pdf.py ~/Downloads/adobe-invoices \
  --fields date,money \
  --template "{date} - Service ({money} EGP).pdf" \
  --dry-run

# Rename for real
python3 scripts/rename_from_pdf.py ~/Downloads/adobe-invoices \
  --fields date,money \
  --template "{date} - Service ({money} EGP).pdf"
```

### Options

| Option | Description |
|--------|-------------|
| `--glob PATTERN` | File glob to match (default: `*.pdf`) |
| `--fields LIST` | Comma-separated fields to extract (default: `date`). Built-in: `date`, `money`. Custom: `name=REGEX` (first capture group, or whole match if no group, is used) — e.g. `invno=Invoice\s*#\s*(\d+)` |
| `--template STR` | Filename template, e.g. `"{date} - Adobe ({money} EGP).pdf"`. Omit to just inspect extracted fields without renaming. |
| `--confirm-each` | Always prompt, even when a field could be auto-resolved from a learned label |
| `--dry-run` | Preview renames without making any changes |

### Known limitations

- The `date` field assumes day-first for bare numeric dates like
  `30/01/2024`. If a document renders dates month-first, that pattern
  will misparse — edit `DATE_PATTERNS` in the script if this bites you.
- The label-matching auto-pick works best when the field sits right after
  a distinct piece of label text (`"Invoice Date: 30 January 2024"`).
  For values packed into a table row with no adjacent label (e.g. a
  line-item's `TOTAL` column), the "label" ends up being other numbers
  on the same row, which auto-pick can't reliably match on — expect to
  rely on `--confirm-each` for those fields, or the value's *trailing*
  context if it happens to be consistent invoice-to-invoice.
- Currency isn't auto-detected — extracted money values are bare amounts
  only. If your invoices are always one currency, put it as a literal in
  `--template` rather than trying to extract it.

Requires: `pypdf` (installed by `setup.sh`). `fzf` is optional but
recommended for the picker — falls back to a plain numbered prompt if
not on `$PATH`.
