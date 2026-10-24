// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 L3 -- the directory home from the installation's own declaration,
// read through the personal client (the installation this device booted
// on). It replaces the constant that pinned the directory to the reference
// deployment whatever the installation said.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backend_settings.dart';
import 'context_client_providers.dart';
import 'personal_home.dart';

/// Where the directory source list lives. Fails with
/// [PersonalHomeUnavailable] when the installation's declaration cannot be
/// used; it is never answered by another server instead.
final directoryHomeProvider = FutureProvider<BackendEndpoint>((ref) async {
  final client = ref.watch(personalClientProvider);
  final declaration = await readPersonalHomeDeclaration(client);
  return directoryHomeOf(
    declaration,
    self: BackendEndpoint(
      Uri.parse(client.rest.url).origin,
      client.auth.headers['apikey'] ?? '',
    ),
  );
}, retry: (_, _) => null);
