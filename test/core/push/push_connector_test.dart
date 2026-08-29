// SPDX-License-Identifier: 0BSD
//
// The push transport this build ships (#716) answers "unavailable" under
// flutter_test in BOTH flavours: the store package because the committed
// firebase_options stub keeps Firebase OFF (#428), the F-Droid package
// because it carries no transport at all. Either way the app stays
// local-only and Settings says why — and nothing here touches a
// platform channel.
import 'package:deskilo_push/deskilo_push.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('this build\'s transport reports unavailable under flutter_test',
      () async {
    final connector = createPushConnector(onWarn: (_, _, _) {});
    expect(
      await connector.initialize(
          onNewEndpoint: (_) {}, onUnregistered: () {}, onMessage: (_) {}),
      isFalse,
    );
  });
}
