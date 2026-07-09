#!/usr/bin/env python3
# Copyright (c) 2026 Florian DITTGEN
# SPDX-License-Identifier: MIT

"""Sync the Play Store listing (texts + images) from fastlane metadata.

Usage:
    python tools/upload_listing.py --key ~/.play-console-key.json
    python tools/upload_listing.py --dry-run          # validate, don't commit

For every locale directory under fastlane/metadata/android/ this uploads:
    - listing texts: title.txt, short_description.txt, full_description.txt
    - images/icon.png            -> app icon (512x512)
    - images/featureGraphic.png  -> feature graphic (1024x500)
    - images/phoneScreenshots/*  -> phone screenshots (sorted by name)

A locale missing an image falls back to en-US's file, so brand images are
stored once. Texts are per-locale and required (all five exist in-repo).

Requires google-api-python-client + google-auth and a service-account key
with "Manage store presence" permission on the app.
"""

from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

import httplib2
from google.oauth2 import service_account
from google_auth_httplib2 import AuthorizedHttp
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload

DEFAULT_PACKAGE = "de.deskilo.app"
DEFAULT_METADATA_DIR = "fastlane/metadata/android"
FALLBACK_LOCALE = "en-US"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
IMAGE_TYPES = {"icon": "icon.png", "featureGraphic": "featureGraphic.png"}

MAX_API_RETRIES = 5
HTTP_SOCKET_TIMEOUT_S = 300
OUTER_RETRY_BACKOFFS_S = (2, 8, 30)


def _execute_with_retry(call_factory, *, label: str):
    """Layered retry, same shape as upload_to_play.py (#2009)."""
    last_error: Exception | None = None
    attempts = len(OUTER_RETRY_BACKOFFS_S) + 1
    for attempt in range(attempts):
        try:
            return call_factory().execute(num_retries=MAX_API_RETRIES)
        except (HttpError, httplib2.HttpLib2Error, TimeoutError) as e:
            last_error = e
            if attempt == attempts - 1:
                break
            delay = OUTER_RETRY_BACKOFFS_S[attempt]
            print(f"  {label} attempt {attempt + 1}/{attempts} failed "
                  f"({type(e).__name__}); retrying in {delay}s", file=sys.stderr)
            time.sleep(delay)
    assert last_error is not None
    raise last_error


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8").strip()


def _image_path(metadata: Path, locale: str, filename: str) -> Path | None:
    """Locale image, falling back to en-US so brand images live once."""
    own = metadata / locale / "images" / filename
    if own.is_file():
        return own
    fallback = metadata / FALLBACK_LOCALE / "images" / filename
    return fallback if fallback.is_file() else None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--package", default=DEFAULT_PACKAGE)
    parser.add_argument("--key", required=True, help="Service-account JSON key path")
    parser.add_argument("--metadata-dir", default=DEFAULT_METADATA_DIR)
    parser.add_argument("--dry-run", action="store_true",
                        help="Validate the edit without committing")
    args = parser.parse_args()

    metadata = Path(args.metadata_dir).resolve()
    locales = sorted(p.name for p in metadata.iterdir()
                     if p.is_dir() and (p / "title.txt").is_file())
    if not locales:
        print(f"ERROR: no locale dirs with title.txt under {metadata}", file=sys.stderr)
        return 2

    creds = service_account.Credentials.from_service_account_file(args.key, scopes=SCOPES)
    authed_http = AuthorizedHttp(creds, http=httplib2.Http(timeout=HTTP_SOCKET_TIMEOUT_S))
    service = build("androidpublisher", "v3", http=authed_http, cache_discovery=False)
    edits = service.edits()

    print(f"Opening edit for {args.package}")
    edit_id = _execute_with_retry(
        lambda: edits.insert(packageName=args.package, body={}),
        label="edits.insert")["id"]

    for locale in locales:
        loc_dir = metadata / locale
        print(f"[{locale}] listing texts")
        _execute_with_retry(
            lambda: edits.listings().update(
                packageName=args.package, editId=edit_id, language=locale,
                body={
                    "language": locale,
                    "title": _read(loc_dir / "title.txt"),
                    "shortDescription": _read(loc_dir / "short_description.txt"),
                    "fullDescription": _read(loc_dir / "full_description.txt"),
                }),
            label=f"listings.update {locale}")

        for image_type, filename in IMAGE_TYPES.items():
            path = _image_path(metadata, locale, filename)
            if path is None:
                print(f"[{locale}] {image_type}: no file, skipped")
                continue
            print(f"[{locale}] {image_type} <- {path.relative_to(metadata)}")
            _execute_with_retry(
                lambda: edits.images().deleteall(
                    packageName=args.package, editId=edit_id,
                    language=locale, imageType=image_type),
                label=f"images.deleteall {locale}/{image_type}")
            _execute_with_retry(
                lambda: edits.images().upload(
                    packageName=args.package, editId=edit_id,
                    language=locale, imageType=image_type,
                    media_body=MediaFileUpload(str(path), mimetype="image/png")),
                label=f"images.upload {locale}/{image_type}")

        shots = sorted((loc_dir / "images" / "phoneScreenshots").glob("*.png"))
        if shots:
            print(f"[{locale}] {len(shots)} phone screenshots")
            _execute_with_retry(
                lambda: edits.images().deleteall(
                    packageName=args.package, editId=edit_id,
                    language=locale, imageType="phoneScreenshots"),
                label=f"images.deleteall {locale}/phoneScreenshots")
            for shot in shots:
                _execute_with_retry(
                    lambda: edits.images().upload(
                        packageName=args.package, editId=edit_id,
                        language=locale, imageType="phoneScreenshots",
                        media_body=MediaFileUpload(str(shot), mimetype="image/png")),
                    label=f"images.upload {locale}/{shot.name}")

    if args.dry_run:
        _execute_with_retry(
            lambda: edits.validate(packageName=args.package, editId=edit_id),
            label="edits.validate")
        print("Dry-run: validation OK, edit NOT committed.")
        return 0

    _execute_with_retry(
        lambda: edits.commit(packageName=args.package, editId=edit_id),
        label="edits.commit")
    print(f"\nSUCCESS: listing synced for {', '.join(locales)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
