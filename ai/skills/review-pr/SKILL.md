---
name: review-pr
description: >
  Review the currently checked-out branch/PR locally, without relying on the
  gh CLI or a live GitHub connection. Trigger when the user asks to "review
  this branch", "review the PR I'm on", "review my changes", or similar,
  especially when working in a sandboxed environment with no network access
  to GitHub. Diffs the branch against the merge-base with the trunk branch
  and produces a severity-categorized review.
---

# Review PR (local)

Reviews the branch currently checked out, working entirely from local git
state. This exists because the sandbox this runs in typically has no `gh`
CLI installed and no network path to GitHub — attempts to install `gh`,
`ssh-keyscan` the remote, or `curl` the GitHub API will fail. Don't retry
those; go straight to the local git approach below.

## Step 1 — Establish what's being reviewed

Identify the repo and current branch (`git branch --show-current`). Confirm
this is actually the branch the user means before proceeding if there's any
ambiguity (e.g. multiple repos with uncommitted changes).

## Step 2 — Get the right diff

Do not diff against the tip of `origin/master`/`origin/main` — that ref is
just whatever was last fetched onto this machine and is not "live" in the
sandbox. `refs/heads/master` (local) and `refs/remotes/origin/master` are
both frozen snapshots from the last fetch/pull; neither is more current than
the other unless one has actually diverged. If they point at the same
commit, it doesn't matter which you use.

There is no network access from the sandbox to refresh either ref — do not
attempt `git fetch`, `ssh-keyscan`, or similar; they will fail with DNS/host
key errors. If it matters whether trunk has moved upstream since the last
sync, tell the user and let them fetch on their own machine first — don't
silently treat a stale ref as current.

Find the merge-base rather than diffing branch-tip against trunk-tip
directly:

```
git merge-base master <branch>
git diff <merge-base> <branch>
```

This isolates just the branch's own changes, not any drift between the two
tips from unrelated history.

## Step 3 — Read the whole diff before writing anything

Don't review file-by-file in isolation — read the full diff first to
understand how pieces connect (e.g. a component change and the hook it
depends on, or a config change and the code path it affects).

## Step 4 — Categorize findings by severity

Structure the review into three tiers, only including tiers that have
content:

- **Likely bugs** — logic errors, incorrect assumptions, race conditions,
  anti-patterns that will misbehave (e.g. side effects inside a state
  updater function, a stale closure, an early return that skips required
  cleanup/animation). These are things you're confident are wrong, not just
  stylistic concerns.
- **Worth double-checking** — behavioral changes whose correctness depends
  on something outside the diff (environment, runtime privileges, invocation
  cwd, CI configuration). Say what could go wrong and what to verify, don't
  just assert it's broken if you're not certain.
- **Minor / cleanup** — dead code, unused variables/functions, redundant
  logic, naming nits. Keep these brief.

For every finding, cite the specific file and line/region and explain the
reasoning — not just "this looks off." If something is a genuine bug, say so
directly rather than hedging with "consider..." language.

## Step 5 — Walking through findings one by one

When the user wants to go through findings individually rather than all at
once (e.g. "let's tackle them one by one"), restate the file and line/region
for each finding at the top of its own message — every time, not just in the
initial recap. Never let a finding stand on its own without its location;
don't assume it carries over from an earlier message just because it was
stated once already.

Each finding's first message should be terse: the verdict and its location,
nothing else. E.g. "`file.tsx`, ~line 42: the early return skips the close
transition." Do not include the reasoning, the fix, or any elaboration
up front — stop there and wait for a reaction. Only give the fuller
explanation, the fix, or both if the user asks for them (and only the parts
they actually asked for — if they ask for the fix only, don't also re-explain
the why unless asked).

## Tone and format

Concise, direct, no fluff, no headers-for-headers'-sake. Prose review
grouped under the tier headers above; short bullets are fine within each
tier since it's inherently a list of distinct findings, but each bullet
should be a real explanation, not a one-line label. Skip a tier entirely if
there's nothing in it rather than writing "none found."

Do not propose fixing anything as part of this skill — review only. If the
user wants a fix, that's a separate, explicit ask (and per general repo
convention, no edits should be made without explicit approval).

## Refining this skill

This skill is expected to evolve as review preferences get clarified in
conversation. When the user corrects or refines how a review should be done,
update this file to reflect the new preference rather than treating it as a
one-off instruction.
