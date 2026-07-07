---
name: capture
description: "Multi-step knowledge logging workflow. Triggered when the user says 'capture'. Extracts highlights from the conversation, routes each one to the appropriate notes file by type, reviews each entry for approval, then writes them. Different files use different formats — Q&A for general knowledge and runbook entries, narrative prose for stories, short dated prose for team conventions."
---

# Capture Skill

A multi-step knowledge logging workflow triggered by the word `capture` in conversation. Entries are written in different formats depending on their destination — Q&A for general knowledge and runbook entries, narrative prose for stories, short dated prose for team conventions.

## On question quality

Q&A framing applies to entries going to `software_engineering.md`, `work_business.md`, and `work_runbook.md`. For these, two types of questions, in order of preference:

- **Reasoning questions** — test whether you understand *why*. Frame these to
  reflect how the understanding was actually reached in the conversation,
  modelled on the real exchange. "Why does X behave this way?" is better than
  "What is X?".
- **Recall questions** — test whether you remember something concrete. Fine for
  commands, flags, syntax. "What flag do you use to X?" is a valid recall
  question. Recall questions apply to `software_engineering.md` and
  `work_runbook.md` only — `work_business.md` entries are always reasoning
  questions.

Prefer reasoning questions. When a reasoning question exists, don't also write
a recall question for the same concept — the reasoning answer will contain the
concrete detail anyway.

A single concept may produce multiple Q&A pairs. When it does, order them
deliberately — start with the question that establishes *why* or *what problem
this solves*, then move to deeper reasoning, then to concrete application. The
sequence should mirror how someone would build understanding from scratch, not
the order things happened to come up in conversation.

### The amnesia test — apply at draft time, not at write time

Every question must pass this test before it is presented in Step 1:

> Could someone who has never seen this conversation, this codebase, or this
> system understand what the question is asking?

This means the question must name the concept, library, system, or tool
explicitly — never assume it from context. Questions that reference "this
function", "our approach", "the backend", or any pronoun that only makes sense
inside the conversation fail immediately.

**Fails:**
- "Why does `rule_priority_between` handle the case where the frontend shows a subset?"
- "What happens when left equals right in our algorithm?"
- "Why did we move generation to the backend?"

**Passes:**
- "You generate a fractional index key on the frontend to position items in an
  ordered list, but the frontend only shows a subset of all items — why does
  this cause collision bugs?"
- "A midpoint algorithm checks `if right - left > 1` — what happens when
  `left == right` or `left > right`, and why does the function silently produce
  a wrong answer rather than raising?"
- "You need to generate a unique ordering key in a web API — why is client-side
  key generation unsafe when the client only sees a partial view of the data?"

Where possible, frame the question as a problem statement the reader would
actually face — "You have X, you want Y, how?" — rather than a declarative
"Why does Z work this way?". If the concept is code-centric, include a short
illustrative snippet in the question itself.

## On answer quality

Good answers share three properties regardless of destination:

**Full paragraphs, not one-liners.** An answer that fits in one sentence
probably hasn't captured the *why*. Write enough to make the concept
self-contained.

**Concrete examples.** Numbers, names, specific scenarios make answers
memorable and verifiable. If concrete examples came up in conversation, use
them.

**Build from the ground up.** Don't assume the reader holds context from
surrounding entries or the conversation. Each Q&A should stand alone — someone
reading it cold should finish understanding the concept.

## Step 1 — Extract highlights and route

Scan the full conversation chronologically from the beginning, not from the
end. Recency bias is a common failure mode — earlier decisions often carry more
knowledge density than later iterative work. A long sequence of small iterative
changes (e.g. "make it wider", "apply", "a bit more") should carry far less
weight than a single message where an architectural or technical decision was
made and reasoned through.

For each of the following categories, ask: did anything meaningful happen here?

- Architectural and design decisions
- Debugging, errors, and fixes
- Tool and library configuration gotchas
- CLI and command patterns
- Workflow and process patterns
- Layout and UI patterns
- Technical concepts introduced or clarified
- Business and domain concepts introduced or clarified

Identify key things learned, decided, clarified, or discovered across all of
these. Don't summarise the task itself; focus on reusable knowledge.

For each highlight, immediately assign it a destination using this routing logic:

**`work_stories.md`** — A specific piece of work happened: a migration, an
incident, a feature build, a discovery during a PR. The value is the narrative
of what was done, what was found, what went wrong, how it was resolved. It is
time-bounded and tied to specific events or PRs. Ask: "Is this about a specific
thing that happened?" If yes → `work_stories.md`.

**`work_systems_and_patterns.md`** — A convention or practice used in the team at
work that is specific to the team or a repo, and may differ from general best
practice. Ask: "Is this 'what we do in the team' that an engineer joining the team
needs to know?" If yes → `work_systems_and_patterns.md`. Team conventions
go at the top of the file; repo-specific ones go under the `# repo-name`
section.

**`work_runbook.md`** — A procedure. "Is this a step-by-step thing someone
would follow?" → `## How-to` section. "Is this about diagnosing or fixing
something broken?" → `## Troubleshooting` section. Security-specific guidance
→ `## Security` section.

**`software_engineering.md`** — General technical knowledge that is not specific
to work. Would this knowledge apply equally at another company or team?
If yes → `software_engineering.md`.

**`work_business.md`** — Work domain knowledge. Business rules,
product concepts, planning domain specifics that are not about how the
systems at work are built but about how the business works.

For highlights going to `software_engineering.md`, `work_business.md`, or
`work_runbook.md`: draft as a question, applying the amnesia test. For
highlights going to `work_stories.md`: identify the story and its key moments
(what it was about, what was done, what was discovered, what went wrong, how it
was resolved). For highlights going to `work_systems_and_patterns.md`:
identify the convention (what the team does, in which repos, any nuance worth
noting).

Present these as a categorised list — grouped by destination — and wait for
approval. I may trim, edit, or reroute them. If I request changes, re-present
the full updated list — not just what changed.

## Step 2 — Review entry by entry

Once the highlights are approved, go through each one at a time. For each,
present:

1. **The file it maps to** — look at existing markdown files in
   `~/Documents_Public/notes/`.
2. **The full content** — exactly as it will be written, in the format
   appropriate for that file (see Step 3).

Wait for approval on each entry before moving to the next. I may edit the
content or the file mapping at this stage. If I request changes, apply them and
re-present that entry — not the whole list.

Once all entries have been reviewed and approved, summarise the full mapping
(entry → file) and wait for a final go-ahead before writing anything.

## Step 3 — Write

Write to the files exactly as approved. No surprises.

Within each file, find the right section or create one. If knowledge already
exists, update or extend rather than duplicate.

### `software_engineering.md` — Q&A format, `### heading` style

Use the existing sections and if none is suitable, suggest a new
section and get approval first before creating it with a new `##`.

Write each entry as a `### Question` heading followed by prose. The answer
should be a few paragraphs at most, with code snippets where they add clarity.
Write as a personal reference note, not documentation.

Apply the amnesia test to every question: it must be fully self-contained —
name the system, library, command, or concept explicitly. "Why does this fail?"
fails; "Why does FastAPI silently swallow dependency errors raised as
HTTPExceptions?" passes.

If any links were shared that are relevant, inline them naturally within the
prose — not as a separate references section.

### `work_business.md` — Q&A format, `**bold**` style

Use the existing sections and if none is suitable, suggest a new
section and get approval first before creating it with a new `##`.

Write each entry as a `**bold question**` followed by prose answer — matching
the existing style in the file.

### `work_runbook.md` — Q&A with date, under the right section

Entries go under `## Troubleshooting` (reactive — diagnosing or fixing
something broken), `## How-to` (proactive — a step-by-step procedure someone
follows), or `## Security` (security-specific guidance).

Write each entry as a `### Question` heading, with `*Last confirmed:
YYYY-MM-DD*` on the line immediately after. If the date isn't clear from
context, ask before writing anything. The answer can be numbered steps — the
Q&A wrapper still applies, the answer just happens to be procedural.

### `work_stories.md` — narrative prose

A story captures a specific piece of work: what happened, what was done, what
was discovered, what went wrong, how it was resolved. It is NOT Q&A — it is a
narrative.

Structure:
```
# Story Title

_YYYY-MM-DD_

## Sub-heading describing this part of the story

Prose...

## Another sub-heading

Prose...
```

Sub-headings should be descriptive of this specific story, not generic
templates. Not every angle needs a sub-heading — use whichever naturally apply.
PRs can be linked inline where relevant. If a story is being added to an
existing entry, find the right place within it and extend rather than
duplicate.

### `work_systems_and_patterns.md` — convention entries with date

Each entry records what the team at work actually does: a convention, a practice, a
configuration requirement. It is NOT Q&A.

Structure:
```
**Convention name.** *(scope — DATE)*

Short prose paragraph explaining the convention, why it exists, and any nuance.
Code block only if it illustrates the convention — not as a how-to step.
```

Team conventions go at the top of the file. Repo-specific conventions go
under the `# repo-name` section — create the section if it does not exist.

---

After writing, show added/updated content with a few lines of surrounding
context above and below — not the full file, just the relevant portion.

## Step 4 — Behavioral extraction

Scan the conversation for behavioral moments — pushback, disagreement,
committing to a decision, updating a view, handling conflict, earning trust.

For each moment found, propose:
- The Amazon Leadership Principle(s) it maps to
- A subsection name
- The date it occurred
- The company context
- A draft note with the flavor specific to that principle

Present the full proposal and wait for approval before writing to
`~/Documents_Public/notes/behavioral.md`.

If no behavioral aspects are present, skip this step silently.

You then go over each behavioral moment approved, show the exact text
that will be written to `behavioral.md` - including surrounding
context - and wait for explicit approval before writing anything.
