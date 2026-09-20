#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
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
#   scripts/branch_protection.sh verify        # report drift, exit 1 if any
#   scripts/branch_protection.sh apply-checks  # required checks only
#   scripts/branch_protection.sh apply         # the whole protection object
#   scripts/branch_protection.sh show          # print the live configuration
#
# `verify` is safe to run anywhere and is what CI should call. The two
# `apply` commands mutate the repository and are a deliberate, manual
# act; prefer `apply-checks`, which changes the required-check list and
# leaves every other protection setting alone.

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
  # #1244 — the job that runs the l10n gate, analyze and the suite. It
  # kept this name when ci.yml folded into `CI · Quality report`,
  # because the name IS the required context and a rename makes every
  # pull request unmergeable until protection is updated in lockstep.
  "analyze · l10n gate · test · coverage"
  # The database half of the same workflow, and the report that carries
  # the complete result. #1446: these sat here unapplied, and on
  # 2026-09-20 four pull requests — #1569, #1571, #1573, #1574 — merged
  # into master with `quality · database` AND `quality · report` red (a
  # stale `assets/instance/contract.txt` after migration 0255). A gate
  # nobody has to pass reports; it does not protect.
  #
  # They are safe to require because `quality.yml` triggers on
  # `pull_request:` with NO path filter, so both contexts report on every
  # pull request — including one the classifier stands the database job
  # down for, which reports `not_applicable` rather than staying silent.
  # A required context that is sometimes not reported would wedge every
  # such PR forever.
  "quality · database"
  "quality · report"
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

  scripts/branch_protection.sh verify        # report drift, exit 1 if any
  scripts/branch_protection.sh apply-checks  # PATCH the required checks only
  scripts/branch_protection.sh apply         # PUT the whole protection object
  scripts/branch_protection.sh show          # print the live configuration

verify is safe anywhere and is what CI calls (advisory). The apply
commands are a deliberate, manual act; apply-checks changes the
required-check list and nothing else, apply resets every unlisted
setting. REPO/BRANCH env vars override the defaults.
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

# The surgical half of `apply`: the required-check LIST, and nothing
# else. `apply` below PUTs the whole protection object, which means every
# field it does not name is reset — including `required_pull_request_reviews`
# and `restrictions`, which it sends as null. That is correct for a
# branch whose protection this file owns entirely, and wrong the moment
# somebody adds a review rule in the console (#1446: "do not use it
# blindly where existing protections must be retained").
#
# This PATCHes the dedicated required_status_checks sub-resource, so
# reviews, restrictions, linear history, force-push and deletion settings
# are untouched by construction rather than by remembering to list them.
apply_checks() {
  local contexts
  contexts=$(printf '%s\n' "${TARGET_CHECKS[@]}" | jq -R . | jq -s .)
  gh api -X PATCH "${API}/required_status_checks" --input - > /dev/null <<JSON
{ "strict": ${STRICT}, "contexts": ${contexts} }
JSON
  echo "branch_protection: required checks set on ${REPO}@${BRANCH}:"
  gh api "${API}/required_status_checks" --jq '.contexts[]' | sed 's/^/  /'
  verify
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
  verify)       verify ;;
  apply)        apply ;;
  apply-checks) apply_checks ;;
  show)         show ;;
  *)            usage ;;
esac
