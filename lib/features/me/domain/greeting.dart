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

/// The first word of [displayName]; null when the account has none.
String? firstNameOf(String? displayName) {
  final words = (displayName ?? '').trim().split(RegExp(r'\s+'));
  return words.first.isEmpty ? null : words.first;
}
