// SPDX-License-Identifier: 0BSD
//
// #875 — reading and writing a layout as XML.
//
// The XML is the file a person or Claude edits, so every failure names
// the element path and the attribute, never a line of Dart. Reading is
// strict: an element or unit the vocabulary lacks is an error, not a
// silent skip — a design that says something the engine cannot draw
// must say so before it is imported, not on paper.
import 'package:xml/xml.dart';

import '../address_window.dart';
import 'layout_model.dart';
import 'layout_units.dart';

/// The vocabulary, as tag and attribute names. `describe` and the
/// generated how-to block read THESE, so documentation cannot list an
/// element the reader does not accept.
abstract final class LayoutXml {
  static const String root = 'report-layout';
  static const String version = '1';

  static const String attrVersion = 'version';
  static const String attrPage = 'page';
  static const String attrMargin = 'margin';
  static const String attrMarginTop = 'margin-top';
  static const String attrMarginBottom = 'margin-bottom';

  static const String header = 'header';
  static const String continuation = 'continuation';
  static const String body = 'body';
  static const String footer = 'footer';
  static const String recipient = 'recipient';

  static const String text = 'text';
  static const String image = 'image';
  static const String rule = 'rule';
  static const String spacer = 'spacer';
  static const String table = 'table';
  static const String col = 'col';
  static const String row = 'row';
  static const String cell = 'cell';
  static const String box = 'box';
  static const String columns = 'columns';
  static const String column = 'column';
  static const String markup = 'markup';

  static const String attrX = 'x';
  static const String attrY = 'y';
  static const String attrW = 'w';
  static const String attrH = 'h';
  static const String attrHeight = 'height';
  static const String attrStyle = 'style';
  static const String attrAlign = 'align';
  static const String attrBold = 'bold';
  static const String attrName = 'name';
  static const String attrFit = 'fit';
  static const String attrSize = 'size';
  static const String attrWindow = 'window';

  /// Elements allowed inside a zone, a box or a column.
  static const List<String> content = [
    text, image, rule, spacer, table, box, columns, markup, //
  ];

  /// The attributes every content element accepts.
  static const List<String> frameAttributes = [attrX, attrY, attrW, attrH];
}

// ─── Reading ─────────────────────────────────────────────────────────

/// Parses a `<report-layout>` document. [source] must already be past
/// the Liquid pass: the reader knows nothing about `{{ }}`.
LayoutDocument parseLayoutXml(String source) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(source);
  } on XmlException catch (e, st) {
    throw LayoutException(LayoutError.malformed, e.message,
        cause: e, stackTrace: st);
  }
  final root = doc.rootElement;
  if (root.name.local != LayoutXml.root) {
    throw LayoutException(
        LayoutError.notALayout, '<${root.name.local}> is not <report-layout>');
  }
  final version = root.getAttribute(LayoutXml.attrVersion) ?? LayoutXml.version;
  if (version != LayoutXml.version) {
    throw LayoutException(LayoutError.unsupportedVersion, 'version $version');
  }
  final page = root.getAttribute(LayoutXml.attrPage) ?? 'A4';
  if (!LayoutDocument.pageFormats.contains(page)) {
    throw LayoutException(
        LayoutError.badAttribute, 'page="$page" is not one of A4');
  }
  final margin = Length.tryParse(root.getAttribute(LayoutXml.attrMargin),
          attribute: 'report-layout/@margin') ??
      const Length(20, LengthUnit.mm);
  // #902 — top and bottom may be stated apart from the side margin.
  final marginTop = Length.tryParse(root.getAttribute(LayoutXml.attrMarginTop),
      attribute: 'report-layout/@margin-top');
  final marginBottom = Length.tryParse(
      root.getAttribute(LayoutXml.attrMarginBottom),
      attribute: 'report-layout/@margin-bottom');

  LayoutZone? header, continuation, body, footer;
  LayoutRecipient? recipient;
  for (final child in root.childElements) {
    final path = '${LayoutXml.root}/${child.name.local}';
    switch (child.name.local) {
      case LayoutXml.header:
        header = _zone(child, path);
      case LayoutXml.continuation:
        continuation = _zone(child, path);
      case LayoutXml.body:
        body = _zone(child, path);
      case LayoutXml.footer:
        footer = _zone(child, path);
      case LayoutXml.recipient:
        recipient = _recipient(child, path);
      default:
        throw LayoutException(LayoutError.unknownElement, path);
    }
  }
  return LayoutDocument(
    page: page,
    margin: margin,
    marginTop: marginTop,
    marginBottom: marginBottom,
    header: header ?? LayoutZone.empty,
    continuation: continuation ?? LayoutZone.empty,
    body: body ?? LayoutZone.empty,
    footer: footer ?? LayoutZone.empty,
    recipient: recipient,
  );
}

LayoutZone _zone(XmlElement e, String path) => LayoutZone(
      height: Length.tryParse(e.getAttribute(LayoutXml.attrHeight),
          attribute: '$path/@height'),
      y: Length.tryParse(e.getAttribute(LayoutXml.attrY), attribute: '$path/@y'),
      children: _children(e, path),
    );

LayoutRecipient _recipient(XmlElement e, String path) {
  final window = e.getAttribute(LayoutXml.attrWindow);
  final frame = _frame(e, path);
  if (window == null && frame.isEmpty) {
    throw LayoutException(LayoutError.badAttribute,
        '$path needs window="fr|din|off" or x/y/w/h');
  }
  return LayoutRecipient(
    window: switch (window) {
      null => null,
      'fr' || 'right' => AddressWindow.right,
      'din' || 'left' => AddressWindow.left,
      'off' => AddressWindow.off,
      _ => throw LayoutException(
          LayoutError.badAttribute, '$path/@window="$window"'),
    },
    frame: frame.isEmpty ? null : frame,
  );
}

List<LayoutElement> _children(XmlElement parent, String path) => [
      for (final child in parent.childElements)
        _element(child, '$path/${child.name.local}'),
    ];

LayoutElement _element(XmlElement e, String path) {
  final frame = _frame(e, path);
  return switch (e.name.local) {
    LayoutXml.text => LayoutText(
        _innerText(e),
        style: _enum(e, LayoutXml.attrStyle, LayoutStyle.values, path,
            fallback: LayoutStyle.body),
        align: _enum(e, LayoutXml.attrAlign, LayoutAlign.values, path,
            fallback: LayoutAlign.left),
        bold: _bool(e, LayoutXml.attrBold, path),
        frame: frame,
      ),
    LayoutXml.image => LayoutImage(
        e.getAttribute(LayoutXml.attrName) ??
            (throw LayoutException(
                LayoutError.badAttribute, '$path needs name="…"')),
        fit: _enum(e, LayoutXml.attrFit, LayoutFit.values, path,
            fallback: LayoutFit.contain),
        align: _enum(e, LayoutXml.attrAlign, LayoutAlign.values, path,
            fallback: LayoutAlign.left),
        frame: frame,
      ),
    LayoutXml.rule => LayoutRule(frame: frame),
    LayoutXml.spacer => LayoutSpacer(
        size: Length.tryParse(e.getAttribute(LayoutXml.attrSize),
            attribute: '$path/@size'),
        frame: frame,
      ),
    LayoutXml.table => _table(e, path, frame),
    LayoutXml.box => LayoutBox(_children(e, path), frame: frame),
    LayoutXml.columns => LayoutColumns(
        [
          for (final c in e.childElements)
            if (c.name.local == LayoutXml.column)
              _children(c, '$path/${LayoutXml.column}')
            else
              throw LayoutException(
                  LayoutError.unknownElement, '$path/${c.name.local}'),
        ],
        frame: frame,
      ),
    LayoutXml.markup => LayoutMarkup(_innerText(e), frame: frame),
    _ => throw LayoutException(LayoutError.unknownElement, path),
  };
}

LayoutTable _table(XmlElement e, String path, LayoutFrame frame) {
  final columns = <LayoutColumn>[];
  final rows = <LayoutRow>[];
  for (final c in e.childElements) {
    final p = '$path/${c.name.local}';
    switch (c.name.local) {
      case LayoutXml.col:
        columns.add(LayoutColumn(
          w: Length.tryParse(c.getAttribute(LayoutXml.attrW),
              attribute: '$p/@w'),
          align: _enum(c, LayoutXml.attrAlign, LayoutAlign.values, p,
              fallback: LayoutAlign.left),
        ));
      case LayoutXml.row:
        final cells = [
          for (final cell in c.childElements)
            if (cell.name.local == LayoutXml.cell)
              LayoutCell(
                _innerText(cell),
                align: cell.getAttribute(LayoutXml.attrAlign) == null
                    ? null
                    : _enum(cell, LayoutXml.attrAlign, LayoutAlign.values,
                        '$p/${LayoutXml.cell}',
                        fallback: LayoutAlign.left),
              )
            else
              throw LayoutException(
                  LayoutError.unknownElement, '$p/${cell.name.local}'),
        ];
        if (columns.isNotEmpty && cells.length > columns.length) {
          throw LayoutException(LayoutError.badAttribute,
              '$p has ${cells.length} cells for ${columns.length} columns');
        }
        rows.add(LayoutRow(cells, bold: _bool(c, LayoutXml.attrBold, p)));
      default:
        throw LayoutException(LayoutError.unknownElement, p);
    }
  }
  return LayoutTable(columns: columns, rows: rows, frame: frame);
}

LayoutFrame _frame(XmlElement e, String path) => LayoutFrame(
      x: Length.tryParse(e.getAttribute(LayoutXml.attrX), attribute: '$path/@x'),
      y: Length.tryParse(e.getAttribute(LayoutXml.attrY), attribute: '$path/@y'),
      w: Length.tryParse(e.getAttribute(LayoutXml.attrW), attribute: '$path/@w'),
      h: Length.tryParse(e.getAttribute(LayoutXml.attrH), attribute: '$path/@h'),
    );

T _enum<T extends Enum>(
  XmlElement e,
  String attr,
  List<T> values,
  String path, {
  required T fallback,
}) {
  final raw = e.getAttribute(attr);
  if (raw == null) return fallback;
  for (final v in values) {
    if (v.name == raw) return v;
  }
  throw LayoutException(LayoutError.badAttribute,
      '$path/@$attr="$raw" is not one of ${values.map((v) => v.name).join('|')}');
}

bool _bool(XmlElement e, String attr, String path) {
  final raw = e.getAttribute(attr);
  return switch (raw) {
    null || 'false' => false,
    'true' => true,
    _ => throw LayoutException(
        LayoutError.badAttribute, '$path/@$attr="$raw" is not true|false'),
  };
}

/// The element's text, whitespace-trimmed line by line so an indented
/// file reads the same as a flat one.
String _innerText(XmlElement e) => e.innerText
    .split('\n')
    .map((l) => l.trim())
    .where((l) => l.isNotEmpty)
    .join('\n');

// ─── Writing ─────────────────────────────────────────────────────────

/// Serialises a document back to XML — the exact inverse of
/// [parseLayoutXml], so an export re-imports as the same tree.
String layoutToXml(LayoutDocument document) {
  final b = XmlBuilder();
  b.element(LayoutXml.root, nest: () {
    b.attribute(LayoutXml.attrVersion, LayoutXml.version);
    b.attribute(LayoutXml.attrPage, document.page);
    b.attribute(LayoutXml.attrMargin, document.margin.toString());
    if (document.marginTop != null) {
      b.attribute(LayoutXml.attrMarginTop, document.marginTop.toString());
    }
    if (document.marginBottom != null) {
      b.attribute(LayoutXml.attrMarginBottom, document.marginBottom.toString());
    }
    _writeZone(b, LayoutXml.header, document.header);
    _writeZone(b, LayoutXml.continuation, document.continuation);
    final r = document.recipient;
    if (r != null) {
      b.element(LayoutXml.recipient, nest: () {
        if (r.window != null) {
          b.attribute(
              LayoutXml.attrWindow,
              switch (r.window!) {
                AddressWindow.right => 'fr',
                AddressWindow.left => 'din',
                AddressWindow.off => 'off',
              });
        }
        if (r.frame != null) _writeFrame(b, r.frame!);
      });
    }
    _writeZone(b, LayoutXml.body, document.body);
    _writeZone(b, LayoutXml.footer, document.footer);
  });
  return b.buildDocument().toXmlString(pretty: true, indent: '  ');
}

void _writeZone(XmlBuilder b, String tag, LayoutZone zone) {
  if (zone.isEmpty && zone.height == null && zone.y == null) return;
  b.element(tag, nest: () {
    if (zone.height != null) {
      b.attribute(LayoutXml.attrHeight, zone.height.toString());
    }
    if (zone.y != null) b.attribute(LayoutXml.attrY, zone.y.toString());
    for (final child in zone.children) {
      _writeElement(b, child);
    }
  });
}

void _writeFrame(XmlBuilder b, LayoutFrame f) {
  if (f.x != null) b.attribute(LayoutXml.attrX, f.x.toString());
  if (f.y != null) b.attribute(LayoutXml.attrY, f.y.toString());
  if (f.w != null) b.attribute(LayoutXml.attrW, f.w.toString());
  if (f.h != null) b.attribute(LayoutXml.attrH, f.h.toString());
}

void _writeElement(XmlBuilder b, LayoutElement el) {
  switch (el) {
    case LayoutText(:final text, :final style, :final align, :final bold):
      b.element(LayoutXml.text, nest: () {
        _writeFrame(b, el.frame);
        if (style != LayoutStyle.body) {
          b.attribute(LayoutXml.attrStyle, style.name);
        }
        if (align != LayoutAlign.left) {
          b.attribute(LayoutXml.attrAlign, align.name);
        }
        if (bold) b.attribute(LayoutXml.attrBold, 'true');
        b.text(text);
      });
    case LayoutImage(:final name, :final fit, :final align):
      b.element(LayoutXml.image, nest: () {
        b.attribute(LayoutXml.attrName, name);
        _writeFrame(b, el.frame);
        if (fit != LayoutFit.contain) b.attribute(LayoutXml.attrFit, fit.name);
        if (align != LayoutAlign.left) {
          b.attribute(LayoutXml.attrAlign, align.name);
        }
      });
    case LayoutRule():
      b.element(LayoutXml.rule, nest: () => _writeFrame(b, el.frame));
    case LayoutSpacer(:final size):
      b.element(LayoutXml.spacer, nest: () {
        _writeFrame(b, el.frame);
        if (size != null) b.attribute(LayoutXml.attrSize, size.toString());
      });
    case LayoutTable(:final columns, :final rows):
      b.element(LayoutXml.table, nest: () {
        _writeFrame(b, el.frame);
        for (final c in columns) {
          b.element(LayoutXml.col, nest: () {
            if (c.w != null) b.attribute(LayoutXml.attrW, c.w.toString());
            if (c.align != LayoutAlign.left) {
              b.attribute(LayoutXml.attrAlign, c.align.name);
            }
          });
        }
        for (final r in rows) {
          b.element(LayoutXml.row, nest: () {
            if (r.bold) b.attribute(LayoutXml.attrBold, 'true');
            for (final c in r.cells) {
              b.element(LayoutXml.cell, nest: () {
                if (c.align != null) {
                  b.attribute(LayoutXml.attrAlign, c.align!.name);
                }
                b.text(c.text);
              });
            }
          });
        }
      });
    case LayoutBox(:final children):
      b.element(LayoutXml.box, nest: () {
        _writeFrame(b, el.frame);
        for (final c in children) {
          _writeElement(b, c);
        }
      });
    case LayoutColumns(:final columns):
      b.element(LayoutXml.columns, nest: () {
        _writeFrame(b, el.frame);
        for (final column in columns) {
          b.element(LayoutXml.column, nest: () {
            for (final c in column) {
              _writeElement(b, c);
            }
          });
        }
      });
    case LayoutMarkup(:final source):
      b.element(LayoutXml.markup, nest: () {
        _writeFrame(b, el.frame);
        b.text(source);
      });
  }
}
