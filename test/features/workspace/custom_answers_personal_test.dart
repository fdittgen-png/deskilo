// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1912 — an answer stored against a member is personal data whatever the
// question's switch says, and the screens say so.
//
// The owner's "personal data" switch used to decide whether an answer was
// exported and erased. Since 0323 it decides neither: every answer is
// erased with the membership unless a documented retention hold keeps it.
// The editor therefore must not let the owner believe that switching it
// off keeps an answer, and the member answering must be told what happens
// to what they type — in every maintained language, at large text sizes.
import 'package:deskilo/features/workspace/domain/workspace_field.dart';
import 'package:deskilo/features/workspace/presentation/widgets/question_editor_sheet.dart';
import 'package:deskilo/features/workspace/presentation/widgets/workspace_fields_section.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _shirt = WorkspaceField(
  id: 'f1',
  key: 'shirt',
  type: WorkspaceFieldType.text,
  labels: {'en': 'Shirt size'},
  personalData: false,
);

Future<List<WorkspaceField>> _pumpEditor(WidgetTester tester) async {
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
          workspaceName: 'Coworkonti',
          workspaceLocale: 'en',
          onSave: (field) async => saved.add(field),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return saved;
}

Future<void> _pumpSection(
  WidgetTester tester, {
  required Locale locale,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: WorkspaceFieldsSection(
            fields: const [_shirt],
            controller: WorkspaceFieldsController(),
            workspaceName: 'Coworkonti',
            locale: locale.languageCode,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('switching "personal data" off warns that the answer is still '
      'exported and erased, and switching it back removes the warning', (
    tester,
  ) async {
    final saved = await _pumpEditor(tester);
    expect(find.byKey(QuestionEditorSheet.notPersonalWarningKey), findsNothing);
    expect(
      find.textContaining('personal data: carried in their data export'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(QuestionEditorSheet.personalSwitchKey));
    await tester.pumpAndSettle();
    final warning = find.byKey(QuestionEditorSheet.notPersonalWarningKey);
    expect(warning, findsOneWidget);
    expect(
      tester.widget<Text>(warning).data,
      contains(
        'exported and erased with the membership whatever this switch '
        'says',
      ),
    );

    // The switch is still stored as the owner set it — templates carry it
    // — but it is no longer what decides erasure.
    await tester.enterText(
      find.byKey(QuestionEditorSheet.keyFieldKey),
      'shirt',
    );
    await tester.enterText(
      find.byKey(QuestionEditorSheet.labelKeyFor('en')),
      'Shirt size',
    );
    await tester.pump();
    await tester.tap(find.byKey(QuestionEditorSheet.saveKey));
    await tester.pumpAndSettle();
    expect(saved.single.personalData, isFalse);

    await tester.tap(find.byKey(QuestionEditorSheet.personalSwitchKey));
    await tester.pumpAndSettle();
    expect(find.byKey(QuestionEditorSheet.notPersonalWarningKey), findsNothing);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('the member answering a "not personal" question is told it is '
        'personal data (${locale.languageCode})', (tester) async {
      await _pumpSection(tester, locale: locale);
      final l10n = lookupAppLocalizations(locale);
      final note = find.byKey(WorkspaceFieldsSection.personalNoteKey);
      expect(note, findsOneWidget);
      expect(tester.widget<Text>(note).data, l10n.workspaceFieldsPersonalNote);
      expect(l10n.workspaceFieldsPersonalNote, isNot(isEmpty));
      expect(l10n.questionEditorNotPersonalWarning, isNot(isEmpty));
    });
  }

  testWidgets('the note survives large text and is read out by semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpSection(tester, locale: const Locale('de'), textScale: 2);
    expect(tester.takeException(), isNull);
    final l10n = lookupAppLocalizations(const Locale('de'));
    expect(
      find.bySemanticsLabel(l10n.workspaceFieldsPersonalNote),
      findsOneWidget,
    );
    handle.dispose();
  });
}
