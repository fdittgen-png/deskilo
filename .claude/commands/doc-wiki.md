---
description: Refresh the technical reference from the repository and mirror every guide AND its images to the GitHub wiki.
---
# /doc-wiki — the wiki, current and complete

## 1. The technical reference
Regenerate `docs/wiki/Technical-Reference.md` from what the repo actually
says, never from memory:
- Flutter and Dart versions (`.fvmrc` / the workflow pins), every
  dependency in `pubspec.yaml` with one line on why it is there.
- Architecture: feature-first layout, domain purity (no Flutter, no l10n
  in `domain/`), Riverpod 3 with codegen, freezed, go_router, the
  layering pairs the lint allows.
- The server: Postgres and RLS, writes only through RPCs, the rolled-back
  migration harness, the system columns, the instance bundle.
- Every lint gate in `test/lint/` and what it protects, in a table.
- The workflows: CI, the release train, the web publish, F-Droid.
- The ADR index from `docs/decisions/`, one line each.
- Standards and references the app implements: EN 16931, the VAT
  directive, NF Z 10-011, Factur-X, FEC, SAF-T, DATEV.
- Licences: the app's 0BSD, the fonts, the assets.

## 2. Mirror
```
git clone https://github.com/fdittgen-png/deskilo.wiki.git <scratchpad>/wiki   # once
cp docs/wiki/*.md <scratchpad>/wiki/
mkdir -p <scratchpad>/wiki/images && cp docs/wiki/images/*.jpg <scratchpad>/wiki/images/
cd <scratchpad>/wiki && git add -A && git commit -m "…" && git push
```
**The images matter**: the guides reference them relatively, and the old
mirror routine copied only `*.md` — every new image rendered broken on
the wiki until it was pushed by hand.

## 3. Check
`_Sidebar.md` lists every guide in every language; every wiki link
resolves; `/doc-check` is clean.
