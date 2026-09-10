---
name: deskilo-documentation
description: How DesKilo's documentation is made — the anchor that is at once a help symbol, a guide heading, a screenshot and its crops; the five guides in five languages; the screenshot pipeline (ingest, merge, Ausschnitte, the non-git index); the lints and the ×5 parity rules. Trigger for any change to docs/wiki, assets/help, the help symbols, or the documentation images.
---
# Documentation and help (DesKilo)

## The anchor is one identity for four things
`<guide>.<module>.<screen>.<object>` — dotted, lower case, never translated.

| the id names | where it lives |
|---|---|
| a help symbol | `HelpDot(anchor: H.moneyInvoiceDetail)` — `lib/core/help/help_anchors.dart` |
| a documented object | `### Invoice detail {#user.money.invoice.detail-sheet}` in all five guides |
| its screenshot | `docs/wiki/images/user-money-invoice-detail-sheet.jpg` |
| an *Ausschnitt* of one part | `…--vat-breakdown.jpg` |

Dots become dashes for a file name; `-full` marks a stitched whole form.
Because the four share one identity: the symbol opens the exact
paragraph, a new screenshot overwrites exactly the right file, and a lint
proves nothing is orphaned.

## The five guides
`docs/wiki/` is the source; `assets/help/` is GENERATED — never hand-edit it.
`User-Guide` · `Admin-Technical-Guide` · `Admin-Configuration-Guide` ·
`Environments-Guide` ×5 languages (en `User-Guide.md`, fr
`Guide-utilisateur.md`, de `Benutzerhandbuch.md`, es `Guia-de-usuario.md`,
it `Guida-utente.md`; the other guides follow the same naming), plus
`Technical-Reference` and `_Sidebar`.

Rules that predate this framework and still hold:
- **Structural parity ×5** (AGENT_RULES): same headings, same anchors,
  same image names in every language. A restructure is a five-file edit.
- **Whole-form stitches live inside `<details>`** — `build_help` strips
  them, so the in-app help never regains a 13 000-pixel block (#765).
- Guides reference images as HTML `<img src="images/x.jpg" width="240">`;
  `build_help` rewrites that to `![](assets/help/images/x.jpg)`.
- After editing a guide: `dart run tool/build_help.dart`, and commit
  `assets/help/`.

## The screenshot pipeline — `tool/media.dart`
```
docs/media/source/    git — the originals, dated: <date>--<screen>--<n>.jpg
docs/wiki/images/     git — what the guides link (the tool's only output)
assets/help/images/   git — copied by build_help, never by hand
.media-workbench/     NOT in git — index.md + index.json: what each image shows
```
`ingest` · `merge` (stitch by row correlation; `--trim-top/--trim-bottom`
drop the status and navigation bands; `--overlap N` forces it when the
tool reports an ambiguous match) · `crop` (`--rect x,y,w,h`, optional
`--callout n@x,y`) · `frame` · `redact` · `describe` · `index` · `check`.

**Replacing a legacy image is renaming nothing**: post a new screenshot
of the same screen, ingest it under the same screen id, merge — the same
`docs/wiki/images/<screen>.jpg` is overwritten and every link in every
language keeps working. The old original stays in `docs/media/source/`
under its own date.

## Stitching a scrolled form — what 2026-09-10 cost

The pipeline works, but four things sink a batch silently:

- **Measure the trims per batch, never as a constant.** `--trim-top` must
  remove the status bar AND the orange dev banner AND the app bar — on
  that device 390 px, not the 130 of the status bar alone. Leave the app
  bar in and every junction carries a repeated "← Features" band, the
  matcher matches the band instead of the content, and the stitch splices
  two unrelated paragraphs on top of each other. `--trim-bottom` is the
  navigation bar, 120 there.
- **The matcher scores the WHOLE overlap with a trimmed mean** (fixed in
  `findOverlap`, #1053). A one-number-per-row signature is a strip, and a
  strip matches a card edge anywhere on the page: it put capture 10 at an
  overlap of 644 instead of 150 and **swallowed 494 rows** without
  changing the output's dimensions. The trimmed mean matters because the
  rotating help-hint card corrupts a minority of rows outright and a
  plain mean lets those few outweigh hundreds of rows of matching text.
- **Trust the render, not the score.** Whole-width, a true overlap scores
  ~0.00–0.36. Anything above ~1.5 is not an overlap. Crop each junction
  out of the merged image and LOOK at it — every stitching bug in that
  session was caught by looking, none by the number.
- **Real gaps exist, and butt-joining is the honest answer.** Two of the
  Features form's 27 junctions had nothing in common: nobody photographed
  between "Member notifications" and "E-invoice delivery to customers",
  nor between "Number sequences" and "VAT groups". A matcher that must
  return something invents an overlap there. Losing the rows nobody
  photographed beats losing rows that WERE photographed, silently.
- **`ingest` and `merge` order by the capture INDEX** — that was a bug
  until #1053 sorted them as strings and handed `merge` 1, 10, 11, … 2.
  Stage the originals under zero-padded names in scroll order anyway; it
  costs nothing and the order is then visible in the directory.

## Screenshots carry personal data, and `docs/media/source/` is in git

Demo mode exists for exactly this — *"Names, e-mails, phones and
addresses are blurred on this device's screen — for screenshots and
videos"* — and a batch shot with it OFF cannot be published: it reaches
the public wiki AND `assets/help/images/` inside every store build.

The 2026-09-09 batch carried a full IBAN, a customer's business address,
five people's names, three e-mail addresses and a live join QR. Note that
**`ingest` alone is already too late**: the originals are tracked, so
committing them writes the data into repository history, where removing
it means a force-pushed rewrite rather than a follow-up commit.

Ask before ingesting: re-shoot with Demo mode on, or redact first. A
rendered PDF may defeat Demo mode — put a placeholder IBAN in Payment
instructions before shooting the invoice screens.

## The text
Written from the app, not from memory of the app: the ARB fragments give
every label verbatim, the registries give every field, flag, permission,
placeholder and operator. A guide never invents a label. Screenshots
confirm and illustrate; they are not the source of the wording.

## What to check before pushing
```
dart run tool/media.dart check       # images ↔ references
dart run tool/build_help.dart        # regenerate the in-app copy
flutter test test/lint test/features/help test/core/help
```
Two existing pins are strict: every help topic must be a substring of a
heading line in **all five** languages (`help_hint_test`), and every
guide image must exist on disk (`help_screen_test`). A parameter that
carries a help symbol in the app must carry one in `web/setup.html` too
(HARD RULE #5) — the setup page links `wiki/User-Guide#<anchor>`.
