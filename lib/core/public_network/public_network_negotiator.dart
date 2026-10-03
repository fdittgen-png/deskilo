// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1847 B — per-operation negotiation with another installation, before
// any mutation. The client reads the target's descriptor anonymously and
// takes the highest version both sides implement, provided it understands
// every capability and every mandatory term the operation carries. The
// server revalidates the version it is sent (`x-deskilo-operation`), so a
// stale descriptor cannot slip a retired version through. Negotiation
// grants nothing: SQL still decides who may do what.
//
// What this client cannot honour refuses the AFFECTED action with a typed
// [PublicActionRefusal]; every other action keeps working. #1832 owns how
// a refusal is presented and recovered.
import '../trace/trace_logger.dart';
import 'public_network_codec.dart';
import 'public_network_operations.dart';
import 'public_network_spec.dart';

/// Why an action was refused before (or by) the target.
enum PublicRefusalReason {
  /// The descriptor could not be read: offline, timeout, server error.
  unreachable,

  /// The server speaks no protocol version this client speaks.
  protocolUnsupported,

  /// A term marked must-understand is unknown to this client.
  termUnknown,

  /// The server does not offer the operation.
  operationUnavailable,

  /// No version of the operation is common to both sides, or the server
  /// refused the version it was sent.
  versionUnsupported,

  /// The operation requires a capability this client does not understand.
  capabilityUnknown,
}

/// The typed outcome of an action this client may not perform there.
class PublicActionRefusal implements Exception {
  const PublicActionRefusal(
    this.operation,
    this.reason, {
    this.byServer = false,
  });
  final String operation;
  final PublicRefusalReason reason;

  /// True when the target's revalidation refused it, after negotiation
  /// had allowed it (a stale descriptor, a version retired meanwhile).
  final bool byServer;

  @override
  String toString() =>
      'PublicActionRefusal($operation: ${reason.name}${byServer ? ', server' : ''})';
}

/// #1850 seam: the maturity and lifecycle metadata of one operation. No
/// term is defined yet, so this client interprets none and infers no
/// maturity from its absence. #1850's consumer reads [terms] here.
class PublicLifecycleMetadata {
  const PublicLifecycleMetadata(this.terms);
  final Map<String, Object?> terms;
}

/// One operation as a server offers it.
class PublicOperationOffer {
  const PublicOperationOffer({
    required this.id,
    required this.versions,
    this.requires = const [],
    this.unlabelled,
    this.lifecycle,
  });
  final String id;
  final List<int> versions;
  final List<String> requires;
  final int? unlabelled;
  final PublicLifecycleMetadata? lifecycle;
}

/// What a target answered about its public network interface.
sealed class PublicServerProfile {
  const PublicServerProfile();

  /// A server from before negotiation: it has no descriptor and implements
  /// version 1 of every baseline operation.
  const factory PublicServerProfile.baseline() = PublicBaselineServer;
}

class PublicBaselineServer extends PublicServerProfile {
  const PublicBaselineServer();
}

/// A descriptor this client could not accept as a whole.
class PublicUnreadableServer extends PublicServerProfile {
  const PublicUnreadableServer(this.reason);
  final PublicRefusalReason reason;
}

class PublicNegotiatingServer extends PublicServerProfile {
  const PublicNegotiatingServer({
    required this.protocolVersions,
    required this.capabilities,
    required this.offers,
    required this.unreadable,
  });
  final List<int> protocolVersions;
  final List<String> capabilities;
  final Map<String, PublicOperationOffer> offers;

  /// Operations the server lists with a term this client cannot interpret.
  final Set<String> unreadable;
}

/// The version agreed for one operation, and the header that names it.
class PublicNegotiation {
  const PublicNegotiation(this.operation, this.version);
  final PublicOperationSpec operation;
  final int version;
  String get header => operation.operationHeader(version);
}

const _descriptorSchema = 'PublicNetworkDescriptor';
const _operationSchema = 'DescriptorOperation';

/// Reads a descriptor answer. Pure.
PublicServerProfile readPublicDescriptor(Object? raw) {
  final Map<String, Object?> d;
  try {
    d = decodePublicRecord(_descriptorSchema, raw);
  } on PublicContractRefusal catch (r, st) {
    TraceLogger.instance.warn(
      'public_network',
      'descriptor refused: ${r.reason}',
      stackTrace: st,
    );
    return PublicUnreadableServer(
      r.reason == publicUnknownRequiredTerm
          ? PublicRefusalReason.termUnknown
          : PublicRefusalReason.protocolUnsupported,
    );
  }
  final offers = <String, PublicOperationOffer>{};
  final unreadable = <String>{};
  // Each entry is read on its own, so one operation this client cannot
  // interpret leaves the others available.
  for (final entry in (raw! as Map)['operations'] as List) {
    try {
      final o = decodePublicRecord(_operationSchema, entry);
      final lifecycle = o['lifecycle'] as Map<String, Object?>?;
      offers[o['id']! as String] = PublicOperationOffer(
        id: o['id']! as String,
        versions: o['versions']! as List<int>,
        requires: o['requires'] as List<String>? ?? const [],
        unlabelled: o['unlabelled'] as int?,
        lifecycle: lifecycle == null
            ? null
            : PublicLifecycleMetadata(lifecycle),
      );
    } on PublicContractRefusal catch (r, st) {
      TraceLogger.instance.warn(
        'public_network',
        'descriptor operation refused: ${r.reason}',
        stackTrace: st,
      );
      final id = entry is Map ? entry['id'] : null;
      if (id is String) unreadable.add(id);
    }
  }
  return PublicNegotiatingServer(
    protocolVersions: d['protocol_versions']! as List<int>,
    capabilities: d['capabilities'] as List<String>? ?? const [],
    offers: offers,
    unreadable: unreadable,
  );
}

/// The version of [op] to use on [server], or a [PublicActionRefusal].
/// Pure.
PublicNegotiation negotiatePublicOperation(
  PublicServerProfile server,
  PublicOperationSpec op,
) {
  PublicActionRefusal refuse(PublicRefusalReason reason) =>
      PublicActionRefusal(op.id, reason);
  switch (server) {
    case PublicBaselineServer():
      if (!op.baseline || !op.versions.contains(1)) {
        throw refuse(PublicRefusalReason.operationUnavailable);
      }
      return PublicNegotiation(op, 1);
    case PublicUnreadableServer(:final reason):
      throw refuse(reason);
    case PublicNegotiatingServer():
      if (!server.protocolVersions.any(
        publicNetworkProtocolVersions.contains,
      )) {
        throw refuse(PublicRefusalReason.protocolUnsupported);
      }
      if (server.unreadable.contains(op.id)) {
        throw refuse(PublicRefusalReason.termUnknown);
      }
      final offer = server.offers[op.id];
      if (offer == null) throw refuse(PublicRefusalReason.operationUnavailable);
      if (!offer.requires.every(publicNetworkCapabilities.contains)) {
        throw refuse(PublicRefusalReason.capabilityUnknown);
      }
      final common = offer.versions.where(op.versions.contains).toList()
        ..sort();
      if (common.isEmpty) throw refuse(PublicRefusalReason.versionUnsupported);
      return PublicNegotiation(op, common.last);
  }
}

/// The message every revalidating RPC raises for a version it refuses.
const publicNetworkVersionRefusal = 'unsupported public network version';
