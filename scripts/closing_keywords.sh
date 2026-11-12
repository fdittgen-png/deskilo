#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# The issues a pull request's BODY closes that its TITLE does not
# (scripts/merge_check.sh). GitHub closes every issue named after a closing
# keyword anywhere in the title or the body, also in a sentence about
# another pull request ("the second pull request closes #N"): #3675 was
# closed that way by #3802, which only referred to it. The title is the one
# place a pull request states what it closes, so a closing keyword in the
# body for an issue the title does not close is a slip.
#
#   source scripts/closing_keywords.sh
#   stray_closes "<title>" "<body>"   # prints the numbers, one per line

closing_pattern='(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved):?[[:space:]]+#[0-9]+'

closed_issues() {
  printf '%s\n' "$1" | grep -ioE "$closing_pattern" | grep -oE '[0-9]+$' | sort -u || true
}

stray_closes() {
  comm -23 <(closed_issues "$2") <(closed_issues "$1")
}
