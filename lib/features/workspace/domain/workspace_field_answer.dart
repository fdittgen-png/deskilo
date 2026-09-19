// SPDX-License-Identifier: 0BSD
//
// #1288 S2 — an answer, and whether it will be accepted.
//
// This is the client half of 0248's `field_answer_problem`. The server
// remains the authority and validates again; what this buys is that a
// member is told about a too-long answer while they are typing it rather
// than after a round trip that refuses it.
//
// The two must agree, which is why [FieldProblem] is a VALUE rather than
// a message: the words belong to the ARB, the decision belongs here, and
// `workspace_field_answer_test` pins each decision against the exact
// refusal 0248 raises.
import 'workspace_field.dart';

/// Why an answer is not acceptable. Null is acceptable.
enum FieldProblem {
  /// A required question with nothing in it.
  required,

  /// Shorter than `min_length`, or longer than `max_length`.
  tooShort,
  tooLong,

  /// Outside `min`/`max`, or not whole when the type is integer.
  tooSmall,
  tooLarge,
  notWhole,

  /// Not a number, a date, or one of the choices.
  notANumber,
  notADate,
  notAChoice,

  /// Before `min_date` or after `max_date`.
  tooEarly,
  tooLate,

  /// The `named` validator refused it.
  notAnEmail,
  notAPhone,
  notAUrl,
}

int? _int(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
num? _num(Object? v) => v is num ? v : null;
DateTime? _date(Object? v) =>
    v is String ? DateTime.tryParse(v) : (v is DateTime ? v : null);

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _phone = RegExp(r'^[+0-9][0-9 ()./-]{4,}$');
final _url = RegExp(r'^https?://\S+$');

/// What is wrong with [answer] as an answer to [field], or null.
///
/// [answer] is the shape the wire carries: a `String`, a `num`, a `bool`,
/// a `List<String>` of choice keys, or null for "not answered".
FieldProblem? fieldProblem(WorkspaceField field, Object? answer) {
  final rules = field.validation;

  if (answer == null) return field.required ? FieldProblem.required : null;

  switch (field.type) {
    case WorkspaceFieldType.text:
    case WorkspaceFieldType.longText:
      if (answer is! String) return FieldProblem.required;
      final text = answer.trim();
      if (text.isEmpty) return field.required ? FieldProblem.required : null;
      final min = _int(rules['min_length']);
      if (min != null && text.length < min) return FieldProblem.tooShort;
      final max = _int(rules['max_length']);
      if (max != null && text.length > max) return FieldProblem.tooLong;
      switch (rules['named']) {
        case 'email':
          if (!_email.hasMatch(text)) return FieldProblem.notAnEmail;
        case 'phone':
          if (!_phone.hasMatch(text)) return FieldProblem.notAPhone;
        case 'url':
          if (!_url.hasMatch(text)) return FieldProblem.notAUrl;
      }
      return null;

    case WorkspaceFieldType.integer:
    case WorkspaceFieldType.decimal:
      final value = _num(answer);
      if (value == null) return FieldProblem.notANumber;
      if (field.type == WorkspaceFieldType.integer &&
          value != value.truncate()) {
        return FieldProblem.notWhole;
      }
      final min = _num(rules['min']);
      if (min != null && value < min) return FieldProblem.tooSmall;
      final max = _num(rules['max']);
      if (max != null && value > max) return FieldProblem.tooLarge;
      return null;

    case WorkspaceFieldType.date:
      final value = _date(answer);
      if (value == null) return FieldProblem.notADate;
      final min = _date(rules['min_date']);
      if (min != null && value.isBefore(min)) return FieldProblem.tooEarly;
      final max = _date(rules['max_date']);
      if (max != null && value.isAfter(max)) return FieldProblem.tooLate;
      return null;

    case WorkspaceFieldType.boolean:
      return answer is bool ? null : FieldProblem.required;

    case WorkspaceFieldType.singleChoice:
      if (answer is! String) return FieldProblem.notAChoice;
      final keys = {for (final o in field.liveOptions) o.key};
      return keys.contains(answer) ? null : FieldProblem.notAChoice;

    case WorkspaceFieldType.multiChoice:
      if (answer is! List) return FieldProblem.notAChoice;
      if (answer.isEmpty) {
        return field.required ? FieldProblem.required : null;
      }
      final keys = {for (final o in field.liveOptions) o.key};
      for (final chosen in answer) {
        if (!keys.contains(chosen)) return FieldProblem.notAChoice;
      }
      return null;
  }
}

/// Every problem in [answers], by field key — what a Save must fix before
/// it is worth sending. The server checks the same things, and refuses
/// the whole write rather than half of it.
Map<String, FieldProblem> fieldProblems(
  Iterable<WorkspaceField> fields,
  Map<String, Object?> answers,
) =>
    {
      for (final field in fields)
        field.key: fieldProblem(field, answers[field.key]),
    }.entries.fold<Map<String, FieldProblem>>({}, (out, e) {
      final problem = e.value;
      if (problem != null) out[e.key] = problem;
      return out;
    });
