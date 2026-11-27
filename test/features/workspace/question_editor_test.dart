// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1288 S4 — defining a question without a migration.
//
// The acceptance row this file answers is the first one in the issue:
// *a new field without a migration*. What it protects is that the editor
// refuses what the server refuses BEFORE the round trip, that the key is
// written once and never again, and that the preview is the real widget
// rather than a drawing of it.
import 'package:deskilo/features/workspace/domain/workspace_field.dart';
import 'package:deskilo/features/workspace/presentation/widgets/question_choice_tile.dart';
import 'package:deskilo/features/workspace/presentation/widgets/question_editor_sheet.dart';
import 'package:deskilo/features/workspace/presentation/widgets/workspace_fields_section.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<WorkspaceField>> pumpEditor(
  WidgetTester tester, {
  WorkspaceField? initial,
  String workspaceLocale = 'en',
  Locale? locale,
}) async {
  // The editor is a tall sheet; a short viewport puts Save off-screen
  // and every tap on it misses. The height is the test's, not the
  // product's — 360 dp width is pinned where it matters, in the section
  // the preview renders.
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final saved = <WorkspaceField>[];
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: QuestionEditorSheet(
          initial: initial,
          workspaceName: 'Coworkonti',
          workspaceLocale: workspaceLocale,
          onSave: (field) async => saved.add(field),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return saved;
}

bool saveEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.byKey(QuestionEditorSheet.saveKey))
        .onPressed !=
    null;

void main() {
  testWidgets('a new question cannot be saved until it has a key and a label '
      'in the language the space reads', (tester) async {
    await pumpEditor(tester);
    expect(saveEnabled(tester), isFalse);

    await tester.enterText(
      find.byKey(QuestionEditorSheet.keyFieldKey),
      'committee',
    );
    await tester.pump();
    expect(
      saveEnabled(tester),
      isFalse,
      reason: '0248 refuses a question with no label in the workspace '
          'language; meeting that as an error would be worse than a '
          'disabled button',
    );

    await tester.enterText(
      find.byKey(QuestionEditorSheet.labelKeyFor('en')),
      'Committee role',
    );
    await tester.pump();
    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('the key must be an identifier, because the answers point at it',
      (tester) async {
    await pumpEditor(tester);
    await tester.enterText(
      find.byKey(QuestionEditorSheet.labelKeyFor('en')),
      'Committee role',
    );
    for (final bad in ['Committee', 'a', 'has space', 'accentué']) {
      await tester.enterText(find.byKey(QuestionEditorSheet.keyFieldKey), bad);
      await tester.pump();
      expect(saveEnabled(tester), isFalse, reason: '"$bad" is not a key');
    }
    await tester.enterText(
      find.byKey(QuestionEditorSheet.keyFieldKey),
      'committee_role',
    );
    await tester.pump();
    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('an existing question does not offer its key — a renamed key '
      'is a lost answer', (tester) async {
    await pumpEditor(
      tester,
      initial: const WorkspaceField(
        id: 'f',
        key: 'committee',
        type: WorkspaceFieldType.text,
        labels: {'en': 'Committee role'},
      ),
    );
    expect(find.byKey(QuestionEditorSheet.keyFieldKey), findsNothing);
    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('a choice question needs choices before it can be saved',
      (tester) async {
    final saved = await pumpEditor(tester);
    await tester.enterText(
      find.byKey(QuestionEditorSheet.keyFieldKey),
      'shirt',
    );
    await tester.enterText(
      find.byKey(QuestionEditorSheet.labelKeyFor('en')),
      'Shirt size',
    );
    await tester.tap(find.byKey(QuestionEditorSheet.typeKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('One of a list').last);
    await tester.pumpAndSettle();
    expect(saveEnabled(tester), isFalse);

    await tester.enterText(
      find.byKey(QuestionEditorSheet.choicesKey),
      'Small\nMedium',
    );
    await tester.pump();
    expect(saveEnabled(tester), isTrue);

    await tester.tap(find.byKey(QuestionEditorSheet.saveKey));
    await tester.pumpAndSettle();
    expect(saved.single.options.map((o) => o.key), ['small', 'medium']);
    expect(saved.single.options.first.labels['en'], 'Small');
  });

  testWidgets('the preview is the identity form\'s own widget, so the owner '
      'is looking at the thing rather than a drawing of it', (tester) async {
    await pumpEditor(
      tester,
      initial: const WorkspaceField(
        id: 'f',
        key: 'committee',
        type: WorkspaceFieldType.text,
        labels: {'en': 'Committee role'},
      ),
    );
    expect(find.byType(WorkspaceFieldsSection), findsOneWidget);
    expect(find.textContaining('Coworkonti'), findsOneWidget);
  });

  testWidgets('a question is personal by default: the safe answer is the one '
      'nobody has to think about', (tester) async {
    final saved = await pumpEditor(tester);
    await tester.enterText(
      find.byKey(QuestionEditorSheet.keyFieldKey),
      'emergency',
    );
    await tester.enterText(
      find.byKey(QuestionEditorSheet.labelKeyFor('en')),
      'Emergency contact',
    );
    await tester.pump();
    await tester.tap(find.byKey(QuestionEditorSheet.saveKey));
    await tester.pumpAndSettle();

    expect(saved.single.personalData, isTrue);
    expect(saved.single.visibility, WorkspaceFieldVisibility.self);
    expect(saved.single.contexts, {WorkspaceFieldContext.profile});
  });

  testWidgets('a question asked nowhere cannot be saved', (tester) async {
    await pumpEditor(tester);
    await tester.enterText(
      find.byKey(QuestionEditorSheet.keyFieldKey),
      'committee',
    );
    await tester.enterText(
      find.byKey(QuestionEditorSheet.labelKeyFor('en')),
      'Committee role',
    );
    await tester.pump();
    expect(saveEnabled(tester), isTrue);

    await tester.tap(
      find.byKey(const ValueKey('question-editor-context-profile')),
    );
    await tester.pumpAndSettle();
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets('the space\'s own language is the one that must be filled in, '
      'not English', (tester) async {
    await pumpEditor(tester, workspaceLocale: 'fr');
    await tester.enterText(
      find.byKey(QuestionEditorSheet.keyFieldKey),
      'committee',
    );
    await tester.enterText(
      find.byKey(QuestionEditorSheet.labelKeyFor('en')),
      'Committee role',
    );
    await tester.pump();
    expect(saveEnabled(tester), isFalse);

    await tester.enterText(
      find.byKey(QuestionEditorSheet.labelKeyFor('fr')),
      'Fonction au bureau',
    );
    await tester.pump();
    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('#3487 a German keyboard types the largest number as 0,5',
      (tester) async {
    final saved = await pumpEditor(
      tester,
      locale: const Locale('de'),
      initial: const WorkspaceField(
        id: 'f',
        key: 'share',
        type: WorkspaceFieldType.decimal,
        labels: {'en': 'Share'},
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('question-editor-sheet-editor-max-length')),
      '0,5',
    );
    await tester.pump();
    await tester.tap(find.byKey(QuestionEditorSheet.saveKey));
    await tester.pumpAndSettle();
    expect(saved.single.validation['max'], 0.5);
  });
  group('an edit keeps what it did not touch', () {
    const labels5 = {'en': 'Small', 'fr': 'Petit', 'de': 'Klein', 'es': 'Pequeña', 'it': 'Piccola'};
    const shirt = WorkspaceField(
      id: 'f-shirt',
      key: 'shirt',
      type: WorkspaceFieldType.singleChoice,
      labels: {'en': 'Shirt size', 'fr': 'Taille'},
      helpTexts: {'en': 'For the team shirt.', 'fr': 'Pour le maillot.'},
      groupKey: 'finance',
      sortOrder: 7,
      options: [
        WorkspaceFieldOption(key: 's', labels: labels5, sortOrder: 10),
        WorkspaceFieldOption(key: 'm', labels: {'en': 'Medium', 'fr': 'Moyen'}, sortOrder: 20),
        WorkspaceFieldOption(key: 'xs', labels: {'en': 'Extra small'}, sortOrder: 30, active: false),
      ],
    );

    Future<WorkspaceField> saveAfter(
      WidgetTester tester,
      WorkspaceField initial,
      Future<void> Function() edit,
    ) async {
      final saved = await pumpEditor(tester, initial: initial);
      await edit();
      await tester.pump();
      await tester.ensureVisible(find.byKey(QuestionEditorSheet.saveKey));
      await tester.tap(find.byKey(QuestionEditorSheet.saveKey));
      await tester.pump();
      return saved.single;
    }

    testWidgets('a title-only save keeps the group, the help, the place and every rule', (tester) async {
      const initial = WorkspaceField(
        id: 'f-mail',
        key: 'work_mail',
        type: WorkspaceFieldType.text,
        labels: {'en': 'Work mail', 'fr': 'Courriel'},
        helpTexts: {'en': 'The address of your desk.', 'fr': 'Votre adresse au bureau.'},
        groupKey: 'finance',
        sortOrder: 7,
        validation: {'min_length': 2, 'max_length': 80, 'named': 'email'},
      );
      final saved = await saveAfter(
        tester,
        initial,
        () => tester.enterText(find.byKey(QuestionEditorSheet.labelKeyFor('en')), 'Work e-mail'),
      );
      expect(saved.labels, {'en': 'Work e-mail', 'fr': 'Courriel'});
      expect(saved.id, 'f-mail');
      expect(saved.groupKey, 'finance');
      expect(saved.sortOrder, 7);
      expect(saved.helpTexts, initial.helpTexts);
      expect(saved.validation, initial.validation);
    });

    testWidgets('rules this sheet has no control for survive: the bounds of a date', (tester) async {
      const initial = WorkspaceField(
        id: 'f-since',
        key: 'member_since',
        type: WorkspaceFieldType.date,
        labels: {'en': 'Member since'},
        validation: {'min_date': '2000-01-01', 'max_date': '2030-12-31'},
      );
      final saved = await saveAfter(
        tester,
        initial,
        () => tester.enterText(find.byKey(QuestionEditorSheet.labelKeyFor('en')), 'Joined on'),
      );
      expect(saved.validation, initial.validation);
    });

    testWidgets('emptying the maximum removes that rule and no other', (tester) async {
      const initial = WorkspaceField(
        id: 'f-mail',
        key: 'work_mail',
        type: WorkspaceFieldType.text,
        labels: {'en': 'Work mail'},
        validation: {'min_length': 2, 'max_length': 80, 'named': 'email'},
      );
      final saved = await saveAfter(
        tester,
        initial,
        () => tester.enterText(find.byKey(const ValueKey('question-editor-sheet-editor-max-length')), ''),
      );
      expect(saved.validation, {'min_length': 2, 'named': 'email'});
    });

    testWidgets('a title-only save sends every choice as it was read: key, labels, order, retired', (tester) async {
      final saved = await saveAfter(
        tester,
        shirt,
        () => tester.enterText(find.byKey(QuestionEditorSheet.labelKeyFor('en')), 'T-shirt size'),
      );
      expect(saved.groupKey, 'finance');
      expect(saved.helpTexts, shirt.helpTexts);
      expect(saved.options, hasLength(3));
      for (final (i, read) in shirt.options.indexed) {
        final sent = saved.options[i];
        expect(sent.key, read.key);
        expect(sent.labels, read.labels);
        expect(sent.sortOrder, read.sortOrder);
        expect(sent.active, read.active, reason: 'a retired choice stays retired');
      }
    });

    testWidgets('a choice is reworded in one language: its key and its other labels stay', (tester) async {
      final saved = await saveAfter(tester, shirt, () async {
        await tester.tap(find.byKey(QuestionChoiceTile.keyFor('s')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(QuestionChoiceTile.labelKeyFor('s', 'fr')), 'Petite taille');
      });
      final small = saved.options.first;
      expect(small.key, 's');
      expect(small.labels, {...labels5, 'fr': 'Petite taille'});
      expect(saved.options.map((o) => o.key), ['s', 'm', 'xs']);
    });

    testWidgets('a choice is retired, moved and added explicitly; a new one never takes a key in use', (tester) async {
      final saved = await saveAfter(tester, shirt, () async {
        await tester.tap(find.byKey(QuestionChoiceTile.keyFor('m')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(QuestionChoiceTile.activeKeyFor('m')));
        await tester.pump();
        await tester.tap(find.byKey(QuestionChoiceTile.upKeyFor('m')));
        await tester.pump();
        // "S" would make the key of the choice that exists.
        await tester.enterText(find.byKey(QuestionEditorSheet.choicesKey), 'S\nLarge');
      });
      expect(saved.options.map((o) => o.key), ['m', 's', 'xs', 's_2', 'large']);
      expect(saved.options.map((o) => o.sortOrder), [0, 1, 2, 3, 4]);
      expect(saved.options.first.active, isFalse);
      expect(saved.options[1].labels, labels5, reason: 'the existing choice is not overwritten');
    });
  });
}
