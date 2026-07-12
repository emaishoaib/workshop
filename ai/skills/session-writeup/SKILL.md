---
name: session-writeup
description: Use whenever the user wants a document, log, recap, postmortem, or "write-up" covering an entire conversation or work session — especially long/multi-day engagements likely compacted/summarized along the way. Trigger on "write up everything we did", "turn this conversation into a doc", "document this from the very beginning", "make me a reference doc of today", "summarize this engagement leaving nothing out", or "capture this session for later" — even without the words "skill", "transcript", or "compaction". Matters most exactly when completeness is requested ("nothing out", "the very beginning", "everything") — the in-context conversation alone silently drops everything before the earliest compaction point, and this skill's job is to prevent that gap and keep the doc free of conversational play-by-play.
---

# Session write-up

Two failure modes ruin this kind of document, and this skill exists to prevent both of them:

1. **Starting from the wrong beginning.** If a conversation has been compacted (summarized) one or more times, the text currently in context is missing everything before the most recent compaction. Writing "the very beginning" from memory, or from an earlier compaction summary, will confidently produce a document that is wrong about where the engagement actually started. The fix is mechanical: go find the raw, uncompacted transcript and read it, rather than trusting anything already in context to be complete.

2. **Writing a transcript instead of a document.** A blow-by-blow account of who asked what and who chose which option reads like meeting minutes, not a reference document. Six months from now, nobody needs to know that "the user requested a commit name" — they need to know what the commit was for. The fix is a discipline: describe the system, the problem, the decision, and the fix — never the conversational mechanics of how those things were communicated.

Work through the two steps below in order. Step 1 gets you the raw material; step 2 turns it into something worth keeping.

## Step 1 — Read from the true beginning, not the in-context summary

Before writing a single word of the document, assume the in-context conversation is incomplete unless you've verified otherwise. Compaction happens silently and can happen more than once in one working session — each time, whatever wasn't preserved in the summary is gone from context, but it usually still exists in a raw session transcript on disk.

**How to find and read the raw transcript:**

- If session-listing/transcript-reading tools are available (e.g. `mcp__session_info__list_sessions`, `mcp__session_info__read_transcript`), use them first — they're the most direct path to the full history.
- Otherwise, look for a pointer to the raw transcript file. Compaction summaries frequently include a line like "If you need specific details from before compaction... read the full transcript at: `/path/to/session-id.jsonl`". If you don't see one, ask the user, or look for session/project directories near wherever conversation logs are stored on the host.
- These transcript files are JSONL (one JSON object per line). Do not try to read the whole file at once — it will very likely exceed your context window, since each line can embed enormous tool outputs, thinking blocks, or attachments. Instead:
  1. Use Grep to find every line matching the human-authored-message marker (in Claude Code-style transcripts this is typically `"origin":{"kind":"human"}` on `"type":"user"` entries — as opposed to tool-result turns, which are also internally tagged `role:"user"` but are not the marker you want). Get line numbers, not full content, in this pass.
  2. Read each matching line individually (e.g. `offset=<line>, limit=1`) to pull out the actual message text. This skips over the huge tool-call/thinking lines sitting between real messages.
  3. If an individual line is still too large to read (this happens with very large pastes — big log dumps, screenshots, diffs), don't force it and don't guess at its contents. Infer what you can from the smaller messages around it (an assistant reply that references what was pasted, or a follow-up question), and say plainly in the final document that this specific piece couldn't be retrieved verbatim. A clearly marked gap is far better than confidently fabricated detail.
  4. Work forward from the true first message only as far as the point where the currently-in-context conversation already picks up — you don't need to re-derive what's already visible to you.
- If, after all this, you're still not confident you've reached the actual start, say so and ask, rather than presenting a partial history as complete.

This step is the one that's easy to skip because it feels like a formality — it isn't. It is the entire value of this skill. A document that starts from the last compaction point instead of the true beginning will look complete and be wrong.

## Step 2 — Write it as a technical narrative, not a conversation record

Once you have the full raw material, write the document around what happened in the system and the project — not around how the conversation went. A simple test for any sentence you write: if it would still make sense with "the user" swapped out for "I" or vice versa, or if its subject is a person's request rather than a system's state, it's conversational narrative and should be cut or rewritten.

**Cut this kind of phrasing:**
- "The user asked why..." / "It was requested that..." / "A question was raised about..."
- "Options were presented, and option B was chosen" / "confirmed readiness at each step"
- "Walked through slowly, one piece at a time" / "discussed", "flagged", "raised", "clarified"
- Anything that records *that a conversation occurred* rather than *what is true about the thing being built*

**Write this kind of phrasing instead:**
- State the situation and the decision directly: "Consolidated on a single root-level Dockerfile instead of maintaining two." / "Chosen: omit `priority` on write — it's optional, and the backend already treats a missing value as 'leave unchanged'."
- State root causes as facts: "`create_app()` unconditionally mounted `/workdir/static`, which only exists inside the built image — so every test failing at setup traces to that one line."
- Preserve exact technical artifacts verbatim wherever they exist: error messages, stack traces, terraform plan output, code diffs, commit names, config values, URLs, resource names. These are the load-bearing content of a reference document — summarizing them away loses the thing someone will actually search for later.

**Structure:**
- Organize chronologically into named sections/parts that mirror the actual sequence the work happened in (e.g. "Part I — diagnosing X", "Part II — building Y"), not into an undifferentiated list.
- Within each section: what the situation or symptom was, the root cause, the decision made (stated as a fact, with its reasoning — not as "the user chose"), the fix (with real diffs/commands), and the result or how it was verified.
- Close with two summary sections that make the document useful as a quick-reference later:
  - **Files changed** — a table of file paths and a one-line description of the change in each.
  - **Open items / not yet done** — anything that came up but wasn't resolved, stated plainly rather than buried in prose.
- If any content couldn't be retrieved verbatim in Step 1, note it briefly near the top of the document (one or two sentences), then don't let it distort anything else — reconstruct the substance from context and move on.

**Before delivering:** reread your own draft once specifically hunting for meta-narrative phrasing (see the cut list above). It's very easy to slip back into "was requested" / "the user then..." out of habit even when trying to avoid it — treat this as a required pass, not an optional polish step.
