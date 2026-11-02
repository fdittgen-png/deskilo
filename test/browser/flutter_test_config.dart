// SPDX-License-Identifier: AGPL-3.0-or-later
// Browser-only tests cannot use the root test config's dart:io asset loader.
import 'dart:async';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await testMain();
}
