#!/usr/bin/env bash
# SPDX-License-Identifier: 0BSD
#
# Branch protection as data.
#
# CONTRIBUTING.md, AGENT_RULES.md and the wiki all stated that direct
# pushes to master were blocked and that a PR needed green CI to merge.
# The API reported no protection and no rulesets: nothing on the server
# would have stopped a red merge or a direct push. Documentation
# describing a guarantee the infrastructure does not provide is worse
# than none, because it stops people checking.
#
# So the required-check set lives HERE, in a file that gets reviewed in a
# pull request, instead of in a console nobody can diff.
#
#   scripts/branch_protection.sh verify   # report drift, exit 1 if any
#   scripts/branch_protection.sh apply    # idempotent PATCH
#   scripts/branch_protection.sh show     # print the live configuration
#
# `verify` is safe to run anywhere and is what CI should call. `apply`
# mutates the repository and is a deliberate, manual act.

set -euo pipefail

REPO="${REPO:-fdittgen-png/deskilo}"
BRANCH="${BRANCH:-master}"
API="repos/${REPO}/branches/${BRANCH}/protection"

# ---------------------------------------------------------------------
# The source of truth.
#
# These are CHECK CONTEXTS — the `name:` GitHub reports for a job, not the
# workflow name and not the job id. `ci.yml`'s single job carries a
# display name, so that whole string is the context. Get one character
# wrong and protection waits forever for a status that never arrives.
# `show` prints what the branch last reported, which is how to confirm a
# name before adding it here.
# ---------------------------------------------------------------------
TARGET_CHECKS=(
  "analyze · l10n gate · test · coverage"
)

# Deliberately NOT required, with reasons — an advisory workflow that
# becomes a required check blocks every unrelated merge the first time its
# infrastructure hiccups:
#   android-boot  builds a release APK and boots an emulator (~15 min, and
#                 a flaky SDK download has already failed it once)
#   web · windows-msi · macos-app
#                 platform packaging; they run on PRs touching their own
#                 target, so they are not reported on most pull requests,
#                 and a required check that is never reported never passes
#   play-* · ios-*
#                 outward-facing publishing, dispatch-only
#
# STRICT MODE IS OFF ON PURPOSE. Strict requires every branch to be up to
# date with the base before merging. With no merge queue, each merge puts
# every other open PR out of date and they all re-run CI — quadratic churn
# for no correctness benefit when the changes are file-disjoint. The trade
# is accepting the small risk of a semantic conflict between two
# independently-green branches. The corollary is a merge discipline:
# serialise merges rather than arming several at once.
STRICT=false

usage() {
  cat <<'EOF'
Branch protection as data.

  scripts/branch_protection.sh verify   # report drift, exit 1 if any
  scripts/branch_protection.sh apply    # idempotent PUT (mutates the repo)
  scripts/branch_protection.sh show     # print the live configuration

verify is safe anywhere and is what CI calls (advisory). apply is a
deliberate, manual act. REPO/BRANCH env vars override the defaults.
EOF
  exit 64
}

show() {
  echo "Live protection on ${REPO}@${BRANCH}:"
  if ! gh api "$API" > /dev/null 2>&1; then
    echo "  (none — the branch is unprotected)"
    echo
    echo "Contexts most recently reported on ${BRANCH}, for reference:"
    gh api "repos/${REPO}/commits/${BRANCH}/check-runs" \
      --jq '.check_runs[].name' 2>/dev/null | sort -u | sed 's/^/  /'
    return 0
  fi
  gh api "$API" --jq '{
    strict: .required_status_checks.strict,
    contexts: .required_status_checks.contexts,
    enforce_admins: .enforce_admins.enabled,
    required_reviews: .required_pull_request_reviews,
    allow_force_pushes: .allow_force_pushes.enabled,
    allow_deletions: .allow_deletions.enabled
  }'
}

verify() {
  # 404 means unprotected; 403 means THIS TOKEN cannot read protection at
  # all (reading it needs repo admin, which the default Actions token does
  # not have). Conflating the two makes CI shout "NO protection" the day
  # after protection was applied — the exact false alarm this script
  # exists to prevent.
  local resp
  if ! resp=$(gh api "$API" 2>&1); then
    if grep -qiE "HTTP 404|not protected|not found" <<< "$resp"; then
      echo "::error::${REPO}@${BRANCH} has NO branch protection." >&2
      echo "Expected required checks:" >&2
      printf '  %s\n' "${TARGET_CHECKS[@]}" >&2
      echo "Run: $0 apply" >&2
      return 1
    fi
    echo "::warning::cannot READ branch protection with this token" \
      "(needs repo admin) — run '$0 verify' locally to check for drift." >&2
    return 0
  fi
  # $resp already holds the whole protection JSON — parse it locally
  # instead of two more authenticated round-trips (this runs on every PR
  # push via the advisory CI step).
  local drift=0 drift_diff
  if ! drift_diff=$(diff -u \
      <(printf '%s\n' "${TARGET_CHECKS[@]}" | sort) \
      <(jq -r '.required_status_checks.contexts[]?' <<< "$resp" | sort)); then
    echo "::error::required-check drift (-committed +live):" >&2
    echo "$drift_diff" >&2
    drift=1
  fi
  local live_strict
  live_strict=$(jq -r '.required_status_checks.strict' <<< "$resp")
  if [ "$live_strict" != "$STRICT" ]; then
    echo "::error::strict mode is '$live_strict', committed target is '$STRICT'." >&2
    drift=1
  fi

  # The rename trap: protection and this script can agree with each other
  # while ci.yml's job name has moved on — every PR then wedges on a
  # status no job ever reports again, and a protection-vs-target diff
  # cannot see it. So also assert every required context is a name some
  # workflow job still carries.
  if [ -d .github/workflows ]; then
    local ctx
    for ctx in "${TARGET_CHECKS[@]}"; do
      if ! grep -rqF "name: ${ctx}" .github/workflows/; then
        echo "::error::required check '${ctx}' matches NO job name under" \
          ".github/workflows/ — a renamed job would wedge every PR on a" \
          "status that never arrives." >&2
        drift=1
      fi
    done
  fi

  [ "$drift" -eq 0 ] && echo "branch_protection: live configuration matches the committed target"
  return "$drift"
}

apply() {
  local contexts
  contexts=$(printf '%s\n' "${TARGET_CHECKS[@]}" | jq -R . | jq -s .)
  gh api -X PUT "$API" --input - <<JSON
{
  "required_status_checks": { "strict": ${STRICT}, "contexts": ${contexts} },
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_linear_history": true,
  "required_conversation_resolution": true
}
JSON
  echo "branch_protection: applied to ${REPO}@${BRANCH}"
  verify
}

case "${1:-}" in
  verify) verify ;;
  apply)  apply ;;
  show)   show ;;
  *)      usage ;;
esac
