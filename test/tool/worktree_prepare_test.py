# SPDX-License-Identifier: AGPL-3.0-or-later
"""Worktree preparation is explicit, source-preserving and fail-closed.

Use real temporary Git repositories; fake only SDK/package/database commands.
The Dart launcher in this directory makes this suite part of the tool shard.
"""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/worktree_prepare.py"
spec = importlib.util.spec_from_file_location("worktree_prepare", SCRIPT)
module = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(module)


class PreparationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="worktree fixture ")
        self.root = Path(self.temp.name).resolve()
        self.real_run = module.run_command
        self.calls = []
        self.version = "3.47.5"
        self.dart_version = "3.13.4"
        self.fail_pub = False
        self.change_lock = False
        self.database_down = False
        self.real_run(["git", "init", "-q"], self.root)
        (self.root / ".flutter-version").write_text(self.version + "\n")
        self.make_package(".", "deskilo", flutter=True)
        self.make_package("packages/plain", "plain")
        self.make_package("packages/push", "deskilo_push", flutter=True)
        self.make_package("packages/push_foss", "deskilo_push", flutter=True)
        (self.root / "pubspec.lock").write_text("pinned lockfile\n")
        (self.root / "unrelated.txt").write_text("original\n")
        (self.root / ".gitignore").write_text("**/.dart_tool/\n")
        self.real_run(["git", "add", "."], self.root)
        self.real_run(["git", "-c", "user.name=Fixture", "-c",
                       "user.email=fixture@example.invalid", "-c", "commit.gpgsign=false",
                       "commit", "-qm", "fixture"], self.root)
        self.mock_run = patch.object(module, "run_command", side_effect=self.run_fake)
        self.mock_run.start()

    def tearDown(self):
        self.mock_run.stop()
        self.temp.cleanup()

    def make_package(self, relative, name, flutter=False):
        directory = self.root / relative
        directory.mkdir(parents=True, exist_ok=True)
        sdk = "dependencies:\n  flutter:\n    sdk: flutter\n" if flutter else ""
        (directory / "pubspec.yaml").write_text(f"name: {name}\n" + sdk)
        return directory

    def config(self, directory, *, target="../", extra=None):
        directory.joinpath(".dart_tool").mkdir(exist_ok=True)
        value = {"configVersion": 2, "packages": [
            {"name": module.package_name(directory), "rootUri": target,
             "packageUri": "lib/", "languageVersion": "3.0"}, *(extra or [])]}
        directory.joinpath(".dart_tool/package_config.json").write_text(json.dumps(value))

    def initialize(self):
        for directory in module.package_roots(self.root):
            self.config(directory)

    def run_fake(self, args, cwd, timeout=10):
        self.calls.append((args, cwd, timeout))
        if args[0] == "git":
            return self.real_run(args, cwd, timeout)
        if args[:3] == ["flutter", "--version", "--machine"]:
            return json.dumps({"frameworkVersion": self.version, "dartSdkVersion": self.dart_version})
        if args == ["dart", "--version"]:
            return "Dart SDK version: 3.13.4 (stable)"
        if args[1:3] == ["pub", "get"]:
            if self.change_lock:
                (self.root / "pubspec.lock").write_text("unexpected drift\n")
            if self.fail_pub:
                raise module.PreparationError("package fixture: exit 7")
            self.config(cwd)
            return "resolved"
        if args[0] in ("docker", "supabase"):
            if self.database_down:
                raise module.PreparationError("database tooling unavailable")
            return "version available"
        raise AssertionError(f"unexpected command: {args}")

    def prepare(self, resolve=False, database="none"):
        return module.prepare(self.root, resolve=resolve, database=database, timeout=90)

    def test_version_banner_on_stderr_is_supported_without_mixing_json(self):
        completed = subprocess.CompletedProcess(["dart", "--version"], 0, "", "Dart SDK version: 3.13.4")
        with patch.object(module.subprocess, "run", return_value=completed):
            self.assertEqual(self.real_run(["dart", "--version"], self.root), "Dart SDK version: 3.13.4")
            self.assertEqual(self.real_run(["flutter", "--version", "--machine"], self.root), "")

    def test_check_only_refuses_uninitialized_package(self):
        with self.assertRaisesRegex(module.PreparationError, "not initialized"):
            self.prepare()
        self.assertFalse(any(a[1:3] == ["pub", "get"] for a, _, _ in self.calls))

    def test_explicit_resolve_prepares_root_and_independent_variants(self):
        before_index = self.real_run(["git", "write-tree"], self.root)
        (self.root / "unrelated.txt").write_text("user edits\n")
        result = self.prepare(resolve=True)
        self.assertEqual(result["tooling"], "READY")
        self.assertEqual(result["tests"], "NOT_RUN")
        pub = [(a, p) for a, p, _ in self.calls if a[1:3] == ["pub", "get"]]
        self.assertEqual(len(pub), 4)
        self.assertEqual(pub[0][0], ["flutter", "pub", "get", "--enforce-lockfile"])
        self.assertEqual(pub[1][0], ["dart", "pub", "get"])
        self.assertEqual({p.name for _, p in pub[2:]}, {"push", "push_foss"})
        self.assertEqual((self.root / "unrelated.txt").read_text(), "user edits\n")
        self.assertEqual(self.real_run(["git", "write-tree"], self.root), before_index)

    def test_ready_check_executes_no_pub_or_database_command(self):
        self.initialize()
        self.calls.clear()
        result = self.prepare()
        self.assertEqual(result["database"], "NOT_REQUESTED")
        self.assertFalse(result["resolved"])
        self.assertFalse(any(a[0] in ("docker", "supabase") or a[1:3] == ["pub", "get"]
                             for a, _, _ in self.calls))

    def test_wrong_flutter_is_blocked_before_resolution(self):
        self.version = "unapproved"
        with self.assertRaisesRegex(module.PreparationError, "Flutter version differs"):
            self.prepare(resolve=True)
        self.assertFalse(any(a[1:3] == ["pub", "get"] for a, _, _ in self.calls))

    def test_wrong_dart_is_blocked(self):
        self.dart_version = "other-dart"
        with self.assertRaisesRegex(module.PreparationError, "dart on PATH"):
            self.prepare()

    def test_package_cannot_resolve_to_other_checkout(self):
        self.initialize()
        self.config(self.root, target=Path(self.temp.name).parent.as_uri())
        with self.assertRaisesRegex(module.PreparationError, "wrong-worktree"):
            self.prepare()

    def test_internal_dependency_cannot_resolve_to_other_checkout(self):
        self.initialize()
        self.config(self.root, extra=[{"name": "plain", "rootUri": "../../other-checkout"}])
        with self.assertRaisesRegex(module.PreparationError, "wrong-worktree"):
            self.prepare()

    def test_config_missing_self_is_blocked(self):
        self.initialize()
        (self.root / ".dart_tool/package_config.json").write_text('{"packages": []}')
        with self.assertRaises(module.PreparationError):
            self.prepare()

    def test_invalid_json_is_blocked(self):
        self.initialize()
        (self.root / ".dart_tool/package_config.json").write_text("not-json")
        with self.assertRaises(module.PreparationError):
            self.prepare()

    def test_tracked_lockfile_drift_is_preserved_and_reported(self):
        self.change_lock = True
        with self.assertRaisesRegex(module.PreparationError, "lockfile changed"):
            self.prepare(resolve=True)
        self.assertEqual((self.root / "pubspec.lock").read_text(), "unexpected drift\n")

    def test_generator_failure_still_reports_lockfile_drift(self):
        self.change_lock = True
        self.fail_pub = True
        with self.assertRaisesRegex(module.PreparationError, "lockfile changed"):
            self.prepare(resolve=True)

    def test_failed_resolution_stops_without_resolving_siblings(self):
        self.fail_pub = True
        with self.assertRaisesRegex(module.PreparationError, "exit 7"):
            self.prepare(resolve=True)
        self.assertEqual(sum(a[1:3] == ["pub", "get"] for a, _, _ in self.calls), 1)

    def test_missing_tracked_lockfile_is_not_silently_regenerated(self):
        (self.root / "pubspec.lock").unlink()
        with self.assertRaisesRegex(module.PreparationError, "lockfile missing"):
            self.prepare(resolve=True)

    def test_local_database_check_is_not_test_evidence(self):
        self.initialize()
        result = self.prepare(database="local")
        self.assertEqual(result["database"], "TOOLS_AVAILABLE_TESTS_NOT_RUN")
        self.assertEqual(result["tests"], "NOT_RUN")
        self.assertEqual([a for a, _, _ in self.calls if a[0] == "supabase"], [["supabase", "--version"]])
        self.assertFalse(any("start" in a or "reset" in a for a, _, _ in self.calls))

    def test_missing_database_is_blocker_when_required(self):
        self.initialize()
        self.database_down = True
        with self.assertRaisesRegex(module.PreparationError, "database tooling"):
            self.prepare(database="local")

    def test_ci_choice_never_claims_database_pass(self):
        self.initialize()
        self.database_down = True
        self.assertEqual(self.prepare(database="ci")["database"], "PENDING_CI_EVIDENCE")
        self.assertFalse(any(a[0] in ("docker", "supabase") for a, _, _ in self.calls))

    def test_untracked_or_nested_fixture_pubspec_not_auto_executed(self):
        self.make_package("packages/untracked", "untracked")
        self.make_package("packages/plain/test/fixture", "fake_fixture")
        self.real_run(["git", "add", "packages/plain/test/fixture/pubspec.yaml"], self.root)
        self.assertEqual(len(module.package_roots(self.root)), 4)

    def test_git_failure_is_not_empty_discovery(self):
        with patch.object(module, "run_command", side_effect=module.PreparationError("git failed")):
            with self.assertRaisesRegex(module.PreparationError, "git failed"):
                module.package_roots(self.root)

    def test_tracked_external_pubspec_is_refused(self):
        path = self.root / "packages/plain/pubspec.yaml"
        path.unlink()
        path.symlink_to(self.root.parent / "external.yml")
        with self.assertRaisesRegex(module.PreparationError, "external package"):
            module.package_roots(self.root)


class ProcessAndHookTests(unittest.TestCase):
    def test_session_hook_needs_no_git_sdk_database_or_network(self):
        result = subprocess.run([sys.executable, str(SCRIPT), "--session"],
                                env={"PATH": ""}, capture_output=True, text=True,
                                timeout=5, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        context = json.loads(result.stdout)["hookSpecificOutput"]["additionalContext"]
        self.assertIn("#2596", context)
        self.assertIn("no tools, tests or setup were run", context)
        self.assertIn("No automatic release", context)

    def test_project_hook_is_registered_without_permission_or_model_override(self):
        config = json.loads((SCRIPT.parents[1] / ".claude/settings.json").read_text())
        session = config["hooks"]["SessionStart"][0]
        self.assertEqual(session["matcher"], "startup|resume|clear|compact")
        hook = session["hooks"][0]
        self.assertEqual(hook["type"], "command")
        self.assertEqual(hook["timeout"], 5)
        self.assertEqual(hook["command"],
                         'python3 "$CLAUDE_PROJECT_DIR/scripts/worktree_prepare.py" --session')
        self.assertNotIn("model", config)
        self.assertIn("mcp__claude_ai_Supabase__create_project", config["permissions"]["deny"])

    def test_session_cannot_trigger_resolve(self):
        result = subprocess.run([sys.executable, str(SCRIPT), "--session", "--resolve"],
                                capture_output=True, text=True, timeout=5, check=False)
        self.assertNotEqual(result.returncode, 0)

    def test_failed_process_does_not_leak_output(self):
        with patch.object(module.subprocess, "run", return_value=subprocess.CompletedProcess(
                ["fixture"], 7, "private-token-canary", "private-token-canary")):
            with self.assertRaises(module.PreparationError) as caught:
                module.run_command(["fixture"], Path.cwd())
        self.assertIn("exit 7", str(caught.exception))
        self.assertNotIn("private-token-canary", str(caught.exception))

    def test_timeout_is_bounded_failure_without_retry(self):
        with patch.object(module.subprocess, "run", side_effect=subprocess.TimeoutExpired("fixture", 10)) as invoke:
            with self.assertRaisesRegex(module.PreparationError, "timed out"):
                module.run_command(["fixture"], Path.cwd())
        invoke.assert_called_once()

    def test_missing_executable_is_explicit(self):
        with patch.object(module.subprocess, "run", side_effect=FileNotFoundError("missing")):
            with self.assertRaisesRegex(module.PreparationError, "could not run"):
                module.run_command(["fixture"], Path.cwd())


if __name__ == "__main__":
    unittest.main()
