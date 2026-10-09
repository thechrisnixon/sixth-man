# Coordinating several agents

When `ship` fans out across agents (one per ticket, slice, or PR), these rules keep them from
colliding. The coordinator holds the watcher and the merge order; each worker holds one lane.

- **One lane per agent.** An agent owns its pull requests and its worktree, and touches nothing
  else. An issue spotted on another agent's PR goes to the coordinator, not into a push.
- **Your own processes only.** Stop a process by the ID you recorded when you started it. A
  pattern-matched kill reaches other agents' checks, servers, and watchers.
- **Fresh context for review.** Run self-review in a subagent that receives the diff and the repo's
  conventions, not your session. The author's context carries the author's blind spots.
- **Verify reports.** An agent's "done", "clean", or "reviewed" is a claim. Check it against the
  artifact: the diff, the head commit's review, the check run.
- **Stop on credentials.** A signing, SSH-agent, or password-manager error stops the push. Report it
  to the human, and leave signing configuration exactly as it is.
- **Reviewer quota.** When the AI reviewer answers that the requester has reached a quota, the
  round's gate becomes your self-review alone. Note that on the PR, and tell the human, since quota
  is a billing setting only they can change.
- **Long runs.** An agent near its turn limit hands its state (PR table, heads, open threads, what's
  uncommitted where) to a fresh agent rather than resuming a context too full to reason in.
