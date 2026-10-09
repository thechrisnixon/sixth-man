# ship

A Claude Code skill that takes a ticket from a stack of small pull requests to production, and
treats **review** as the main job.

AI agents made writing code cheap. A single ticket can become thousands of lines in an afternoon.
What didn't get cheaper is reviewing it: catching the bug on line 400, keeping a stack of PRs
mergeable as they land, and knowing when a PR is actually done. `ship` is the workflow I use to
manage that.

## What it does

- **Builds in reviewable slices.** `implement-as-stack` carves a finished branch into a stack of
  PRs, each readable in under twenty minutes, with each risky concern (a transaction, an auth
  boundary, token handling) in a slice of its own.
- **Runs a review loop gated on the head commit.** A review only counts if it ran on the PR's
  current head. Agents will report that "the reviewer found nothing" about a commit that has since
  changed.
- **Self-reviews before every push.** After fixing the AI reviewer's findings, the agent reviews the
  whole PR with `code-review`, not just its fix. In practice this catches bugs the AI reviewer never
  flags.
- **Fixes test-first.** Each finding is reproduced as a failing test before the fix.
- **Judges convergence instead of counting rounds.** If each round finds new real problems in new
  places, the PR is too big, so it is split into a smaller stack. If only nits are left, the agent
  calls it production-ready and stops asking. Real bugs and security issues are always fixed.
- **Advances the stack as PRs merge.** When one PR merges, the next is brought up to date, the rest
  are restacked by merging (never rebasing), the reviewer is re-requested only if the PR's own diff
  changed, and you're told which PR is ready next.
- **Treats a merge as not yet a deploy.** Deploy order across repos, verifying the live system,
  flags that default to off, and one-off data scripts that dry-run first are part of done.
- **Never merges.** You merge, approve deploys, and flip flags. The skill makes each of those a
  single, verified action.

## What's in the box

| Skill | Role |
|---|---|
| [`ship`](skills/ship/SKILL.md) | The workflow: review loop, splitting, restacks, hand-off, production. Includes a PR watcher script. |
| [`implement-as-stack`](skills/implement-as-stack/SKILL.md) | Build a ticket, then carve it into a stack of small, ordered PRs. |
| [`code-review`](skills/code-review/SKILL.md) | The deep self-review: risk triage, routed review angles, and adversarial verification of each finding. |
| [`verification-before-completion`](skills/verification-before-completion/SKILL.md) | Vendored unmodified from [obra/superpowers](https://github.com/obra/superpowers): evidence before any claim of "done". |

`ship` also names a few optional companions from [mattpocock/skills](https://github.com/mattpocock/skills)
(`tdd`, `implement`, `resolving-merge-conflicts`, `diagnosing-bugs`) and
[trailofbits/skills](https://github.com/trailofbits/skills) (`differential-review`). Install them
for the full experience; without them, the skill says how to do each step directly.

## Requirements

- [Claude Code](https://code.claude.com)
- The [GitHub CLI](https://cli.github.com) (`gh`), authenticated, and `jq`
- An AI pull-request reviewer. The watcher defaults to GitHub Copilot code review
  (`copilot-pull-request-reviewer[bot]`); set `REVIEW_BOT` to use another.
- Stacked pull requests: the [`gh stack`](https://github.com/github/gh-stack) extension, or plain
  branches based on one another.
- An `AGENTS.md` or `CLAUDE.md` in your repo naming your fast check, production build, the CI label
  that gates expensive jobs (if any), and how you deploy. The skills refer to these by role.

## Install

As a plugin, from this repository's marketplace:

```bash
claude plugin marketplace add thechrisnixon/claude-ship
claude plugin install ship@claude-ship
```

The skills then run as `/ship:ship`, `/ship:implement-as-stack`, and so on.

Or copy the skills you want into your project's `.claude/skills/` directory (or `~/.claude/skills/`
for every project).

## Quick start

1. In a repo with an `AGENTS.md` or `CLAUDE.md`, ask: *"Ship this ticket as a stack"*, and paste the
   ticket.
2. Approve the slice plan when `implement-as-stack` asks.
3. The agent opens the PRs, requests the AI reviewer, and starts the watcher:

   ```bash
   skills/ship/scripts/watch-prs.sh owner/repo prs.txt
   ```

   `prs.txt` lists one PR number per line. Run it under a monitor; each printed line is an event:
   a merge, a conflict, a failed check, or a new review on the head.
4. Merge in the order the agent gives you. After each merge, it brings the next PR up to date and
   tells you when it's ready.

## Credits

`ship` stands on other people's work. See [CREDITS.md](CREDITS.md) for what was vendored, what
inspired an idea, and each licence.

## License

[MIT](LICENSE) © 2026 Chris Nixon. Vendored files keep their own licences, listed in
[CREDITS.md](CREDITS.md) and stored in [`licenses/`](licenses/).
