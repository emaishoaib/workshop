---
name: capture
description: "Multi-step knowledge logging workflow. Triggered when the user says 'capture'. Extracts highlights from the conversation, routes each one to the topic file in ~/docs/notes it belongs to, reviews each entry for approval, then merges it into that file. Work knowledge goes into topic-based reference files as prose; general programming knowledge goes to software_engineering.md as Q&A; behavioral moments go to behavioral.md."
---

# Capture Skill

A multi-step knowledge logging workflow triggered by the word `capture` in conversation. Knowledge is merged into a small set of topic-based reference files in `~/docs/notes/`. Each file covers one business concept, workflow, service or engineering area. `README.md` in that folder lists them.

This applies the same way regardless of where the material comes from: a live technical discussion, or pasted or external content (old notes, a batch of Q&As someone wants logged). A source that already looks "finished" is not a shortcut past the review gates in Steps 1–2. Draft, present, get approval, then write. Never write first and revise after just because the content arrived pre-formed.

## The destination files

Before routing anything, read `~/docs/notes/README.md` and the headings of the candidate files. The folder holds:

| File | Owns |
|---|---|
| `business_overview.md` | The company, brands, markets, sites, teams and people, who decides what, how WHT works (sprints, rota, Jira, code chill) |
| `glossary.md` | Terms, acronyms, aliases. One line each, pointing to the owning file |
| `order_to_delivery.md` | The chain of dates from order to delivery, billing and locking, release deadlines, order and dispatch calendars, Admin delivery states |
| `subscriptions.md` | Subs vs gifting, the actuals pipeline, the Papyrus load balancer (business role), ordering to forecast, subs-to-forecast |
| `forecasting_and_buying.md` | Forecasts, buying dues (business view), BMS stem ordering, intake, MOQ/EOQ, up/down, B2B extras |
| `production_planning.md` | How COP plans production: rules as practised, product groups and BAS, capacity, smoothing (concept), stock objects |
| `diversions_and_peaks.md` | Peak calendar, diversions, the four system changes, worked examples |
| `products_and_packaging.md` | Product identifiers, BAS meaning, wrap vs craft, cart allocation, box sizes (concept), greeting cards, combinability |
| `warehouse_floor.md` | Production runs, carts, scans, cold store, packing, print room, freshness, inventory vs stock |
| `systems_map.md` | Every system and how they connect, Airflow DAGs and the data hub, and the smaller services (Admin, BMS, Mosaic, pcode, Abacus, Cardshark, ...) |
| `papyrus.md`, `pandora.md`, `spidercode.md` | Each service in depth |
| `coding_patterns_and_practices.md` | How code is written here, good and bad, git and PR norms, anti-patterns |
| `infrastructure_and_deployment.md` | GCP, Terraform, IAM, secrets, build and deploy pipeline, environments, disaster recovery |
| `local_development.md` | Running and testing services on a Mac, troubleshooting local errors |
| `operations_runbook.md` | Step-by-step procedures against staging and prod |
| `security.md` | Access control, IAM hygiene, Wiz, GitHub protection, dependency security |
| `software_engineering.md` | General programming knowledge that is not specific to work, as Q&A |
| `behavioral.md` | Behavioral moments mapped to Amazon Leadership Principles |

If a topic file starts to cover something none of these own, propose a new topic file in Step 1 and wait for approval. Do not create one silently.

## Step 1 — Extract highlights and route

Scan the full conversation chronologically from the beginning, not from the end. Recency bias is a common failure mode. Earlier decisions often carry more knowledge density than later iterative work. A long sequence of small iterative changes ("make it wider", "apply", "a bit more") should carry far less weight than one message where an architectural or technical decision was made and reasoned through.

For each of these categories, ask whether anything meaningful happened:
- Architectural and design decisions
- Debugging, errors and fixes
- Tool and library configuration gotchas
- CLI and command patterns
- Workflow and process patterns
- Technical concepts introduced or clarified
- Business and domain concepts introduced or clarified
- Incidents and pieces of work worth remembering

Identify the reusable knowledge: things learned, decided, clarified or discovered. Don't summarise the task itself.

Route each highlight with these rules:

- **Work knowledge** goes to the topic file that owns the topic. Pick the target section inside it too. When two files touch a topic, the owner gets the full fact and the other gets at most a sentence and a link. The ownership table above decides.
- **A team convention or coding pattern**, good or bad, goes to `coding_patterns_and_practices.md`. A convention that only applies to one service goes to that service's file, in its conventions or codebase section.
- **A procedure** goes to `operations_runbook.md` when it runs against staging or prod. It goes to `local_development.md` when it runs on a laptop.
- **Troubleshooting** goes to the troubleshooting section of the same file the procedure would go to.
- **A specific piece of work or incident** becomes an entry in the `## History and incidents` section of the topic file it is about. There is no separate stories file. The entry carries the lesson. If it changes how something works, update the reference text above it too.
- **General programming knowledge** that would apply equally at another company goes to `software_engineering.md`.
- **A new term** gets a one-line entry in `glossary.md` pointing to the owning file. Add it alongside the main entry.

### Check against existing content before presenting

Before a drafted entry goes into the list, open the target section and check what it already says. Re-capturing a fact already in the file is the likely failure mode, not the exception.

- **Already there:** drop the draft, or fold any genuinely new detail into the existing text.
- **Overlapping:** propose an edit to the existing text instead of a second passage, and say so in the list.
- **Contradicts what's there** (a number, a name, a claim): do not silently resolve it either way. Show both versions side by side and let me decide. If neither can be confirmed, the contradiction goes under the file's `## Open questions`.
- **Supersedes what's there** (the design changed): propose replacing the old text. Move the old state into History only if it's worth remembering.

Present the list grouped by destination file and section, and wait for approval. I may trim, edit or reroute entries. If I request changes, re-present the full updated list, not just what changed.

## Step 2 — Review entry by entry

Once the highlights are approved, go through them one at a time. For each, present:
1. **The file and section** it goes into.
2. **The exact change**: the new or edited text, with a few lines of the surrounding existing text so I can see where it lands. For an edit, show before and after.

Wait for approval on each entry before moving to the next. I may edit the content or the destination. If I request changes, apply them and re-present that entry, not the whole list.

Once every entry is approved, summarise the full mapping (entry → file → section) and wait for a final go-ahead before writing anything.

## Step 3 — Write

Write exactly what was approved. No surprises.

### Topic files (everything except software_engineering.md and behavioral.md)

These are reference documents, not logs. Merge new knowledge into the right section as prose that matches the file. Do not append it at the bottom.

- Keep the file's existing structure. Add a `###` subsection only when the section has a genuinely new distinct part.
- Write in the file's style:
  - one idea per sentence
  - lists for parts, tables when items share attributes
  - concrete names of repos, tables, endpoints, commands and numbers
  - code blocks for commands
- Explain a new term the first time, or link `glossary.md`.
- Mark facts likely to change with "(as of Mon YYYY)".
- Prefer updating a sentence that went stale to adding a correcting sentence next to it.
- **History entries** use `### YYYY-MM — short title`. They are chronological, and each covers what happened, the cause and the lesson in 2 to 6 sentences.
- **Procedures** in the runbook and local-dev files follow the file's layout: when to use it, prerequisites, steps, how to verify, gotchas.
- **Open questions** state the competing versions plainly.
- **Links** to external pages (Confluence, Sheets, Jira, PRs) go in the file's `## Links` section.
- Never copy secrets, tokens, passwords, customer or order IDs, or personal email addresses.

### `software_engineering.md` — Q&A format, `### heading` style

Use the existing sections. If none fits, suggest a new `##` section and get approval before creating it.

Write each entry as a `### Question` heading followed by prose. The answer is a few paragraphs at most, with code snippets where they help. Write it as a personal reference note, not documentation. Inline relevant links within the prose.

Questions must pass the amnesia test: could someone who has never seen this conversation, codebase or system understand what the question asks? Name the concept, library or tool explicitly. "Why does this fail?" fails. "Why does FastAPI silently swallow dependency errors raised as HTTPExceptions?" passes. Prefer reasoning questions ("why does X behave this way") over recall questions. Frame them as a problem the reader would face where possible.

---

After writing, show the added or updated content with a few lines of surrounding context. Do not show the full file.

## Step 4 — Behavioral extraction

Scan the conversation for behavioral moments: pushback, disagreement, committing to a decision, updating a view, handling conflict, earning trust.

For each moment, propose:
- the Amazon Leadership Principle(s) it maps to
- a subsection name
- the date it occurred
- the company context
- a draft note with the flavor specific to that principle

Present the full proposal and wait for approval before writing to `~/docs/notes/behavioral.md`.

If no behavioral moments are present, skip this step silently.

Then go over each approved moment. Show the exact text that will be written to `behavioral.md`, including surrounding context, and wait for explicit approval before writing anything.
