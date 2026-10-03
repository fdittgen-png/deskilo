// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../backend/backend_settings.dart';
import '../../backend/secondary_federation.dart';

/// Demo and tests that never reach a real server: every target is
/// "not available", so nothing ever opens a browser.
class OfflineIdentityConnector implements IdentityConnector {
  const OfflineIdentityConnector();

  @override
  Future<IdentityConnectReadiness> assess(BackendEndpoint target) async =>
      throw const IdentityConnectUnavailable(
        IdentityConnectUnsupported.noSharedIdentity,
      );

  @override
  Future<String> begin(SecondaryConnectIntent intent) async =>
      throw const IdentityConnectUnavailable(
        IdentityConnectUnsupported.noSharedIdentity,
      );

  @override
  Future<void> cancel(String flow) async {}

  @override
  Stream<SecondaryConnectEvent> get events => const Stream.empty();
}
