// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Waiting for work only real I/O can finish, without guessing how long.
//
// A widget test runs on a fake clock, so font assets, the image codec and
// a PDF build have to finish inside `tester.runAsync`. The suite used to
// give them a fixed 100–300 ms there: a race the slowest CI runner
// eventually loses, and a pause the fastest machine pays for nothing.
// [untilReal] polls the observable result instead (#1334).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Polls [condition] in real time until it holds.
///
/// Call it INSIDE `tester.runAsync`, where time is real. [what] names the
/// work in the failure message when [timeout] passes first — a hang
/// reads as "the e-invoice send did not finish", not as a timeout of the
/// whole test.
Future<void> untilReal(
  FutureOr<bool> Function() condition, {
  required String what,
  Duration timeout = const Duration(seconds: 20),
}) async {
  final watch = Stopwatch()..start();
  while (!await condition()) {
    if (watch.elapsed > timeout) {
      fail('$what did not finish within $timeout of real time');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
