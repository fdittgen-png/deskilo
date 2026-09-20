// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1532 — a question and its choices are saved together, or not at all.
//
// The questions screen used to call `set_workspace_field` and then
// `set_workspace_field_options`: two server writes behind one button.
// When the second was refused — a malformed choice key, or the removal
// of a choice somebody had already made — the first had already landed,
// and the owner read *"The question was not saved."*
//
// It had been. It was live for members, and it was a choice question
// with no choices: a state the editor cannot show and cannot reach on
// purpose. The message was not merely unhelpful, it was false, which is
// worse — an owner who believes it re-types the question and gets a
// second one, or walks away from a broken form thinking nothing changed.
//
// 0252 makes it one transaction. These tests state the invariant on the
// fake, which mirrors 0248's refusals for exactly this reason: a fake
// that let the definition survive would let the screen ship a Save the
// server rejects with every test green.
import 'package:deskilo/core/demo/data/workspace_fields_repository.dart';
import 'package:deskilo/features/workspace/domain/workspace_field.dart';
import 'package:flutter_test/flutter_test.dart';

const _ws = 'ws-1';

WorkspaceField _choice({
  String key = 'diet',
  List<WorkspaceFieldOption> options = const [],
}) =>
    WorkspaceField(
      id: '',
      key: key,
      type: WorkspaceFieldType.singleChoice,
      labels: const {'en': 'Diet'},
      options: options,
    );

WorkspaceFieldOption _option(String key) =>
    WorkspaceFieldOption(key: key, labels: {'en': key});

void main() {
  test('a question and its choices arrive together', () async {
    final repo = FakeWorkspaceFields();

    final id = await repo.saveField(
      _ws,
      _choice(),
      options: [_option('vegan'), _option('other')],
    );

    expect(repo.fields.single.key, 'diet');
    expect(
      repo.fields.single.options.map((o) => o.key),
      ['vegan', 'other'],
      reason: 'one call writes both, so a choice question is never live '
          'without the choices it asks about',
    );
    expect(id, isNotEmpty);
  });

  test('a NEW question refused on its choices does not exist afterwards',
      () async {
    final repo = FakeWorkspaceFields();

    await expectLater(
      // A malformed choice key. 0248 refuses it — after the definition
      // has already been written, when the two are separate calls.
      repo.saveField(_ws, _choice(key: 'shirt'),
          options: [_option('NOT A KEY')]),
      throwsA(isA<StateError>()),
    );

    expect(repo.fields, isEmpty,
        reason: 'this is the state the bug produced: a live choice '
            'question with no choices, under a message telling the owner '
            'it had not been saved. Nothing may survive the refusal');
  });

  test('an edit refused on its choices does not half-apply the edit',
      () async {
    final repo = FakeWorkspaceFields();
    await repo.saveField(_ws, _choice(),
        options: [_option('vegan'), _option('other')]);
    repo.answers['m-1'] = {'diet': 'vegan'};

    await expectLater(
      repo.saveField(
        _ws,
        const WorkspaceField(
          id: '',
          key: 'diet',
          type: WorkspaceFieldType.singleChoice,
          // The owner also renamed the question in the same Save.
          labels: {'en': 'Dietary requirements'},
        ),
        options: [_option('other')],
      ),
      throwsA(isA<StateError>()),
    );

    expect(repo.fields.single.labels['en'], 'Diet',
        reason: 'the rename rode on the same Save as the refused choice, '
            'so it goes back too — a partial save is the thing this '
            'transaction exists to prevent');
  });

  test('a question without choices saves with no options at all', () async {
    final repo = FakeWorkspaceFields();

    await repo.saveField(
      _ws,
      const WorkspaceField(
        id: '',
        key: 'committee',
        type: WorkspaceFieldType.text,
        labels: {'en': 'Committee'},
      ),
      // null, not []: an empty list asks for every existing choice to be
      // removed, which the server refuses once one has been made.
      options: null,
    );

    expect(repo.fields.single.key, 'committee');
    expect(repo.fields.single.options, isEmpty);
  });
}
