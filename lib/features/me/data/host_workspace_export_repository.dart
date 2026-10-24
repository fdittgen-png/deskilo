// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C3 — a workspace's own-data export (`export_my_data`) asked on THAT
// workspace's verified host, never on the personal home and never on the
// selected workspace's client. The host is the installation the app is
// signed in to for a workspace of my personal home, else the connected
// installation whose verified identity is the source's; a host that is
// not connected here, or answers as another installation, is refused.
// The workspace's own switch (`memberDataExport`) is read on the same host
// first: a workspace that has the export off offers none.
import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/connected_target.dart';
import '../../../core/backend/connection_outcome.dart';
import '../../../core/backend/context_clients.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../domain/workspace_export.dart';

/// The verified host of [source], through the existing resolver
/// ([resolverFor] the connected origin, null for the signed-in one).
Future<ResolvedWorkspaceHost> resolveWorkspaceExportHost(
  WorkspaceExportSource source, {
  required Future<List<ConnectedInstallation>> Function() connected,
  required WorkspaceHostResolver Function(String? origin) resolverFor,
}) async {
  String? origin;
  if (!source.hostedHere) {
    for (final c in await connected()) {
      if (c.installationId == source.installationId) origin = c.endpoint.url;
    }
    if (origin == null) {
      throw WorkspaceExportRefused(
        WorkspaceExportFailure.hostUnavailable,
        detail: '${source.installationId} is not connected here',
      );
    }
  }
  return resolverFor(origin).resolve(source.workspaceId);
}

/// The refusals `export_my_data` raises on purpose; null for the others.
@visibleForTesting
WorkspaceExportFailure? workspaceExportRefusalOf(PostgrestException e) =>
    switch (e.code) {
      '42501' => WorkspaceExportFailure.forbidden,
      'P0001' when e.message.contains('not a member') =>
        WorkspaceExportFailure.forbidden,
      _ => null,
    };

class HostWorkspaceExportRepository implements WorkspaceExportRepository {
  const HostWorkspaceExportRepository({required this.hostOf});

  /// The verified host of a source, with its own client.
  final Future<ResolvedWorkspaceHost> Function(WorkspaceExportSource source)
  hostOf;

  Future<ResolvedWorkspaceHost> _host(WorkspaceExportSource source) async {
    final ResolvedWorkspaceHost host;
    try {
      host = await hostOf(source);
    } on UnverifiedInstallation catch (e, st) {
      // trace-exempt: rethrown typed; the row says its host is unavailable.
      Error.throwWithStackTrace(
        WorkspaceExportRefused(
          WorkspaceExportFailure.hostUnavailable,
          detail: '$e',
        ),
        st,
      );
    } on ConnectionFailure catch (e, st) {
      // trace-exempt: rethrown typed; the row says its host is unavailable.
      Error.throwWithStackTrace(
        WorkspaceExportRefused(
          WorkspaceExportFailure.hostUnavailable,
          detail: '$e',
        ),
        st,
      );
    }
    if (host.installationId != source.installationId) {
      host.lease?.release();
      throw WorkspaceExportRefused(
        WorkspaceExportFailure.hostUnavailable,
        detail:
            'asked ${source.installationId}, answered ${host.installationId}',
      );
    }
    return host;
  }

  @override
  Future<WorkspaceExport> export(WorkspaceExportSource source) async {
    final host = await _host(source);
    try {
      await _requireSwitchedOn(host.client, source);
      final Object? raw;
      try {
        raw = await host.client.rpc<Object?>(
          'export_my_data',
          params: {'p_workspace_id': source.workspaceId},
        );
      } on PostgrestException catch (e, st) {
        // trace-exempt: rethrown typed; the row says which refusal.
        final failure = workspaceExportRefusalOf(e);
        if (failure == null) rethrow;
        Error.throwWithStackTrace(
          WorkspaceExportRefused(failure, detail: e.message),
          st,
        );
      }
      return WorkspaceExport.decode(source, raw);
    } finally {
      host.lease?.release();
    }
  }

  /// The workspace's own switch, as its row on the host holds it. A row the
  /// person may not read is a workspace they are not in.
  Future<void> _requireSwitchedOn(
    SupabaseClient client,
    WorkspaceExportSource source,
  ) async {
    final row = await client
        .from('workspaces')
        .select('feature_flags, country_code')
        .eq('id', source.workspaceId)
        .maybeSingle();
    if (row == null) {
      throw const WorkspaceExportRefused(
        WorkspaceExportFailure.forbidden,
        detail: 'workspace row not readable',
      );
    }
    final flags = row['feature_flags'];
    final country = row['country_code'];
    final on = effectiveFeatures(
      resolveEnabledFeatures(
        flags is Map ? Map<String, Object?>.from(flags) : const {},
      ),
      country: country is String ? country : null,
    );
    if (!on.contains(WorkspaceFeature.memberDataExport)) {
      throw const WorkspaceExportRefused(WorkspaceExportFailure.disabled);
    }
  }
}
