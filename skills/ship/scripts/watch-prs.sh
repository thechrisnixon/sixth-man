#!/usr/bin/env bash
# Watches a set of open pull requests and prints one line per change worth
# acting on: a merge or close, a conflict, a failed check, or a new review
# from the AI reviewer on the current head. Run it under a monitor; each line
# is an event. Merged and closed PRs are removed from the list.
#
# Requires: gh (authenticated) and jq.
#
# Usage: watch-prs.sh <owner/repo> <pr-list-file>
#   pr-list-file   one PR number per line; edit it while the watcher runs
# Environment:
#   REVIEW_BOT     reviewer login (default copilot-pull-request-reviewer[bot])
#   WATCH_INTERVAL seconds between sweeps (default 120)
#   WATCH_STATE    directory for "already reported" markers (default: beside the list)
set -u

REPO="${1:?usage: watch-prs.sh <owner/repo> <pr-list-file>}"
LIST="${2:?usage: watch-prs.sh <owner/repo> <pr-list-file>}"
BOT="${REVIEW_BOT:-copilot-pull-request-reviewer[bot]}"
INTERVAL="${WATCH_INTERVAL:-120}"
STATE="${WATCH_STATE:-$(dirname "$LIST")/.watch-state}"
mkdir -p "$STATE"

# Report once per head: a marker file holds the head SHA last reported.
seen() { [ "$(cat "$STATE/$1" 2>/dev/null)" = "$2" ]; }
mark() { echo "$2" > "$STATE/$1"; }
# Each endpoint's failure is tracked on its own, so one staying down never
# reads as the other recovering.
recovered() { if [ -s "$STATE/$1" ]; then echo "WATCHER RECOVERED on $2"; : > "$STATE/$1"; fi; }

while true; do
  while read -r PR; do
    [ -z "$PR" ] && continue
    # A failed read is reported once per distinct error, so an unattended
    # watcher never mistakes expired auth or an outage for a quiet sweep.
    if ! J=$(gh pr view "$PR" -R "$REPO" \
      --json state,headRefOid,mergeable,mergeStateStatus,statusCheckRollup 2>&1); then
      ERR=$(head -c 200 <<<"$J" | tr '\n' ' ')
      seen "$PR.view-error" "$ERR" || { echo "WATCHER ERROR on PR $PR: $ERR"; mark "$PR.view-error" "$ERR"; }
      continue
    fi
    recovered "$PR.view-error" "PR $PR"
    # A merged or closed PR leaves the list, so the next sweep watches only
    # what is still in flight; MERGED is the cue to advance the stack.
    STATUS=$(jq -r .state <<<"$J")
    if [ "$STATUS" != "OPEN" ]; then
      echo "PR $PR $STATUS"
      # grep exits 1 when it removes the last line; the list is still right.
      { grep -vx "$PR" "$LIST" || true; } > "$LIST.tmp" && mv "$LIST.tmp" "$LIST"
      continue
    fi
    HEAD=$(jq -r .headRefOid <<<"$J")

    # DIRTY catches conflicts that `mergeable` still reports as UNKNOWN.
    if [ "$(jq -r .mergeable <<<"$J")" = "CONFLICTING" ] || [ "$(jq -r .mergeStateStatus <<<"$J")" = "DIRTY" ]; then
      seen "$PR.conflict" "$HEAD" || { echo "PR $PR CONFLICTING at ${HEAD:0:9}"; mark "$PR.conflict" "$HEAD"; }
    fi

    # A check fails when no run of that name succeeded and one ended badly.
    # Grouping by name keeps a duplicate run cancelled beside a passing one
    # from reading as a failure.
    FAILED=$(jq -r '
      [.statusCheckRollup[]? | {name: (.name // .context), result: (.conclusion // .state)}]
      | group_by(.name)
      | map(select(
          (map(.result) | any(. == "SUCCESS" or . == "NEUTRAL" or . == "SKIPPED")) | not
        ) | select(
          map(.result) | any(. == "FAILURE" or . == "ERROR" or . == "TIMED_OUT" or . == "CANCELLED"
            or . == "ACTION_REQUIRED" or . == "STARTUP_FAILURE" or . == "STALE")
        ) | .[0].name)
      | join(", ")' <<<"$J")
    # Keyed by head and the failing set, so a new failure on the same commit,
    # or a retry failing again after a pass, is reported too.
    if [ -n "$FAILED" ]; then
      seen "$PR.ci" "$HEAD $FAILED" || { echo "PR $PR CI FAILED at ${HEAD:0:9}: $FAILED"; mark "$PR.ci" "$HEAD $FAILED"; }
    else
      : > "$STATE/$PR.ci" 2>/dev/null
    fi

    # Reports reviews of the current head. Whether a restacked PR is still reviewed is judged by
    # patch-id, per SKILL.md step 2; this only reports.
    R=$(gh api "repos/$REPO/pulls/$PR/reviews" --jq "
      [.[] | select(.user.login == \"$BOT\")] as \$all
      | [\$all[] | select(.commit_id == \"$HEAD\")] as \$onHead
      | if (\$onHead | length) == 0 then empty else
          \"\(\$onHead[-1].id)\t\(\$all | length)\t\" + ((\$onHead[-1].body // \"\") | split(\"\n\") | map(select(startswith(\"### \") or test(\"quota limit\"))) | first // \"reviewed\")
        end" 2>&1) || {
      ERR="reviews: $(head -c 200 <<<"$R" | tr '\n' ' ')"
      seen "$PR.review-error" "$ERR" || { echo "WATCHER ERROR on PR $PR $ERR"; mark "$PR.review-error" "$ERR"; }
      R=""
      continue
    }
    recovered "$PR.review-error" "PR $PR reviews"
    # Keyed by the review's own id: a re-review of an unchanged head is news.
    REVIEW_ID=${R%%$'\t'*}
    R=${R#*$'\t'}
    if [ -n "$REVIEW_ID" ] && ! seen "$PR.review" "$REVIEW_ID"; then
      ROUND=${R%%$'\t'*}
      echo "PR $PR reviewed on ${HEAD:0:9}: ${R#*$'\t'} (bot review #$ROUND)"
      mark "$PR.review" "$REVIEW_ID"
    fi
  done < "$LIST"
  sleep "$INTERVAL"
done
