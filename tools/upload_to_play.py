#!/usr/bin/env python3
# Copyright (c) 2026 Florian DITTGEN
# SPDX-License-Identifier: 0BSD

"""Upload a Flutter-built AAB to a Google Play track via the Android Publisher API.

Usage:
    python tools/upload_to_play.py                          # uses all defaults
    python tools/upload_to_play.py --track internal         # internal testing
    python tools/upload_to_play.py --release-notes "Daily build"
    python tools/upload_to_play.py --dry-run                # validate without committing

Requires:
    - google-api-python-client, google-auth (pip install)
    - Service-account JSON key with Play Console "Release manager" access
    - AAB at build/app/outputs/bundle/release/app-release.aab (or pass --aab)
"""

from __future__ import annotations

import argparse
import os
import sys
import time
from datetime import date
from pathlib import Path

import httplib2
from google.oauth2 import service_account
from google_auth_httplib2 import AuthorizedHttp
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload

# #2009 part 2 — httplib2 lists 308 in `REDIRECT_CODES` and follows it
# as a normal redirect. Google's resumable-upload protocol abuses 308
# ("Resume Incomplete") to mean "I've received N bytes — please POST
# the next range to the SAME session URI" and intentionally omits the
# `Location` header (the session URI is sticky). httplib2's redirect-
# follow code then raises `RedirectMissingLocation` and the upload
# dies even though googleapiclient's `next_chunk` is itself designed
# to recognise a 308 + sticky URI and continue the upload (see
# googleapiclient/http.py `next_chunk` — it reads `resp["range"]` and
# loops). Removing 308 from `REDIRECT_CODES` lets the 308 pass
# through to googleapiclient so it can resume correctly. Affects
# only our process — the frozenset is class-level, not per-instance.
httplib2.REDIRECT_CODES = frozenset(httplib2.REDIRECT_CODES - {308})

DEFAULT_PACKAGE = "de.deskilo.app"
def _gh_output(key: str, value: str) -> None:
    """Publish a step output when running under GitHub Actions."""
    path = os.environ.get("GITHUB_OUTPUT")
    if not path:
        return
    with open(path, "a", encoding="utf-8") as fh:
        fh.write(f"{key}={value}\n")


def _gh_annotate(level: str, message: str) -> None:
    """Surface a message as a GitHub Actions annotation (#594).

    Job logs can be unretrievable through the API while the run they
    belong to is still in progress, so the release train's report job
    falls back to check-run annotations — which only carry what a step
    annotated. Annotate the real cause here so it always survives.
    Workflow commands are single-line: newlines fold to ' | '.
    """
    if not os.environ.get("GITHUB_ACTIONS"):
        return
    print(f"::{level}::{str(message).replace(chr(10), ' | ')}")


DEFAULT_TRACK = "internal"  # 'internal' = internal testing, 'alpha' = closed, 'beta' = open, 'production' = prod
DEFAULT_AAB = "build/app/outputs/bundle/release/app-release.aab"
DEFAULT_KEY = os.path.expanduser("~/.play-console-key.json")
DEFAULT_CHANGELOG_DIR = "fastlane/metadata/android"
DEFAULT_LOCALES = ["en-US", "de-DE", "fr-FR", "es-ES", "it-IT"]
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]

# #1983 — every Android Publisher call is a network round-trip; a daily
# CI build must not die on a single transient socket timeout / 5xx.
# `num_retries` makes googleapiclient retry those with exponential
# backoff. `UPLOAD_CHUNK_BYTES` splits the resumable AAB upload into
# smaller, individually-retryable requests (must be a 256 KB multiple).
#
# #1999 — #1983's retries don't help when the failure mode is a *slow*
# chunk (server still processing the previous one, the PUT response
# read stalls past httplib2's default ~60 s socket timeout). Two
# follow-ups:
#   1. Drop the chunk size from 8 MiB to 4 MiB — a retry replays half
#      as much data, and the per-chunk wall-clock shrinks so a slow
#      server is less likely to push us past the read timeout.
#   2. Wrap the credentialed client in an [AuthorizedHttp] backed by
#      an [httplib2.Http] with a 300 s (5 min) socket timeout, well
#      above the worst slow-chunk window observed in CI (~65 s).
#
# #2009 — #1999 still leaves one failure mode uncovered. The Play
# upload server occasionally returns HTTP 308 ("Resume Incomplete")
# WITHOUT a `Location` header, and httplib2 misreads that as a
# malformed redirect and raises `RedirectMissingLocation` straight
# out of `next_chunk`. The googleapiclient inner `num_retries` DOES
# catch it (it's a `httplib2.HttpLib2Error` subclass) but every
# retry hits the same server window with the same response. The fix:
# wrap each Android-Publisher .execute() through `_execute_with_retry`,
# which catches both `HttpError` AND `httplib2.HttpLib2Error` and
# retries the WHOLE edit call (3 attempts, 2 s / 8 s / 30 s backoff)
# so each outer attempt starts a fresh resumable session — that's
# what actually clears the flaky 308.
MAX_API_RETRIES = 5
UPLOAD_CHUNK_BYTES = 4 * 1024 * 1024
HTTP_SOCKET_TIMEOUT_S = 300
OUTER_RETRY_BACKOFFS_S = (2, 8, 30)


def _execute_with_retry(call_factory, *, label: str):
    """Run a Google API request through layered retry (#2009).

    `call_factory` is a zero-arg callable that builds a fresh request
    object each invocation. We don't reuse the same request across
    outer retries — a `MediaFileUpload` becomes useless after a
    failed resumable session because its internal byte-offset state
    is stale. Building fresh each attempt keeps the retry idempotent.

    Catches:
        - `googleapiclient.errors.HttpError` (real HTTP-level errors
          surfaced after the inner `num_retries=MAX_API_RETRIES` gave
          up).
        - `httplib2.error.HttpLib2Error` (covers `RedirectMissingLocation`
          and the parse-level errors httplib2 raises when the
          upstream returns a malformed response — exactly the 308-
          without-Location case from #2009).
        - `TimeoutError` (the per-chunk socket read timed out even
          past the 300 s `HTTP_SOCKET_TIMEOUT_S` ceiling).

    Returns the result of the successful `.execute(...)` call.
    Re-raises the last exception when all attempts fail.
    """
    last_error: Exception | None = None
    attempts = len(OUTER_RETRY_BACKOFFS_S) + 1
    for attempt in range(attempts):
        try:
            request = call_factory()
            return request.execute(num_retries=MAX_API_RETRIES)
        except (HttpError, httplib2.HttpLib2Error, TimeoutError) as e:
            last_error = e
            if attempt == attempts - 1:
                break
            delay = OUTER_RETRY_BACKOFFS_S[attempt]
            print(
                f"  {label} attempt {attempt + 1}/{attempts} failed "
                f"({type(e).__name__}); retrying in {delay}s",
                file=sys.stderr,
            )
            time.sleep(delay)
    # Re-raise so the per-step `except` blocks in main() can map to
    # the right exit code. The original traceback is preserved.
    assert last_error is not None
    raise last_error


def load_release_notes(
    changelog_dir: Path,
    locales: list[str],
    version_code: int,
    fallback: str,
) -> list[dict]:
    """Build the releaseNotes payload, one entry per locale.

    For each locale, prefer fastlane/metadata/android/{locale}/changelogs/{versionCode}.txt;
    fall back to the provided default text if the file is missing.
    """
    notes = []
    for locale in locales:
        path = changelog_dir / locale / "changelogs" / f"{version_code}.txt"
        if path.is_file():
            text = path.read_text(encoding="utf-8").strip()
            print(f"  [{locale}] using {path}")
        else:
            text = fallback
            print(f"  [{locale}] no per-version changelog, using fallback")
        # Play Store caps release notes at 500 chars per locale
        if len(text) > 500:
            print(f"  [{locale}] WARNING: truncated from {len(text)} to 500 chars")
            text = text[:497] + "..."
        notes.append({"language": locale, "text": text})
    return notes



# The markets DesKilo is offered in. A testing track that targets no
# country serves nobody — the opt-in page still says "you are a tester",
# and the store still says the app does not exist. EU 27, then the four
# named non-EU markets.
EU_27 = [
    "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE",
    "GR", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT",
    "RO", "SK", "SI", "ES", "SE",
]
DEFAULT_COUNTRIES = EU_27 + ["US", "CA", "JP", "KR"]


def _set_countries(edits, package: str, track_name: str,
                   countries: list[str]) -> int:
    """Give the newest release on [track_name] a country list.

    The API has no "set the track's countries" call: availability lives
    on the RELEASE, so the newest one is read back and re-sent with the
    targeting added and everything else — versionCodes, status, release
    notes — carried over untouched. Anything less would silently roll
    back the build that is live.
    """
    try:
        edit = _execute_with_retry(
            lambda: edits.insert(packageName=package, body={}),
            label="edits.insert",
        )
    except HttpError as e:
        print(f"ERROR: edits.insert failed: {e}", file=sys.stderr)
        _gh_annotate("error", f"edits.insert failed: {e}")
        return 4
    edit_id = edit["id"]

    try:
        current = _execute_with_retry(
            lambda: edits.tracks().get(
                packageName=package, editId=edit_id, track=track_name),
            label="tracks.get",
        )
    except HttpError as e:
        print(f"ERROR: tracks.get failed: {e}", file=sys.stderr)
        _gh_annotate("error", f"tracks.get failed: {e}")
        return 4

    releases = current.get("releases", [])
    if not releases:
        print(f"ERROR: track '{track_name}' has no release to target. "
              f"Upload a build first.", file=sys.stderr)
        _gh_annotate("error", f"track '{track_name}' has no release")
        return 6

    # Newest first is not guaranteed, so pick by version code.
    def _newest(release):
        codes = [int(c) for c in release.get("versionCodes", []) if c.isdigit()]
        return max(codes) if codes else -1

    target = max(releases, key=_newest)
    before = target.get("countryTargeting", {}).get("countries")
    print(f"track '{track_name}': newest release is versionCodes "
          f"{target.get('versionCodes')} status={target.get('status')}")
    print(f"  countries before: "
          f"{'ALL' if before is None else (', '.join(before) or 'NONE')}")

    updated = dict(target)
    updated["countryTargeting"] = {
        "countries": countries,
        # Explicitly NOT the rest of the world: the named markets only.
        "includeRestOfWorld": False,
    }
    body = {
        "track": track_name,
        "releases": [
            updated if r is target else r for r in releases
        ],
    }
    try:
        _execute_with_retry(
            lambda: edits.tracks().update(
                packageName=package, editId=edit_id,
                track=track_name, body=body),
            label="tracks.update (countries)",
        )
        _execute_with_retry(
            lambda: edits.commit(packageName=package, editId=edit_id),
            label="edits.commit (countries)",
        )
    except HttpError as e:
        print(f"ERROR: setting countries failed: {e}", file=sys.stderr)
        _gh_annotate("error", f"setting countries on '{track_name}' failed: {e}")
        return 7

    print(f"  countries after:  {', '.join(countries)} "
          f"({len(countries)} markets, rest of world excluded)")
    _gh_annotate("notice",
                 f"track '{track_name}' now serves {len(countries)} markets")
    return 0


def _report_status(edits, package: str) -> int:
    """Print what every track actually serves, and why a tester might see
    nothing.

    Three things make an app invisible to somebody who IS on the tester
    list, and none of them is visible from the phone: the release is a
    DRAFT (uploaded, never rolled out), the track targets NO COUNTRY, or
    the newest release is not the build you think it is. This says which.
    """
    try:
        edit = _execute_with_retry(
            lambda: edits.insert(packageName=package, body={}),
            label="edits.insert",
        )
    except HttpError as e:
        print(f"ERROR: edits.insert failed: {e}", file=sys.stderr)
        return 4
    edit_id = edit["id"]
    try:
        listing = _execute_with_retry(
            lambda: edits.tracks().list(packageName=package, editId=edit_id),
            label="tracks.list",
        )
    except HttpError as e:
        print(f"ERROR: tracks.list failed: {e}", file=sys.stderr)
        return 4

    problems = []
    for track in listing.get("tracks", []):
        name = track.get("track", "?")
        releases = track.get("releases", [])
        print(f"\ntrack {name}: {len(releases)} release(s)")
        if not releases:
            print("  (nothing here — testers of this track can install nothing)")
            problems.append(f"{name}: no release")
            continue
        for release in releases:
            status = release.get("status", "?")
            codes = ", ".join(release.get("versionCodes", []) or ["-"])
            fraction = release.get("userFraction")
            countries = release.get("countryTargeting", {}).get("countries")
            print(f"  versionCodes [{codes}] status={status}"
                  + (f" userFraction={fraction}" if fraction else "")
                  + f" countries={'ALL' if countries is None else (', '.join(countries) or 'NONE')}")
            if status == "draft":
                problems.append(
                    f"{name}: versionCode {codes} is a DRAFT — uploaded but never "
                    f"rolled out, so no tester can install it")
            if countries is not None and not countries:
                problems.append(
                    f"{name}: versionCode {codes} targets NO COUNTRY — nobody, "
                    f"anywhere, can install it")

    print("\n" + ("-" * 60))
    if problems:
        print("What would make a tester see \"item not found\":")
        for problem in problems:
            print(f"  - {problem}")
            _gh_annotate("warning", problem)
    else:
        print("Every track has a rolled-out release. If a tester still cannot "
              "install, the cause is on their side or in the Console's app "
              "content tasks, not in the track: check that the Play Store app "
              "is signed in with the SAME Google account that opted in, and "
              "that Play Console shows no unfinished app-content declaration "
              "holding the release.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--package", default=DEFAULT_PACKAGE, help=f"App package name (default: {DEFAULT_PACKAGE})")
    parser.add_argument("--track", default=DEFAULT_TRACK, choices=["internal", "alpha", "beta", "production"],
                        help=f"Play Store track (default: {DEFAULT_TRACK} = open testing)")
    parser.add_argument("--aab", default=DEFAULT_AAB, help=f"Path to AAB (default: {DEFAULT_AAB})")
    parser.add_argument("--key", default=DEFAULT_KEY, help=f"Service-account JSON key path (default: {DEFAULT_KEY})")
    parser.add_argument("--changelog-dir", default=DEFAULT_CHANGELOG_DIR,
                        help=f"Root of fastlane-style changelog metadata (default: {DEFAULT_CHANGELOG_DIR})")
    parser.add_argument("--locales", nargs="+", default=DEFAULT_LOCALES,
                        help=f"Locales to publish release notes for (default: {' '.join(DEFAULT_LOCALES)})")
    parser.add_argument("--release-notes", default=None,
                        help="Fallback release-notes text used when a per-version changelog file is missing. "
                             "Defaults to 'Daily build YYYY-MM-DD'.")
    parser.add_argument("--dry-run", action="store_true",
                        help="Validate the edit without committing (no testers receive the build)")
    parser.add_argument("--set-countries", nargs="*", default=None, metavar="CC",
                        help="Give the newest release on --track a country list, then exit. "
                             "No argument means the default markets (EU 27 plus US, CA, JP, KR). "
                             "Needs no AAB. This CHANGES what the store serves.")
    parser.add_argument("--status", action="store_true",
                        help="Read-only: report every track's releases, their status and their "
                             "country targeting, then exit. Needs no AAB. Use it when a tester "
                             "is on the list and the store still says the app does not exist: "
                             "a release that is a draft, or a track that targets no country, "
                             "looks exactly like that from the phone.")
    args = parser.parse_args()

    aab = Path(args.aab).resolve()
    key = Path(args.key).resolve()
    changelog_dir = Path(args.changelog_dir).resolve()

    read_only = args.status or args.set_countries is not None
    if not read_only and not aab.is_file():
        print(f"ERROR: AAB not found at {aab}", file=sys.stderr)
        _gh_annotate("error", f"AAB not found at {aab}")
        print("       Run `flutter build appbundle --release` first.", file=sys.stderr)
        return 2
    if not key.is_file():
        print(f"ERROR: service-account key not found at {key}", file=sys.stderr)
        _gh_annotate("error", f"service-account key not found at {key}")
        return 2

    fallback_notes = args.release_notes or f"Daily build {date.today().isoformat()}"

    print(f"Authenticating as service account from {key}")
    creds = service_account.Credentials.from_service_account_file(str(key), scopes=SCOPES)
    # #1999 — route the API client through an httplib2.Http with a
    # 5-minute socket timeout so the chunked AAB upload doesn't die on
    # one slow-server response read. The default httplib2 timeout
    # (~60 s) was the trigger for the Daily Open-Testing Build failures
    # logged on 2026-05-19 / 2026-05-20.
    authed_http = AuthorizedHttp(creds, http=httplib2.Http(timeout=HTTP_SOCKET_TIMEOUT_S))
    service = build("androidpublisher", "v3", http=authed_http, cache_discovery=False)
    edits = service.edits()

    if args.status:
        return _report_status(edits, args.package)

    if args.set_countries is not None:
        return _set_countries(edits, args.package, args.track,
                              args.set_countries or DEFAULT_COUNTRIES)

    # All Android-Publisher edit calls below route through
    # `_execute_with_retry` so each layered failure mode has the same
    # 3-attempt safety net (#2009). The same `except` mapping each
    # step had before stays — only the call itself is wrapped.
    print(f"Opening edit for {args.package}")
    try:
        edit = _execute_with_retry(
            lambda: edits.insert(packageName=args.package, body={}),
            label="edits.insert",
        )
    except (HttpError, httplib2.HttpLib2Error, TimeoutError) as e:
        print(f"ERROR: edits.insert failed: {e}", file=sys.stderr)
        _gh_annotate("error", f"edits.insert failed: {e}")
        return 3
    edit_id = edit["id"]
    print(f"  edit id: {edit_id}")

    print(f"Uploading {aab} ({aab.stat().st_size / 1_000_000:.2f} MB)")
    # #2009 — build a FRESH MediaFileUpload inside each outer retry.
    # A `MediaFileUpload` carries internal resumable-session state
    # (byte-offset, session URI) that becomes stale after a failed
    # session; reusing it across outer retries would resend a chunk
    # to a dead URI. The lambda below is re-evaluated on every
    # outer attempt so each one starts a clean resumable session.
    def _build_upload_request():
        media = MediaFileUpload(
            str(aab),
            mimetype="application/octet-stream",
            resumable=True,
            chunksize=UPLOAD_CHUNK_BYTES,
        )
        return edits.bundles().upload(
            packageName=args.package,
            editId=edit_id,
            media_body=media,
        )

    try:
        bundle = _execute_with_retry(
            _build_upload_request,
            label="bundles.upload",
        )
    except (HttpError, httplib2.HttpLib2Error, TimeoutError) as e:
        print(f"ERROR: bundle upload failed: {e}", file=sys.stderr)
        _gh_annotate("error", f"bundle upload failed: {e}")
        return 4
    version_code = bundle["versionCode"]
    print(f"  uploaded versionCode: {version_code}")

    print(f"Resolving release notes for versionCode {version_code}")
    release_notes = load_release_notes(changelog_dir, args.locales, version_code, fallback_notes)

    # The Play API can't bootstrap a FIRST production rollout's country
    # availability (a first release must be 'completed', 'completed' rejects
    # countryTargeting, and a fresh prod track targets no countries). So upload
    # production as a DRAFT: the AAB lands on the production track as a draft the
    # maintainer finalizes in the Console (set Countries/regions + publish). A
    # draft isn't rolled out, so commit succeeds with no country requirement.
    # Testing tracks (internal/alpha/beta) still roll out fully ('completed').
    release_status = "draft" if args.track == "production" else "completed"

    def _update_track(status):
        return _execute_with_retry(
            lambda: edits.tracks().update(
                packageName=args.package,
                editId=edit_id,
                track=args.track,
                body={
                    "track": args.track,
                    "releases": [{
                        "name": f"{version_code}",
                        "versionCodes": [str(version_code)],
                        "status": status,
                        "releaseNotes": release_notes,
                    }],
                },
            ),
            label="tracks.update",
        )

    print(f"Assigning to track '{args.track}' (release status: {release_status})")
    try:
        _update_track(release_status)
    except HttpError as e:
        # A FRESH alpha/beta track rejects a full rollout before the
        # Console prerequisites (countries, app setup): "Precondition
        # check failed". Stage the release as a DRAFT instead — it lands
        # on the track ready to roll out from the Console (the same
        # bootstrap contract production always used).
        if release_status == "completed" and "Precondition" in str(e):
            print("  full rollout refused (Console prerequisites pending) "
                  "— staging as DRAFT instead")
            release_status = "draft"
            try:
                _update_track(release_status)
            except HttpError as e2:
                if "Precondition" in str(e2):
                    # Even a DRAFT is refused: Play LOCKS this track until
                    # the Console prerequisites are done (app setup, the
                    # closed test, production access for open testing).
                    # That is store policy, not a build failure — report
                    # it loudly and end GREEN so the pipeline stays honest
                    # about real errors.
                    print(f"\nUPLOAD SKIPPED: Play refuses ANY release on "
                          f"track '{args.track}' until the Console "
                          f"prerequisites are completed (app setup tasks, "
                          f"closed test, production access). versionCode "
                          f"{version_code} was built and validated; rerun "
                          f"this workflow once the track is unlocked.")
                    _gh_annotate("notice", f"UPLOAD SKIPPED: track '{args.track}' is locked by Play policy until the Console prerequisites are completed; versionCode {version_code} was built and validated")
                    _gh_output("uploaded", "false")
                    _gh_output("skip_reason", "track locked by Play policy")
                    return 0
                print(f"ERROR: track update failed: {e2}", file=sys.stderr)
                _gh_annotate("error", f"tracks.update failed: {e2}")
                return 5
            except (httplib2.HttpLib2Error, TimeoutError) as e2:
                print(f"ERROR: track update failed: {e2}", file=sys.stderr)
                _gh_annotate("error", f"tracks.update failed: {e2}")
                return 5
        else:
            print(f"ERROR: track update failed: {e}", file=sys.stderr)
            _gh_annotate("error", f"tracks.update failed: {e}")
            return 5
    except (httplib2.HttpLib2Error, TimeoutError) as e:
        print(f"ERROR: track update failed: {e}", file=sys.stderr)
        _gh_annotate("error", f"tracks.update failed: {e}")
        return 5

    if args.dry_run:
        print("Dry-run: validating edit (no commit)")
        try:
            _execute_with_retry(
                lambda: edits.validate(
                    packageName=args.package, editId=edit_id,
                ),
                label="edits.validate",
            )
            print("Validation OK — edit will NOT be committed (dry-run).")
        except (HttpError, httplib2.HttpLib2Error, TimeoutError) as e:
            print(f"ERROR: validation failed: {e}", file=sys.stderr)
            _gh_annotate("error", f"edits.validate failed: {e}")
            return 6
        _gh_output("uploaded", "false")
        _gh_output("skip_reason", "dry-run")
        return 0

    print("Committing edit")
    try:
        _execute_with_retry(
            lambda: edits.commit(
                packageName=args.package, editId=edit_id,
            ),
            label="edits.commit",
        )
    except (HttpError, httplib2.HttpLib2Error, TimeoutError) as e:
        # A DRAFT APP (store listing never reviewed/published) only accepts
        # DRAFT releases outside the internal track. Fall back: redo the
        # whole edit with status 'draft' so the build still lands on the
        # track — the maintainer publishes it in the Console once the app
        # leaves draft state.
        if isinstance(e, HttpError) and "draft app" in str(e):
            print("Draft app: retrying the release with status 'draft' "
                  "(publish it in the Console after app review)")
            try:
                edit_id = _execute_with_retry(
                    lambda: edits.insert(packageName=args.package),
                    label="edits.insert (draft retry)",
                )["id"]
                _execute_with_retry(
                    lambda: edits.bundles().upload(
                        packageName=args.package, editId=edit_id,
                        media_body=MediaFileUpload(
                            str(aab), mimetype=(
                                "application/octet-stream"), resumable=True),
                    ),
                    label="bundles.upload (draft retry)",
                )
                _execute_with_retry(
                    lambda: edits.tracks().update(
                        packageName=args.package, editId=edit_id,
                        track=args.track,
                        body={
                            "track": args.track,
                            "releases": [{
                                "name": f"{version_code}",
                                "versionCodes": [str(version_code)],
                                "status": "draft",
                                "releaseNotes": release_notes,
                            }],
                        },
                    ),
                    label="tracks.update (draft retry)",
                )
                _execute_with_retry(
                    lambda: edits.commit(
                        packageName=args.package, editId=edit_id,
                    ),
                    label="edits.commit (draft retry)",
                )
                print(f"\nSUCCESS: versionCode {version_code} uploaded to "
                      f"track '{args.track}' as a DRAFT release")
                _gh_output("uploaded", "true")
                return 0
            except (HttpError, httplib2.HttpLib2Error, TimeoutError) as e2:
                print(f"ERROR: draft retry failed: {e2}", file=sys.stderr)
                _gh_annotate("error", f"draft retry failed: {e2}")
                return 7
        print(f"ERROR: edits.commit failed: {e}", file=sys.stderr)
        _gh_annotate("error", f"edits.commit failed: {e}")
        return 7

    _gh_output("uploaded", "true")
    print(f"\nSUCCESS: versionCode {version_code} published to track '{args.track}'")
    # DesKilo's own app (4972789796909667632). This used to print the id
    # of a DIFFERENT app on the same developer account, alongside a track
    # the upload may not have touched — a link that opens the wrong
    # release page reads as "it went somewhere else", which is exactly
    # the doubt a success line exists to remove. The overview page is
    # track-agnostic and always the right first stop.
    print(
        "https://play.google.com/console/u/0/developers/5325652654414690657"
        "/app/4972789796909667632/releases/overview"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
