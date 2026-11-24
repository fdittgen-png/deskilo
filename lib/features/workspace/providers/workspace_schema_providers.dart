// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3729 (K2) — the schema of the installation hosting the CURRENT workspace,
// as the shell and the Features screens read it. WATCHED, never awaited: the
// read has an eight-second limit and must not hold the shell; until it
// answers, or when it cannot, nothing is withheld.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/installation_schema.dart';
import 'workspace_providers.dart';

part 'workspace_schema_providers.g.dart';

/// What the installation hosting the current workspace answered, or null
/// while there is no workspace or nothing answered yet.
@Riverpod(keepAlive: true)
InstallationSchema? currentWorkspaceInstallationSchema(Ref ref) {
  final id = ref.watch(currentWorkspaceProvider).value?.id;
  return id == null ? null : ref.watch(workspaceSchemaProvider(id)).value;
}

/// The number a feature's `since` is compared with: null when it is not
/// established.
@Riverpod(keepAlive: true)
int? currentWorkspaceSchema(Ref ref) =>
    ref.watch(currentWorkspaceInstallationSchemaProvider)?.featureSchema;
