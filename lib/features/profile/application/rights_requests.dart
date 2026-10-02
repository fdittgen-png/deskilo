// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1915 — filing a rights request and previewing an erasure. The clock,
// the controller and the outcome are the server's; this is the one door
// the screens use.
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/rights_request.dart';
import '../providers/profile_providers.dart';
import '../../../core/trace/trace_logger.dart';

/// A random v4 UUID for one submission: a retry after a lost answer
/// sends the same id and gets the same request back.
String newClientRequestId([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String hex(int from, int to) =>
      [for (final x in b.sublist(from, to)) x.toRadixString(16).padLeft(2, '0')]
          .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

Future<RightsRequest> submitRightsRequest(
  WidgetRef ref, {
  required String workspaceId,
  required String kind,
  required String details,
  required String clientRequestId,
}) async {
  final request = await ref
      .read(profileRepositoryProvider)
      .submitRightsRequest(
        workspaceId: workspaceId,
        kind: kind,
        details: details,
        clientRequestId: clientRequestId,
      );
  ref.invalidate(myRightsRequestsProvider);
  return request;
}

Future<ErasurePreview> previewErasure(WidgetRef ref, String workspaceId) =>
    ref.read(profileRepositoryProvider).previewMyErasure(workspaceId);

/// The preview, or null when the server cannot give one (an older
/// server, a membership already left): erasure then asks as it always did.
Future<ErasurePreview?> previewErasureOrNull(
  WidgetRef ref,
  String workspaceId,
) async {
  try {
    return await previewErasure(ref, workspaceId);
  } catch (e, st) {
    TraceLogger.instance.warn('privacy', 'erasure preview unavailable',
        error: e, stackTrace: st);
    return null;
  }
}
