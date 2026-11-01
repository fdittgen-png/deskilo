// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3061 — a read whose answers the test decides, one at a time, and which
// counts how often it was asked: the proof that Retry repeats the SAME query
// (one more call, not zero, not two) and that a refresh reads once.
import 'dart:async';

import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';


class ReadProbe<T> {
  int calls = 0;
  final List<Completer<T>> _open = [];

  /// The read itself: waits until the test answers or fails it.
  Future<T> call() {
    calls++;
    final answer = Completer<T>();
    _open.add(answer);
    return answer.future;
  }

  void answer(T value) => _open.removeAt(0).complete(value);

  void fail(Object error) => _open.removeAt(0).completeError(error);
}

/// Pumps [home] with failed providers NOT retried by the container (the
/// failure is the state under test), the localisation delegates and a fixed
/// view size restored at teardown. Does not settle.
Future<void> pumpStateScreen(
  WidgetTester tester,
  Widget home, {
  required List<Override> overrides,
  Size size = const Size(800, 1400),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
}
