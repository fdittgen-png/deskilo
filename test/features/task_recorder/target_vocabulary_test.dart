// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4158 (A3 of #4174) — a validation-rule step names its event type through a
// vocabulary the app composes into the recorder, not through the events
// feature: (1) the recorder text and transcript ask the vocabulary they are
// given; (2) the app's real event adapter gives the canonical event label in
// every language, and the default rule and an unknown target keep their
// fallbacks; (3) the production composition renders the step in the recorded
// steps widget and in the exported transcript, and a scope that did not
// compose one fails loudly instead of reading every rule as unknown.
import 'package:deskilo/app/recorder_target_wiring.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/presentation/event_labels.dart';
import 'package:deskilo/features/task_recorder/data/recorder_store.dart';
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/presentation/recorder_labels.dart';
import 'package:deskilo/features/task_recorder/presentation/recorder_target_vocabulary.dart';
import 'package:deskilo/features/task_recorder/presentation/recording_export.dart';
import 'package:deskilo/features/task_recorder/presentation/widgets/recording_steps_view.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_task_recording/task_recording.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/memory_recorder_log_backend.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';
import 'fixtures/recording_fixtures.dart';

const _languages = ['en', 'fr', 'de', 'es', 'it'];

/// A vocabulary that says what it was asked: the recorder must call it.
class _Asked implements RecorderTargetVocabulary {
  final List<(String, String)> asked = [];

  @override
  String? labelOf(AppLocalizations l10n, String action, String target) {
    asked.add((action, target));
    return target == 'reservation' ? 'FAKE-WORDS-FOR-RESERVATION' : null;
  }
}

Future<TaskRecording> _recording(String target) async {
  final c = fixtureController(
    RecorderStore(
      backend: MemoryRecorderLogBackend(),
      namespace: canaryNamespace,
    ),
    StepClock(),
  );
  await c.start(scope: canaryScope);
  c.attempt(RecorderActions.saveValidationRule, target: target);
  final r = (await c.stop())!;
  await c.dispose();
  return r;
}

void main() {
  group('the recorder asks the vocabulary it is given', () {
    test('the step text and the transcript use the supplied words, not the '
        'events feature\'s', () async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final fake = _Asked();
      final r = await _recording('reservation');
      final step = r.steps.single;

      final text = stepText(l10n, step, vocabulary: fake);
      expect(text.detail, 'FAKE-WORDS-FOR-RESERVATION');
      expect(fake.asked, [(RecorderActions.saveValidationRule, 'reservation')]);

      final transcript = recordingTranscript(l10n, r, vocabulary: fake);
      expect(transcript, contains('FAKE-WORDS-FOR-RESERVATION'));
      expect(
        transcript,
        isNot(contains(eventTypeLabel(l10n, EventType.reservation))),
        reason: 'the canonical label came from the events feature, not here',
      );
    });

    test('the default rule is the recorder\'s own words: the vocabulary is '
        'not asked', () async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final fake = _Asked();
      final r = await _recording(validationDefaultRule);
      final text = stepText(l10n, r.steps.single, vocabulary: fake);
      expect(text.detail, l10n.taskRecorderTargetDefaultRule);
      expect(fake.asked, isEmpty);
    });

    test('a target the vocabulary does not describe reads as any unnamed '
        'target', () async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final fake = _Asked();
      // `payment` is a registered rule key the fake does not describe.
      final r = await _recording('payment');
      final text = stepText(l10n, r.steps.single, vocabulary: fake);
      expect(fake.asked, [(RecorderActions.saveValidationRule, 'payment')]);
      expect(text.detail, isNotNull);
      expect(text.detail, isNot('FAKE-WORDS-FOR-RESERVATION'));
    });

    test('a validation-rule target with no vocabulary composed is a bug, not '
        'an unknown target', () async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        () => targetLabel(
          l10n,
          'reservation',
          action: RecorderActions.saveValidationRule,
        ),
        throwsStateError,
      );
    });
  });

  group('the app\'s real event adapter gives the canonical label', () {
    for (final language in _languages) {
      test('every validation type in $language', () {
        final l10n = lookupAppLocalizations(Locale(language));
        const adapter = EventTargetVocabulary();
        for (final key in validationRuleKeys) {
          final type = EventType.values.firstWhere((t) => t.dbName == key);
          expect(
            targetLabel(
              l10n,
              key,
              action: RecorderActions.saveValidationRule,
              vocabulary: adapter,
            ),
            eventTypeLabel(l10n, type),
            reason: '$language $key',
          );
        }
      });
    }

    test('the default rule and an unknown future target keep their documented '
        'fallbacks', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      const adapter = EventTargetVocabulary();
      expect(
        targetLabel(
          l10n,
          validationDefaultRule,
          action: RecorderActions.saveValidationRule,
          vocabulary: adapter,
        ),
        l10n.taskRecorderTargetDefaultRule,
      );
      final unknown = targetLabel(
        l10n,
        'a_future_event_type',
        action: RecorderActions.saveValidationRule,
        vocabulary: adapter,
      );
      expect(unknown, isNotEmpty);
      expect(adapter.labelOf(l10n, RecorderActions.saveValidationRule, 'x'), isNull);
      expect(
        adapter.labelOf(l10n, RecorderActions.selectDate, 'reservation'),
        isNull,
        reason: 'only a validation-rule target is this adapter\'s',
      );
    });
  });

  group('the production composition', () {
    testWidgets('a recorded step in the steps widget and the exported '
        'transcript read the canonical event label', (tester) async {
      final r = await _recording('payment');
      final label = eventTypeLabel(
        lookupAppLocalizations(const Locale('en')),
        EventType.payment,
      );
      late WidgetRef captured;
      await pumpApp(
        tester,
        Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return SingleChildScrollView(
                child: RecordingStepsView(
                  recording: r,
                  leftOut: const {},
                  onToggle: (_) {},
                ),
              );
            },
          ),
        ),
        overrides: standardTestOverrides(),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(label), findsWidgets);

      final transcript = recordingTranscript(
        lookupAppLocalizations(const Locale('en')),
        r,
        vocabulary: captured.read(recorderTargetVocabularyProvider),
      );
      expect(transcript, contains(label));
      expect(
        recordingExportBytes(
          lookupAppLocalizations(const Locale('en')),
          r,
          package: true,
          vocabulary: captured.read(recorderTargetVocabularyProvider),
        ),
        isNotNull,
      );
    });

    testWidgets('a scope that composed no vocabulary fails: the step is not '
        'silently read as unknown', (tester) async {
      final r = await _recording('payment');
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: RecordingStepsView(
                  recording: r,
                  leftOut: const {},
                  onToggle: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.takeException().toString(),
        contains('recorderTargetVocabularyProvider is not composed'),
      );
    });
  });
}
