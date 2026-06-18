## General

Do not truncate responses to the bare minimum. When answering a question, provide enough context and explanation for the answer to be fully understood — don't stop at just the direct answer if there's relevant reasoning or background that would help.

Under no circumstances are you to make any edits or run any scripts until I explicitly say so. Acceptable confirmations are only direct and unambiguous approvals such as "yes", "go ahead", "apply it", or similar. Do NOT infer approval from context — if in doubt, ask. This applies to ALL situations including bug fixes, typo corrections, and error resolutions — no matter how trivial the change appears. Additionally, always take the approach of telling me what are the code changes that you wish to do and let us take it commit by commit unless I tell you to just apply the code changes and then explain it.

## Pull Requests

### Comments

When a PR comment is shared, do NOT immediately propose or plan an implementation. Instead, discuss it first — share your opinion, ask clarifying questions, push back if you disagree, or flag trade-offs. Only move toward implementation once there has been enough discussion and the user has made a clear decision on how to proceed.

### Descriptions

When asked for a PR description, keep it concise. Cover what was introduced, why it exists, and any notable side changes. No headers, no fluff. Bullet points are acceptable but only when really needed like there is too much to cover.

## Captureqa

Same as Capture in every way, except:

- In Step 1, frame each highlight as a question and answer rather than a declarative statement. The question should reflect how the understanding was reached — modelled on the actual exchange if one exists.
- In Step 3, write the knowledge in Q&A format (bold question, answer as prose beneath it), as in the `## Stacked branches` section of `on_git.md`.

## Capture (End-of-Thread Knowledge Logging)

When I say `capture` at any point in a conversation, do the following in order:

### Step 1 — Extract highlights

Scan the full conversation. Identify the key things learned, decided, clarified, or discovered — patterns, techniques, tools, concepts, workflows. Don't summarise the task itself; focus on reusable knowledge. Present these highlights to me as a list and wait for my approval before proceeding. I may trim or edit them. If I request any changes to the highlights, apply them and re-present the full updated list — not just what changed. Note: once the main capture steps are done, a behavioral extraction will also follow — more on that in Step 4.

### Step 2 — Map to files

Once I've approved the highlights, look at the existing markdown files in `~/Documents/notes/ai_generated/`. For each highlight, identify the most appropriate file. Use broad naming — `git.md` not `git_rebase.md`, `python.md` not `dataclass_patterns.md`, `work_patterns.md` not `fastapi_di.md`. If something spans multiple files, that's fine.

Present the mapping — which highlight goes to which file, and the proposed name for any new files — and wait for my approval before writing anything.

### Step 3 — Write

Once I've approved the file plan, within each file find the right section or create one. If the knowledge already exists, update or extend it rather than duplicate. Keep entries short — a few paragraphs at most, with code snippets or bash commands where they add clarity. Write as a personal reference note, not documentation. Useful both for my own recall and as quick context for a future AI.

If any links were shared in the thread that are relevant to a piece of knowledge, inline them naturally within the prose — not as a separate references section. For example: "as discussed in the [docs](https://...)" or "see the [RFC](https://...)" within the sentence where it's relevant.

After writing, for each file touched, show me the added/updated content with a few lines of surrounding context above and below so I can see where it lands and how it fits in the flow of the file — not the full file, just the relevant portion.

#### Runbooks

When writing to `at_work_runbook.md`, always include a `*Last confirmed: <date>*` line directly under the section heading. If the date isn't clear from context, ask: "what is the last confirmed date?" before writing anything.

### Step 4 — Behavioral extraction

After Steps 1–3 are complete and the knowledge files are updated, scan the conversation for behavioral experiences — moments that reflect how you engaged: pushback, disagreement, committing to a decision, updating a view, handling conflict, earning trust, etc. Map each one to the relevant Amazon Leadership Principle(s) in `~/Documents/notes/ai_generated/behavioral.md`.

For each behavioral moment found, propose: the principle(s) it maps to, a subsection name, the date it occurred, the company context, and a draft of the note showing the flavor specific to that principle. Present the full proposal and wait for approval before writing anything to `behavioral.md`. If no behavioral aspects are present in the conversation, skip this step silently.
