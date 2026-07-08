// SPDX-License-Identifier: MIT
//
// Cold-boot smoke test on a real device/emulator (#86/#87): runs the REAL
// main() — Supabase init, timezone data, notification plugin — and asserts
// the first screen renders. This is the layer plain widget tests cannot
// reach (platform channels), where the release-only launch crash lived.
import 'package:deskilo/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cold boot reaches the first frame and the auth screen',
      (tester) async {
    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // Fresh install has no session → the auth screen must be visible.
    expect(find.text('Sign in'), findsWidgets);
  });
}
