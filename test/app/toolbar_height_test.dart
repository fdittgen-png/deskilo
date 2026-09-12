// SPDX-License-Identifier: 0BSD
//
// The compact toolbar: 48 dp on every AppBar through the theme (the
// Sparkilo shell idiom — its #4082). Material's 56 spent eight dp on
// every screen for nothing; the touch targets are 48 anyway.
import 'package:deskilo/app/theme.dart';
import 'package:deskilo/core/theme/shell_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every theme carries the compact toolbar height', () {
    for (final theme in [
      DeskiloTheme.light(),
      DeskiloTheme.dark(),
      DeskiloTheme.warm(),
    ]) {
      expect(theme.appBarTheme.toolbarHeight, kAppToolbarHeight);
    }
    expect(kAppToolbarHeight, 48, reason: 'an IconButton is 48 dp — the '
        'bar must not go below its own touch targets');
  });

  testWidgets('an AppBar renders 48 dp tall, no override needed',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: DeskiloTheme.light(),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Réserver'),
          actions: [
            IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
          ],
        ),
        body: const SizedBox(),
      ),
    ));
    expect(tester.getSize(find.byType(AppBar)).height, kAppToolbarHeight);
    // The action keeps its full touch target inside the shorter bar.
    expect(tester.getSize(find.byType(IconButton)).height,
        greaterThanOrEqualTo(48));
  });
}
