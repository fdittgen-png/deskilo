#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# #4015 -- the verdict of a branch check, from the test runner's JSON stream.
#
#   scripts/branch_check_summary.py <stream.jsonl> <exit code of the run>
#
# Prints one verdict line and, when tests failed, their names (file first):
#
#   BRANCH CHECK: ok -- 1234 passed, 3 skipped
#   BRANCH CHECK: FAILED -- 1230 passed, 4 failed, 3 skipped (exit 1)
#   - test/features/x_test.dart: the name of the test
#
# A stream that is missing or has no test in it is a failure with its reason:
# a run that compiled nothing must not read as a pass.
import json
import sys


def main() -> int:
    path, code = sys.argv[1], sys.argv[2]
    suites, tests, failed = {}, {}, []
    passed = skipped = 0
    try:
        with open(path, encoding="utf-8") as stream:
            for line in stream:
                line = line.strip()
                if not line.startswith("{"):
                    continue
                try:
                    event = json.loads(line)
                except ValueError:
                    continue
                kind = event.get("type")
                if kind == "suite":
                    suites[event["suite"]["id"]] = event["suite"].get("path") or "?"
                elif kind == "testStart":
                    test = event["test"]
                    tests[test["id"]] = (
                        suites.get(test.get("suiteID"), "?"),
                        test.get("name", "?"),
                    )
                elif kind == "testDone":
                    if event.get("hidden"):
                        continue
                    if event.get("skipped"):
                        skipped += 1
                    elif event.get("result") == "success":
                        passed += 1
                    else:
                        failed.append(tests.get(event["testID"], ("?", "?")))
    except OSError as error:
        print(f"BRANCH CHECK: FAILED -- no test stream ({error.strerror}); exit {code}")
        return 0
    if code == "0" and not failed and passed > 0:
        print(f"BRANCH CHECK: ok -- {passed} passed, {skipped} skipped")
        return 0
    reason = "no test ran" if passed == 0 and not failed else f"{len(failed)} failed"
    print(
        f"BRANCH CHECK: FAILED -- {passed} passed, {reason}, "
        f"{skipped} skipped (exit {code})"
    )
    for suite, name in failed[:200]:
        print(f"- {suite}: {name}")
    if len(failed) > 200:
        print(f"- ... and {len(failed) - 200} more")
    return 0


if __name__ == "__main__":
    sys.exit(main())
