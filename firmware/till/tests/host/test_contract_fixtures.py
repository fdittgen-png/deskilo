#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Exercise the production C++ decoder and arithmetic through shared wire cases."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile


def main():
    executable = Path(sys.argv[1]).resolve()
    root = Path(__file__).resolve().parents[4]
    fixture = root / "contracts/embedded_till/v1/fixtures"
    checked = 0

    def check(expected, *arguments):
        nonlocal checked
        result = subprocess.run([str(executable), *arguments], check=True,
                                text=True, capture_output=True).stdout.strip()
        assert result == expected, (arguments, expected, result)
        checked += 1

    check("ok", "embedded")
    cases = json.loads((fixture / "decimal_cases.json").read_text())
    for operation in ("minor", "quantity"):
        for case in cases[operation]:
            check(case["expected"] or "invalid", operation, case["input"])
    for case in cases["line"]:
        check(case["expected"] or "invalid", "line", case["unit_minor"], case["quantity"])
    for case in json.loads((fixture / "profile_cases.json").read_text()):
        check(case["expected"], "profile", str(fixture / case["file"]))

    valid = (fixture / "profile_valid.json").read_bytes().rstrip()
    profile = json.loads(valid)
    with tempfile.TemporaryDirectory(prefix="terminal-contract-") as directory:
        path = Path(directory) / "profile.json"

        def profile_case(expected, content):
            path.write_bytes(content if isinstance(content, bytes) else json.dumps(content, ensure_ascii=False).encode())
            check(expected, "profile", str(path))

        profile_case("ok", valid + b" " * (16384 - len(valid)))
        profile_case("payload_too_large", valid + b" " * (16385 - len(valid)))
        profile_case("invalid_json", valid + b"{}")
        profile_case("invalid_json", valid[:-1])
        profile_case("invalid_json", valid.replace(b'"revision":1', b'"revision":01'))
        profile_case("invalid_json", valid.replace(b'"revision":1', b'"revision":1.'))
        profile_case("invalid_json", valid.replace(b'"revision":1', b'"revision":1e'))
        profile_case("invalid_json", b'\x0b' + valid)
        profile_case("invalid_json", valid.replace(b'"Caf\xc3\xa9"', b'"Cafe\nline"'))
        profile_case("invalid_profile", valid.replace(b'"revision":1', b'"revision":1,"revision":1'))
        profile_case("invalid_json", b'\0' + valid)
        profile_case("invalid_json", valid.replace(b'"Caf\xc3\xa9"', b'"Cafe\\u0000hidden"'))
        profile_case("invalid_utf8", valid.replace(b'\xc3\xa9', b'\xc0\xaf'))
        profile_case("invalid_utf8", valid.replace(b'\xc3\xa9', b'\xed\xa0\x80'))
        profile_case("invalid_json", valid.replace(b'"Caf\xc3\xa9"', b'"\\ud800"'))
        profile_case("invalid_json", valid.replace(b'"Caf\xc3\xa9"', b'"\\udfff"'))
        profile_case("capacity_exceeded", b"[" * 13 + b"]" * 13)
        maximum = copy.deepcopy(profile)
        maximum["pages"] = []
        for page in range(12):
            keys = []
            for index in range(8):
                key = copy.deepcopy(profile["pages"][0]["keys"][0])
                key["item_id"] = f"00000000-0000-0000-0000-{page * 8 + index:012x}"
                keys.append(key)
            maximum["pages"].append({"number": page + 1, "keys": keys})
        profile_case("ok", json.dumps(maximum, ensure_ascii=False, separators=(",", ":")).encode())
        overflow = copy.deepcopy(profile)
        overflow["pages"][0]["keys"] = maximum["pages"][0]["keys"] + [maximum["pages"][1]["keys"][0]]
        profile_case("capacity_exceeded", overflow)
        overflow = copy.deepcopy(profile)
        overflow["pages"] = [{"number": n + 1, "keys": []} for n in range(13)]
        profile_case("capacity_exceeded", overflow)
        fractional = copy.deepcopy(profile)
        fractional["pages"][0]["keys"][0]["quantity"] = "0.350000"
        fractional["pages"][0]["keys"][0]["gross_minor"] = "9007199254740993"
        profile_case("ok", fractional)
    print(f"terminal contract: {checked} production-consumer cases passed")


if __name__ == "__main__":
    main()
