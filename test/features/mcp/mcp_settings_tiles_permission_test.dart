// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1826 — the Settings entry for what a workspace exposes to assistants
// follows the role matrix: whoever holds manageIntegrations sees it (an
// owner always does, an admin once the owner delegates it), nobody else,
// and never with the feature off.
import 'package:deskilo/features/auth/domain/database_capabilities.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/mcp/presentation/widgets/mcp_settings_tiles.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpTiles(
  WidgetTester tester, {
  required Set<WorkspacePermission> permissions,
  Set<WorkspaceFeature> features = const {WorkspaceFeature.mcpAccess},
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myPermissionsProvider.overrideWithValue(permissions),
        enabledFeaturesSyncProvider.overrideWithValue(features),
        myDatabaseCapabilitiesProvider.overrideWith(
          (ref) async => DatabaseCapabilities.unavailable,
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: McpSettingsTiles()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const policyTile = ValueKey('settings-assistant-policy');
  const ownTile = ValueKey('settings-assistants');

  testWidgets('a holder of manageIntegrations sees the exposure entry', (
    tester,
  ) async {
    await pumpTiles(
      tester,
      permissions: {WorkspacePermission.manageIntegrations},
    );
    expect(find.byKey(policyTile), findsOneWidget);
    expect(find.byKey(ownTile), findsOneWidget);
  });

  testWidgets('an admin without the permission sees only their own entry', (
    tester,
  ) async {
    await pumpTiles(
      tester,
      permissions: {
        WorkspacePermission.manageMembers,
        WorkspacePermission.manageReservations,
      },
    );
    expect(find.byKey(policyTile), findsNothing);
    expect(find.byKey(ownTile), findsOneWidget);
  });

  testWidgets('with the feature off neither entry shows', (tester) async {
    await pumpTiles(
      tester,
      permissions: {WorkspacePermission.manageIntegrations},
      features: const {},
    );
    expect(find.byKey(policyTile), findsNothing);
    expect(find.byKey(ownTile), findsNothing);
  });
}
