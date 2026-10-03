// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1876 — a package keeps the reviewed storyboard: what the person
// decided (order, omissions, captions, durations, redactions, approvals)
// round-trips through a version-2 package and is replayed, through the
// storyboard's own edit rules, on a storyboard derived again from the
// same recording. A review made for another revision is set aside; a
// hostile review is refused; a package without a storyboard stays
// version 1; and the workbench restores the review on import and passes
// it to the outputs.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:deskilo/core/files/file_picker.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/task_recorder/package/storyboard_review.dart';
import 'package:deskilo/features/task_recorder/package/task_output.dart';
import 'package:deskilo/features/task_recorder/package/task_package.dart';
import 'package:deskilo/features/task_recorder/presentation/screens/task_workbench_screen.dart';
import 'package:deskilo/features/task_recorder/providers/recorder_providers.dart';
import 'package:deskilo/features/task_recorder/storyboard/storyboard.dart';
import 'package:deskilo/features/task_recorder/storyboard/storyboard_builder.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/real_async.dart';
import 'fixtures/recording_fixtures.dart';

AppLocalizations get _en => lookupAppLocalizations(const Locale('en'));

/// A reviewed storyboard: one approval, one caption, one omission.
Storyboard _reviewed(Storyboard s) {
  final drawn = s.frames.indexWhere(
    (f) => f.source == IllustrationSource.recreatedScene,
  );
  var out = s.setCaption(0, 'Open Reserve from the bar');
  out = out.setOmitted(1, true);
  if (drawn >= 0) out = out.setApproved(drawn, true);
  return out;
}

class _Capture implements TaskOutputGenerator {
  Storyboard? story;
  @override
  String get id => 'docx';
  @override
  TaskOutputKind get kind => TaskOutputKind.document;
  @override
  String get fileExtension => 'docx';
  @override
  Future<TaskOutputAvailability> availability() async =>
      const TaskOutputAvailable();
  @override
  Future<TaskOutputResult> generate(
    TaskOutputRequest request, {
    void Function(double fraction)? onProgress,
    TaskOutputCancel? cancel,
  }) async {
    story = request.storyboard;
    return TaskOutputProduced(Uint8List.fromList([1]), 'x.docx');
  }
}

void main() {
  test(
    'decisions round-trip and replay on a storyboard derived again',
    () async {
      final r = (await recordFixture(BookingJourney.planConfirmed)).recording;
      final reviewed = _reviewed(buildStoryboard(r, _en));
      final text = StoryboardReview.of(reviewed).toText();
      final parsed = StoryboardReview.parse(text)!;
      final replay = applyReview(buildStoryboard(r, _en), parsed);
      expect(replay.outcome, ReviewOutcome.applied);
      expect(
        replay.storyboard.frames.map(
          (f) => (f.stepSeq, f.approved, f.omitted, f.caption),
        ),
        reviewed.frames.map(
          (f) => (f.stepSeq, f.approved, f.omitted, f.caption),
        ),
      );
      for (final c in [...privateCanaries, ...canaryFragments]) {
        expect(text.contains(c), isFalse, reason: c);
      }
    },
  );

  test('a review for another revision is set aside, not applied', () async {
    final a = (await recordFixture(BookingJourney.planConfirmed)).recording;
    final b = (await recordFixture(BookingJourney.listRefused)).recording;
    final review = StoryboardReview.of(_reviewed(buildStoryboard(a, _en)));
    expect(
      applyReview(buildStoryboard(b, _en), review).outcome,
      ReviewOutcome.stale,
    );
  });

  test('a hostile review is refused, not trimmed', () async {
    final r = (await recordFixture(BookingJourney.planConfirmed)).recording;
    Map<String, Object?> json() => (jsonDecode(
      StoryboardReview.of(buildStoryboard(r, _en)).toText(),
    ) as Map).cast<String, Object?>();
    List<Map<String, Object?>> frames(Map<String, Object?> j) =>
        (j['frames']! as List).cast<Map<String, Object?>>();
    expect(
      StoryboardReview.parse(jsonEncode(json()..['script'] = 'x')),
      isNull,
    );
    final long = json();
    frames(long)[0]['caption'] = 'x' * 500;
    expect(StoryboardReview.parse(jsonEncode(long)), isNull);
    final rect = json();
    frames(rect)[0]['redactions'] = [
      [0.5, 0.5, 0.9, 0.9],
    ];
    expect(StoryboardReview.parse(jsonEncode(rect)), isNull);
    final stranger = json();
    frames(stranger)[0]['step_seq'] = 999;
    final parsed = StoryboardReview.parse(jsonEncode(stranger))!;
    expect(
      applyReview(buildStoryboard(r, _en), parsed).outcome,
      ReviewOutcome.invalid,
    );
  });

  test(
    'a package carries it as version 2; without one it stays version 1',
    () async {
      final r = (await recordFixture(BookingJourney.planConfirmed)).recording;
      final review = StoryboardReview.of(_reviewed(buildStoryboard(r, _en)));
      final with2 = writeTaskPackage(r, storyboard: review);
      final read = readTaskPackage(with2);
      expect(read.accepted, isTrue, reason: '${read.issues}');
      expect(read.package!.storyboard!.frames.length, review.frames.length);
      String manifest(Uint8List zip) => utf8.decode(
        ZipDecoder()
            .decodeBytes(zip)
            .files
            .firstWhere((f) => f.name == 'manifest.json')
            .content,
      );
      expect(manifest(with2), contains('"package_version": 2'));
      expect(manifest(writeTaskPackage(r)), contains('"package_version": 1'));
    },
  );

  testWidgets('the workbench restores the review and hands it on', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final r = (await recordFixture(BookingJourney.planConfirmed)).recording;
    final reviewed = _reviewed(buildStoryboard(r, _en));
    final zip = writeTaskPackage(r, storyboard: StoryboardReview.of(reviewed));
    final capture = _Capture();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filePickerProvider.overrideWithValue(
            (_) async => XFile.fromData(zip, name: 'task.deskilo-task.zip'),
          ),
          typedFileSaverProvider.overrideWithValue(
            ({required Uint8List bytes, required String fileName}) async =>
                SavedFile('/Downloads/$fileName'),
          ),
          taskOutputGeneratorsProvider.overrideWithValue([capture]),
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
    await tester.tap(find.byKey(const ValueKey('workbench-choose')));
    await tester.pumpAndSettle();
    expect(find.textContaining('restored from the file'), findsOneWidget);
    final make = find.byKey(const ValueKey('task-output-make-docx'));
    await tester.scrollUntilVisible(
      make,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(make);
    await tester.pumpAndSettle();
    expect(capture.story, isNotNull);
    expect(
      capture.story!.frames.where((f) => f.approved).length,
      reviewed.frames.where((f) => f.approved).length,
    );
    expect(capture.story!.frames[0].caption, 'Open Reserve from the bar');
  });

  testWidgets('saving the package keeps the review and the approved pictures', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final r = (await recordFixture(BookingJourney.planConfirmed)).recording;
    final reviewed = _reviewed(buildStoryboard(r, _en));
    final zip = writeTaskPackage(r, storyboard: StoryboardReview.of(reviewed));
    final saved = <String, Uint8List>{};
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filePickerProvider.overrideWithValue(
            (_) async => XFile.fromData(zip, name: 'task.deskilo-task.zip'),
          ),
          typedFileSaverProvider.overrideWithValue(({
            required Uint8List bytes,
            required String fileName,
          }) async {
            saved[fileName] = bytes;
            return SavedFile('/Downloads/$fileName');
          }),
          taskOutputGeneratorsProvider.overrideWithValue(const []),
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
    await tester.tap(find.byKey(const ValueKey('workbench-choose')));
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('workbench-save-package'));
    await tester.scrollUntilVisible(
      save,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    // The approved pictures are drawn for real: let real time pass.
    await tester.runAsync(() async {
      await tester.tap(save);
      await untilReal(() async {
        await tester.pump();
        return saved.isNotEmpty;
      }, what: 'the package with its pictures');
    });
    await tester.pump();
    final back = readTaskPackage(saved.values.single);
    expect(back.accepted, isTrue, reason: '${back.issues}');
    expect(back.package!.storyboard, isNotNull);
    final approved = reviewed.frames
        .where((f) => f.approved)
        .map((f) => f.stepSeq);
    expect(
      back.package!.assets.map((a) => a.path),
      containsAll([for (final seq in approved) 'media/frame-$seq.png']),
    );
  });
}
