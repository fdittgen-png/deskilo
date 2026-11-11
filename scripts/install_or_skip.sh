#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #3739 -- a small tool a NON-REQUIRED workflow needs from the package mirror.
# Already on the runner: nothing to do. Otherwise it is installed, with
# retries. When the mirror stays unreachable on a pull request the job says
# that it checked nothing and lets the workflow skip the steps that need the
# tool (`available=false` in $GITHUB_OUTPUT): an outage of the mirror is not a
# finding about the change. On every other event the job fails as before, so
# master is never reported as checked when it was not.
#
#   scripts/install_or_skip.sh <command> <package>
set -uo pipefail

cmd="${1:?the command to look for}"
pkg="${2:?the package that provides it}"
out="${GITHUB_OUTPUT:-/dev/null}"
pause="${INSTALL_RETRY_PAUSE_SECONDS:-20}"

if command -v "$cmd" >/dev/null 2>&1; then
  echo "available=true" >> "$out"
  exit 0
fi

for attempt in 1 2 3; do
  if sudo apt-get -o Acquire::Retries=3 update -q &&
    sudo apt-get -o Acquire::Retries=3 install -y --no-install-recommends "$pkg"; then
    echo "available=true" >> "$out"
    exit 0
  fi
  echo "attempt $attempt to install $pkg failed"
  [ "$attempt" = 3 ] || sleep $((attempt * pause))
done

if [ "${GITHUB_EVENT_NAME:-}" = "pull_request" ]; then
  echo "::warning title=Nothing was checked::$cmd could not be installed (package mirror unreachable); this job checked nothing for this change."
  {
    echo "### Nothing was checked"
    echo "\`$cmd\` could not be installed: the package mirror was unreachable. The steps that need it were skipped."
  } >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
  echo "available=false" >> "$out"
  exit 0
fi

echo "::error::$cmd could not be installed: the package mirror is unreachable."
exit 1
