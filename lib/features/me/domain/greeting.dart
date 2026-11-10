// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step A -- the Home greeting: the part of the day on the reader's wall
// clock, and the first name of the account. Pure Dart.

/// Which greeting the hour calls for.
enum GreetingPart { morning, afternoon, evening }

/// Morning before 12:00, afternoon before 18:00, evening after.
GreetingPart greetingPartAt(DateTime wall) => wall.hour < 12
    ? GreetingPart.morning
    : wall.hour < 18
    ? GreetingPart.afternoon
    : GreetingPart.evening;

/// The first name of an account: the one its identity states, else the first
/// word of its display name; null when it has neither.
String? firstNameOf({String? firstName, String? displayName}) {
  final stated = (firstName ?? '').trim();
  if (stated.isNotEmpty) return stated;
  final word = (displayName ?? '').trim().split(RegExp(r'\s+')).first;
  return word.isEmpty ? null : word;
}
