// SPDX-License-Identifier: 0BSD
//
// #875 — the element tree a positioned report layout is made of.
//
// This is the whole vocabulary. The XML reader produces it, the PDF
// renderer and the on-screen mirror both consume it, and the `describe`
// command documents it — from the same constants, so the four cannot
// drift. Anything the tree cannot express, the format cannot promise.
import '../address_window.dart';
import 'layout_units.dart';

/// The typographic roles a text may take. Same four the banded engine
/// draws with, so a design that mixes `<markup>` and `<text>` reads as
/// one document.
enum LayoutStyle { heading, subheading, body, small }

enum LayoutAlign { left, center, right }

/// How an image meets the box it is given.
enum LayoutFit { contain, cover, fill }

/// One element of a layout. Every element carries a [frame]; a frame
/// without x/y flows after its siblings, one with x or y is placed
/// absolutely inside the parent box.
sealed class LayoutElement {
  const LayoutElement({this.frame = LayoutFrame.flow});
  final LayoutFrame frame;
}

/// A run of text. [text] is a Liquid template already rendered by the
/// time the tree exists — the reader runs Liquid over the whole file
/// first, so the model never sees `{{ }}`.
class LayoutText extends LayoutElement {
  const LayoutText(
    this.text, {
    this.style = LayoutStyle.body,
    this.align = LayoutAlign.left,
    this.bold = false,
    super.frame,
  });
  final String text;
  final LayoutStyle style;
  final LayoutAlign align;
  final bool bold;
}

/// An image from the workspace library, by name. Unknown names render
/// as nothing rather than breaking the document — the same contract as
/// the banded `![name]`.
class LayoutImage extends LayoutElement {
  const LayoutImage(
    this.name, {
    this.fit = LayoutFit.contain,
    this.align = LayoutAlign.left,
    super.frame,
  });
  final String name;
  final LayoutFit fit;
  final LayoutAlign align;
}

/// The accent rule.
class LayoutRule extends LayoutElement {
  const LayoutRule({super.frame});
}

/// Vertical breathing room; [size] defaults to the engine's 8 pt.
class LayoutSpacer extends LayoutElement {
  const LayoutSpacer({this.size, super.frame});
  final Length? size;
}

/// One column of a table: its width (a percentage of the table by
/// convention, any unit allowed) and how its cells align.
class LayoutColumn {
  const LayoutColumn({this.w, this.align = LayoutAlign.left});
  final Length? w;
  final LayoutAlign align;
}

class LayoutCell {
  const LayoutCell(this.text, {this.align});
  final String text;

  /// Overrides the column's alignment for this cell only.
  final LayoutAlign? align;
}

class LayoutRow {
  const LayoutRow(this.cells, {this.bold = false});
  final List<LayoutCell> cells;
  final bool bold;
}

/// A table with declared columns. Rows longer than the column list are
/// an error at read time — a design must say what every column is.
class LayoutTable extends LayoutElement {
  const LayoutTable({
    this.columns = const [],
    this.rows = const [],
    super.frame,
  });
  final List<LayoutColumn> columns;
  final List<LayoutRow> rows;
}

/// A box: a parent for further elements, with its own frame. This is
/// how "40% wide, at 60% across" is said.
class LayoutBox extends LayoutElement {
  const LayoutBox(this.children, {super.frame});
  final List<LayoutElement> children;
}

/// Equal-width side-by-side columns, each a list of flowing elements —
/// the positioned twin of the banded `::: ||| :::`.
class LayoutColumns extends LayoutElement {
  const LayoutColumns(this.columns, {super.frame});
  final List<List<LayoutElement>> columns;
}

/// A block of today's band markup, verbatim, rendered by the same
/// block renderer the bands use. The bridge that lets an existing
/// design move into a layout one element at a time.
class LayoutMarkup extends LayoutElement {
  const LayoutMarkup(this.source, {super.frame});
  final String source;
}

/// One of the four page zones. [height] fixes a header/footer zone;
/// [y] says where the body resumes (90 mm under a window envelope).
class LayoutZone {
  const LayoutZone({this.children = const [], this.height, this.y});

  static const LayoutZone empty = LayoutZone();

  final List<LayoutElement> children;
  final Length? height;
  final Length? y;

  bool get isEmpty => children.isEmpty;
}

/// Where the recipient is drawn. Either a named window convention —
/// which takes its millimetres from `address_window.dart`, the one
/// place they live — or an explicit page-absolute frame.
class LayoutRecipient {
  const LayoutRecipient({this.window, this.frame});

  final AddressWindow? window;

  /// Page coordinates, not zone coordinates: the envelope does not
  /// know about the document's margins.
  final LayoutFrame? frame;

  bool get isOff => window == AddressWindow.off;
}

/// A whole layout: the page, its margin, the four zones and the
/// recipient. Header on page 1, continuation on every later page,
/// footer on every page, body flowing between — the #872 contract,
/// now stated by the design instead of assumed by the engine.
class LayoutDocument {
  const LayoutDocument({
    this.page = 'A4',
    this.margin = const Length(20, LengthUnit.mm),
    this.header = LayoutZone.empty,
    this.continuation = LayoutZone.empty,
    this.body = LayoutZone.empty,
    this.footer = LayoutZone.empty,
    this.recipient,
  });

  final String page;
  final Length margin;
  final LayoutZone header;
  final LayoutZone continuation;
  final LayoutZone body;
  final LayoutZone footer;
  final LayoutRecipient? recipient;

  /// The page formats this engine knows. Only A4 today — the envelope
  /// spec is an A4 spec — but the attribute exists so a second format
  /// is a value, not a schema change.
  static const List<String> pageFormats = ['A4'];
}
