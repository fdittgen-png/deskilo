// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1866 B — approved storyboard illustrations in the Word document.
//
// Invariant: only frames a person approved (and still included) become
// pictures; each is a metadata-free PNG part behind an internal image
// relationship, drawn inline at no more than the text width with the
// frame's alt text and a caption saying it is recreated; an unapproved
// scene gets a placeholder line, an omitted step a "left out" line, so
// the document keeps one numbered item per step in the storyboard's
// order; a redaction after an earlier export withdraws that picture from
// the next one; a storyboard from another recording is refused; a
// malformed or excessive picture is refused by the writer; and no canary
// reaches any part, pictures included.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:deskilo/features/task_recorder/export/docx/docx_writer.dart';
import 'package:deskilo/features/task_recorder/export/docx_export.dart';
import 'package:deskilo/features/task_recorder/export/task_document.dart';
import 'package:deskilo/features/task_recorder/storyboard/png_safety.dart';
import 'package:deskilo/features/task_recorder/storyboard/storyboard.dart';
import 'package:deskilo/features/task_recorder/storyboard/storyboard_builder.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import '../fixtures/recording_fixtures.dart';

const _w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
const _wp =
    'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing';

AppLocalizations _l(String code) => lookupAppLocalizations(Locale(code));

TaskRecording _fixture(BookingJourney j) =>
    decodeRecordingText(fixtureText(j.file)).recording!;

Map<String, Uint8List> _unzip(Uint8List bytes) => {
  for (final f in ZipDecoder().decodeBytes(bytes).files)
    if (f.isFile) f.name: Uint8List.fromList(f.content),
};

XmlDocument _xml(Map<String, Uint8List> parts, String name) =>
    XmlDocument.parse(utf8.decode(parts[name]!));

/// Saves [r] with [sb] and returns the package parts.
Future<Map<String, Uint8List>> _export(
  WidgetTester tester,
  TaskRecording r,
  Storyboard sb, {
  String code = 'en',
}) async {
  Uint8List? saved;
  final exporter = TaskDocxExporter(({
    required bytes,
    required fileName,
  }) async {
    saved = bytes;
    return SavedFile(fileName);
  });
  final result = await tester.runAsync(
    () => exporter.save(r, _l(code), storyboard: sb),
  );
  expect(result, isA<TaskDocxSaved>());
  return _unzip(saved!);
}

List<int> _sceneIndexes(Storyboard sb) => [
  for (var i = 0; i < sb.frames.length; i++)
    if (sb.frames[i].source == IllustrationSource.recreatedScene) i,
];

void main() {
  testWidgets('approved frames become captioned, alt-texted pictures', (
    tester,
  ) async {
    final r = _fixture(BookingJourney.planConfirmed);
    final l = _l('en');
    var sb = buildStoryboard(r, l);
    final scenes = _sceneIndexes(sb);
    sb = sb.setApproved(scenes[0], true).setApproved(scenes[1], true);
    sb = sb.addRedaction(scenes[1], const NormalizedRect(0, 0, 0.3, 0.3));
    sb = sb.setApproved(scenes[1], true);
    final textFrame = sb.frames.indexWhere(
      (f) => f.source == IllustrationSource.textSlide,
    );
    sb = sb.setOmitted(textFrame, true).move(0, 1);
    final parts = await _export(tester, r, sb);

    // Two media parts, metadata-free, behind internal relationships.
    final media = parts.keys.where((k) => k.startsWith('word/media/')).toList()
      ..sort();
    expect(media, ['word/media/image1.png', 'word/media/image2.png']);
    for (final m in media) {
      expect(pngChunkTypes(parts[m]!).toSet(), {'IHDR', 'IDAT', 'IEND'});
    }
    final rels = _xml(parts, 'word/_rels/document.xml.rels')
        .findAllElements('Relationship')
        .where((e) => e.getAttribute('Type')!.endsWith('/image'))
        .map((e) => e.getAttribute('Target'))
        .toList();
    expect(rels, ['media/image1.png', 'media/image2.png']);
    expect(
      _xml(
        parts,
        '[Content_Types].xml',
      ).findAllElements('Default').map((e) => e.getAttribute('Extension')),
      contains('png'),
    );

    // Inline pictures with the frames' alt text, within the text width.
    final doc = _xml(parts, 'word/document.xml');
    final inlines = doc.findAllElements('inline', namespace: _wp).toList();
    expect(inlines, hasLength(2));
    final alts = inlines
        .map(
          (i) => i
              .findElements('docPr', namespace: _wp)
              .single
              .getAttribute('descr'),
        )
        .toList();
    expect(alts.toSet(), {
      sb.frames[scenes[0]].altText,
      sb.frames[scenes[1]].altText,
    });
    for (final i in inlines) {
      final extent = i.findElements('extent', namespace: _wp).single;
      expect(int.parse(extent.getAttribute('cx')!), lessThanOrEqualTo(5760000));
      expect(int.parse(extent.getAttribute('cy')!), lessThanOrEqualTo(6480000));
    }

    // One numbered item per step, in the storyboard's order.
    final paras = doc.findAllElements('p', namespace: _w).toList();
    String style(XmlElement p) =>
        p
            .findAllElements('pStyle', namespace: _w)
            .firstOrNull
            ?.getAttribute('val', namespace: _w) ??
        '';
    String text(XmlElement p) =>
        p.findAllElements('t', namespace: _w).map((t) => t.innerText).join();
    final numbered = paras.where((p) => style(p) == 'ListNumber').toList();
    expect(
      numbered.map(
        (p) => p
            .findAllElements('bookmarkStart', namespace: _w)
            .single
            .getAttribute('name', namespace: _w),
      ),
      [for (final f in sb.frames) 'step_${f.stepSeq}'],
    );
    final all = paras.map(text).join('\n');
    expect(all, contains(l.taskExportStoryboardLeftOut));
    expect(all, contains(l.taskExportIllustrationNotApproved));
    expect(all, contains(l.taskExportLimitRecreated));
    expect(all, isNot(contains(l.taskExportLimitNoIllustrations)));
    expect(
      paras.where((p) => style(p) == 'Caption').map(text),
      everyElement(l.taskExportSceneProvenance),
    );
  });

  testWidgets('a redaction after an export withdraws the picture', (
    tester,
  ) async {
    final r = _fixture(BookingJourney.listRefused);
    final l = _l('fr');
    var sb = buildStoryboard(r, l);
    final i = _sceneIndexes(sb).first;
    sb = sb.setApproved(i, true);
    final first = await _export(tester, r, sb, code: 'fr');
    expect(first.keys.where((k) => k.startsWith('word/media/')), hasLength(1));
    sb = sb.addRedaction(i, const NormalizedRect(0.1, 0.1, 0.2, 0.2));
    final second = await _export(tester, r, sb, code: 'fr');
    expect(second.keys.where((k) => k.startsWith('word/media/')), isEmpty);
    expect(
      utf8.decode(second['word/document.xml']!),
      contains(escapeXml(l.taskExportIllustrationNotApproved)),
    );
  });

  testWidgets('a storyboard of another recording is refused', (tester) async {
    final sb = buildStoryboard(_fixture(BookingJourney.listRefused), _l('en'));
    final exporter = TaskDocxExporter(
      ({required bytes, required fileName}) async => SavedFile(fileName),
    );
    final result = await tester.runAsync(
      () => exporter.save(
        _fixture(BookingJourney.planConfirmed),
        _l('en'),
        storyboard: sb,
      ),
    );
    expect(
      result,
      isA<TaskDocxRefused>().having(
        (r) => r.refusal,
        'refusal',
        TaskExportRefusal.stale,
      ),
    );
  });

  testWidgets('no canary in any part, pictures included', (tester) async {
    for (final j in BookingJourney.values) {
      final recorded = await tester.runAsync(() => recordFixture(j));
      final r = recorded!.recording;
      var sb = buildStoryboard(r, _l('de'));
      for (final i in _sceneIndexes(sb)) {
        sb = sb.setApproved(i, true);
      }
      final parts = await _export(tester, r, sb, code: 'de');
      expect(parts.keys.where((k) => k.startsWith('word/media/')), isNotEmpty);
      for (final MapEntry(key: name, value: bytes) in parts.entries) {
        final text = latin1.decode(bytes).toLowerCase();
        for (final c in [...privateCanaries, ...canaryFragments]) {
          expect(
            text.contains(c.toLowerCase()),
            isFalse,
            reason: '$c in $name',
          );
        }
      }
    }
  });

  test('the writer refuses a malformed or excessive picture', () {
    DocxDocument doc(List<DocxBlock> blocks) => DocxDocument(
      title: 't',
      languageTag: 'en-US',
      blocks: blocks,
      footer: const DocxFooter('', '/', ''),
    );
    expect(
      () => buildDocx(
        doc([
          DocxImage(Uint8List.fromList([1, 2, 3]), 'a'),
        ]),
      ),
      throwsA(
        isA<DocxException>().having(
          (e) => e.issue,
          'issue',
          DocxIssue.badImage,
        ),
      ),
    );
    expect(
      () => buildDocx(
        doc([for (var i = 0; i < 3; i++) DocxImage(Uint8List(10), 'a')]),
        limits: const DocxLimits(maxImages: 2),
      ),
      throwsA(
        isA<DocxException>().having(
          (e) => e.issue,
          'issue',
          DocxIssue.tooLarge,
        ),
      ),
    );
  });
}
