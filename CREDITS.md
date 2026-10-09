# Credits

`ship` was written by Chris Nixon and is MIT-licensed (see [LICENSE](LICENSE)). It borrows from the
work below. Each entry says whether files were **vendored** (copied into this repository) or an
idea was **adapted** (written here in our own words), along with its licence.

## Vendored

| Source | Files | Licence | Notes |
|---|---|---|---|
| [obra/superpowers](https://github.com/obra/superpowers), © 2025 Jesse Vincent | `skills/verification-before-completion/SKILL.md` | MIT ([text](licenses/LICENSE.obra-superpowers-MIT)) | Copied unmodified from upstream commit `8ca22dba9a94f28898bbce59f2537ff4d87c747d`. |

## Adapted ideas

| Source | Licence | What it shaped |
|---|---|---|
| [obra/superpowers](https://github.com/obra/superpowers) `receiving-code-review` | MIT | `ship`'s verify step: check findings against the code rather than the reviewer's framing, push back with evidence, and escalate only when a fix would reverse one of the human's decisions. |
| [obra/superpowers](https://github.com/obra/superpowers) `requesting-code-review` | MIT | Running self-review in a fresh context rather than the author's session. |
| [obra/superpowers](https://github.com/obra/superpowers) `subagent-driven-development` | MIT | `implement-as-stack`'s decision log of judgement calls. |
| [trailofbits/skills](https://github.com/trailofbits/skills) `pr-improver` | CC BY-SA 4.0 | The idea of stopping a review loop on "no critical or major findings" rather than "no comments". No text was copied. |
| [mattpocock/skills](https://github.com/mattpocock/skills) | MIT | The skill-writing conventions these skills follow, and the `tdd` / `implement` flow `implement-as-stack` builds on. |
| [GitHub Copilot code review docs](https://docs.github.com/en/copilot/concepts/agents/code-review) | — | How the AI reviewer is requested, billed, and keyed to commits. |

## Optional companions (not included)

`ship` names these skills and works better with them installed. They aren't bundled here; get them
from their own repositories, under their own licences.

| Skill | Source | Licence |
|---|---|---|
| `tdd`, `implement`, `resolving-merge-conflicts`, `diagnosing-bugs` | [mattpocock/skills](https://github.com/mattpocock/skills) | MIT |
| `differential-review` | [trailofbits/skills](https://github.com/trailofbits/skills) | CC BY-SA 4.0 (its ShareAlike terms are why it's linked, not bundled) |
