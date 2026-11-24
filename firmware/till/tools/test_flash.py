# SPDX-License-Identifier: AGPL-3.0-or-later
import json
from pathlib import Path
import struct
import tempfile
import unittest

import flash


class FlashSafetyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bundle = self.root / "bundle"
        self.bundle.mkdir()
        partitions = [
            ("nvs", 1, 2, 0x9000, 0x6000),
            ("otadata", 1, 0, 0xf000, 0x2000),
            ("phy_init", 1, 1, 0x11000, 0x1000),
            ("ota_0", 0, 16, 0x20000, 0x1e0000),
            ("ota_1", 0, 17, 0x200000, 0x1e0000),
            ("diag_nvs", 1, 2, 0x3e0000, 0x20000),
        ]
        table = b"".join(struct.pack("<HBBII16sI", 0x50AA, kind, subtype,
                         offset, size, name.encode(), 0)
                         for name, kind, subtype, offset, size in partitions)
        app = bytearray(288)
        app[0], app[1] = 0xE9, 1
        struct.pack_into("<I", app, 28, 256)
        struct.pack_into("<I", app, 32, 0xABCD5432)
        app[48:65] = b"diag-aaaaaaaaaaaa"
        app[80:92] = b"deskilo_till"
        app[144:150] = b"v6.1.1"
        app[176:208] = b"\x01" * 32
        data = {"bootloader": b"boot", "partition-table": table,
                "otadata": b"\xff" * 0x2000, "app": bytes(app)}
        offsets = dict(bootloader=0x1000, **{"partition-table": 0x8000}, otadata=0xf000, app=0x20000)
        records = []
        for role, content in data.items():
            path = self.bundle / f"{role}.bin"
            path.write_bytes(content)
            records.append(dict(role=role, file=path.name, offset=offsets[role],
                                size=len(content), sha256=flash.digest(path)))
        self.manifest = dict(schema=1, board=flash.BOARD, chip="esp32",
                             flash_bytes=flash.FLASH_BYTES, build_kind="diagnostic",
                             financial_capabilities=[], drawer_output_enabled=False,
                             esptool_version=flash.ESPTOOL_VERSION, source_commit="a" * 40,
                             app_elf_sha256="01" * 32,
                             flash_settings=dict(flash_mode="dio", flash_size="4MB", flash_freq="40m"),
                             images=records)
        self.save()
        self.calls = []

    def save(self):
        (self.bundle / "manifest.json").write_text(json.dumps(self.manifest))

    def runner(self, args):
        self.calls.append(args)
        if "flash-id" in args:
            return "Chip type: ESP32-D0WD-V3\nDetected flash size: 4MB\n"
        if "read-flash" in args:
            Path(args[-1]).write_bytes(b"x" * flash.FLASH_BYTES)
        return ""

    def act(self, runner=None):
        return flash.flash_bundle(self.bundle, "/dev/test-board", self.root / "private-backups",
                                  runner or self.runner)

    def test_success_preserves_complete_backup_before_write_and_verifies_before_reset(self):
        backup = self.act()
        stages = [next(item for item in args if item in (
            "flash-id", "read-flash", "write-flash", "verify-flash", "run")) for args in self.calls]
        self.assertEqual(stages, ["flash-id", "read-flash", "write-flash", "verify-flash", "run"])
        self.assertEqual(backup.stat().st_size, flash.FLASH_BYTES)
        receipt = json.loads(backup.with_suffix(".json").read_text())
        self.assertEqual(receipt["sha256"], flash.digest(backup))
        if hasattr(backup.stat(), "st_mode"):
            self.assertEqual(backup.stat().st_mode & 0o077, 0)
        self.assertTrue(all("erase-flash" not in args and "--force" not in args for args in self.calls))
        self.assertIn("--after", self.calls[-1])
        self.assertIn("hard-reset", self.calls[-1])

    def test_corrupt_image_stops_before_serial_port_is_opened(self):
        (self.bundle / "app.bin").write_bytes(b"bad")
        with self.assertRaises(ValueError):
            self.act()
        self.assertEqual(self.calls, [])

    def test_stale_binary_cannot_claim_new_source_even_with_valid_image_hash(self):
        self.manifest["source_commit"] = "b" * 40
        self.save()
        with self.assertRaises(ValueError):
            self.act()
        self.assertEqual(self.calls, [])

    def test_different_elf_identity_is_refused(self):
        self.manifest["app_elf_sha256"] = "02" * 32
        self.save()
        with self.assertRaises(ValueError):
            self.act()
        self.assertEqual(self.calls, [])

    def test_wrong_flash_size_never_reads_or_writes(self):
        def wrong(args):
            self.calls.append(args)
            return "Detected flash size: 8MB"
        with self.assertRaises(ValueError):
            self.act(wrong)
        self.assertEqual(len(self.calls), 1)

    def test_backup_failure_or_truncation_never_writes(self):
        for raises in (False, True):
            self.calls = []
            def failed(args):
                if "read-flash" in args:
                    self.calls.append(args)
                    if raises:
                        raise RuntimeError("serial disconnected")
                    Path(args[-1]).write_bytes(b"truncated")
                    return ""
                return self.runner(args)
            with self.assertRaises((ValueError, RuntimeError)):
                self.act(failed)
            self.assertFalse(any("write-flash" in args for args in self.calls))

    def test_bundle_changed_during_backup_never_writes(self):
        def changed(args):
            result = self.runner(args)
            if "read-flash" in args:
                self.manifest["source_commit"] = "b" * 40
                self.save()
            return result
        with self.assertRaises(ValueError):
            self.act(changed)
        self.assertFalse(any("write-flash" in args for args in self.calls))

    def test_write_failure_never_resets_or_reports_readback(self):
        def failed(args):
            if "write-flash" in args:
                self.calls.append(args)
                raise RuntimeError("serial disconnected")
            return self.runner(args)
        with self.assertRaises(RuntimeError):
            self.act(failed)
        self.assertFalse(any("verify-flash" in args or "run" in args for args in self.calls))

    def test_verify_failure_never_resets(self):
        def failed(args):
            if "verify-flash" in args:
                self.calls.append(args)
                raise RuntimeError("readback differs")
            return self.runner(args)
        with self.assertRaises(RuntimeError):
            self.act(failed)
        self.assertFalse(any("run" in args for args in self.calls))

    def test_unknown_roles_out_of_bounds_and_partition_mismatch_are_refused(self):
        app = next(image for image in self.manifest["images"] if image["role"] == "app")
        for key, value in (("role", "nvs"), ("offset", flash.FLASH_BYTES),
                           ("offset", 0x21000), ("offset", -4096)):
            previous = app[key]
            app[key] = value
            self.save()
            with self.assertRaises(ValueError):
                flash.load_bundle(self.bundle)
            app[key] = previous

    def test_path_escape_is_refused_even_with_valid_hash(self):
        app = next(image for image in self.manifest["images"] if image["role"] == "app")
        outside = self.root / "outside.bin"
        outside.write_bytes((self.bundle / "app.bin").read_bytes())
        app["file"] = "../outside.bin"
        self.save()
        with self.assertRaises(ValueError):
            self.act()
        self.assertEqual(self.calls, [])

    def test_financial_or_drawer_enabled_bundle_is_refused(self):
        for key, value in (("financial_capabilities", ["cash"]), ("drawer_output_enabled", True)):
            previous = self.manifest[key]
            self.manifest[key] = value
            self.save()
            with self.assertRaises(ValueError):
                flash.load_bundle(self.bundle)
            self.manifest[key] = previous


if __name__ == "__main__":
    unittest.main()
