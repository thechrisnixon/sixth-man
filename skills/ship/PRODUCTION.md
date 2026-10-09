# Production

What `ship` does after the merge. The human approves every deploy, flag change, and data write;
your job is to make each one a single, verified action.

## Deploy order

When one repository serves another (a data or analytics service, a shared schema, an API another
app calls), the provider deploys first. Ship the provider's change additively: new columns, pipes,
endpoints, or datasources beside the old ones, never renames or removals. The consumer then reads
something that already exists, and an old consumer keeps working through the window.

State the order explicitly in the hand-off ("deploy the provider, then merge the consumer"), and
make the consumer degrade honestly while the provider lags: an "unavailable" state, never a
silently empty or zero result that reads as real data.

## Verify live

After each deploy, check the live system read-only:

- An endpoint, pipe, or query the change added answers, and returns real rows for a real tenant.
- The deploy actually ran. A merged change sitting behind a pending or failed pipeline is not live.
  Check the pipeline's status, not only the merge.
- A database read against production runs in a session you've set read-only and confirmed with
  `SHOW`. A connection-string parameter can be dropped by a pooler.

"It does not exist" or a stale result after a merge usually means the deploy didn't run. Check the
pipeline before debugging the code.

## Flags

A change that alters what users see ships behind a flag that defaults to off. The human flips it.
Gate before anything renders: a loading boundary or shell that streams before the flag is read can
leak the new experience to a tenant with the flag off.

## One-off data scripts

A backfill or repair is a script, run from its branch. It doesn't need to merge unless the human
wants it on record.

- **Dry run by default.** It prints what it would write (counts per day, per category, in total) and
  writes nothing. Writing takes an explicit `--apply`.
- **Idempotent.** It uses deterministic ids, skips rows already written, and skips anything the live
  system already recorded. Running it twice changes nothing.
- **Reads production read-only.** The read transaction is checked, not assumed.
- **Scoped credentials.** A read token scoped to an endpoint can't run ad-hoc SQL on the tables
  beneath it. Name the exact scope each step needs.
- **Kept separate from live data.** It writes to its own table or datasource, so existing readers
  aren't silently changed and the backfill can be removed.

You run the dry run when you can, and the human reviews its numbers and runs `--apply`. Afterwards,
verify the row count, and that a second dry run finds nothing left to write.

## Close out

- Close each ticket with its pull requests linked.
- Remove a finished worktree only when its branch head is the merged PR's head and `git status`
  shows nothing uncommitted. Any other difference, deletions included, is work: ask before
  removing it.
- Stop the dev servers you started, by process ID.
- Remind the human to delete any credential file they created for the run.
