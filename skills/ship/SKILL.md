---
name: ship
description: "Take a ticket from spec to production: build it as a stack of small pull requests, drive each through the AI reviewer and your own self-review until clean, split any PR that won't converge, keep the stack restacked and green as PRs merge, then verify the rollout live. Use when the user says to ship, land, or take a ticket to production, when a stack of open pull requests needs babysitting through review, CI, and merges, or when merged work still needs deploying and verifying."
---

# Ship

One ticket in, verified in production out. `implement-as-stack` produces the stack; this skill owns
everything after it: the **review loop**, **splitting** what won't converge, keeping the stack
**true**, **advancing** it as PRs merge, and the **rollout**. The human merges, approves deploys,
and flips flags. You prepare each of those so it is one action for them.

The repo's `AGENTS.md` (or `CLAUDE.md`) names the concrete commands this skill refers to by role:
the fast check, the production build, the CI label that gates expensive jobs, and the deploy path.

## Skills this one names

Bundled with this skill: `implement-as-stack`, `code-review`, and `verification-before-completion`.
The others are optional companions. Use them when they're installed; otherwise do their job directly:

| Named here | Get it from | Without it |
|---|---|---|
| `tdd` | [mattpocock/skills](https://github.com/mattpocock/skills) | Write the failing test first, watch it fail for the right reason, then make the smallest change that passes. |
| `resolving-merge-conflicts` | [mattpocock/skills](https://github.com/mattpocock/skills) | Resolve each hunk deliberately, keeping the PR's side where it builds on the merged work, and rerun the PR's checks. |
| `diagnosing-bugs` | [mattpocock/skills](https://github.com/mattpocock/skills) | Reproduce first, form a hypothesis, prove it, then fix the cause. |
| `implement` (used by `implement-as-stack`) | [mattpocock/skills](https://github.com/mattpocock/skills) | Build the ticket test-first on the integration branch, then review it with `code-review`. |
| `differential-review` | [trailofbits/skills](https://github.com/trailofbits/skills) | Give auth, input, locking, and token changes a security-focused pass of `code-review`'s line-by-line and removed-behaviour angles. |

## Start where the work is

- **No stack yet:** start at step 1.
- **Pull requests already open:** start at step 2, with those PRs on the watch list.
- **Everything merged:** start at step 9.

Never rebuild or republish work that's already open.

## 1. Build

Run `implement-as-stack`. Size each slice so a reviewer can read it in **under twenty minutes**,
and give each risky concern (a transaction, an auth boundary, token handling) a slice of its own,
with its tests. A reviewer can only attend to the hard part when nothing routine surrounds it.

Done when every slice is published with its CI label, and the AI reviewer is requested on each.

## 2. Watch

When the environment supports subagents, start or reuse **one dedicated shipping agent per stack**.
Read [COORDINATION.md](COORDINATION.md) before delegating. That agent owns the watcher and drives
the review, CI, and stack-advancement steps below while the human reviews and merges. Starting a
background shell that prints events is not enough: an active agent must consume those events and
act on them.

Give it the repository, ordered PR list, current bases and heads, its worktree, existing review
dispositions, check evidence, decision log, and any running watcher/process IDs. Include the human's
recorded decisions and authorization boundaries. It may fix and push within its assigned lane;
merges, deploy approvals, and flag changes remain with the human. Reuse an existing agent or transfer
ownership explicitly rather than starting competing watchers or writers for the same stack.

Start [`scripts/watch-prs.sh`](scripts/watch-prs.sh) under a monitor, with the repo and a file
listing the open PR numbers. It reports:

- **merges and closes** (and drops those PRs from the list)
- **conflicts**
- **failed checks**
- **new AI reviews on the current head**, with the round count

Add PRs to the list as they open. Re-arm the watcher when it expires while any PR is still in
flight.

Treat each event as a cue to verify the current head, open findings, and actual check runs before
acting. A check from an older head is not evidence of a failure on a new head. A separate branch CI
run does not replace the PR's required checks; verify both and never cancel the PR run merely because
the branch run passed.

The shipping agent reports meaningful changes to the coordinator: findings and their dispositions,
failures, conflicts, and the next PR that is ready. It stays active after reporting a PR ready:
waiting for a human merge is part of the job. Each merge triggers step 8 without another prompt.
Before handing off a ready PR, re-read its head, review threads, and checks so a late review or head
change is not missed. Keep watching until the stack is merged and the rollout is verified, the human
pauses the work, or a blocker needs human action. A merge alone does not authorize production actions.

If the environment cannot run a separate agent, the invoking agent owns this loop. If it cannot keep
monitoring after its turn ends, say so and leave a resumable handoff with the PR order, heads, pending
events, process IDs, and next action. Do not claim an unattended watcher will drive the work.

A PR is **reviewed** when the reviewer's review carries its current head commit, or carries an
earlier head whose own diff (against its base at the time) has the same patch-id as the current
head's. That second case is a restack that only merged the base in: the reviewed change hasn't
moved. Compare with `git patch-id --verbatim`: the default ignores whitespace, which would carry a
review across a changed indentation in Python or YAML. Any other review of an older commit says nothing about the head. Neither does an empty review
list, or a reply posted by another agent.

## 3. The review round

Each round, for one PR:

1. **Gather** every open thread, plus the summary's "previously missed" items. Those are findings
   even when no thread exists.
2. **Verify** each finding before touching code, the way `code-review` verifies: restate it, then
   rule it CONFIRMED / PLAUSIBLE / REFUTED. Decline what's refuted, with a reply that says why.
   Bring a finding to the human only when it would reverse one of their recorded decisions, when
   its fix needs a test seam they haven't agreed (step 3), or when the **Disposition** rule below
   sends it there.
   Check each against the code, not the reviewer's framing:
   - **Context the reviewer lacks.** The PR may be one slice of a stack, so a "missing" piece can
     land in a later slice. The current code may exist for a reason the diff doesn't show.
   - **Added surface.** When a finding asks you to build something out "properly", find its callers
     first. If nothing uses it, propose deleting it instead.
   - **Unverifiable.** Say so in the reply, and name what would settle it. Don't fix on faith.
   - **Disposition.** Before a thread is resolved, its finding has one: fixed, refuted with
     evidence, or accepted or deferred with a reason and, when deferred, a follow-up ticket. An
     accepted behaviour change is also recorded in the PR description, as `code-review` asks, so
     an approver sees the decision without reading the threads. A PLAUSIBLE finding with real
     impact, such as a race, data loss, or a security gap, that you can neither fix nor refute
     goes to the human. It doesn't close on a reply.
   - **Unclear.** Don't fix a finding you can only half read, or anything that depends on it: a
     partial reading produces a wrong fix. A human reviewer gets a question in the thread. An AI
     reviewer won't answer, so reply with your reading and act on it, or bring it to the human if
     it touches a recorded decision.
   - **Replies.** State the fix or the evidence. No performative agreement, and no thanks. When
     your pushback proves wrong, say so plainly and fix it. Answer each threaded finding in its own
     thread. A finding with no thread, such as a "previously missed" item, gets its disposition in
     step 6's round summary, which is the only top-level comment.
3. **Fix** everything confirmed, in one batch, test-first through `tdd`: for each behavioural fix,
   write the test that reproduces the finding and watch it fail for the right reason before changing
   any code, then make the smallest fix that turns it green. Write it at a seam the PR's tests
   already use, which the human agreed when the work was built; a fix that needs a new seam goes to
   the human first, as `tdd` requires. Test-, comment- and doc-only findings have no behaviour to
   reproduce. When no test can reproduce a finding, re-verify it against the code: decline it with
   the evidence if it isn't real. If it is real but no automated test can express it, such as a
   failure only a production build shows, fix it and prove it with the check that exposed it, and
   say so in step 6's round summary.
4. **Self-review** before pushing: run `code-review` on the PR's **full diff against its base**, not
   just the fix, plus `differential-review` when the PR touches auth, input, locking, or tokens. Fix
   what it confirms the same way, test-first. This is the step that turns "previously missed" into
   "found first".
5. **Prove** each behavioural fix: its reproducing test, red before the fix and green after, or,
   for a finding no test can express, the check that exposed it; plus the suites the PR touches. A
   test that never failed proves nothing.
6. **Push** once, after fetching, with a lease. Reply to each thread, and resolve it once its
   finding has a disposition. A thread waiting on the human stays open. Post one PR comment listing
   the reviewer's items, your self-review's findings and fixes, anything waiting on the human, what
   you checked and found clean, and step 4's call with its reason. Step 4 decides whether to
   re-request the reviewer.

Done when every finding on the head has a disposition and none is waiting on the human, or when
step 4 calls the PR production-ready.

## 4. Judge convergence

There is no fixed round limit. After each round's push, and before its summary comment, judge
whether review is converging, and act on it. One of three calls:

**No trend yet:** an early round, or the findings point no clear way. Re-request the reviewer and
run another round.

**Not converging:** each round finds new *real* defects in different areas, fixes keep drawing fresh
findings, or the PR is too large to reason about as a whole. Split it, if a sensible split exists:

1. Run only `implement-as-stack`'s carving and publishing steps, with the PR's current head as the
   integration branch. The work is already built, and this judgement stands in for its
   plan-approval step, so go straight to cutting. Cut slices of one concern each, readable in under
   twenty minutes, with the risky part on its own.
2. Prove the top of the new stack equals the old head.
3. Close the old PR, with links to the slices, and restack whatever was stacked above it (step 5).
4. Run the loop again on each slice.

Tell the human after the split, with the new PR table and its merge order.

**Converging:** what remains is nits, speculative edge cases, test-name or wording items, or repeats
of settled points. Make the production-ready call: don't re-request the reviewer, give each
remaining item a one-line disposition on its thread, and hand the PR off as ready. A PR that can't
usefully split (about one file, or one concern) ends here too.

No call skips a real bug, a security gap, or a data-integrity issue: those are fixed whatever the
round. The call and its reason go in the round's summary comment (step 3, item 6).

## 5. Keep the stack true

Once the stack is in review, these rules govern restacks; `implement-as-stack` restacks the same
way. Never cascade-rebase: a rebase replays commits a squash-merge already landed, and it moves heads
the reviewer has already reviewed.

- **Conflicts:** use `resolving-merge-conflicts`. When a squash-merge retargets a PR, merge the
  trunk in, keeping the PR's side where it builds on the merged slice.
- **Clean restacks:** use the forge's update-branch on each PR in stack order, waiting for each head
  to move before starting the next. Hand-dispatch CI on any PR whose base isn't the trunk.
- **Re-review:** request the reviewer again only when the PR's own diff changed. Compare patch-ids
  (verbatim, per step 2), not heads.

## 6. Red checks

Use `diagnosing-bugs`. First decide whose failure it is: **yours**, or a **red trunk** that every PR
inherits.

- **Red trunk:** fix it in its own PR, first. A red trunk usually blocks every deploy.
- **Fix the cause.** Change the code or a genuinely stale test; never weaken an assertion to pass.
  A behaviour bug goes through `tdd`: reproduce the failure in a test before changing the code, or,
  when no automated test can express it, with the check that exposed it.
- **CI-only paths:** when only CI exercises a path (a production build's prerender, for example),
  reproduce it with the production build locally before pushing a fix.

## 7. Hand-off

Before calling anything ready, run the checks that prove it and quote their output: the fast check
and the production build after any restack, and the PR's CI on its head. "Should pass" is not a
status. `verification-before-completion` is the gate for every such claim, here and in step 3.

Give the human a table (PR, what it does, head, CI, reviewer status) and the **exact merge order**.
Never merge.

## 8. Advance the stack on merge

When the watcher reports `PR N MERGED`, it has already dropped N from its list. Advance the next PR
in the merge order without being asked:

1. **Bring it up to date.** A squash-merge retargets it to the trunk. Merge the trunk in: use the
   forge's update-branch when it's clean, or `resolving-merge-conflicts` when it isn't.
2. **Confirm** it's mergeable and not dirty.
3. **Restack the rest** in order (step 5).
4. **Reviewer state:** compare its diff's patch-id with the head the reviewer last reviewed.
   - Unchanged: comment that the diff is identical.
   - Changed: run step 3 for it.
5. **Wait for CI to pass on its new head.**

Report "PR N is next and ready", or exactly what blocks it, then carry on watching.

Done when the next PR is mergeable, green, and reviewed in step 2's sense, or its blocker is
reported.

## 9. Production

A merge is not a deploy. Read [PRODUCTION.md](PRODUCTION.md) whenever the change crosses a
repository boundary, adds a flag, migrates or backfills data, or changes what a live system serves.
It covers deploy order, live verification, flags, one-off scripts, and close-out.

Done when the change is verified on the live system and the tickets, worktrees, branches, and your
own processes are closed out.

## Running as several agents

Read [COORDINATION.md](COORDINATION.md) before splitting this work across agents.
