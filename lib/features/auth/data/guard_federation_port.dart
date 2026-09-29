// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/backend/auth_callback_guard.dart';
import '../../../core/backend/federation_authority.dart';
import '../../../core/backend/native_federation_flow.dart';
import '../domain/federation_port.dart';

/// [FederationPort] over the running installation's [AuthCallbackGuard]
/// and a fresh [NativeFederationFlow] per step.
class GuardFederationPort implements FederationPort {
  GuardFederationPort(
    this.guard, {
    required this.authority,
    required this.flow,
  });

  final AuthCallbackGuard guard;
  final Future<FederationAuthority?> Function() authority;
  final NativeFederationFlow Function() flow;

  @override
  Future<FederationDestination?> destination() async {
    final current = await authority();
    if (current == null) return null;
    return (
      server: guard.origin.host,
      authority: Uri.parse(current.issuer).host,
    );
  }

  @override
  Future<String> begin({required bool link}) async {
    final FederationAuthority? current;
    try {
      current = await authority();
    } catch (error, stack) {
      // trace-exempt: the discovery answer is not shown; its absence is.
      Error.throwWithStackTrace(
        const FederationStartFailure(FederationFailure.network),
        stack,
      );
    }
    if (current == null) {
      throw const FederationStartFailure(FederationFailure.providerMissing);
    }
    return flow().begin(current, link: link);
  }

  @override
  Stream<FederationEvent> get events => guard.events.stream;

  @override
  FederationEvent? get lastEvent => guard.lastEvent;

  @override
  ({String flow, bool link})? get pending {
    final current = guard.flow;
    final purpose = guard.purpose;
    if (current == null ||
        purpose == null ||
        !purpose.startsWith('federation') ||
        !guard.awaiting(current)) {
      return null;
    }
    return (flow: current, link: purpose == 'federation-link');
  }

  @override
  bool awaiting(String pendingFlow) => guard.awaiting(pendingFlow);

  @override
  bool completing(String pendingFlow) =>
      guard.flow == pendingFlow && guard.consumed;

  @override
  Future<void> cancel(String pendingFlow) async {
    // A claimed return is already being exchanged; its own completion
    // scrubs it. Only an unclaimed flow is abandoned here.
    await flow().cancel(pendingFlow);
  }
}
