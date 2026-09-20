// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1288 S2 — the client's validator agrees with 0248's.
//
// `field_answer_problem` in the database is the authority; this is the
// same rule set in Dart, so a member is told about a too-long answer
// while they are typing rather than after a round trip. Two
// implementations of one rule drift unless somebody writes down what
// each case is, so each test below names the refusal 0248 raises for it.
import 'package:deskilo/features/workspace/domain/workspace_field.dart';
import 'package:deskilo/features/workspace/domain/workspace_field_answer.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceField field({
  required WorkspaceFieldType type,
  bool required = false,
  Map<String, Object?> validation = const {},
  List<String> options = const [],
}) =>
    WorkspaceField(
      id: 'f',
      key: 'k',
      type: type,
      labels: const {'en': 'Question'},
      required: required,
      validation: validation,
      options: [
        for (final o in options)
          WorkspaceFieldOption(key: o, labels: {'en': o}),
      ],
    );

void main() {
  group('an unanswered question', () {
    test('is fine when it is optional, and a refusal when it is not', () {
      expect(fieldProblem(field(type: WorkspaceFieldType.text), null), isNull);
      expect(
        fieldProblem(field(type: WorkspaceFieldType.text, required: true), null),
        FieldProblem.required,
        // 0248: 'this question must be answered'.
      );
    });

    test('a blank string is not an answer to a required question', () {
      expect(
        fieldProblem(
          field(type: WorkspaceFieldType.text, required: true),
          '   ',
        ),
        FieldProblem.required,
      );
    });
  });

  group('text', () {
    test('length bounds, counted after trimming as the server counts', () {
      final f = field(
        type: WorkspaceFieldType.text,
        validation: const {'min_length': 3, 'max_length': 5},
      );
      expect(fieldProblem(f, 'ab'), FieldProblem.tooShort);
      expect(fieldProblem(f, '  abc  '), isNull);
      expect(fieldProblem(f, 'abcdef'), FieldProblem.tooLong);
    });

    test('the three named validators, and nothing else', () {
      final email =
          field(type: WorkspaceFieldType.text, validation: const {'named': 'email'});
      expect(fieldProblem(email, 'ada@example.test'), isNull);
      expect(fieldProblem(email, 'ada@example'), FieldProblem.notAnEmail);

      final phone =
          field(type: WorkspaceFieldType.text, validation: const {'named': 'phone'});
      expect(fieldProblem(phone, '+33 1 23 45 67'), isNull);
      expect(fieldProblem(phone, 'ring me'), FieldProblem.notAPhone);

      final url =
          field(type: WorkspaceFieldType.text, validation: const {'named': 'url'});
      expect(fieldProblem(url, 'https://deskilo.test/x'), isNull);
      expect(fieldProblem(url, 'deskilo.test'), FieldProblem.notAUrl);
    });

    test('an optional field with a validator accepts being left empty — '
        'the rule describes an answer, not the absence of one', () {
      final email =
          field(type: WorkspaceFieldType.text, validation: const {'named': 'email'});
      expect(fieldProblem(email, ''), isNull);
    });
  });

  group('numbers', () {
    test('an integer question refuses a fraction', () {
      expect(
        fieldProblem(field(type: WorkspaceFieldType.integer), 1.5),
        FieldProblem.notWhole,
      );
      expect(fieldProblem(field(type: WorkspaceFieldType.integer), 2), isNull);
      expect(
        fieldProblem(field(type: WorkspaceFieldType.decimal), 1.5),
        isNull,
      );
    });

    test('range bounds', () {
      final f = field(
        type: WorkspaceFieldType.integer,
        validation: const {'min': 1, 'max': 10},
      );
      expect(fieldProblem(f, 0), FieldProblem.tooSmall);
      expect(fieldProblem(f, 10), isNull);
      expect(fieldProblem(f, 11), FieldProblem.tooLarge);
    });

    test('text where a number belongs is refused, not coerced', () {
      expect(
        fieldProblem(field(type: WorkspaceFieldType.integer), '3'),
        FieldProblem.notANumber,
      );
    });
  });

  group('dates and choices', () {
    test('a date outside its bounds', () {
      final f = field(
        type: WorkspaceFieldType.date,
        validation: const {'min_date': '2026-01-01', 'max_date': '2026-12-31'},
      );
      expect(fieldProblem(f, '2025-12-31'), FieldProblem.tooEarly);
      expect(fieldProblem(f, '2026-06-01'), isNull);
      expect(fieldProblem(f, '2027-01-01'), FieldProblem.tooLate);
      expect(fieldProblem(f, 'someday'), FieldProblem.notADate);
    });

    test('a choice must be one of the LIVE options', () {
      final f = field(
        type: WorkspaceFieldType.singleChoice,
        options: const ['s', 'm'],
      );
      expect(fieldProblem(f, 's'), isNull);
      expect(fieldProblem(f, 'xl'), FieldProblem.notAChoice);
    });

    test('a deactivated choice is no longer offerable, which is what '
        'deactivation means', () {
      const f = WorkspaceField(
        id: 'f',
        key: 'k',
        type: WorkspaceFieldType.singleChoice,
        labels: {'en': 'Size'},
        options: [
          WorkspaceFieldOption(key: 's', labels: {'en': 'S'}),
          WorkspaceFieldOption(key: 'm', labels: {'en': 'M'}, active: false),
        ],
      );
      expect(fieldProblem(f, 's'), isNull);
      expect(fieldProblem(f, 'm'), FieldProblem.notAChoice);
    });

    test('several choices, and an empty list where one was required', () {
      final f = field(
        type: WorkspaceFieldType.multiChoice,
        required: true,
        options: const ['s', 'm'],
      );
      expect(fieldProblem(f, ['s', 'm']), isNull);
      expect(fieldProblem(f, ['s', 'xl']), FieldProblem.notAChoice);
      expect(fieldProblem(f, <String>[]), FieldProblem.required);
    });
  });

  test('a form reports every problem at once, because the server refuses '
      'the whole write rather than half of it', () {
    final fields = [
      field(type: WorkspaceFieldType.text, required: true),
      const WorkspaceField(
        id: 'g',
        key: 'age',
        type: WorkspaceFieldType.integer,
        labels: {'en': 'Age'},
        validation: {'min': 18},
      ),
    ];
    expect(
      fieldProblems(fields, const {'age': 12}),
      {'k': FieldProblem.required, 'age': FieldProblem.tooSmall},
    );
    expect(fieldProblems(fields, const {'k': 'x', 'age': 20}), isEmpty);
  });

  test('a context asks its own questions, in group then order then key', () {
    final fields = [
      const WorkspaceField(
        id: '1',
        key: 'zeta',
        type: WorkspaceFieldType.text,
        labels: {'en': 'Z'},
        groupKey: 'a',
        sortOrder: 2,
      ),
      const WorkspaceField(
        id: '2',
        key: 'alpha',
        type: WorkspaceFieldType.text,
        labels: {'en': 'A'},
        groupKey: 'a',
        sortOrder: 1,
      ),
      const WorkspaceField(
        id: '3',
        key: 'elsewhere',
        type: WorkspaceFieldType.text,
        labels: {'en': 'E'},
        contexts: {WorkspaceFieldContext.joinRequest},
      ),
      const WorkspaceField(
        id: '4',
        key: 'retired',
        type: WorkspaceFieldType.text,
        labels: {'en': 'R'},
        active: false,
      ),
    ];
    expect(
      fieldsForContext(fields, WorkspaceFieldContext.profile)
          .map((f) => f.key),
      ['alpha', 'zeta'],
    );
  });

  test('a label falls back to the workspace language, then to the key — '
      'ugly on screen and therefore visible', () {
    const f = WorkspaceField(
      id: 'f',
      key: 'committee',
      type: WorkspaceFieldType.text,
      labels: {'en': 'Committee role'},
    );
    expect(f.labelIn('fr'), 'Committee role');
    expect(f.labelIn('fr', fallbackLocale: 'de'), 'committee');
  });
}
