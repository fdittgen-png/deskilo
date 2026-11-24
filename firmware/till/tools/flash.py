#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Validate, back up, flash and read back an E32R40T diagnostic bundle."""

import argparse
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import uuid

FLASH_BYTES = 4 * 1024 * 1024
SECTOR_BYTES = 4096
APP_HEADROOM_BYTES = 64 * 1024
ESPTOOL_VERSION = "5.7.0"
BOARD = "lcdwiki_e32r40t"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def app_identity(path):
    data = path.read_bytes()
    if (len(data) < 288 or data[0] != 0xE9 or data[1] == 0
            or struct.unpack_from("<I", data, 28)[0] < 256
            or struct.unpack_from("<I", data, 32)[0] != 0xABCD5432):
        raise ValueError("Application lacks the ESP-IDF descriptor")
    def string(start):
        return data[start:start + 32].split(b"\0", 1)[0].decode("ascii")
    return {"version": string(48), "project": string(80), "idf": string(144),
            "elf_sha256": data[176:208].hex()}


def local_file(root, name):
    if not isinstance(name, str) or not name or Path(name).is_absolute():
        raise ValueError("Bundle paths must be relative files")
    root = root.resolve()
    path = (root / name).resolve(strict=True)
    if not path.is_relative_to(root) or not path.is_file():
        raise ValueError("Bundle path escapes its directory")
    return path


def partition_entries(path):
    entries = {}
    data = path.read_bytes()
    for index in range(0, len(data) - 31, 32):
        magic, kind, subtype, offset, size, label, flags = struct.unpack(
            "<HBBII16sI", data[index:index + 32]
        )
        if magic != 0x50AA:
            break
        name = label.rstrip(b"\0").decode("ascii")
        if not name or name in entries or flags or not size:
            raise ValueError("Unsupported or duplicate partition")
        if offset % SECTOR_BYTES or size % SECTOR_BYTES or offset + size > FLASH_BYTES:
            raise ValueError("Invalid partition bounds")
        entries[name] = dict(type=kind, subtype=subtype, offset=offset, size=size)
    regions = sorted(entries.values(), key=lambda entry: entry["offset"])
    if any(a["offset"] + a["size"] > b["offset"] for a, b in zip(regions, regions[1:])):
        raise ValueError("Overlapping partitions")
    expected = {"nvs": (1, 2), "otadata": (1, 0), "phy_init": (1, 1),
                "ota_0": (0, 16), "ota_1": (0, 17), "diag_nvs": (1, 2)}
    if set(entries) != set(expected):
        raise ValueError("Unexpected diagnostic partition layout")
    for name, types in expected.items():
        if (entries[name]["type"], entries[name]["subtype"]) != types:
            raise ValueError("Unexpected partition type")
    return entries


def load_bundle(directory):
    directory = Path(directory).resolve()
    manifest = json.loads((directory / "manifest.json").read_text())
    if (manifest.get("schema") != 1 or manifest.get("board") != BOARD
            or manifest.get("chip") != "esp32" or manifest.get("flash_bytes") != FLASH_BYTES
            or manifest.get("build_kind") != "diagnostic"
            or manifest.get("financial_capabilities") != []
            or manifest.get("drawer_output_enabled") is not False
            or manifest.get("esptool_version") != ESPTOOL_VERSION):
        raise ValueError("This flasher accepts only the E32R40T diagnostic bundle")
    if not re.fullmatch(r"[0-9a-f]{40}", manifest.get("source_commit", "")):
        raise ValueError("Missing exact source commit")
    if manifest.get("flash_settings") != {
            "flash_mode": "dio", "flash_size": "4MB", "flash_freq": "40m"}:
        raise ValueError("Unsupported flash settings")
    images = manifest.get("images")
    if not isinstance(images, list) or len(images) != 4:
        raise ValueError("Expected bootloader, partition table, initial OTA data and application")
    roles = {}
    for image in images:
        role = image.get("role")
        if role in roles:
            raise ValueError("Duplicate image role")
        path = local_file(directory, image["file"])
        offset, size = image.get("offset"), image.get("size")
        if (type(offset) is not int or type(size) is not int or offset < SECTOR_BYTES
                or offset % SECTOR_BYTES or size <= 0 or offset + size > FLASH_BYTES
                or path.stat().st_size != size or digest(path) != image.get("sha256")):
            raise ValueError("Image hash, size or flash bounds differ from manifest")
        roles[role] = {**image, "path": path}
    if set(roles) != {"bootloader", "partition-table", "otadata", "app"}:
        raise ValueError("Unexpected image role")
    regions = partition_entries(roles["partition-table"]["path"])
    for role, partition in (("app", "ota_0"), ("otadata", "otadata")):
        if (roles[role]["offset"] != regions[partition]["offset"]
                or roles[role]["size"] > regions[partition]["size"]):
            raise ValueError("Image does not fit its partition")
    app_size = roles["app"]["size"]
    identity = app_identity(roles["app"]["path"])
    if (identity["version"] != "diag-" + manifest["source_commit"][:12]
            or identity["project"] != "deskilo_till" or identity["idf"] != "v6.1.1"
            or identity["elf_sha256"] != manifest.get("app_elf_sha256")):
        raise ValueError("Application descriptor differs from the source/build identity")
    if any(app_size + APP_HEADROOM_BYTES > regions[slot]["size"] for slot in ("ota_0", "ota_1")):
        raise ValueError("Application exceeds the reserved slot headroom")
    table = roles["partition-table"]
    first_data = min(region["offset"] for region in regions.values())
    if table["size"] > SECTOR_BYTES or table["offset"] + SECTOR_BYTES > first_data:
        raise ValueError("Partition table overlaps partition data")
    if roles["bootloader"]["offset"] + roles["bootloader"]["size"] > table["offset"]:
        raise ValueError("Bootloader overlaps partition table")
    ordered = sorted(roles.values(), key=lambda image: image["offset"])
    for left, right in zip(ordered, ordered[1:]):
        erased_end = left["offset"] + ((left["size"] + SECTOR_BYTES - 1) // SECTOR_BYTES) * SECTOR_BYTES
        if erased_end > right["offset"]:
            raise ValueError("Images overlap an erased flash sector")
    return manifest, ordered


def run_esptool(arguments):
    result = subprocess.run([sys.executable, "-m", "esptool", *arguments],
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            check=False, timeout=600)
    if result.stdout:
        print(result.stdout, end="")
    if result.returncode:
        raise RuntimeError(f"esptool stopped with exit {result.returncode}; no later step was run")
    return result.stdout


def flash_bundle(directory, port, backup_dir, runner=run_esptool):
    manifest, images = load_bundle(directory)
    if not port or port.startswith("-"):
        raise ValueError("An explicit serial port is required")
    connection = ["--chip", "esp32", "--port", port, "--baud", "115200",
                  "--before", "default-reset", "--after", "no-reset"]
    identity = runner([*connection, "flash-id"])
    # esptool's explicit --chip also rejects a different silicon family.
    if not re.search(r"Detected flash size:\s*4MB\b", identity):
        raise ValueError("The attached board did not report 4MB flash; nothing was written")
    backup_dir = Path(backup_dir)
    backup_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    backup = backup_dir / f"esp32-before-{uuid.uuid4().hex}.bin"
    descriptor = os.open(backup, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    os.close(descriptor)
    runner([*connection, "read-flash", "0x0", hex(FLASH_BYTES), str(backup)])
    if backup.stat().st_size != FLASH_BYTES:
        raise ValueError("Full-flash backup is incomplete; nothing was written")
    receipt = {"file": backup.name, "size": FLASH_BYTES, "sha256": digest(backup),
               "replacement_source_commit": manifest["source_commit"]}
    receipt_path = backup.with_suffix(".json")
    with os.fdopen(os.open(receipt_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600), "w") as output:
        json.dump(receipt, output, indent=2)
        output.write("\n")
        output.flush()
        os.fsync(output.fileno())
    with backup.open("rb") as source:
        os.fsync(source.fileno())
    # Re-read after backup so a changed/corrupt bundle cannot reach write-flash.
    checked_manifest, checked_images = load_bundle(directory)
    if checked_manifest != manifest:
        raise ValueError("Bundle changed during backup; nothing was written")
    pairs = [value for image in checked_images for value in (hex(image["offset"]), str(image["path"]))]
    runner([*connection, "write-flash", "--flash-mode", "dio", "--flash-size", "4MB",
            "--flash-freq", "40m", *pairs])
    runner([*connection, "verify-flash", *pairs])
    runner([*connection[:-1], "hard-reset", "run"])
    print(f"Flash written and readback verified. Private recovery backup: {backup}")
    print("Display, touch, heap, Wi-Fi and HTTPS still require the physical qualification record.")
    return backup


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--port", help="Explicit USB serial port; no automatic device selection")
    parser.add_argument("--backup-dir", type=Path, default=Path("backups"))
    parser.add_argument("--check", action="store_true", help="Validate files without opening a serial port")
    args = parser.parse_args()
    try:
        manifest, _ = load_bundle(args.bundle)
        if args.check:
            print(f"Bundle verified: {BOARD}, source {manifest['source_commit']}, diagnostic only")
            return
        if not args.port:
            parser.error("--port is required when flashing")
        if importlib.metadata.version("esptool") != ESPTOOL_VERSION:
            raise ValueError(f"Install the pinned requirements: esptool=={ESPTOOL_VERSION}")
        flash_bundle(args.bundle, args.port, args.backup_dir)
    except (ValueError, OSError, RuntimeError, subprocess.TimeoutExpired,
            importlib.metadata.PackageNotFoundError) as error:
        parser.exit(1, f"Stopped: {error}\n")


if __name__ == "__main__":
    main()
