// SPDX-License-Identifier: 0BSD
//
// #1288 S2b — the workspace's questions inside the identity form.
//
// What this protects is that the section renders each answer type with a
// control a person can actually use, reports the SERVER's verdict rather
// than one of its own, and holds the answers where the host's Save can
// read them. The rule itself is `fieldProblem`, tested separately; here
// the question is whether a member can answer and be told when they have
// not.
import 'package:deskilo/features/profile/presentation/widgets/workspace_fields_section.dart';
import 'package:deskilo/features/workspace/domain/workspace_field.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceField field({
  required String key,
  required WorkspaceFieldType type,
  bool required = false,
  Map<String, Object?> validation = const {},
  List<String> options = const [],
}) =>
    WorkspaceField(
      id: key,
      key: key,
      type: type,
      labels: {'en': key},
      required: required,
      validation: validation,
      options: [
        for (final o in options)
          WorkspaceFieldOption(key: o, labels: {'en': o.toUpperCase()}),
      ],
    );

Future<WorkspaceFieldsController> pump(
  WidgetTester tester,
  List<WorkspaceField> fields, {
  Map<String, Object?> initial = const {},
  bool enabled = true,
}) async {
  final controller = WorkspaceFieldsController(initial: initial);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      // The real strings, not the English fallbacks: the point of the
      // messages is that they come from the ARB.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: WorkspaceFieldsSection(
            fields: fields,
            controller: controller,
            workspaceName: 'Coworkonti',
            enabled: enabled,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets('no questions, no section — a workspace that asks nothing '
      'leaves the identity form exactly as it was', (tester) async {
    await pump(tester, const []);
    expect(find.byKey(WorkspaceFieldsSection.sectionKey), findsNothing);
  });

  testWidgets('the section names the workspace asking', (tester) async {
    await pump(tester, [field(key: 'committee', type: WorkspaceFieldType.text)]);
    expect(find.textContaining('Coworkonti'), findsOneWidget);
  });

  testWidgets('an optional question says so, and a required one does not',
      (tester) async {
    await pump(tester, [
      field(key: 'committee', type: WorkspaceFieldType.text),
      field(key: 'emergency', type: WorkspaceFieldType.text, required: true),
    ]);
    expect(find.text('committee (optional)'), findsOneWidget);
    expect(find.text('emergency'), findsOneWidget);
  });

  testWidgets('typing an answer puts it where the host\'s Save will look',
      (tester) async {
    final controller = await pump(
      tester,
      [field(key: 'committee', type: WorkspaceFieldType.text)],
    );
    await tester.enterText(
      find.byKey(WorkspaceFieldsSection.keyOf('committee')),
      'tresorier',
    );
    await tester.pump();
    expect(controller.answers['committee'], 'tresorier');
  });

  testWidgets('a number is sent as a number, not as the text that was typed',
      (tester) async {
    final controller = await pump(
      tester,
      [field(key: 'seats', type: WorkspaceFieldType.integer)],
    );
    await tester.enterText(
      find.byKey(WorkspaceFieldsSection.keyOf('seats')),
      '4',
    );
    await tester.pump();
    expect(controller.answers['seats'], 4);
  });

  testWidgets('the refusal shown is the one the server would give, and only '
      'after the member has answered', (tester) async {
    final controller = await pump(tester, [
      field(
        key: 'committee',
        type: WorkspaceFieldType.text,
        validation: const {'max_length': 5},
      ),
    ]);

    // Nothing typed: no complaint. Telling somebody their empty form is
    // wrong before they start is noise.
    expect(find.textContaining('At most'), findsNothing);

    await tester.enterText(
      find.byKey(WorkspaceFieldsSection.keyOf('committee')),
      'tresorier',
    );
    await tester.pump();
    expect(find.text('At most 5 characters.'), findsOneWidget);
    expect(controller.isValid([
      field(
        key: 'committee',
        type: WorkspaceFieldType.text,
        validation: const {'max_length': 5},
      ),
    ]), isFalse);
  });

  testWidgets('a yes-or-no question is a switch', (tester) async {
    final controller = await pump(
      tester,
      [field(key: 'consent', type: WorkspaceFieldType.boolean)],
    );
    await tester.tap(find.byKey(WorkspaceFieldsSection.keyOf('consent')));
    await tester.pump();
    expect(controller.answers['consent'], isTrue);
  });

  testWidgets('one choice is a menu, several are chips', (tester) async {
    final controller = await pump(tester, [
      field(
        key: 'size',
        type: WorkspaceFieldType.singleChoice,
        options: const ['s', 'm'],
      ),
      field(
        key: 'days',
        type: WorkspaceFieldType.multiChoice,
        options: const ['mon', 'tue'],
      ),
    ]);

    await tester.tap(find.byKey(WorkspaceFieldsSection.keyOf('size')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('M').last);
    await tester.pumpAndSettle();
    expect(controller.answers['size'], 'm');

    await tester.tap(find.byKey(const ValueKey('workspace-field-days-mon')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('workspace-field-days-tue')));
    await tester.pump();
    expect(controller.answers['days'], ['mon', 'tue']);

    await tester.tap(find.byKey(const ValueKey('workspace-field-days-mon')));
    await tester.pump();
    expect(controller.answers['days'], ['tue']);
  });

  testWidgets('an existing answer is what the form opens on', (tester) async {
    await pump(
      tester,
      [field(key: 'committee', type: WorkspaceFieldType.text)],
      initial: const {'committee': 'secretaire'},
    );
    expect(find.text('secretaire'), findsOneWidget);
  });

  testWidgets('while saving, nothing can be changed', (tester) async {
    final controller = await pump(
      tester,
      [field(key: 'consent', type: WorkspaceFieldType.boolean)],
      enabled: false,
    );
    await tester.tap(
      find.byKey(WorkspaceFieldsSection.keyOf('consent')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(controller.answers['consent'], isNull);
  });

  testWidgets('it fits 360 dp, chips and all', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pump(tester, [
      field(
        key: 'days',
        type: WorkspaceFieldType.multiChoice,
        options: const ['monday', 'tuesday', 'wednesday', 'thursday'],
      ),
    ]);
    expect(tester.takeException(), isNull);
  });
}
