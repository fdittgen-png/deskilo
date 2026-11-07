// SPDX-License-Identifier: AGPL-3.0-or-later

/// One thing that stops a filing. The [code] is stable and machine-read; the
/// host words it. No user-facing text lives in this package.
class ValidationIssue {
  const ValidationIssue(this.code, {this.field = ''});

  /// A stable code (`period`, `taxNumber`, `vatNumber`, `uid`, ...).
  final String code;

  /// The input the issue is about, when one is.
  final String field;

  @override
  bool operator ==(Object other) =>
      other is ValidationIssue && other.code == code && other.field == field;

  @override
  int get hashCode => Object.hash(code, field);

  @override
  String toString() => field.isEmpty ? code : '$code($field)';
}

/// The outcome of validating a [FilingContext]: ok, or the issues.
class ValidationResult {
  const ValidationResult.ok() : issues = const [];
  const ValidationResult.refused(this.issues);

  final List<ValidationIssue> issues;

  bool get isOk => issues.isEmpty;

  /// The codes, in order.
  List<String> get codes => [for (final i in issues) i.code];
}
