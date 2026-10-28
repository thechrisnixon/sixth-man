---
name: implement-as-stack
description: "Take a ticket through test-first implementation and ship it as a GitHub stack of small, dependency-ordered pull requests — migrations and shared types first, each one reviewable in under twenty minutes, with each risky concern in a slice of its own. Use when the user says to build a ticket and ship it as a stack, when a ticket will change more than a reviewer can read in one sitting, or when a finished branch needs carving into reviewable pull requests."
---

# Implement as a stack

One ticket in, one **stack** of pull requests out. Each pull request is a **slice** of the change:
ordered so a reviewer reads the foundations before what is built on them, sized so a reviewer
reads it in **under twenty minutes**, and chained so every pull request's diff is only its own
slice. Each risky concern (a transaction, an auth boundary, token handling) gets a slice of its own
with its tests: a reviewer can only attend to the hard part when nothing routine surrounds it.
The chain is plain pull requests: each slice's base is the slice below it, and the bottom slice's
base is the trunk. A native stack tool, such as the `gh stack` extension, can hold the same chain,
but on GitHub a native stack refuses base changes and update-branch on its entries, which blocks
the restacks a review loop needs. Use one only when the repo has chosen it, and then use it
throughout; mixing the two is where the friction comes from.

The stack is carved from a finished, green branch. Building slice by slice from the start lets the
slice boundaries steer the design, and the reviewer then reads boundaries instead of the change.

## 1. Build it whole

Cut an **integration branch** from the trunk and run `/implement` on the ticket there, test-first:
every behaviour change goes through `/tdd`, red before green at pre-agreed seams, so each one
lands with a test that was red before it. Behaviour no automated test can express, such as a
failure only a production build shows, is proven with the check that exposes it instead.
`/implement` closes with `/code-review`; fix what the review finds. (`/implement` and `/tdd` come
from [mattpocock/skills](https://github.com/mattpocock/skills); without them, build test-first by
hand the same way, then run `/code-review`.)

Keep a **decision log** as you build, outside the repository: one line per judgement call, such as
a reading of an ambiguous requirement, a trade-off taken, an alternative rejected, or a departure
from the spec or design, each with its reason. A reviewer can't see a road not taken in a diff; the
log is how the call reaches them, in step 4.

Done when the integration branch typechecks, every suite it touches passes, the review's findings
are fixed or recorded as accepted, and the working tree is clean.

## 2. Carve the slice plan

Read [SLICING.md](SLICING.md), then write the plan: an ordered list of slices, each naming its
files, what it delivers, its non-test line count, and the slice it depends on. Every changed file
lands in exactly one slice; a generated file rides with its source; a test rides with the code it
exercises. Where one file serves two slices, the plan names the **surgery** that splits it.

Present the plan as a numbered list — title, delivers, files, size, depends on — and ask whether
the granularity and the order are right. Wait for the answer.

Done when the user has approved the plan, no slice's files import from a later slice, and no slice
is over budget.

## 3. Cut the branches

Work in a fresh worktree on the trunk; the integration branch is only ever read from.

1. Branch the bottom slice from the trunk, and each later slice from the slice below it
   (`git switch -c <branch-n> <branch-n-1>`), so every branch is based on the one below.
2. On each branch, `git checkout <integration-branch> -- <the slice's files>`, apply the slice's
   surgery, and run the repo's gates at CI strictness for what changed: the whole-project
   typecheck, the linter and formatter over the slice's files, and the suites the slice adds or
   touches. Commit with a message that says why the slice exists, not what files it holds.
3. A slice that goes red is fixed by moving a file to an earlier slice, never by writing code the
   integration branch does not have.

Done when every slice commit is green on its own and `git diff --stat <integration-branch>` from
the top of the stack is empty. Claim each of those only with the output of the command that proves
it, run fresh, per `verification-before-completion`.

## 4. Publish the stack

Push every branch, then open one pull request per slice with its base set to the branch below it
(`gh pr create --base <branch-n-1> --head <branch-n>`; the bottom slice's base is the trunk). Give
each its real title and body: the title is the imperative outcome plus `(<TICKET>, n of N)`; the
body carries a table of the whole stack in merge order, and says what the
slice delivers, which file to read first, what the next slice adds when this one leaves code
with no caller yet, and the decision-log entries that touch this slice. Add the labels the repo's
CI gates on, when the repo's conventions say to: a repo may hold the label for its expensive jobs
back until a slice is next to merge, so the full run happens once, on the head that merges. Attach
the pull requests to the ticket.

Confirm a check run exists on each pull request. A workflow whose pull-request trigger filters on
the base branch (`branches: [main]`) runs nothing for a slice whose base is another slice; the
lasting fix is to drop that filter, and until then dispatch the workflow on that branch by hand and
say so on the pull request.

Only a **merge commit** keeps a merged slice's commits identical, so that the forge retargets the
slice above with nothing to restack. A squash merge, and on GitHub a rebase-and-merge too, gives
the merged slice new commits, so each slice above needs a restack before it merges (step 5). Use
whichever merge method the repo has chosen, and expect that restack unless it is merge commits.

Done when every slice has an open pull request with its title, a body naming its place in the
stack, the labels the repo's conventions call for at this point, and a check run underway.

## 5. Keep the stack true

Once the stack is published, restack the way `ship` step 5 says the repo or the human chose: by
merging, which keeps reviewed heads stable, or by `git rebase --onto <new base> <old base head>`
per slice with `--force-with-lease`, which keeps each pull request's diff to its own commits.
`ship` owns the review loop and these restacks in full. The short form:

- A review finding lands on the slice it belongs to as an ordinary commit. Then each layer above
  takes the one below, in stack order, by the chosen method, as one batch of pushes;
  `resolving-merge-conflicts` when it doesn't apply cleanly.
- After each merge to the trunk, GitHub retargets the next pull request. Unless the repo merges
  with merge commits, the merged slice landed as new commits, so bring the next one onto the trunk.
  Restack the layers above it the same way, now or as each comes up; the repo's conventions say
  which. Restacking every layer restarts every layer's CI.
- When the trunk moves under the stack (a migration slot taken, a conflict), resolve on the bottom
  open slice first — regenerate a migration into the free slot rather than renumbering by hand —
  then restack upward.
- Merging is the reviewer's call under the repo's rules. When the last slice merges, close the
  ticket with every pull request linked.

Done when the last pull request is merged, the ticket is closed, and the stack has no open entry.
