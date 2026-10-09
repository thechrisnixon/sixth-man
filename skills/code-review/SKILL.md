---
name: code-review
description:
  Deep multi-angle code review of a PR or branch diff with risk triage, conditional finder
  routing, and adversarial verification of findings. Use when the user asks to review a PR,
  review a branch, code-review changes, or audit a diff before merge. This is the on-demand deep
  layer — an automated PR reviewer is the always-on layer; this skill goes wider and verifies
  before reporting.
---

# Code Review

Review a diff the way a careful staff engineer would in one sitting: triage risk first, run the
finder angles the diff actually calls for, then adversarially verify so only real findings reach
the report. Findings name a concrete failure scenario, not a style opinion.

## Phase 0 — Scope, context, risk triage

1. Gather the diff: `git diff origin/main...HEAD` for a branch, or the PR's branch if a PR
   number/URL was given. Include uncommitted changes when reviewing pre-commit.
2. Load the authoritative convention layers **before** hunting — findings that contradict these
   files are wrong by definition: the repo's `AGENTS.md` or `CLAUDE.md` (and anything it
   includes), its rules directory (for example `.claude/rules/*` or `.cursor/rules/*`), and any design doc those files
   declare as source of truth (the doc wins — flag divergence, don't silently pick a side).
3. **Risk-triage the diff** before allocating effort. Risk is never inferred from diff size —
   Heartbleed was two lines.
   - **HIGH**: auth/authz, crypto, secrets handling, external calls, money/value paths,
     removed validation or guards, migrations/DDL, RLS/permissions
   - **MEDIUM**: business logic, state machines, new public APIs/exports, error handling
   - **LOW**: comments, docs, tests-only, logging, UI copy
   - Depth scales with the highest risk present and the codebase's size: small diffs in HIGH
     areas get full dependency tracing; large LOW-risk diffs get sampling plus the always-on
     angles.

## Phase 1 — Finder angles (routed by diff content)

Run angles as parallel subagents when available, sequentially otherwise. **Route, don't blanket**:

| Angle | Runs when |
| --- | --- |
| Line-by-line | always |
| Removed-behavior audit | the diff deletes or replaces lines (almost always) |
| Cross-file tracer | exports/signatures/contracts changed |
| Reuse / simplification / efficiency | new modules or >~100 added lines |
| Altitude (right depth, not a bandaid) | changes touch shared infrastructure or add special cases |
| Test coverage | behavior added/changed, or tests deleted/weakened |
| Team checklist sweep | when the repo keeps a cross-cutting review checklist (migrations, env vars, permissions, …), per its triggers |

Each angle surfaces candidates as `file`, `line`, one-line `summary`, and a concrete
`failure_scenario`. Pass every candidate with a nameable failure scenario to Phase 2 — silently
dropping half-believed candidates is the dominant cause of missed bugs; Phase 2 exists so
finders don't self-censor.

Angle definitions:

- **Line-by-line** — read every hunk, then the full enclosing function. For each line: what
  input, state, timing, or platform makes it wrong? Inverted conditions, off-by-one,
  null/undefined deref, missing await, falsy-zero, swallowed errors, wrong-variable copy-paste.
- **Removed behavior** — for every deleted/replaced line, name the invariant it enforced and
  find where the new code re-establishes it. Diff against the old file
  (`git show origin/main:<path>`), not memory.
- **Cross-file tracer** — for each changed export, grep all callers and **quantify blast
  radius**: 1–5 callers, read each call site; 6–50, read the risky ones and sample the rest;
  50+, treat the change as HIGH risk regardless of triage and say so in the finding. Check new
  preconditions, changed return shapes, changed error types/messages callers may match on.
- **Reuse / simplification / efficiency** — code that re-implements an existing helper (grep
  shared modules first), derivable state, copy-paste variation, dead code, speculative surface
  with zero callers (YAGNI), wasted work, per-request allocations that accumulate.
- **Altitude** — is each change at the right depth? Special cases layered on shared
  infrastructure mean the fix isn't deep enough. Conventions enforced by comments should usually
  be mechanisms (a type, a constraint, a lint rule, a config list).
- **Test coverage** — for each new/changed behavior, find the test that would fail if the
  behavior regressed; no such test is a candidate. For each deleted or loosened test, name the
  case that lost coverage (removed-behavior's twin, applied to the test suite). Flag tests that
  assert the mock instead of the behavior.

## Phase 2 — Verify

Dedup, then verify each candidate. **Restate the claim first** — root cause, trigger condition,
impact — before judging it; half of false positives collapse at the restatement step. Then
classify **CONFIRMED / PLAUSIBLE / REFUTED**:

- PLAUSIBLE by default — realistic-but-unproven states (races, rare error paths, cold caches,
  retry storms) stay in.
- REFUTED only when constructible from the code: factually wrong (quote the line), provably
  impossible (show the type/constant/guard), already handled in this diff, or pure style with no
  observable effect.
- For migrations and DB claims, verify **empirically** against the local database when one is
  available — run the DDL, fire the constraint, exercise the trigger. Generated-column and
  immutability claims in particular cannot be verified by reading.
- No shortcuts: a verifier that didn't read the surrounding code hasn't verified anything.

### Never flag (drop before reporting, whatever an angle surfaced)

- Pre-existing issues the diff didn't introduce or re-expose — note them aside if severe, never
  as findings against the PR
- Issues a linter/typechecker/formatter in the repo's CI will catch
- Pedantic nitpicks a senior engineer would not raise
- Code that looks like a bug but is correct (the verify pass must prove the failure, not the smell)
- Style preferences not backed by the repo's convention files
- Anything explicitly silenced by a lint-ignore comment with a rationale

## Output

Report CONFIRMED findings always; PLAUSIBLE findings only when the failure scenario is concrete
enough that a reviewer could reproduce the reasoning (when in doubt on a quick review, drop it;
on a thorough review, ship it labeled). Rank by severity: `file:line`, summary, failure
scenario, verdict. Distinguish "fix now" from "accepted behavior change" — and record accepted
changes in the PR description so they read as decisions, not oversights. Close with what was
checked and found clean — reviewers need to know coverage, not just catches.

If asked to fix: apply fixes, re-run the repo's gates **at CI strictness** (the repo's lint
script with its warning budget, format check over everything including generated files, a
dead-code check where present), and note each finding's resolution (fixed / accepted / deferred-with-reason) in
the PR.

## Comments are part of the review

The repo's ``AGENTS.md`` carries the comment conventions this codebase
holds -- read that section and hold the diff to it. They are easy to skip
because a comment never fails a test, and they are exactly the thing a
review is for.

What they ask for, in short: comments explain *why*, not what, since one
that restates the code is noise; a ticket, PR or issue id in a comment
duplicates what ``git blame`` already links and rots when the tracker
moves; a rationale is stated once rather than repeated across call sites;
and a TODO names what and why with its exit condition, not a bare "fix".
The repo's own file is the authority -- this is a pointer to it, not a
replacement.

Judge new comments and comments the diff leaves stale. A comment that no
longer describes the code it sits above is a defect, and the change that
outdated it is where it should have been caught.
