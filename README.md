# sixth-man

The sixth man comes off the bench and makes the whole team better. These skills do that for coding
agents: they are plain Markdown instructions that any agent able to read skills can load and follow.

## Why

Coding agents have made writing code close to effortless, and a single ticket can now turn into
thousands of lines in an afternoon. What has not become any cheaper is reviewing that code: catching
the bug buried on line 400, keeping a stack of pull requests mergeable as they land, and knowing when
a pull request is genuinely done. Review is the bottleneck, so these skills treat it as the main job
rather than an afterthought, and they keep each change small enough that a person can actually take
in what was written and make sense of it.

## Skills

| Skill | What it does |
|---|---|
| [`ship`](skills/ship/SKILL.md) | Takes a ticket from a stack of small pull requests to production: an AI-reviewer loop gated on the head commit, a self-review before every push, splitting pull requests whose review won't converge, advancing the stack as pull requests merge, and a verified rollout. Includes a pull-request watcher script. |
| [`implement-as-stack`](skills/implement-as-stack/SKILL.md) | Builds a ticket test-first, then carves it into a stack of small, dependency-ordered pull requests, each reviewable in under twenty minutes with its riskiest concern in a slice of its own. |
| [`code-review`](skills/code-review/SKILL.md) | A deep self-review of a diff: risk triage, review angles routed by what the diff touches, and adversarial verification of each finding before it is reported. |
| [`verification-before-completion`](skills/verification-before-completion/SKILL.md) | Vendored unmodified from [obra/superpowers](https://github.com/obra/superpowers): run the command that proves a claim before making it. |

`ship` also names a few optional companions from [mattpocock/skills](https://github.com/mattpocock/skills)
(`tdd`, `implement`, `resolving-merge-conflicts`, `diagnosing-bugs`) and
[trailofbits/skills](https://github.com/trailofbits/skills) (`differential-review`). They are worth
installing alongside, but each step also says how to proceed without them.

## How `ship` works

`implement-as-stack` builds the ticket and splits it into small pull requests. From there, `ship`
drives each one through review. A review only counts when it ran on the pull request's current head
commit, because agents will otherwise report that "the reviewer found nothing" about code that has
since changed. After fixing the AI reviewer's findings, test-first, the agent reviews the whole pull
request itself before pushing, which in practice catches problems the AI reviewer never raises.

Rather than stopping after a fixed number of rounds, the agent judges whether review is converging.
When each round turns up new and genuine problems in different places, the pull request is too large,
so it is split into a smaller stack; when only nits remain, the agent calls it production-ready and
stops requesting reviews. Real bugs and security issues are always fixed. As each pull request
merges, the next one is brought up to date, the rest are restacked by merging rather than rebasing,
and you are told which one is ready. A merge is not treated as a deploy: deploy order across repos,
verification against the live system, flags that default to off, and one-off data scripts that
dry-run first are all part of being done. The skills never merge on your behalf; you merge, approve
deploys, and flip flags.

## Requirements

- An agent that can read Markdown skills (see Install below).
- The [GitHub CLI](https://cli.github.com) (`gh`), authenticated, and `jq`.
- An AI pull-request reviewer. The watcher defaults to GitHub Copilot code review
  (`copilot-pull-request-reviewer[bot]`); set `REVIEW_BOT` to use another reviewer's login.
- Optionally, a stacking tool such as the [`gh stack`](https://github.com/github/gh-stack) extension;
  plain branches based on one another work too.
- An `AGENTS.md` (or your agent's equivalent, such as `CLAUDE.md`) naming your fast check, production
  build, any CI label that gates expensive jobs, and how you deploy. The skills refer to these by role.

## Install

Each skill is a folder under `skills/` with a `SKILL.md` and any supporting files. Install the ones
you want for your agent.

### Claude Code

As a plugin, from this repository's marketplace:

```bash
claude plugin marketplace add thechrisnixon/sixth-man
claude plugin install sixth-man@sixth-man
```

The skills then run as `/sixth-man:ship`, `/sixth-man:implement-as-stack`, and so on. Alternatively,
copy the skill folders into your project's `.claude/skills/` directory, or into `~/.claude/skills/`
to use them in every project.

### Codex and other OpenAI agents

Copy the skill folders into your agent's skills directory (for example `~/.codex/skills/`). Each
skill ships an `agents/openai.yaml` with its display name and invocation policy, and the skills read
your repo's `AGENTS.md` for project-specific commands.

### Cursor and other agents

Copy the skill folders into your repo, for example under `skills/`, and point your agent at them from
its instructions file (`AGENTS.md`, a Cursor rule, or equivalent), such as: "When shipping a ticket,
follow `skills/ship/SKILL.md`."

### Any agent that reads Markdown skills

The skills are plain Markdown with YAML front matter (`name` and a `description` that says when to
use them), so any agent that loads skills or follows referenced instructions can use them unchanged.

## Quick start

1. In a repo with an `AGENTS.md`, ask your agent: *"Ship this ticket as a stack"*, and paste the
   ticket.
2. Approve the slice plan when `implement-as-stack` asks for it.
3. The agent opens the pull requests, requests the AI reviewer, and starts the watcher:

   ```bash
   skills/ship/scripts/watch-prs.sh owner/repo prs.txt
   ```

   `prs.txt` lists one pull-request number per line. Run the script under a monitor; each line it
   prints is an event: a merge, a conflict, a failed check, or a new review on the head commit.
4. Merge in the order the agent gives you. After each merge it brings the next pull request up to
   date and tells you when it is ready.

## Credits

These skills build on other people's work. [CREDITS.md](CREDITS.md) lists what was vendored, what
inspired an idea, and each licence.

## License

[MIT](LICENSE) © 2026 Chris Nixon. Vendored files keep their own licences, listed in
[CREDITS.md](CREDITS.md) and stored in [`licenses/`](licenses/).
