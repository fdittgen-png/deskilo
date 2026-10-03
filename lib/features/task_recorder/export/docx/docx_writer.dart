// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1866 — the smallest genuine WordprocessingML package the task
// document needs, written with the `archive` + XML-text pattern of
// lib/core/files/xlsx.dart rather than a DOCX library or the reports
// engine: the document is "a title, headings, numbered steps and a
// footer", not a word processor.
//
// What the package holds is fixed here, so nothing can ride along:
//   * every relationship is INTERNAL; a target that is a URL, an
//     absolute path or climbs out of the package is refused
//     ([DocxIssue.externalRelationship]) — no remote image, template,
//     font or hyperlink can be referenced;
//   * no macros, no custom XML, no comments, no app.xml; core properties
//     carry the title and the language only — no author, editor, dates
//     or revision count;
//   * page numbers are PAGE/NUMPAGES fields, which every reader computes
//     at layout; there is no table of contents, so nothing depends on a
//     reader refreshing fields;
//   * text is escaped and stripped of characters XML 1.0 cannot carry.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../../../core/trace/trace_logger.dart';
import '../../storyboard/png_safety.dart';

/// Why a document was refused.
enum DocxIssue {
  /// More blocks, characters or bytes than [DocxLimits] allow.
  tooLarge,

  /// A relationship pointing outside the package.
  externalRelationship,

  /// A picture that is not a well-formed PNG within the bounds.
  badImage,
}

/// A refused document. Carries the reason, never the content.
class DocxException implements Exception {
  const DocxException(this.issue, this.detail);

  final DocxIssue issue;

  /// Which limit or which part, never a value from the document.
  final String detail;

  @override
  String toString() => 'DocxException(${issue.name}: $detail)';
}

/// The bounds a generated document lives within.
class DocxLimits {
  const DocxLimits({
    this.maxBlocks = 6000,
    this.maxParagraphChars = 4000,
    this.maxBytes = 8 * 1024 * 1024,
    this.maxImages = 60,
    this.maxImageBytes = 6 * 1024 * 1024,
  });

  final int maxBlocks;
  final int maxParagraphChars;

  /// Pictures in one document, and their bytes together.
  final int maxImages;
  final int maxImageBytes;

  /// The finished package, compressed.
  final int maxBytes;
}

/// The paragraph styles of the one template.
enum DocxStyle {
  title('Title', 'Title'),
  heading1('Heading1', 'heading 1'),
  normal('Normal', 'Normal'),
  listNumber('ListNumber', 'List Number'),
  listBullet('ListBullet', 'List Bullet'),
  stepDetail('StepDetail', 'Step Detail'),
  illustration('Illustration', 'Illustration'),
  caption('Caption', 'caption');

  const DocxStyle(this.id, this.name);
  final String id;
  final String name;
}

/// A run of text inside a paragraph.
class DocxRun {
  const DocxRun(this.text, {this.bold = false, this.italic = false});

  final String text;
  final bool bold;
  final bool italic;
}

/// One block of the body.
sealed class DocxBlock {
  const DocxBlock();
}

/// A paragraph in one of the template's styles.
class DocxParagraph extends DocxBlock {
  const DocxParagraph(
    this.style,
    this.runs, {
    this.bookmark,
    this.keepWithNext = false,
  });

  DocxParagraph.text(
    DocxStyle style,
    String text, {
    String? bookmark,
    bool keepWithNext = false,
  }) : this(
         style,
         [DocxRun(text)],
         bookmark: bookmark,
         keepWithNext: keepWithNext,
       );

  final DocxStyle style;
  final List<DocxRun> runs;

  /// A bookmark name: a stable semantic anchor such as `step_3`.
  final String? bookmark;

  /// Keeps this paragraph on the page of the next one (a step and its
  /// detail lines); headings always do.
  final bool keepWithNext;
}

/// A picture: a PNG checked and stripped again on write, scaled to fit
/// the text width without distortion, with its alt text.
class DocxImage extends DocxBlock {
  const DocxImage(this.png, this.altText);

  final Uint8List png;
  final String altText;
}

/// The footer line around the page fields: `before PAGE between NUMPAGES
/// after`.
class DocxFooter {
  const DocxFooter(this.before, this.between, this.after);

  final String before;
  final String between;
  final String after;
}

/// A whole document.
class DocxDocument {
  const DocxDocument({
    required this.title,
    required this.languageTag,
    required this.blocks,
    required this.footer,
  });

  final String title;

  /// BCP 47, e.g. `fr-FR`: the proofing language of every run.
  final String languageTag;
  final List<DocxBlock> blocks;
  final DocxFooter footer;
}

/// One package relationship.
class DocxRelationship {
  const DocxRelationship(this.id, this.type, this.target);

  final String id;

  /// The last segment of the relationship type URI (`styles`, `image`).
  final String type;
  final String target;
}

const _relNs =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _pkgRelNs =
    'http://schemas.openxmlformats.org/package/2006/relationships';
const _wNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
const _wpNs =
    'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing';
const _aNs = 'http://schemas.openxmlformats.org/drawingml/2006/main';
const _picNs = 'http://schemas.openxmlformats.org/drawingml/2006/picture';
const _xmlHead = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';

final _internalTarget = RegExp(r'^[A-Za-z0-9_\-]+(/[A-Za-z0-9_\-]+)*\.[a-z]+$');

/// The relationships part for [rels]. Refuses any target that is not a
/// plain path inside the package.
String docxRelationshipsXml(List<DocxRelationship> rels) {
  final out = StringBuffer('$_xmlHead<Relationships xmlns="$_pkgRelNs">');
  for (final r in rels) {
    if (!_internalTarget.hasMatch(r.target)) {
      throw DocxException(DocxIssue.externalRelationship, r.id);
    }
    final type = r.type.startsWith('http')
        ? r.type
        : r.type == 'core-properties'
        ? 'http://schemas.openxmlformats.org/package/2006/relationships/'
              'metadata/core-properties'
        : '$_relNs/${r.type}';
    out.write(
      '<Relationship Id="${escapeXml(r.id)}" '
      'Type="${escapeXml(type)}" Target="${escapeXml(r.target)}"/>',
    );
  }
  out.write('</Relationships>');
  return out.toString();
}

final _notXml = RegExp(
  '[\u0000-\u0008\u000B\u000C\u000E-\u001F￾￿]|'
  r'[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]',
);

/// [value] made safe for XML text and attributes: escaped, and without
/// the characters XML 1.0 cannot carry (control characters, lone
/// surrogates).
String escapeXml(String value) => value
    .replaceAll(_notXml, '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

/// Builds the package bytes, ready for the file saver. Throws
/// [DocxException] when [doc] is over [limits].
Uint8List buildDocx(
  DocxDocument doc, {
  DocxLimits limits = const DocxLimits(),
}) {
  if (doc.blocks.length > limits.maxBlocks) {
    throw const DocxException(DocxIssue.tooLarge, 'blocks');
  }
  final images = [
    for (final b in doc.blocks)
      if (b is DocxImage) b,
  ];
  if (images.length > limits.maxImages ||
      images.fold<int>(0, (n, i) => n + i.png.length) > limits.maxImageBytes) {
    throw const DocxException(DocxIssue.tooLarge, 'images');
  }
  final media = <DocxImage, (Uint8List, int, int)>{};
  for (final image in images) {
    try {
      final clean = stripPngMetadata(image.png);
      final header = readPngHeader(clean);
      media[image] = (clean, header.width, header.height);
    } on PngRejected catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'document picture refused',
        error: e,
        stackTrace: st,
      );
      throw const DocxException(DocxIssue.badImage, 'image');
    }
  }
  for (final b in doc.blocks) {
    if (b is DocxParagraph &&
        b.runs.fold<int>(0, (n, r) => n + r.text.length) >
            limits.maxParagraphChars) {
      throw const DocxException(DocxIssue.tooLarge, 'paragraph');
    }
  }
  final archive = Archive();
  void add(String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  add('[Content_Types].xml', _contentTypes);
  add(
    '_rels/.rels',
    docxRelationshipsXml(const [
      DocxRelationship('rId1', 'officeDocument', 'word/document.xml'),
      DocxRelationship('rId2', 'core-properties', 'docProps/core.xml'),
    ]),
  );
  add(
    'word/_rels/document.xml.rels',
    docxRelationshipsXml([
      const DocxRelationship('rIdStyles', 'styles', 'styles.xml'),
      const DocxRelationship('rIdNumbering', 'numbering', 'numbering.xml'),
      const DocxRelationship('rIdSettings', 'settings', 'settings.xml'),
      const DocxRelationship('rIdFooter', 'footer', 'footer1.xml'),
      for (var i = 0; i < images.length; i++)
        DocxRelationship('rIdImg${i + 1}', 'image', 'media/image${i + 1}.png'),
    ]),
  );
  for (var i = 0; i < images.length; i++) {
    final png = media[images[i]]!.$1;
    archive.addFile(
      ArchiveFile('word/media/image${i + 1}.png', png.length, png),
    );
  }
  add('word/document.xml', _document(doc, [for (final i in images) media[i]!]));
  add('word/styles.xml', _styles(doc.languageTag));
  add('word/numbering.xml', _numbering);
  add('word/settings.xml', _settings(doc.languageTag));
  add('word/footer1.xml', _footer(doc.footer));
  add('docProps/core.xml', _core(doc));

  final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
  if (bytes.length > limits.maxBytes) {
    throw const DocxException(DocxIssue.tooLarge, 'bytes');
  }
  return bytes;
}

String _runs(List<DocxRun> runs) {
  final out = StringBuffer();
  for (final run in runs) {
    final props = StringBuffer();
    if (run.bold) props.write('<w:b/>');
    if (run.italic) props.write('<w:i/>');
    final rPr = props.isEmpty ? '' : '<w:rPr>$props</w:rPr>';
    final lines = run.text.split('\n');
    out.write('<w:r>$rPr');
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) out.write('<w:br/>');
      final pieces = lines[i].split('\t');
      for (var j = 0; j < pieces.length; j++) {
        if (j > 0) out.write('<w:tab/>');
        if (pieces[j].isNotEmpty) {
          out.write('<w:t xml:space="preserve">${escapeXml(pieces[j])}</w:t>');
        }
      }
    }
    out.write('</w:r>');
  }
  return out.toString();
}

/// Text width of the page (16 cm) and the tallest picture (18 cm), in
/// EMU, so no picture is clipped or pushes a page off.
const _maxImageWidthEmu = 16 * 360000;
const _maxImageHeightEmu = 18 * 360000;

String _drawing(int n, String alt, int width, int height) {
  final scale = [
    _maxImageWidthEmu / width,
    _maxImageHeightEmu / height,
  ].reduce((a, b) => a < b ? a : b);
  final cx = (width * scale).floor();
  final cy = (height * scale).floor();
  final descr = escapeXml(alt);
  return '<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" '
      'distR="0"><wp:extent cx="$cx" cy="$cy"/>'
      '<wp:docPr id="$n" name="Illustration $n" descr="$descr"/>'
      '<wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect="1"/>'
      '</wp:cNvGraphicFramePr><a:graphic><a:graphicData uri="$_picNs">'
      '<pic:pic><pic:nvPicPr><pic:cNvPr id="$n" name="image$n.png" '
      'descr="$descr"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill>'
      '<a:blip r:embed="rIdImg$n"/><a:stretch><a:fillRect/></a:stretch>'
      '</pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/>'
      '<a:ext cx="$cx" cy="$cy"/></a:xfrm><a:prstGeom prst="rect">'
      '<a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData>'
      '</a:graphic></wp:inline></w:drawing></w:r>';
}

String _document(DocxDocument doc, List<(Uint8List, int, int)> media) {
  final body = StringBuffer();
  var bookmarkId = 0;
  var image = 0;
  for (final block in doc.blocks) {
    switch (block) {
      case DocxParagraph p:
        final pPr = StringBuffer('<w:pStyle w:val="${p.style.id}"/>');
        if (p.keepWithNext) pPr.write('<w:keepNext/>');
        body.write('<w:p><w:pPr>$pPr</w:pPr>');
        final mark = p.bookmark;
        if (mark != null) {
          body.write(
            '<w:bookmarkStart w:id="$bookmarkId" '
            'w:name="${escapeXml(mark)}"/>',
          );
        }
        body.write(_runs(p.runs));
        if (mark != null) body.write('<w:bookmarkEnd w:id="${bookmarkId++}"/>');
        body.write('</w:p>');
      case DocxImage i:
        final (_, width, height) = media[image++];
        body.write(
          '<w:p><w:pPr><w:pStyle w:val="Illustration"/>'
          '<w:keepNext/></w:pPr>'
          '${_drawing(image, i.altText, width, height)}</w:p>',
        );
    }
  }
  return '$_xmlHead<w:document xmlns:w="$_wNs" xmlns:r="$_relNs" '
      'xmlns:wp="$_wpNs" xmlns:a="$_aNs" xmlns:pic="$_picNs"><w:body>'
      '$body'
      '<w:sectPr><w:footerReference w:type="default" r:id="rIdFooter"/>'
      // A4 with 2.5 cm margins: fits Letter readers too without clipping.
      '<w:pgSz w:w="11906" w:h="16838"/>'
      '<w:pgMar w:top="1417" w:right="1417" w:bottom="1417" w:left="1417" '
      'w:header="708" w:footer="708" w:gutter="0"/>'
      '</w:sectPr></w:body></w:document>';
}

String _field(String instr, String shown) =>
    '<w:fldSimple w:instr=" $instr "><w:r><w:t>$shown</w:t></w:r>'
    '</w:fldSimple>';

String _footer(DocxFooter f) =>
    '$_xmlHead<w:ftr xmlns:w="$_wNs" xmlns:r="$_relNs"><w:p><w:pPr>'
    '<w:pStyle w:val="Footer"/><w:jc w:val="center"/></w:pPr>'
    '${_runs([DocxRun(f.before)])}${_field('PAGE', '1')}'
    '${_runs([DocxRun(f.between)])}${_field('NUMPAGES', '1')}'
    '${_runs([DocxRun(f.after)])}</w:p></w:ftr>';

String _core(DocxDocument doc) =>
    '$_xmlHead<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/'
    'package/2006/metadata/core-properties" '
    'xmlns:dc="http://purl.org/dc/elements/1.1/">'
    '<dc:title>${escapeXml(doc.title)}</dc:title>'
    '<dc:language>${escapeXml(doc.languageTag)}</dc:language>'
    '</cp:coreProperties>';

String _settings(String lang) =>
    '$_xmlHead<w:settings xmlns:w="$_wNs">'
    '<w:defaultTabStop w:val="708"/>'
    '<w:characterSpacingControl w:val="doNotCompress"/>'
    '<w:themeFontLang w:val="${escapeXml(lang)}"/>'
    '</w:settings>';

const _wordMain =
    'application/vnd.openxmlformats-officedocument.'
    'wordprocessingml';
const _contentTypes =
    '$_xmlHead'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/'
    'content-types">'
    '<Default Extension="rels" ContentType="application/vnd.'
    'openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Default Extension="png" ContentType="image/png"/>'
    '<Override PartName="/word/document.xml" '
    'ContentType="$_wordMain.document.main+xml"/>'
    '<Override PartName="/word/styles.xml" '
    'ContentType="$_wordMain.styles+xml"/>'
    '<Override PartName="/word/numbering.xml" '
    'ContentType="$_wordMain.numbering+xml"/>'
    '<Override PartName="/word/settings.xml" '
    'ContentType="$_wordMain.settings+xml"/>'
    '<Override PartName="/word/footer1.xml" '
    'ContentType="$_wordMain.footer+xml"/>'
    '<Override PartName="/docProps/core.xml" ContentType="application/vnd.'
    'openxmlformats-package.core-properties+xml"/>'
    '</Types>';

/// Two lists: decimal steps (numId 1) and bullets (numId 2).
const _numbering =
    '$_xmlHead<w:numbering xmlns:w="$_wNs">'
    '<w:abstractNum w:abstractNumId="0"><w:multiLevelType '
    'w:val="singleLevel"/><w:lvl w:ilvl="0"><w:start w:val="1"/>'
    '<w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/><w:lvlJc '
    'w:val="left"/><w:pPr><w:ind w:left="567" w:hanging="567"/></w:pPr>'
    '</w:lvl></w:abstractNum>'
    '<w:abstractNum w:abstractNumId="1"><w:multiLevelType '
    'w:val="singleLevel"/><w:lvl w:ilvl="0"><w:start w:val="1"/>'
    '<w:numFmt w:val="bullet"/><w:lvlText w:val="•"/><w:lvlJc '
    'w:val="left"/><w:pPr><w:ind w:left="567" w:hanging="283"/></w:pPr>'
    '</w:lvl></w:abstractNum>'
    '<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>'
    '<w:num w:numId="2"><w:abstractNumId w:val="1"/></w:num>'
    '</w:numbering>';

String _style(
  String id,
  String name, {
  String basedOn = 'Normal',
  String pPr = '',
  String rPr = '',
}) =>
    '<w:style w:type="paragraph" w:styleId="$id"><w:name w:val="$name"/>'
    '<w:basedOn w:val="$basedOn"/><w:next w:val="Normal"/><w:qFormat/>'
    '${pPr.isEmpty ? '' : '<w:pPr>$pPr</w:pPr>'}'
    '${rPr.isEmpty ? '' : '<w:rPr>$rPr</w:rPr>'}</w:style>';

/// Arial is named on purpose: present on Windows and macOS and
/// metric-substituted (Liberation Sans) everywhere else, so no font is
/// embedded or fetched.
String _styles(String lang) =>
    '$_xmlHead<w:styles xmlns:w="$_wNs"><w:docDefaults><w:rPrDefault>'
    '<w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:eastAsia="Arial" '
    'w:cs="Arial"/><w:sz w:val="22"/><w:szCs w:val="22"/>'
    '<w:lang w:val="${escapeXml(lang)}" w:eastAsia="${escapeXml(lang)}" '
    'w:bidi="${escapeXml(lang)}"/></w:rPr></w:rPrDefault>'
    '<w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="276" '
    'w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>'
    '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
    '<w:name w:val="Normal"/><w:qFormat/></w:style>'
    '${_style(DocxStyle.title.id, DocxStyle.title.name, pPr: '<w:keepNext/>'
        '<w:spacing w:after="240"/>', rPr: '<w:b/><w:sz w:val="40"/>')}'
    '${_style(DocxStyle.heading1.id, DocxStyle.heading1.name, pPr: '<w:keepNext/>'
        '<w:keepLines/><w:spacing w:before="360" w:after="120"/>'
        '<w:outlineLvl w:val="0"/>', rPr: '<w:b/><w:sz w:val="30"/>')}'
    '${_style(DocxStyle.listNumber.id, DocxStyle.listNumber.name, pPr: '<w:keepLines/>'
        '<w:numPr><w:numId w:val="1"/></w:numPr>')}'
    '${_style(DocxStyle.listBullet.id, DocxStyle.listBullet.name, pPr: '<w:numPr>'
        '<w:numId w:val="2"/></w:numPr>')}'
    '${_style(DocxStyle.stepDetail.id, DocxStyle.stepDetail.name, pPr: '<w:keepLines/>'
        '<w:ind w:left="567"/><w:spacing w:after="60"/>', rPr: '<w:color '
        'w:val="404040"/><w:sz w:val="20"/>')}'
    '${_style(DocxStyle.illustration.id, DocxStyle.illustration.name, pPr: '<w:keepNext/><w:jc w:val="center"/><w:spacing w:before="120" w:after="60"/>')}'
    '${_style(DocxStyle.caption.id, DocxStyle.caption.name, pPr: '<w:jc w:val="center"/>', rPr: '<w:i/><w:sz w:val="18"/>')}'
    '${_style('Footer', 'footer', rPr: '<w:sz w:val="18"/>')}'
    '</w:styles>';
