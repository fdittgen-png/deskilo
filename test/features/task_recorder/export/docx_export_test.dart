// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1866 A — the Word export is a genuine, private OpenXML package.
//
// Invariant: every export of a shared fixture recording unzips into
// well-formed XML parts that the content types and relationships fully
// account for, with only internal relationships, cleaned core
// properties, the document language, page fields, and exactly one
// numbered paragraph per recorded step in recording order; none of the
// private canaries appears in ANY part (raw bytes and decoded text); an
// oversized, empty or refused recording is refused, and a failed save is
// reported as failed with the recording unchanged. Read back with the
// `archive` and `xml` packages, independently of the writer's strings.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:deskilo/features/task_recorder/export/docx/docx_writer.dart';
import 'package:deskilo/features/task_recorder/export/docx_export.dart';
import 'package:deskilo/features/task_recorder/export/task_document.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import '../fixtures/recording_fixtures.dart';

const _w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

AppLocalizations _l(String code) => lookupAppLocalizations(Locale(code));

TaskRecording _fixture(BookingJourney j) =>
    decodeRecordingText(fixtureText(j.file)).recording!;

Map<String, Uint8List> _unzip(Uint8List bytes) => {
  for (final f in ZipDecoder().decodeBytes(bytes).files)
    if (f.isFile) f.name: Uint8List.fromList(f.content),
};

XmlDocument _xml(Map<String, Uint8List> parts, String name) =>
    XmlDocument.parse(utf8.decode(parts[name]!));

/// The paragraphs of word/document.xml with their style and text.
List<({String style, String text, String? bookmark})> _paragraphs(
  Map<String, Uint8List> parts,
) {
  final doc = _xml(parts, 'word/document.xml');
  return [
    for (final p in doc.findAllElements('p', namespace: _w))
      (
        style:
            p
                .findAllElements('pStyle', namespace: _w)
                .firstOrNull
                ?.getAttribute('val', namespace: _w) ??
            '',
        text: p
            .findAllElements('t', namespace: _w)
            .map((t) => t.innerText)
            .join(),
        bookmark: p
            .findAllElements('bookmarkStart', namespace: _w)
            .firstOrNull
            ?.getAttribute('name', namespace: _w),
      ),
  ];
}

void _expectNoCanary(Map<String, Uint8List> parts) {
  for (final MapEntry(key: name, value: bytes) in parts.entries) {
    final text = utf8.decode(bytes, allowMalformed: true);
    for (final c in [...privateCanaries, ...canaryFragments]) {
      expect(text.contains(c), isFalse, reason: '$c leaked into $name');
      expect(
        text.toLowerCase().contains(c.toLowerCase()),
        isFalse,
        reason: '$c (any case) leaked into $name',
      );
    }
  }
}

void main() {
  group('package structure', () {
    for (final journey in BookingJourney.values) {
      test('${journey.file}: every part parses and is accounted for', () {
        final recording = _fixture(journey);
        final parts = _unzip(exportDocx(recording, _l('en')));

        for (final name in parts.keys) {
          if (name.endsWith('.xml') || name.endsWith('.rels')) {
            expect(() => _xml(parts, name), returnsNormally, reason: name);
          }
        }
        // Content types name every non-rels part; relationships point
        // only inside the package, at parts that exist.
        final types = _xml(parts, '[Content_Types].xml');
        final overrides = {
          for (final o in types.findAllElements('Override'))
            o.getAttribute('PartName')!.substring(1),
        };
        expect(
          parts.keys.where(
            (n) => !n.endsWith('.rels') && n != '[Content_Types].xml',
          ),
          everyElement(isIn(overrides)),
        );
        for (final (rels, base) in [
          ('_rels/.rels', ''),
          ('word/_rels/document.xml.rels', 'word/'),
        ]) {
          for (final r in _xml(parts, rels).findAllElements('Relationship')) {
            expect(r.getAttribute('TargetMode'), isNull);
            expect(
              parts.containsKey('$base${r.getAttribute('Target')}'),
              isTrue,
              reason: '$rels → ${r.getAttribute('Target')}',
            );
          }
        }
        expect(
          parts.keys.where(
            (n) =>
                n.contains('vbaProject') ||
                n.contains('customXml') ||
                n.contains('comments') ||
                n.endsWith('app.xml'),
          ),
          isEmpty,
        );

        // Cleaned core properties: title and language, nothing else.
        final core = _xml(parts, 'docProps/core.xml').rootElement;
        expect(core.childElements.map((e) => e.localName).toSet(), {
          'title',
          'language',
        });
        expect(
          core.findAllElements('language', namespace: '*').single.innerText,
          'en-US',
        );

        // Document language and page fields.
        final lang = _xml(
          parts,
          'word/styles.xml',
        ).findAllElements('lang', namespace: _w).single;
        expect(lang.getAttribute('val', namespace: _w), 'en-US');
        final instr = _xml(parts, 'word/footer1.xml')
            .findAllElements('fldSimple', namespace: _w)
            .map((f) => f.getAttribute('instr', namespace: _w)!.trim());
        expect(instr, ['PAGE', 'NUMPAGES']);
        // Named heading and list styles are defined.
        final styles = _xml(parts, 'word/styles.xml')
            .findAllElements('style', namespace: _w)
            .map((s) => s.getAttribute('styleId', namespace: _w))
            .toSet();
        expect(
          styles,
          containsAll([
            'Title',
            'Heading1',
            'ListNumber',
            'ListBullet',
            'StepDetail',
            'Footer',
          ]),
        );
        expect(
          _xml(parts, 'word/numbering.xml')
              .findAllElements('numFmt', namespace: _w)
              .map((e) => e.getAttribute('val', namespace: _w)),
          ['decimal', 'bullet'],
        );
      });

      test('${journey.file}: one numbered item per step, in order', () {
        final recording = _fixture(journey);
        final paras = _paragraphs(_unzip(exportDocx(recording, _l('en'))));
        final steps = paras.where((p) => p.style == 'ListNumber').toList();
        expect(steps.map((p) => p.bookmark), [
          for (final s in recording.steps) 'step_${s.seq}',
        ]);
        expect(steps.every((p) => p.text.trim().isNotEmpty), isTrue);
        expect(paras.first.style, 'Title');
        expect(paras.first.text, 'Book a desk');
        expect(
          paras.where((p) => p.text.contains(recordingRevision(recording))),
          hasLength(1),
        );
      });
    }

    test('outcomes are stated as recorded, never as success', () {
      String steps(BookingJourney j) =>
          _paragraphs(_unzip(exportDocx(_fixture(j), _l('en'))))
              .map((p) => p.text)
              .join('\n');
      final l = _l('en');
      expect(
        steps(BookingJourney.planConfirmed),
        contains(l.taskExportResult(l.taskExportOutcomeConfirmed)),
      );
      final refused = steps(BookingJourney.listRefused);
      expect(refused, contains(l.taskExportResult(l.taskExportOutcomeRefused)));
      expect(
        refused,
        contains(
          l.taskExportDetail(
            l.taskExportFieldRefusal,
            l.taskExportValueConflict,
          ),
        ),
      );
      expect(refused, isNot(contains(l.taskExportOutcomeConfirmed)));
      final unknown = steps(BookingJourney.unknownOutcome);
      expect(unknown, contains(l.taskExportOutcomeUnknown));
      expect(unknown, isNot(contains(l.taskExportOutcomeConfirmed)));
      expect(
        steps(BookingJourney.cancelledReview),
        contains(l.taskExportActionCancelReview),
      );
    });
  });

  group('privacy', () {
    for (final journey in BookingJourney.values) {
      for (final notes in [false, true]) {
        test(
          '${journey.file} (notes: $notes): no canary in any part',
          () async {
            // Recorded live with canaries at every capture boundary.
            final recorded = await recordFixture(journey);
            for (final code in ['en', 'fr', 'de', 'es', 'it']) {
              _expectNoCanary(
                _unzip(
                  exportDocx(
                    recorded.recording,
                    _l(code),
                    options: TaskDocumentOptions(includeNotes: notes),
                  ),
                ),
              );
            }
          },
        );
      }
    }

    test('a note is left out unless notes are included, and then labelled', () {
      final r = _fixture(BookingJourney.cancelledReview);
      final l = _l('en');
      String text(bool notes) => _paragraphs(
        _unzip(
          exportDocx(r, l, options: TaskDocumentOptions(includeNotes: notes)),
        ),
      ).map((p) => p.text).join('\n');
      expect(text(false), isNot(contains('I only wanted to look.')));
      expect(text(false), contains(l.taskExportNoteOmitted));
      expect(text(true), contains(l.taskExportNote('I only wanted to look.')));
    });

    test('an external relationship is refused', () {
      for (final target in [
        'https://canary.invalid/x.png',
        '../outside.xml',
        '/abs/path.xml',
        r'file:\\host\share.xml',
      ]) {
        expect(
          () =>
              docxRelationshipsXml([DocxRelationship('rId9', 'image', target)]),
          throwsA(
            isA<DocxException>().having(
              (e) => e.issue,
              'issue',
              DocxIssue.externalRelationship,
            ),
          ),
          reason: target,
        );
      }
    });
  });

  group('content and languages', () {
    test('five locales: language tag, translated headings', () {
      final r = _fixture(BookingJourney.planConfirmed);
      final tags = <String>{};
      for (final code in ['en', 'fr', 'de', 'es', 'it']) {
        final l = _l(code);
        final parts = _unzip(exportDocx(r, l));
        final tag = _xml(
          parts,
          'docProps/core.xml',
        ).findAllElements('language', namespace: '*').single.innerText;
        tags.add(tag);
        expect(tag, startsWith(code));
        final headings = _paragraphs(parts)
            .where((p) => p.style == 'Heading1')
            .map((p) => p.text)
            .toList();
        expect(headings, [
          l.taskExportSectionAbout,
          l.taskExportSectionBefore,
          l.taskExportSectionSteps,
          l.taskExportSectionLimits,
        ]);
        final footer = _xml(
          parts,
          'word/footer1.xml',
        ).findAllElements('t', namespace: _w).map((t) => t.innerText).join();
        expect(footer, isNot(contains('\u0001')));
      }
      expect(tags, hasLength(5));
    });

    test('Unicode, markup and control characters survive escaping', () {
      final r = TaskRecording(
        actionContractVersion: 1,
        platform: RecordingPlatform.web,
        title: 'Réserver <b>&"\'</b> 漢字 😀\u0001 end',
        segments: const [RecordingSegment(index: 0, startMs: 0, endMs: 900)],
        steps: const [
          RecordedStep(
            seq: 1,
            segment: 0,
            elapsedMs: 100,
            kind: StepKind.action,
            surface: RecorderSurfaces.reserve,
            action: RecorderActions.openReserve,
            actionVersion: 1,
          ),
        ],
        endReason: RecordingEndReason.stopped,
      );
      final parts = _unzip(exportDocx(r, _l('fr')));
      expect(_paragraphs(parts).first.text, 'Réserver <b>&"\'</b> 漢字 😀 end');
      expect(
        _xml(
          parts,
          'docProps/core.xml',
        ).findAllElements('title', namespace: '*').single.innerText,
        'Réserver <b>&"\'</b> 漢字 😀 end',
      );
    });

    test('the most steps a recording may hold export; one more is refused', () {
      TaskRecording many(int n) => TaskRecording(
        actionContractVersion: 1,
        platform: RecordingPlatform.android,
        segments: [RecordingSegment(index: 0, startMs: 0, endMs: n * 10 + 10)],
        steps: [
          for (var i = 1; i <= n; i++)
            RecordedStep(
              seq: i,
              segment: 0,
              elapsedMs: i * 10,
              kind: StepKind.action,
              surface: RecorderSurfaces.reserve,
              action: RecorderActions.selectDate,
              actionVersion: 1,
            ),
        ],
        endReason: RecordingEndReason.stopped,
      );
      const limits = RecordingLimits();
      final paras = _paragraphs(
        _unzip(exportDocx(many(limits.maxSteps), _l('en'))),
      );
      expect(
        paras.where((p) => p.style == 'ListNumber'),
        hasLength(limits.maxSteps),
      );
      expect(
        () => exportDocx(many(limits.maxSteps + 1), _l('en')),
        throwsA(
          isA<TaskExportException>().having(
            (e) => e.refusal,
            'refusal',
            TaskExportRefusal.tooLarge,
          ),
        ),
      );
    });

    test('an empty recording is refused, not exported as a blank document', () {
      final r = TaskRecording(
        actionContractVersion: 1,
        platform: RecordingPlatform.android,
        segments: const [],
        steps: const [],
        endReason: RecordingEndReason.stopped,
      );
      expect(
        () => exportDocx(r, _l('en')),
        throwsA(
          isA<TaskExportException>().having(
            (e) => e.refusal,
            'refusal',
            TaskExportRefusal.empty,
          ),
        ),
      );
    });

    test('an unknown action is shown as undescribable, and says so', () {
      final decoded = decodeRecordingText(
        fixtureText('degrade_unknown_action'),
      );
      expect(decoded.runnable, isFalse);
      final l = _l('en');
      final text = _paragraphs(_unzip(exportDocx(decoded.recording!, l)))
          .map((p) => p.text)
          .join('\n');
      expect(text, contains(l.taskExportUnrecorded));
      expect(text, contains(l.taskExportLimitNotRunnable));
      expect(text, isNot(contains('book_and_pay')));
      expect(text, isNot(contains('4111')));
    });

    test('an edited recording marks authored steps as not observed', () {
      final source = _fixture(BookingJourney.planConfirmed);
      final edited = TaskRecording(
        actionContractVersion: source.actionContractVersion,
        platform: source.platform,
        kind: RecordingKind.edited,
        sourceDigest: recordingDigest(source),
        title: source.title,
        segments: source.segments,
        steps: [
          source.steps.first,
          const RecordedStep(
            seq: 2,
            segment: 0,
            elapsedMs: 500,
            kind: StepKind.action,
            surface: RecorderSurfaces.reserve,
            action: RecorderActions.selectPeriod,
            actionVersion: 1,
            origin: StepOrigin.authored,
          ),
        ],
        endReason: RecordingEndReason.stopped,
      );
      final l = _l('en');
      final text = _paragraphs(_unzip(exportDocx(edited, l)))
          .map((p) => p.text)
          .join('\n');
      expect(text, contains(l.taskExportKindEdited));
      expect(text, contains(l.taskExportAuthored));
      expect(text, contains(l.taskExportLimitEdited));
    });
  });

  group('saving', () {
    test('saved: the saver gets a .docx named by title and revision', () async {
      final r = _fixture(BookingJourney.planConfirmed);
      final before = encodeRecordingText(r);
      String? savedName;
      Uint8List? savedBytes;
      final exporter = TaskDocxExporter(({
        required bytes,
        required fileName,
      }) async {
        savedName = fileName;
        savedBytes = bytes;
        return SavedFile('/downloads/$fileName');
      });
      final result = await exporter.save(r, _l('en'));
      expect(
        result,
        isA<TaskDocxSaved>().having(
          (s) => s.outcome,
          'outcome',
          isA<SavedFile>(),
        ),
      );
      expect(savedName, 'procedure-book-a-desk-${recordingRevision(r)}.docx');
      expect(_unzip(savedBytes!), contains('word/document.xml'));
      expect(encodeRecordingText(r), before);
    });

    test('a cancelled or failing save is reported as failed', () async {
      final r = _fixture(BookingJourney.planConfirmed);
      final before = encodeRecordingText(r);
      final cancelled = TaskDocxExporter(
        ({required bytes, required fileName}) async => const SaveFailed(),
      );
      final throwing = TaskDocxExporter(
        ({required bytes, required fileName}) async =>
            throw const FileSystemLikeError(),
      );
      expect(await cancelled.save(r, _l('en')), isA<TaskDocxSaveFailed>());
      expect(await throwing.save(r, _l('en')), isA<TaskDocxSaveFailed>());
      expect(encodeRecordingText(r), before);
    });

    test('a refused import never reaches the saver', () async {
      var calls = 0;
      final exporter = TaskDocxExporter(({
        required bytes,
        required fileName,
      }) async {
        calls++;
        return DownloadRequested(fileName);
      });
      for (final name in [
        'reject_claims_complete',
        'reject_future_schema',
        'reject_orphan_outcome',
        'reject_unknown_key',
        'reject_unsafe_payload',
      ]) {
        final result = await exporter.saveFromText(fixtureText(name), _l('en'));
        expect(
          result,
          isA<TaskDocxRefused>().having(
            (r) => r.refusal,
            'refusal',
            TaskExportRefusal.rejected,
          ),
          reason: name,
        );
      }
      expect(
        await exporter.saveFromText('{not json', _l('en')),
        isA<TaskDocxRefused>(),
      );
      expect(calls, 0);
      expect(
        await exporter.saveFromText(
          fixtureText(BookingJourney.listRefused.file),
          _l('de'),
        ),
        isA<TaskDocxSaved>(),
      );
      expect(calls, 1);
    });

    test('the provider exports through the app file saver', () async {
      String? savedName;
      final container = ProviderContainer(
        overrides: [
          typedFileSaverProvider.overrideWithValue(({
            required bytes,
            required fileName,
          }) async {
            savedName = fileName;
            return SavedPrivately(fileName);
          }),
        ],
      );
      addTearDown(container.dispose);
      final result = await container
          .read(taskDocxExporterProvider)
          .save(_fixture(BookingJourney.listRefused), _l('it'));
      expect(result, isA<TaskDocxSaved>());
      expect(savedName, endsWith('.docx'));
    });
  });
}

class FileSystemLikeError implements Exception {
  const FileSystemLikeError();
}
