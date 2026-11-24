#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Package exact ESP-IDF outputs, retaining source identity and bounded flash layout."""

import argparse
import json
from pathlib import Path
import shutil
import subprocess

from flash import BOARD, ESPTOOL_VERSION, FLASH_BYTES, app_identity, digest, load_bundle, local_file


def package(build, output, repository):
    build, output, repository = build.resolve(), output.resolve(), repository.resolve()
    if output.exists():
        raise ValueError("Output directory already exists; choose a new package path")
    git = lambda *args: subprocess.check_output(["git", "-C", str(repository), *args], text=True).strip()
    if git("status", "--porcelain", "--untracked-files=normal"):
        raise ValueError("Commit the complete source checkpoint before packaging")
    source = git("rev-parse", "HEAD")
    description = json.loads((build / "project_description.json").read_text())
    if description.get("target") != "esp32" or description.get("project_name") != "deskilo_till":
        raise ValueError("Build is not the Deskilo ESP32 diagnostic target")
    if description.get("project_version") != f"diag-{source[:12]}":
        raise ValueError("Reconfigure/rebuild from the committed source before packaging")
    args = json.loads((build / "flasher_args.json").read_text())
    if args.get("extra_esptool_args", {}).get("chip") != "esp32":
        raise ValueError("Build has the wrong chip target")
    records = []
    roles = ("bootloader", "partition-table", "otadata", "app")
    if set(args.get("flash_files", {})) != {args[role]["offset"] for role in roles}:
        raise ValueError("Build flash file map contains an unexpected write")
    for role in roles:
        entry = args[role]
        if entry.get("encrypted") not in (False, "false"):
            raise ValueError("Encrypted initial flashing is not supported by this diagnostic")
        if args["flash_files"][entry["offset"]] != entry["file"]:
            raise ValueError("Build image metadata is inconsistent")
        path = local_file(build, entry["file"])
        records.append({"role": role, "file": role + ".bin", "offset": int(entry["offset"], 0),
                        "size": path.stat().st_size, "sha256": digest(path), "input": path})
    elf = local_file(build, description["app_elf"])
    elf_hash = digest(elf)
    app = next(record["input"] for record in records if record["role"] == "app")
    identity = app_identity(app)
    if (identity["version"] != f"diag-{source[:12]}" or identity["project"] != "deskilo_till"
            or identity["idf"] != "v6.1.1" or identity["elf_sha256"] != elf_hash):
        raise ValueError("Actual application binary/ELF does not match the committed build identity")
    manifest = {"schema": 1, "board": BOARD, "chip": "esp32", "flash_bytes": FLASH_BYTES,
                "build_kind": "diagnostic", "financial_capabilities": [], "drawer_output_enabled": False,
                "source_commit": source, "source_tree": git("rev-parse", "HEAD^{tree}"),
                "source_url": f"https://github.com/fdittgen-png/deskilo/tree/{source}",
                "app_elf_sha256": elf_hash,
                "idf_version": "6.1.1", "esptool_version": ESPTOOL_VERSION,
                "flash_settings": args["flash_settings"],
                "images": [{key: value for key, value in record.items() if key != "input"} for record in records],
                "physical_qualification": "NOT RUN", "ota_update_implemented": False,
                "signing": "unsigned development diagnostic; hashes check integrity, not authenticity"}
    output.mkdir(parents=True)
    try:
        for record in records:
            shutil.copyfile(record["input"], output / record["file"])
        (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        load_bundle(output)
        here = Path(__file__).resolve().parent
        shutil.copyfile(here / "flash.py", output / "flash.py")
        shutil.copyfile(here / "requirements.txt", output / "requirements.txt")
        shutil.copyfile(repository / "firmware/till/README.md", output / "README.md")
        shutil.copyfile(repository / "LICENSE", output / "LICENSE")
        shutil.copytree(repository / "firmware/till/third_party", output / "third_party")
        shutil.copytree(repository / "firmware/till/components/till_ui/fonts", output / "font-license",
                        ignore=shutil.ignore_patterns("*.c"))
    except Exception:
        # The caller can inspect a failed package; it cannot look ready to flash.
        (output / "manifest.json").unlink(missing_ok=True)
        raise
    print(f"Packaged {source}: {output}")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", type=Path, default=Path("firmware/till/build"))
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--repository", type=Path, default=Path("."))
    args = parser.parse_args()
    try:
        package(args.build, args.out, args.repository)
    except (ValueError, OSError, KeyError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Package refused: {error}\n")


if __name__ == "__main__":
    main()
