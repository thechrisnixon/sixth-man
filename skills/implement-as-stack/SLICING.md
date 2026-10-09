# Slicing

Reference for step 2 of `implement-as-stack`: how a finished branch is carved into slices a
reviewer reads bottom-up in under twenty minutes each.

## Order: tiers

A slice's place in the stack is decided by what its files are, lowest tier first, because a
reviewer wants the thing everything else compiles against before the thing that uses it:

1. **Foundations** — migrations and their generated snapshots, schema, enums, constants, shared
   types. A migration stays in a slice of its own with only what it needs to compile: reviewers
   read DDL with different eyes, and a tiny slice is the point.
2. **Domain** — server-side services, queries, pure utilities: the rules, with no transport.
3. **Background work** — tasks, jobs, schedules.
4. **Routes** — API handlers. A route whose payload keeps its shape but changes meaning moves to a
   versioned path in the same slice, per the repo's rule on payload meaning.
5. **Client services** — fetch wrappers and their types.
6. **Surfaces** — components, hooks, pages.

Tests ride with the code they exercise. Glossary and doc entries ride with the slice that introduces
the term. Generated files ride with their source and never count toward size.

## Risk: isolate the hard part

A slice holds one concern. When the change has a risky one, such as a transaction, an auth or
role boundary, token or credential handling, or a migration, that concern gets a slice of its own
with its tests, even under the size budget. A risky slice that reaches the review cap is the one
`ship` splits next, so keep its routine neighbours out of it from the start.

## Order: dependencies

Within the tiers, a file's slice is the earliest slice whose own files plus every slice below
contain everything it imports. Read the import statements; a repo alias such as `@/` names the file
directly. No slice imports from a slice above it.

A slice may leave code with no caller yet — a task before the route that triggers it, a hook before
the component that renders it — when the next slice wires it. Say so in the pull request body.
Dead code the stack never wires is a sign the file belongs in a later slice, or in no slice.

## Size: budget

- Up to 300 non-test lines per slice; 500 is the ceiling.
- Tests do not count, but a slice whose tests push it past about 900 lines in total is too big to
  read in one sitting and splits along a tier boundary inside it.
- A slice under about 30 lines merges into its neighbour, unless it is the migration or an
  isolated risky concern (see Risk above).
- A risky concern that alone exceeds the ceiling splits along its own seams, not into its routine
  neighbours: each piece stays a risky slice of its own.

## Surgery

When one file belongs to two slices — a route that gains a verb, a form that gains a prop, a
component whose new branch needs a hook from later — the earlier slice carries the file **without**
the later addition and the later slice restores the whole file. Check the full file out of the
integration branch, delete the later function, prop or import, rerun that slice's gates, and let
the later slice's diff show the addition exactly.

Surgery is deletion of whole units. When splitting a file needs logic rewritten, the boundary is in
the wrong place: move it.

## Verification

Each slice, on its own branch, passes the repo's gates at CI strictness for what changed: the
whole-project typecheck, lint and format over the slice's files, and the suites the slice adds or
touches plus any neighbour that imports them. The invariant across the stack is that the top slice's
tree equals the integration branch: `git diff --stat <integration-branch>` from the top is empty.

## Naming and prose

- Branches: `<user>/<ticket>-<n>-<slug>`, numbered bottom to top.
- Titles: the imperative outcome, then `(<TICKET>, n of N)`.
- Bodies: what the slice delivers, which file to read first, what the next slice adds, what the
  reviewer should know about any code left without a caller, and the decision-log entries that
  touch the slice.

## A worked example

A ticket that added a release status and a way to move a server between builds came out as seven
slices: the status enum and its migration; the approval rules that treat the new status like the
old one; the pin that writes the status, with its route moved to a versioned path; the background
task that relaunches the server; the route that queues that task; the admin card's control and its
shared cache hook; the list-row actions that reuse both. The task and the route were separate
slices because the task was 275 lines with its tests and needed no caller to be reviewed; the two
surfaces were separate because the second reused the first's hook. One file, the route, needed
surgery: slice three carried it without the new verb, slice five restored it whole.
