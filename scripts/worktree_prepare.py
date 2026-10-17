#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Check worktree prerequisites; resolve packages only with explicit --resolve.

No database is started, reset, seeded or modified. SessionStart emits context
only: it must stay fast and usable even on a machine without the toolchain.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote, urljoin, urlparse

SESSION_CONTEXT = (
    "Deskilo execution: read issue #2596 and its latest corrections, then only "
    "the selected leaf and current .agent-work claims. Keep at most two active "
    "coding workstreams; preserve an existing claim. Finish the current real "
    "consumer and its success/refusal/recovery tests before unrelated breadth. "
    "Before code, run python3 scripts/worktree_prepare.py (check-only); "
    "--resolve explicitly initializes packages. Database-dependent work must "
    "name --require-database or --database-ci and its actual test evidence. "
    "Run preflight --list, implicated generators, analyze, lint and affected "
    "tests before pushing; retain original exits and review generated diffs. "
    "Do not run a full local suite. Deterministic CI failures need a corrected "
    "candidate; superseded runs stay cancelled; one justified infrastructure "
    "retry only. Implemented, verified and released are different. Close a "
    "leaf when its own acceptance is verified, not when its entire parent is "
    "finished. No automatic release, hosted writes or permission changes. "
    "This hook supplied instructions only; no tools, tests or setup were run."
)


class PreparationError(RuntimeError):
    """A prerequisite failed; do not silently narrow verification."""


def run_command(args: list[str], cwd: Path, timeout: float = 10) -> str:
    # Do not print command output: it may contain a private dependency URL.
    try:
        result = subprocess.run(args, cwd=cwd, capture_output=True,
                                text=True, encoding="utf-8", errors="strict",
                                timeout=timeout, check=False)
    except (OSError, subprocess.TimeoutExpired, UnicodeError) as exc:
        kind = "timed out" if isinstance(exc, subprocess.TimeoutExpired) else "could not run"
        raise PreparationError(f"{Path(args[0]).name}: {kind}; inspect the named local command") from exc
    if result.returncode != 0:
        raise PreparationError(f"{Path(args[0]).name}: exit {result.returncode}; inspect the named local command")
    # Dart SDK builds may write the version banner to stderr. Only this
    # metadata probe combines streams; JSON and NUL-delimited readers do not.
    return result.stdout + result.stderr if args == ["dart", "--version"] else result.stdout


def nul_paths(root: Path, *args: str) -> list[str]:
    return [p for p in run_command(["git", *args], root).split("\0") if p]


def package_roots(root: Path) -> list[Path]:
    paths = nul_paths(root, "ls-files", "-z", "--", "pubspec.yaml",
                      "packages/**/pubspec.yaml")
    selected = [p for p in paths if p == "pubspec.yaml" or
                (len(Path(p).parts) == 3 and Path(p).parts[0] == "packages")]
    if "pubspec.yaml" not in selected:
        raise PreparationError("tracked root pubspec.yaml is missing")
    result = []
    for path in sorted(set(selected), key=lambda p: (p != "pubspec.yaml", p)):
        file = root / path
        if not file.is_file() or not file.resolve().is_relative_to(root):
            raise PreparationError(f"missing or external package input: {path}")
        result.append(file.parent)
    return result


def package_name(directory: Path) -> str:
    text = (directory / "pubspec.yaml").read_text(encoding="utf-8")
    match = re.search(r"(?m)^name:\s*['\"]?([a-zA-Z0-9_]+)['\"]?\s*(?:#.*)?$", text)
    if not match:
        raise PreparationError(f"cannot read package name: {directory.name}")
    return match.group(1)


def verify_package_config(directory: Path, root: Path, internal_names: set[str]) -> None:
    config_path = directory / ".dart_tool/package_config.json"
    if not config_path.is_file() or not config_path.resolve().is_relative_to(root):
        raise PreparationError(f"package is not initialized: {directory.relative_to(root) or '.'}")
    try:
        config = json.loads(config_path.read_text(encoding="utf-8"))
        entries = config["packages"]
        if not isinstance(entries, list):
            raise ValueError("packages is not a list")
        own_name = package_name(directory)
        own = [p for p in entries if isinstance(p, dict) and p.get("name") == own_name]
        if len(own) != 1:
            raise ValueError("missing or duplicate self mapping")
        for entry in entries:
            if not isinstance(entry, dict) or not isinstance(entry.get("name"), str):
                raise ValueError("malformed package entry")
            if entry["name"] not in internal_names:
                continue
            uri = entry.get("rootUri")
            if not isinstance(uri, str):
                raise ValueError("malformed root URI")
            target = urlparse(urljoin(config_path.as_uri(), uri))
            if target.scheme != "file" or target.netloc not in ("", "localhost"):
                raise ValueError("nonlocal internal package")
            location = Path(unquote(target.path)).resolve()
            if not location.is_relative_to(root):
                raise ValueError("internal package resolves to another checkout")
            if entry["name"] == own_name and location != directory.resolve():
                raise ValueError("self package resolves to another directory")
    except (KeyError, TypeError, ValueError, OSError) as exc:
        raise PreparationError(f"invalid or wrong-worktree package configuration: {directory.name}") from exc


def lock_snapshot(root: Path) -> dict[str, str]:
    names = nul_paths(root, "ls-files", "-z", "--", "pubspec.lock", "**/pubspec.lock")
    result = {}
    for name in names:
        path = root / name
        if path.is_symlink() or not path.resolve().is_relative_to(root):
            raise PreparationError("tracked lockfile must be local, not a symlink")
        result[name] = hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else "MISSING"
    return result


def prepare(root: Path, *, resolve: bool, database: str, timeout: float) -> dict:
    expected = (root / ".flutter-version").read_text(encoding="utf-8").strip()
    try:
        actual = json.loads(run_command(["flutter", "--version", "--machine"], root))
        if actual.get("frameworkVersion") != expected:
            raise PreparationError("Flutter version differs from .flutter-version; do not upgrade implicitly")
        bundled = str(actual["dartSdkVersion"]).split()[0]
    except (KeyError, TypeError, ValueError) as exc:
        raise PreparationError("invalid Flutter version response") from exc
    dart = run_command(["dart", "--version"], root)
    found = re.search(r"Dart SDK version:\s+(\S+)", dart)
    if not found or found.group(1) != bundled:
        raise PreparationError("dart on PATH differs from Flutter's bundled Dart")

    packages = package_roots(root)
    names = {package_name(p) for p in packages}
    locks = lock_snapshot(root)
    if resolve:
        try:
            for directory in packages:
                pubspec = (directory / "pubspec.yaml").read_text(encoding="utf-8")
                flutter = directory == root or re.search(r"(?m)^\s+sdk:\s*flutter\s*(?:#.*)?$", pubspec)
                args = ["flutter" if flutter else "dart", "pub", "get"]
                relative_lock = (directory / "pubspec.lock").relative_to(root).as_posix()
                if relative_lock in locks:
                    if locks[relative_lock] == "MISSING":
                        raise PreparationError(f"tracked lockfile missing: {relative_lock}")
                    args.append("--enforce-lockfile")
                run_command(args, directory, timeout)
        finally:
            # A failed command may still have edited a lockfile. Never revert it.
            if lock_snapshot(root) != locks:
                raise PreparationError("tracked lockfile changed; edits preserved for review, setup not accepted")
    for directory in packages:
        verify_package_config(directory, root, names)

    db = "NOT_REQUESTED"
    if database == "local":
        run_command(["docker", "info", "--format", "{{.ServerVersion}}"], root)
        run_command(["supabase", "--version"], root)
        db = "TOOLS_AVAILABLE_TESTS_NOT_RUN"
    elif database == "ci":
        db = "PENDING_CI_EVIDENCE"
    return {"tooling": "READY", "flutter": expected, "dart": bundled,
            "packages": [p.relative_to(root).as_posix() for p in packages],
            "resolved": resolve, "database": db,
            "tests": "NOT_RUN", "hosted_writes": False}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--resolve", action="store_true", help="explicitly initialize package configs")
    parser.add_argument("--session", action="store_true", help="emit a fast, read-only SessionStart reminder")
    database = parser.add_mutually_exclusive_group()
    database.add_argument("--require-database", action="store_true")
    database.add_argument("--database-ci", action="store_true")
    parser.add_argument("--timeout-seconds", type=float, default=300,
                        help="per-package resolution timeout, not a retry budget")
    args = parser.parse_args(argv)
    if not 0 < args.timeout_seconds <= 600:
        parser.error("timeout must be >0 and <=600 seconds")
    if args.session:
        if args.resolve or args.require_database or args.database_ci:
            parser.error("--session does not run setup or probes")
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart",
                                                "additionalContext": SESSION_CONTEXT}}))
        return 0
    try:
        root = Path(run_command(["git", "rev-parse", "--show-toplevel"], Path.cwd()).rstrip("\r\n")).resolve()
        mode = "local" if args.require_database else "ci" if args.database_ci else "none"
        result = prepare(root, resolve=args.resolve, database=mode, timeout=args.timeout_seconds)
        print(json.dumps(result, sort_keys=True))
        return 0
    except (PreparationError, OSError, UnicodeError) as exc:
        print(json.dumps({"tooling": "BLOCKED", "reason": str(exc), "tests": "NOT_RUN"}), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
