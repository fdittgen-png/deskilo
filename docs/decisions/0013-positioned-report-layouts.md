# ADR 0013 — Positioned report layouts beside the bands

**Status:** accepted · **Date:** 2026-09-04

## Context

Three printed invoices in a row did not match what the designer showed.
The report engine was a *banded flow*: three Liquid + line-markup bands
(header, body, footer, later a continuation strip) rendered as
`package:pdf` widgets. Position was a by-product of flow; a design could
not *state* it. The window-envelope work (#873) bolted absolute geometry
on — 20 mm margins, the recipient at 110/45 mm in an 85 × 40 mm
aperture, the body resuming at 90 mm — but only for the recipient block,
and only in code. The owner asked for designs that state position and
size in mm, cm, px or %, absolute or relative; a PDF that prints exactly
that; a way to design, run and validate a report locally without the
app; and an export that can be edited and re-imported.

## Decision

**A second engine, coexisting; a layout wins when a document has one.**
`InvoicePdfTemplate.layouts` stores, per report kind, the XML of a
`<report-layout>`. When a kind has one, the positioned engine renders
it; otherwise its bands render as before. Nothing already designed
changes until its owner gives that document a layout. Retiring the bands
would have meant migrating every live design in one PR and losing the
`<markup>` bridge that lets a design move over one element at a time.

**XML, not JSON, for the layout.** A positioned tree is elements with
`x/y/w/h` attributes; that reads naturally in XML and is what the
workspace export already uses. The JSON band exchange (#864) is
untouched. Both files are self-describing: the how-to block is generated
from the same constants the reader accepts, so the documentation cannot
list an element the engine would refuse.

**Lengths resolve once.** `mm`, `cm`, `px` (the CSS pixel, 1/96 in),
`pt` and `%` all resolve to points in `Length.resolve`, against the
parent's width for `x`/`w` and height for `y`/`h`. A bare number is
millimetres — the unit the envelope spec and a ruler use. The renderer
and the on-screen mirror share that one function, so they cannot
disagree about what `45mm` is.

**Liquid first, then parse, with escaped data.** The bands render
Liquid into markup and parse the result; the layout does the same into
XML. String *values* are XML-escaped before the pass so "Smith & Sons"
cannot break the document; the template itself is the XML and is never
escaped. Placeholders are seeded first (`placeholderDefaults`), so an absent one is empty
rather than nil and a guarded element vanishes rather than printing a
bare label.

**Exceptions carry the place and the cause.** `LayoutException` names
the error class, the element path or attribute, the underlying error and
its stack. The layout-wins hook traces all of it and falls back to the
bands — the #470 contract that a broken design never blocks a document,
kept, but with a trace that can be read instead of reproduced.

**The PDF is the oracle.** Every geometric claim is proven on a
generated document: `test/helpers/pdf_geometry.dart` inflates the
content streams and reports ink in millimetres from the sheet's
top-left. The in-app preview is a mirror for editing; the harness and
the CLI `check` measure the PDF.

## Consequences

- A design can say where things go, and a test can say whether they
  went there. The window-envelope contract (#873) becomes something a
  design states — `<recipient window="fr"/>`, `<body y="90mm">` —
  rather than something the engine assumes.
- Two engines draw documents. They share the block renderer
  (`report_block_widgets.dart`), the ink (`report_style.dart`) and the
  geometry constants (`address_window.dart`); anything that would make
  a `<markup>` element look different from the same markup in a band is
  a bug, and there is one place to fix it.
- The feature is flagged (`reportLayouts`, under `reportDesigner`) and
  the template's `layouts` key is absent until a layout exists, so
  templates from before layouts existed and new ones stay byte-identical.
- Not yet covered by layouts, and deliberately so: annexed invoices
  (documentation appended behind a settlement) stay banded — the
  positioned engine renders one document. A visual drag-and-resize
  canvas is a follow-up; the XML is the editing surface first, because
  the format has to be proven on paper before a canvas is built over it.
