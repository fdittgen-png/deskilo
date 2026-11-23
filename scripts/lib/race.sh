#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# What the race scripts share (#4400): the query helper and the comparison. Source it
# (`. "$(dirname "${BASH_SOURCE[0]}")/lib/race.sh"`) after the database url is set.
#
#   q SQL            one statement on the race database ($RACE_URL, else $url), the script fails on an error;
#                    $RACE_PGOPTIONS and the RACE_LIMIT array (a timeout wrapper) are optional
#   expect LABEL GOT WANT   the script fails, saying what it got, when GOT is not WANT

q() {
  PGOPTIONS="${RACE_PGOPTIONS:-${PGOPTIONS:-}}" ${RACE_LIMIT[@]+"${RACE_LIMIT[@]}"} \
    psql "${RACE_URL:-$url}" -X -qAt -v ON_ERROR_STOP=1 -c "$1"
}
expect() { [[ "$2" == "$3" ]] || { echo "::error::$1: expected '$3', got '$2'" >&2; exit 1; }; }
