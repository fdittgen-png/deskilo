// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1872 — the local workbench, with no account and no backend: the only
// providers in its scope are the file picker, the typed saver and the
// output registry, so any read of a repository or a session would fail
// the test. A saved recording or package opens as a private draft with
// its claims as claims; a hostile, damaged, newer or oversized file is
// refused by category before anything is shown (an oversized one by its
// size, unread); a private copy leaves steps out and saves as JSON or a
// package that reads back; outputs come from the registry and are
// offered only where their generator says the platform can make them.
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo/core/files/file_picker.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/task_recorder/application/workbench_import.dart';
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:deskilo/features/task_recorder/package/task_output.dart';
import 'package:deskilo/features/task_recorder/package/task_package.dart';
import 'package:deskilo/features/task_recorder/presentation/screens/task_workbench_screen.dart';
import 'package:deskilo/features/task_recorder/providers/recorder_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/recording_fixtures.dart';

class _Doc implements TaskOutputGenerator {
  _Doc({this.available = true});
  final bool available;
  TaskRecording? got;
  @override
  String get id => 'docx';
  @override
  TaskOutputKind get kind => TaskOutputKind.document;
  @override
  String get fileExtension => 'docx';
  @override
  Future<TaskOutputAvailability> availability() async => available
      ? const TaskOutputAvailable()
      : const TaskOutputUnsupported(TaskOutputReason.unsupportedPlatform);
  @override
  Future<TaskOutputResult> generate(
    TaskOutputRequest request, {
    void Function(double fraction)? onProgress,
    TaskOutputCancel? cancel,
  }) async {
    got = request.recording;
    return TaskOutputProduced(Uint8List.fromList([1, 2, 3]), 'task.docx');
  }
}

/// A picked file whose declared length can lie, to prove the size is
/// checked before the bytes are read.
class _BigFile extends XFile {
  _BigFile() : super.fromData(Uint8List(1), name: 'big.json');
  bool read = false;
  @override
  Future<int> length() async => 200 * 1024 * 1024;
  @override
  Future<Uint8List> readAsBytes() async {
    read = true;
    return Uint8List(1);
  }
}

void main() {
  group('opening a file', () {
    test('a recording, a package, and what the package claims', () async {
      final r = (await recordFixture(BookingJourney.planConfirmed)).recording;
      final json = openTaskFile(
        Uint8List.fromList(utf8.encode(encodeRecordingText(r))),
      );
      expect((json as WorkbenchOpened).fromPackage, isFalse);
      expect(json.runnable, isTrue);
      final pkg = openTaskFile(
        writeTaskPackage(
          r,
          transcript: 'x',
          claims: const {'reviewed': 'by the owner'},
        ),
      );
      expect((pkg as WorkbenchOpened).fromPackage, isTrue);
      expect(pkg.claims, {'reviewed': 'by the owner'});
    });

    test('refusals by category, never by the file name', () {
      WorkbenchRefusal? refused(String text) =>
          switch (openTaskFile(Uint8List.fromList(utf8.encode(text)))) {
            WorkbenchRefused(:final reason) => reason,
            _ => null,
          };
      expect(
        refused(fixtureText('reject_unsafe_payload')),
        WorkbenchRefusal.invalid,
      );
      expect(
        refused(fixtureText('reject_future_schema')),
        WorkbenchRefusal.newer,
      );
      expect(refused('MZ not a task'), WorkbenchRefusal.unsupported);
      expect(
        refused('{"format": "something.else"}'),
        WorkbenchRefusal.unsupported,
      );
      final degraded = openTaskFile(
        Uint8List.fromList(utf8.encode(fixtureText('degrade_unknown_action'))),
      );
      expect((degraded as WorkbenchOpened).runnable, isFalse);
      final damaged = writeTaskPackage(
        decodeRecordingText(fixtureText('booking_list_refused')).recording!,
        transcript: 'x',
      );
      // Flip one byte of the stored transcript: the checksum no longer holds.
      final idx = utf8.decode(damaged, allowMalformed: true).lastIndexOf('x');
      final altered = Uint8List.fromList(damaged)..[idx] = 0x79;
      final result = openTaskFile(altered);
      expect(result, isA<WorkbenchRefused>());
    });
  });

  group('the screen', () {
    late Uint8List picked;
    late XFile file;
    late List<SaveOutcome> answers;
    late Map<String, Uint8List> saved;
    late _Doc doc;

    Future<void> pump(
      WidgetTester tester, {
      List<TaskOutputGenerator>? outputs,
    }) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            filePickerProvider.overrideWithValue((_) async => file),
            typedFileSaverProvider.overrideWithValue(({
              required Uint8List bytes,
              required String fileName,
            }) async {
              saved[fileName] = bytes;
              return answers.isEmpty
                  ? SavedFile('/Downloads/$fileName')
                  : answers.removeAt(0);
            }),
            taskOutputGeneratorsProvider.overrideWithValue(outputs ?? [doc]),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TaskWorkbenchScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    setUp(() async {
      final r = (await recordFixture(BookingJourney.planConfirmed)).recording;
      picked = writeTaskPackage(
        r,
        transcript: 'steps',
        claims: const {'scope': 'global admin'},
      );
      file = XFile.fromData(picked, name: 'task.deskilo-task.zip');
      answers = [];
      saved = {};
      doc = _Doc();
    });

    testWidgets('formats and limit first; open, edit a copy, save, make', (
      tester,
    ) async {
      await pump(tester);
      expect(
        find.textContaining('.deskilo-task.zip, up to 64 MB'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('workbench-choose')));
      await tester.pumpAndSettle();
      expect(find.text('Opened Reserve'), findsOneWidget);
      expect(
        find.text('The file says scope: global admin'),
        findsOneWidget,
        reason: 'a claim is shown as a claim',
      );
      expect(find.textContaining('nothing in it is trusted'), findsOneWidget);

      final attempt = readTaskPackage(picked).package!.recording.steps
          .firstWhere((s) => s.action == RecorderActions.confirmBooking)
          .seq;
      await tester.tap(find.byKey(ValueKey('task-step-toggle-$attempt')));
      await tester.pumpAndSettle();

      final package = find.byKey(const ValueKey('workbench-save-package'));
      await tester.scrollUntilVisible(
        package,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(package);
      await tester.pumpAndSettle();
      final back = readTaskPackage(saved['deskilo-task.deskilo-task.zip']!);
      expect(back.accepted, isTrue, reason: '${back.issues}');
      expect(back.package!.recording.kind, RecordingKind.edited);
      expect(back.package!.recording.steps.where((s) => s.op != null), isEmpty);
      expect(
        find.text('Saved: /Downloads/deskilo-task.deskilo-task.zip'),
        findsOneWidget,
      );

      final make = find.byKey(const ValueKey('task-output-make-docx'));
      await tester.scrollUntilVisible(
        make,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      answers.add(const DownloadRequested('task.docx'));
      ScaffoldMessenger.of(tester.element(make)).clearSnackBars();
      await tester.pumpAndSettle();
      await tester.tap(make);
      await tester.pumpAndSettle();
      expect(saved['task.docx'], [1, 2, 3]);
      expect(
        doc.got!.kind,
        RecordingKind.edited,
        reason: 'the output is made from the private copy',
      );
      expect(find.textContaining('did not say where it went'), findsOneWidget);
    });

    testWidgets('an output the platform cannot make says why, disabled', (
      tester,
    ) async {
      await pump(tester, outputs: [_Doc(available: false)]);
      await tester.tap(find.byKey(const ValueKey('workbench-choose')));
      await tester.pumpAndSettle();
      final make = find.byKey(const ValueKey('task-output-make-docx'));
      await tester.scrollUntilVisible(
        make,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(make).onPressed, isNull);
      expect(find.text('Not available on this device.'), findsOneWidget);
    });

    testWidgets('a hostile or oversized file is refused, the big one unread', (
      tester,
    ) async {
      file = XFile.fromData(
        Uint8List.fromList(utf8.encode(fixtureText('reject_orphan_outcome'))),
        name: 'task.json',
      );
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('workbench-choose')));
      await tester.pumpAndSettle();
      expect(
        find.text('This file does not hold a valid task.'),
        findsOneWidget,
      );
      expect(find.text('Opened Reserve'), findsNothing);

      final big = _BigFile();
      file = big;
      ScaffoldMessenger.of(tester.element(find.byType(ListView)))
          .clearSnackBars();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('workbench-choose')));
      await tester.pumpAndSettle();
      expect(
        find.text('This file is larger than the workbench reads.'),
        findsOneWidget,
      );
      expect(big.read, isFalse);
    });
  });
}
