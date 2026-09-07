---
name: trace
description: >
  Produce a start-to-end execution-sequence trace of one specific code flow: a tree diagram
  showing exactly what file and function/method calls what, in the order it actually executes,
  from a trigger (an HTTP request, a CLI command, a UI action, an event) through to its final
  outcome. Trigger when the user asks to "trace" a flow, wants a "sequence", "call chain", or
  "call graph" from start to finish, asks "what happens when X happens" or "what calls what"
  across multiple files, or wants the shape of a flow before diving into any one piece of it.
  Also trigger on "show me start to finish", "walk me through the request lifecycle", or when
  someone is orienting in an unfamiliar codebase and asks how a feature's pieces connect end to
  end. Works in any language. Distinct from a skill that does a deep one-function walkthrough
  with worked example values — that goes deep on one thing; this maps how several things connect,
  and is often worth doing first.
---

# Trace

## What this produces

A literal tree, in a fenced code block, that a reader can follow top to bottom and see the
entire execution path: which file receives the trigger, what it calls, what that calls, all the
way to the final outcome. Not prose describing the flow — an actual diagram, built from
box-drawing characters, that reads like a map.

The whole point is that someone can look at this for thirty seconds and know which file to open
first, without you having explained anything yet. It replaces "let me walk you through how this
works" with something they can scan.

## Step 0 — Pin down the entry point

A codebase usually has more than one plausible starting point for "trace this." Before writing
anything, make sure you and the user agree on exactly one trigger and one outcome.

If it's genuinely ambiguous — several endpoints could be what they mean, or "when a user does X"
could start from more than one handler — ask, with a short numbered list of the candidates you
can see, and a guess at which one they probably mean and why. Ask this as a plain chat message,
not a picker or structured-question tool — the numbered list needs to stay in scrollable
conversation history so the user can scroll back up and re-read what was found, not disappear
once answered. Don't guess silently and build the wrong trace; it's expensive to produce and
worse to redo.

If they've already named the specific entry point (a route, a command, a function), skip this
step and move on.

## Step 1 — Read the real code, right now

Do not reconstruct the trace from memory of having read these files earlier in the conversation,
and don't infer a callee's behavior from its name. Read every file in the path fresh, in this
pass, especially if there's any chance the codebase has moved since you last looked — a branch
switch, a merge, someone else's commit, a rebase. Getting a method's actual current signature and
behavior wrong makes the whole trace untrustworthy, and the entire value of this format is that
it can be trusted at a glance.

## Step 2 — Decide how deep to go on each callee

Expand a callee's internals only if understanding them changes what the reader takes away about
the traced flow's behavior. A generic library helper, a framework internal, or a data-tracking
detail that's just plumbing gets one bullet describing what it's for, not its own sub-tree. Stop
descending once you've said what a piece does in domain terms — you don't need to open every
file it happens to touch.

The judgment call: would the reader be surprised or misled if they didn't know what's inside this
callee? If no, name it and move on. If yes, expand one more level.

## The format

This is the deliverable. Follow it exactly — the mechanics below aren't stylistic preference,
they're what makes the tree scannable instead of just another wall of text with arrows in it.

**Bookends.** Open with `START — <the trigger>` and close with `END — <the final outcome>`,
literally spelled `START` and `END`. The reader should never have to wonder where the trace
begins or ends.

**A real tree, not markdown nesting.** Use box-drawing characters — `│`, `├─`, `└─` — to show
the call structure. Do not represent nesting with markdown bullet indentation or numbered
sub-lists; those don't hold their shape once there are three or four levels of nesting, and the
box-drawing tree does.

**Number only the top level.** The direct steps inside the entry point's own function get
numbers (`1.`, `2.`, `3.`, ...) in execution order. Everything nested inside one of those steps
is unnumbered — just further branches of the tree. Numbering everything defeats the purpose;
the numbers exist so the reader can refer to "step 4" in conversation afterward.

**Name the file and the function together.** Use `file/path.ext :: functionName()` when
introducing a call, so the reader knows both where to look and what to look for. For the very
first node under the entry point, a two-line form reads better — the file path alone, then the
method on the next line.

**Arrow only when you cross a file.** `└─→` or `├─→` (the branch followed by an arrow) means
this call jumps into a *different file* than the one you're currently inside. Plain `├─` or
`└─` (no arrow) means you're still narrating something in the current step — a loop, a
condition, a sub-call that stays in the same file. This distinction is what lets a reader tell,
at a glance, when they'd actually need to open a new file to keep following along, versus when
they're still reading the consequences of the step they're already in.

**Bullets, not prose, for what each step does.** Every step's description is a `•` bulleted
list, one fact per bullet, never a wrapped paragraph. A step that's doing three things is three
bullets, not one sentence with three clauses stitched together. This is the single most
important rule in this format — a paragraph buried inside a tree branch is exactly the kind of
thing that's easy to skim past, and the entire benefit of this format is that nothing gets
skimmed past.

**A return value gets its own `→` line, never a bullet.** When a step or a callee hands
something back — a return value, what a generator yields, what a query returns — put that on
its own line starting with `→`, visually separate from the `•` bullets describing what happened
internally. The reader should be able to scan just the `→` lines and reconstruct the data flow
without reading anything else.

**Conditionals get their own branch line.** `if x is True:` (or your language's equivalent) is
not a bullet inside another step — it's its own tree branch, with whatever happens inside it
nested one level deeper. Same for loops: `for each rule, in priority order:` gets its own branch
line introducing whatever runs per iteration.

## After the tree: what's easy to miss

Close with two to four short callouts — things a first read of the tree would miss, even though
they're sitting right there in it. Genuine "wait, really?" facts: two things that look related
but actually run on completely separate paths, a side effect that happens regardless of a
branch's outcome, a piece of state that never gets recomputed even though it looks like it
should be.

Keep this section proportional to what's actually surprising. If there's nothing genuinely
non-obvious, it's fine to skip this section rather than manufacture three bullets that just
restate the tree.

## Worked example

This is a fictional trace — a support-ticket auto-routing endpoint in a made-up Python/FastAPI
backend. The domain isn't real; the format is. Read it closely before writing your own — it's
the calibration for exactly how dense the bullets should be, exactly where arrows appear versus
plain branches, and exactly what the closing callouts look like.

```
START — HTTP POST /api/tickets/{ticket_id}/auto-route

routers/tickets.py
└─ TicketRoutes.auto_route()
   └─→ services/routing.py :: RoutingService.route_ticket()
       │
       ├─ 1. self._load_routing_rules(team_id)
       │      • queries RoutingRule, filtered by team_id + enabled
       │      • each rule's own applies_to_window() narrows further (e.g. business hours)
       │      • ordered by priority
       │      → returns list[RoutingRule]
       │
       ├─ 2. self._load_candidate_agents(team_id)   [generator]
       │      • queries Agent ⋈ AgentSkill, filtered by team + currently online
       │      • looks up each agent's open-ticket count via self.workload_tracker.get_counts()
       │      → yields matching.Candidate per agent
       │
       ├─ 3. matching/engine.py :: assign_candidates(rules, candidates, ticket)
       │      • wraps each Candidate in a TrackedCandidate (tracks remaining capacity)
       │      • for each rule, in priority order:
       │        └─→ matching/rule_base.py :: BaseRoutingRule.__call__()
       │               (via matching/helpers.py :: PerCandidateRule)
       │            • filters candidates by eligibility_filters() (skill tag/language/seniority)
       │            • each concrete rule type (RoundRobinRule, SkillMatchRule, ...) picks a
       │              candidate and a suggested queue position
       │      • caps assignments to each candidate's remaining capacity
       │      → returns MatchResult(assignments, unmatched_rules)
       │
       ├─ 4. self._apply_overflow_rebalancing(team_id, result.assignments)
       │      • queries RebalancingPolicy, filtered by team_id + enabled, ordered by priority
       │      • if none found → return assignments unchanged
       │      • computes the set of queues touched by all assignments
       │      • for each policy, in priority order:
       │        ├─→ matching/rebalancing.py :: get_policy_queue_groups()
       │        │      • groups touched queues into clusters matching this policy's
       │        │        queue_pattern + shift_window
       │        │
       │        └─ for each cluster:
       │             ├─→ self._claimable_queue_slots(...)
       │             │      • finds which (queue, agent) pairs have overflow in scope
       │             │        (skill_tags / team_scope)
       │             │      • excludes any already claimed by a higher-priority policy
       │             │
       │             ├─ if policy.pause_only is False:
       │             │    └─→ self._rebalance(assignments, claimable, policy.max_hops)
       │             │           • sums ticket count per queue across the claimable set
       │             │           └─→ matching/rebalancing.py ::
       │             │                 compute_rebalance_fractions_per_source_queue()
       │             │               • averages, then shifts overflow into the nearest
       │             │                 under-capacity queue first
       │             │               • capped by max_hops
       │             │           • rebuilds the assignment list: each claimable
       │             │             assignment may split into several, count/queue
       │             │             adjusted per the computed fractions
       │             │           • never reassigns a ticket past its own SLA deadline
       │             │
       │             └─ marks these (queue, agent) pairs claimed regardless of
       │                pause_only, so a lower-priority policy can't touch them either
       │      → returns the (possibly rewritten) assignments list
       │
       ├─ 5. self._load_pinned_assignments(team_id)
       │      • queries PinnedAssignment (manually assigned, locked tickets) ⋈ Ticket
       │      • entirely separate from the routing engine and from rebalancing —
       │        these are past decisions, not recomputed
       │      → returns list[AssignmentRow]
       │
       └─ 6. constructs RoutingResponse
              • assignments     = rebalanced assignments (step 4), mapped to AssignmentRow
              • pinned          = step 5's rows
              • unmatched_rules = result.unmatched_rules (step 3)
              • ms_timings      = wall-clock timings for steps 1–3

FastAPI serializes RoutingResponse → JSON

END — HTTP 200
```

Callouts that followed this one, for reference on tone and proportion:

- Step 4 runs on top of step 3's output, not the raw candidate list — rebalancing only ever sees
  what the routing engine already assigned, it never looks at raw agent availability directly.
- The "claimed" bookkeeping in step 4 happens whether or not the policy actually rebalances
  anything (`pause_only=True` policies still claim, they just don't call `_rebalance`). That's
  the mechanism that lets a high-priority pause-only policy carve out a queue so a
  lower-priority general policy can't touch it.
- Step 5 (pinned assignments) never goes through steps 3 or 4 at all — it's a completely
  separate query appended to the response, which is why a manually-pinned ticket's agent never
  changes when routing rules or rebalancing policies are edited.

## Adapting to other languages and stacks

The worked example is Python/FastAPI, but nothing about the format is Python-specific. Keep the
tree, bullet, and arrow mechanics identical; adapt only the naming convention for how you refer
to a callee to whatever reads naturally in that language — `Class.method()` in Java or C#,
`module.function()` in Go, `file.js :: functionName()` in JS/TS, and so on. The `::` separator
between file and function in the worked example is a convention, not a requirement — use
whatever separator is idiomatic, as long as file and function both show up on the same line.

## A note on scope

This is a map, not a deep dive. If, partway through building the trace, you notice something
that would take real unpacking to explain properly — a non-obvious algorithm, a subtle invariant,
a piece of business logic with its own rationale — name it in a bullet and move on. Mention that
it's worth a closer look afterward rather than expanding it inline; expanding it here breaks the
one property that makes this format valuable, which is that the whole thing fits in one scan.
