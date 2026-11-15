#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #4044 -- the total of a branch check whose paths ran side by side.
#
#   <verdict lines on stdin> | scripts/branch_check_total.py <paths asked> <run conclusion>
#
# Reads the lines the paths' verdict steps printed (one `BRANCH CHECK: ...
# [path]` per path, each followed by the names of its failed tests) and
# prints one total line first:
#
#   BRANCH CHECK: ok -- 7076 passed, 4 skipped (8 paths)
#   BRANCH CHECK: FAILED -- 7070 passed, 6 failed, 4 skipped (2 of 8 paths)
#
# then, for a failure, each failing path's own line and its names. A path
# that printed no verdict (its job was cancelled or ran out of time) is a
# failure that says how many are missing; so is a run that did not end in
# success although every verdict read ok. Exit 0 only for an ok total.
import re
import sys

_VERDICT = re.compile(
    r"^BRANCH CHECK: (ok|FAILED) -- (?:(\d+) passed)?(?:, (\d+) failed)?"
    r"(?:, no test ran)?(?:, (\d+) skipped)?"
)


def main() -> int:
    asked, conclusion = int(sys.argv[1]), sys.argv[2]
    passed = failed = skipped = 0
    paths, bad = 0, []
    current = None
    for raw in sys.stdin:
        line = raw.rstrip("\n")
        match = _VERDICT.match(line)
        if match:
            paths += 1
            passed += int(match.group(2) or 0)
            failed += int(match.group(3) or 0)
            skipped += int(match.group(4) or 0)
            current = [line] if match.group(1) == "FAILED" else None
            if current is not None:
                bad.append(current)
        elif line.startswith("- ") and current is not None:
            current.append(line)
    missing = max(asked - paths, 0)
    if not bad and not missing and conclusion == "success":
        print(f"BRANCH CHECK: ok -- {passed} passed, {skipped} skipped ({paths} paths)")
        return 0
    reasons = [f"{failed} failed"]
    if missing:
        reasons.append(f"{missing} of {asked} paths gave no verdict")
    if not bad and not missing:
        reasons.append(f"the run ended {conclusion}")
    print(
        f"BRANCH CHECK: FAILED -- {passed} passed, {', '.join(reasons)}, "
        f"{skipped} skipped ({len(bad)} of {asked} paths)"
    )
    for block in bad:
        for line in block:
            print(line)
    return 1


if __name__ == "__main__":
    sys.exit(main())
