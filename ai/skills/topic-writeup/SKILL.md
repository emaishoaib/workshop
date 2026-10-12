---
name: topic-writeup
description: Use whenever the user wants a document that explains a topic covered in a conversation or work session, organised by subject rather than by time — an overview, a briefing, an "explain this to someone who wasn't here" doc, or a status-and-context page. Trigger on "write a doc about this topic", "a markdown file a human can read and understand what's going on", "an overview of X", "where does X stand", "connect the dots", "not part one, part two", or when the user rejects a chronological write-up and wants it topic-based. Like session-writeup, it reads the whole conversation from the true beginning, including anything lost to compaction, so nothing substantive is missed; unlike session-writeup, it writes the result as an explanation of a subject with its current status, not as a sequence of what happened.
---

# Topic write-up

This skill produces a document that a person who was not in the conversation can read top to bottom and come away understanding a topic: what it is, how it connects to the things around it, how it works, and where it stands right now.

It shares its first half with `session-writeup` and differs in its second half:

- **Gathering is exhaustive.** Every substantive finding, decision, root cause, code change, open question and reference from the whole conversation is raw material. Nothing is dropped for being small.
- **Writing is topical.** The document is organised around the subject, not around the order in which things were discovered or built. There are no "Part I", "Part II" sections that mirror the timeline, no per-commit sections, no "then we did X".

Three failure modes ruin this kind of document:

1. **Starting from the wrong beginning.** A compacted conversation silently loses everything before the last compaction. A document written from what is in context can be confidently incomplete.
2. **Writing a timeline instead of an explanation.** Sections like "Commit 3", "Tests commit", or "PR and CI" force the reader to replay the work to understand the subject. A reader wants the subject explained, then its status.
3. **Writing a transcript instead of a document.** Anything about who asked what, which option was picked in a picker, or how a question was phrased is conversational mechanics, not knowledge.

Work through the three steps below in order.

## Step 1 — Read from the true beginning

Assume the in-context conversation is incomplete until verified.

- If the conversation has not been compacted, the full history is already in context. Say so in one line in your reply (not in the document) and move on.
- If it has been compacted, find the raw transcript before writing anything:
  - Use session-listing or transcript-reading tools first if they exist.
  - Otherwise look for a transcript path in the compaction summary (often a line pointing to a `.jsonl` file), or ask the user.
  - The file is JSONL and too large to read whole. Grep for human-authored message lines first (in Claude Code transcripts, `"origin":{"kind":"human"}` on `"type":"user"` entries) to get line numbers, then read each matching line individually with `offset=<line>, limit=1`.
  - If a single line is too large to read, infer its content from the surrounding messages and do not invent it. Note the gap in your reply.
  - Work forward only to the point where the in-context conversation picks up.
- If you still are not confident you reached the actual start, say so and ask rather than presenting a partial picture as complete.

Also read anything the conversation produced on disk that is part of the topic (for example an earlier detailed write-up, committed code, config files). Use the **current** state of files, not the version you remember writing. The user may have edited them since.

## Step 2 — Extract, then sort by subject

Before writing, list the raw material, then group it by what it is *about*, not when it came up.

**Extract everything substantive:**
- what the thing is, and what it replaces or changes;
- neighbouring initiatives, tickets and systems it touches, and how;
- root causes, mechanisms and non-obvious behaviour discovered in the code or systems;
- decisions and their reasons (including things deliberately not done, and why);
- exact artefacts worth searching for later: error messages, function and config names, endpoints, ticket keys, PR numbers, doc titles and links;
- current state of every piece: done, in review, blocked, unanswered;
- every open question, and who or what it waits on.

**Drop the mechanics:**
- the back-and-forth of creating PRs, tickets or commits (pickers, recaps, title confirmations);
- staging commands, commit-message drafts, amend instructions;
- local test-environment plumbing (scratch environments, temporary databases, probe files), unless a finding from it matters, in which case keep the finding and drop the plumbing;
- detours, reverted attempts and corrections. Keep only where things landed. If a correction changed a fact, state the corrected fact.

**Then sort into subjects.** Typical buckets: what it is; how it relates to other work; how it works; specific gotchas; status; references. A gotcha belongs inside the subject where it bites, not in a list of its own.

## Step 3 — Write it as an explanation with a status

### Shape

Use headings that name subjects, not phases. A good default, adapted to the topic:

1. **Title and status line.** The topic name, then one line with the date the status reflects and the main ticket and PR links.
2. **What this is.** What the thing is in plain words, what sets it apart, and what it changes. Define every term on first use.
3. **How it relates to [neighbouring work].** Only if there is real overlap. Say where the two meet, and say plainly what is and is not blocked, with the evidence.
4. **How it works.** Walk one concrete thing through the system end to end (a request, a record, a job run), as numbered subsections. Put each surprise, gotcha or required workaround at the step where it happens, with the reason. This section is what "connecting the dots" means.
5. **Specific technical issues** that do not fit the walk, each as its own short section.
6. **Current status.**
   - A short "Done" list.
   - Anything currently failing or red, and why, stated as a fact.
   - An open-items table with columns *Item* and *Waiting on*. Name people or dependencies, not vague owners.
   - Any timeline pressure, stated with dates.
7. **References.** Grouped by kind (tickets, docs, code), as links. Link to any detailed chronological write-up of the same work.

Drop or merge sections that would be empty or thin. Do not pad.

### Style

- Write for a colleague with general context on the company and systems but none on this work.
- Plain prose, one idea per sentence. Lists where items are genuinely parallel. Tables only where rows compare on the same attributes.
- Light code only. Include a snippet when it makes a mechanism click faster than prose (an enum, a mapping, a loop, an error message). Never paste whole diffs or per-file change lists; those belong in a chronological write-up.
- State decisions as facts with their reason: "The new site has an empty config entry because the method won't run without one", not "it was decided that".
- Keep exact names and messages verbatim where they appear. Summarise everything else.

### Cut this kind of phrasing

- "The user asked…", "it was requested…", "a question was raised…", "we discussed…"
- "Options were presented and B was chosen"
- "Part I", "Part II", "Commit 1", "Next, we…", "after that…"
- Anything recording *that a conversation happened* rather than *what is true about the subject*.

## Before delivering

Reread the draft twice:

1. **Meta-narrative pass.** Hunt for the phrasing in the cut list above. Grep for words like "asked", "requested", "discussed", "chose", "Part", "Commit" and rewrite any hits.
2. **Cold-reader pass.** Read it as someone who was not there. Every term defined before use? Every open item says what it waits on? Could they answer "what is this, how does it work, and where does it stand" from the document alone?

Save the file where the user asks. If they name only a folder, follow that folder's naming convention (for example a `YYYYMMDD - topic-name.md` prefix). In your reply, link the file and summarise its sections in a few lines. Do not paste the document into the reply.
