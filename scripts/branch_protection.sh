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
#
# #1446 — THREE OUTCOMES, never two: `show` printed "(none — the branch
# is unprotected)" for any answer it could not parse, and `verify` warned
# and exited 0 when the token could not READ protection, so a green step
# was citable as proof the settings were right. Every command now ends on
# one `result=` line — verified-match (0), verified-drift (1, a branch
# read as unprotected included), unverified-access (2, 403 or no answer)
# — and `verify --advisory` prints it while still exiting 0.

set -euo pipefail

REPO="${REPO:-fdittgen-png/deskilo}"
BRANCH="${BRANCH:-master}"
API="repos/${REPO}/branches/${BRANCH}/protection"
# The API client, as a seam: the tests drive this real script with a
# stub answering 200/404/403/no-answer, touching no setting.
GH="${GH:-gh}"

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

verify is safe anywhere and is what CI calls; `verify --advisory` always
exits 0 but still reports its result. The apply commands are a
deliberate, manual act; apply-checks ADDS the committed contexts to the
live ones, apply replaces the whole object and refuses to run over
protection it has not read. Exit: 0 verified-match, 1 verified-drift,
2 unverified-access, 64 usage. REPO/BRANCH/GH override the defaults.
EOF
  exit 64
}

# 404 means verifiably unprotected; 403 means THIS TOKEN cannot read
# protection at all (that needs repo admin, which the Actions token does
# not have); anything else is no answer. Conflating them is how a checker
# reports a guarantee it never inspected.
PROT_STATE=''  # readable | absent | forbidden | unreachable
PROT_BODY=''
PROT_DETAIL=''

read_protection() {
  local resp rc=0
  resp=$("$GH" api "${1:-$API}" 2>&1) || rc=$?
  PROT_BODY='' PROT_DETAIL=''
  if [ "$rc" -eq 0 ]; then PROT_STATE=readable PROT_BODY="$resp"; return 0; fi
  PROT_DETAIL=$(printf '%s' "$resp" | tr '\n' ' ' | cut -c1-200)
  PROT_STATE=unreachable
  if grep -qiE "HTTP 404|not protected|not found" <<< "$resp"; then PROT_STATE=absent; fi
  if grep -qiE "HTTP 40[13]|not accessible|must have admin" <<< "$resp"; then PROT_STATE=forbidden; fi
  return 0
}

# The single line every command ends on, and the exit status that carries
# the same fact to a caller that reads statuses rather than output.
outcome() {
  local result="$1"; shift
  echo "branch_protection: result=${result} — $*"
  [ -z "${GITHUB_OUTPUT:-}" ] || echo "result=${result}" >> "$GITHUB_OUTPUT"
  [ -z "${GITHUB_STEP_SUMMARY:-}" ] ||
    echo "\`${REPO}@${BRANCH}\`: **${result}** — $*" >> "$GITHUB_STEP_SUMMARY"
  case "$result" in
    verified-match) return 0 ;;
    verified-drift) return 1 ;;
    *) return 2 ;;
  esac
}

show() {
  echo "Live protection on ${REPO}@${BRANCH}:"
  read_protection
  case "$PROT_STATE" in
    absent)
      echo "  (none — I READ the branch and it is unprotected)"
      echo
      echo "Contexts most recently reported on ${BRANCH}, for reference:"
      "$GH" api "repos/${REPO}/commits/${BRANCH}/check-runs" 2>/dev/null |
        jq -r '.check_runs[].name' 2>/dev/null | sort -u | sed 's/^/  /' || true
      ;;
    readable)
      jq '.required_status_checks as $c | {
        strict: $c.strict,
        contexts: ([$c.checks[]?.context, $c.contexts[]?] | unique),
        apps: [$c.checks[]? | select(.app_id) | {context, app_id}],
        enforce_admins: .enforce_admins.enabled,
        required_reviews: .required_pull_request_reviews,
        allow_force_pushes: .allow_force_pushes.enabled,
        allow_deletions: .allow_deletions.enabled
      }' <<< "$PROT_BODY" ;;
    *)
      echo "  (UNREADABLE — ${PROT_DETAIL})"
      echo "  This is NOT 'unprotected': the settings here are unknown."
      outcome unverified-access "the protection object could not be read" ||
        return $? ;;
  esac
}

verify() {
  local advisory=0 rc=0
  [ "${1:-}" != '--advisory' ] || advisory=1
  verify_once || rc=$?
  if [ "$advisory" -eq 1 ] && [ "$rc" -ne 0 ]; then
    echo "::warning::this step is advisory and exits 0; the result= line" \
      "above is the fact, and only 'verified-match' is settings proof." >&2
    return 0
  fi
  return "$rc"
}

verify_once() {
  read_protection
  case "$PROT_STATE" in
    absent)
      echo "::error::${REPO}@${BRANCH} has NO branch protection. Expected:" >&2
      printf '  %s\n' "${TARGET_CHECKS[@]}" >&2
      echo "Run: $0 apply" >&2
      outcome verified-drift "the branch was read and is unprotected"
      return $? ;;
    forbidden)
      echo "::warning::cannot READ branch protection with this token" \
        "(needs repo admin) — run '$0 verify' locally to check for drift." >&2
      outcome unverified-access "HTTP 403: nothing was checked — ${PROT_DETAIL}"
      return $? ;;
    unreachable)
      echo "::warning::the protection API did not answer — ${PROT_DETAIL}" >&2
      outcome unverified-access "no answer: nothing was checked"
      return $? ;;
  esac
  # $PROT_BODY already holds the whole protection JSON — parse it locally
  # instead of two more authenticated round-trips (this runs on every PR
  # push via the advisory CI step).
  # Every context the live object requires, however it spells them:
  # modern `checks[]` binds each to an app, legacy `contexts[]` does not,
  # and a real response carries both.
  local drift=0 ctx live
  live=$(jq -r '.required_status_checks
    | [.checks[]?.context, .contexts[]?] | unique | .[]' <<< "$PROT_BODY")
  for ctx in "${TARGET_CHECKS[@]}"; do
    if ! grep -qxF "$ctx" <<< "$live"; then
      echo "::error::required check MISSING from live protection: ${ctx}" >&2
      drift=1
    fi
  done
  # A context the live object requires and this file does not name is
  # deliberately NOT drift: `apply-checks` keeps it, and `show` lists it.
  # Calling it drift invites somebody to "fix" it by deleting a
  # protection nobody here owns.
  local live_strict
  live_strict=$(jq -r '.required_status_checks.strict' <<< "$PROT_BODY")
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

  if [ "$drift" -eq 0 ]; then
    outcome verified-match "read it: every committed check is required"
  else
    outcome verified-drift "read it: it does not match the committed target"
  fi
  return $?
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
#
# It is also ADDITIVE (#1446): sending this file's list as THE list would
# drop a context somebody required in the console, drop the app binding
# that says which app may report it, and reset strictness. So it reads
# the live sub-resource and sends live ∪ committed, live entries winning,
# at the live strictness.
apply_checks() {
  read_protection "${API}/required_status_checks"
  local live='[]' strict="$STRICT" targets body
  case "$PROT_STATE" in
    readable)
      live=$(jq -c '[(.checks[]? | {context, app_id}),
                     (.contexts[]? | {context: ., app_id: null})]
                    | unique_by(.context)' <<< "$PROT_BODY")
      strict=$(jq -r '.strict' <<< "$PROT_BODY") ;;
    absent)
      echo "::error::no protection object to patch — run '$0 apply' first." >&2
      outcome verified-drift "the branch was read and is unprotected"
      return $? ;;
    *)
      echo "::error::cannot read the current required checks — ${PROT_DETAIL}" >&2
      echo "Refusing to PATCH a list built from a response I could not read." >&2
      outcome unverified-access "nothing was read, so nothing was written"
      return $? ;;
  esac
  targets=$(printf '%s\n' "${TARGET_CHECKS[@]}" |
    jq -R '{context: ., app_id: null}' | jq -sc .)
  # unique_by keeps the first of each group and jq's sort is stable, so a
  # live entry (with its app binding) survives its committed twin.
  body=$(jq -nc --argjson live "$live" --argjson targets "$targets" \
    --argjson strict "$strict" \
    '{strict: $strict, checks: ($live + $targets | unique_by(.context))}')
  "$GH" api -X PATCH "${API}/required_status_checks" --input - > /dev/null \
    <<< "$body"
  [ "$strict" = "$STRICT" ] || echo "::warning::kept live strict=${strict};" \
    "the committed target is ${STRICT}. Changing it is a separate act." >&2
  echo "branch_protection: required checks set on ${REPO}@${BRANCH}:"
  jq -r '.checks[] | "  \(.context)\(if .app_id then " (app \(.app_id))" else "" end)"' \
    <<< "$body"
  verify
}

# The blunt command: a PUT of the WHOLE protection object, which resets
# every field it does not name. #1446: it therefore never runs over a
# configuration it has not read — not over a 403, not over settings
# somebody expanded. It reads first and refuses, naming `apply-checks`;
# `apply --reset` is the deliberate override.
apply() {
  read_protection
  case "$PROT_STATE" in
    readable)
      if [ "${1:-}" != '--reset' ]; then
        echo "::error::${REPO}@${BRANCH} is already protected, and a PUT" \
          "sends null for every field this file does not name: reviews," \
          "restrictions and any context '$0 show' lists would be RESET." >&2
        echo "Use '$0 apply-checks' (additive), or '$0 apply --reset'." >&2
        outcome verified-drift "refused: the live object would be replaced"
        return $?
      fi ;;
    forbidden | unreachable)
      echo "::error::cannot read the current protection — ${PROT_DETAIL};" \
        "refusing to overwrite settings I could not see." >&2
      outcome unverified-access "nothing was read, so nothing was written"
      return $? ;;
  esac
  local contexts
  contexts=$(printf '%s\n' "${TARGET_CHECKS[@]}" | jq -R . | jq -s .)
  "$GH" api -X PUT "$API" --input - <<JSON
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

cmd="${1:-}"
shift || true
case "$cmd" in
  verify)       verify "$@" ;;
  apply)        apply "$@" ;;
  apply-checks) apply_checks ;;
  show)         show ;;
  *)            usage ;;
esac
