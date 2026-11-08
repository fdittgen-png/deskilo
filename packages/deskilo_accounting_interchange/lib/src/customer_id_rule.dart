// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3376 -- what a customer id may look like in an accounting target. It lived
// with the target registry (application); the Sage 50 writer needs the rule.

/// What a customer id may look like in the target; null fields are free.
class CustomerIdRule {
  const CustomerIdRule({this.maxLength, this.charset});

  final int? maxLength;

  /// A regular expression every id must match in full.
  final String? charset;

  /// [number] as the target's id: in capitals without separators, when the
  /// rule admits it; null otherwise (empty, too long, another charset).
  String? admit(String number) {
    final code = number.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    if (code.isEmpty) return null;
    if (maxLength case final max? when code.length > max) return null;
    if (charset case final c? when !RegExp('^(?:$c)\$').hasMatch(code)) {
      return null;
    }
    return code;
  }
}
