---
description: Refresh the technical reference from the repository and mirror the technical and admin pages AND their images to the GitHub wiki; the user and setup guides live only on the guide site.
---
# /doc-wiki — the wiki, current and complete

## 1. The technical reference
Regenerate `docs/wiki/Technical-Reference.md` from what the repo actually
says, never from memory:
- Flutter and Dart versions (`.flutter-version` / the workflow pins), every
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
- Licences: the app's AGPL-3.0-or-later, the fonts, the assets.

## 2. Mirror
The user guide and the setup guide are NOT wiki pages: they are published as
the guide site (`https://fdittgen-png.github.io/deskilo/guide/<lang>.html`,
`setup-<lang>.html`, each section's element id is its anchor) and bundled as
the in-app help. `docs/wiki/User-Guide.md` and its siblings stay in the repo
(they feed `build_help` and `build_guide_site`) but are never copied to the
wiki. Mirror everything else, and turn each link into a guide page into a
link to the site:
```
git clone https://github.com/fdittgen-png/deskilo.wiki.git <scratchpad>/wiki   # once
guides='User-Guide|Guide-utilisateur|Benutzerhandbuch|Guia-de-usuario|Guida-utente|Setup-Guide|Guide-de-demarrage|Einrichtungsanleitung|Guia-de-puesta-en-marcha|Guida-di-avvio'
for f in docs/wiki/*.md; do
  case "$(basename "$f" .md)" in User-Guide|Guide-utilisateur|Benutzerhandbuch|Guia-de-usuario|Guida-utente|Setup-Guide|Guide-de-demarrage|Einrichtungsanleitung|Guia-de-puesta-en-marcha|Guida-di-avvio) continue;; esac
  cp "$f" <scratchpad>/wiki/
done
# a [x](User-Guide#slug) link -> the site's page + the slug's anchor id (tool/guide_links.dart anchorSlugs)
grep -nE "\]\(($guides)(#[^)]*)?\)" <scratchpad>/wiki/*.md   # rewrite every hit by hand, then re-run: no hit
mkdir -p <scratchpad>/wiki/images && for i in $(grep -ho 'images/[^")]*\.jpg' <scratchpad>/wiki/*.md | sort -u); do cp "docs/wiki/$i" <scratchpad>/wiki/images/; done
cd <scratchpad>/wiki && git add -A && git commit -m "…" && git push
```
**The images matter**: the pages reference them relatively, and the old
mirror routine copied only `*.md` — every new image rendered broken on
the wiki until it was pushed by hand.

## 3. Check
`_Sidebar.md` lists every wiki page and the guide site's ten pages; no wiki
page links a guide page (the grep above is empty); every wiki link
resolves; `/doc-check` is clean.
