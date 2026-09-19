// SPDX-License-Identifier: 0BSD
//
// #1288 S4 — defining a question without a migration.
//
// The acceptance row this file answers is the first one in the issue:
// *a new field without a migration*. What it protects is that the editor
// refuses what the server refuses BEFORE the round trip, that the key is
// written once and never again, and that the preview is the real widget
// rather than a drawing of it.
import 'package:deskilo/features/workspace/presentation/widgets/workspace_fields_section.dart';
import 'package:deskilo/features/workspace/domain/workspace_field.dart';
import 'package:deskilo/features/workspace/presentation/widgets/question_editor_sheet.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<WorkspaceField>> pumpEditor(
  WidgetTester tester, {
  WorkspaceField? initial,
  String workspaceLocale = 'en',
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
}
