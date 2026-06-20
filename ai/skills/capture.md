# Capture Skill

A multi-step knowledge logging workflow triggered by the word `capture` in 
conversation. Everything is written in Q&A format — no declarative statements.

## On question quality

Two types of questions, in order of preference:

- **Reasoning questions** — test whether you understand *why*. Frame these to 
  reflect how the understanding was actually reached in the conversation, 
  modelled on the real exchange. "Why does X behave this way?" is better than 
  "What is X?".
- **Recall questions** — test whether you remember something concrete. Fine for 
  commands, flags, syntax. "What flag do you use to X?" is a valid recall 
  question.

Prefer reasoning questions. When a reasoning question exists, don't also write 
a recall question for the same concept — the reasoning answer will contain the 
concrete detail anyway.

A single concept may produce multiple Q&A pairs. When it does, order them 
deliberately — start with the question that establishes *why* or *what problem 
this solves*, then move to deeper reasoning, then to concrete application. The 
sequence should mirror how someone would build understanding from scratch, not 
the order things happened to come up in conversation.

## Step 1 — Extract highlights

Scan the full conversation. Identify key things learned, decided, clarified, 
or discovered — patterns, techniques, tools, concepts, workflows. Don't 
summarise the task itself; focus on reusable knowledge.

For each highlight, draft it immediately as a question — not a declarative 
statement. The question should reflect how the understanding was reached, 
modelled on the actual exchange if one exists. Note that a single highlight may 
expand into multiple ordered Q&A pairs in Step 3 — at this stage, flag that 
where you can see it coming. Present these as a list and wait for approval. I 
may trim or edit them. If I request changes, re-present the full updated list 
— not just what changed.

## Step 2 — Map to files

Look at existing markdown files in `~/Documents/notes/ai_generated/`. For each 
highlight, identify the most appropriate file. Use broad naming — `git.md` not 
`git_rebase.md`, `python.md` not `dataclass_patterns.md`.

Present the mapping and wait for approval before writing anything.

## Step 3 — Write

Within each file, find the right section or create one. If knowledge already 
exists, update or extend rather than duplicate.

Write each entry as:

**The question, framed as it would be asked under pressure or during review.**  
The answer as prose beneath — a few paragraphs at most, with code snippets or 
bash commands where they add clarity. Write as a personal reference note, not 
documentation. Useful both for your own recall and as quick context for a 
future AI.

Where a concept produces multiple Q&A pairs, write them in sequence under the 
same section — do not scatter them. The order should build understanding 
progressively: why it exists → deeper reasoning → concrete application.

If any links were shared that are relevant, inline them naturally within the 
prose — not as a separate references section.

### Runbooks
When writing to `at_work_runbook.md`, always include a `*Last confirmed: 
<date>*` line directly under the section heading. If the date isn't clear from 
context, ask before writing anything. Runbook answers can be numbered steps — 
the Q&A wrapper still applies, the answer just happens to be procedural.

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
`~/Documents/notes/ai_generated/behavioral.md`.

If no behavioral aspects are present, skip this step silently.