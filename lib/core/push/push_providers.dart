// SPDX-License-Identifier: MIT
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/workspace/providers/workspace_providers.dart';
import '../../l10n/app_localizations.dart';
import '../notifications/notification_providers.dart';
import 'push_connector.dart';
import 'push_endpoint_repository.dart';
import 'push_service.dart';

part 'push_providers.g.dart';

@Riverpod(keepAlive: true)
PushConnector pushConnector(Ref ref) => UnifiedPushConnector();

@Riverpod(keepAlive: true)
PushEndpointRepository pushEndpointRepository(Ref ref) =>
    SupabasePushEndpointRepository(Supabase.instance.client);

/// Starts the UnifiedPush pipeline once per app run (#72). Watched from
/// the shell; a missing distributor or platform just means local-only.
@Riverpod(keepAlive: true)
Future<void> pushBootstrap(Ref ref) async {
  AppLocalizations? l10n;
  try {
    l10n = lookupAppLocalizations(PlatformDispatcher.instance.locale);
  } catch (e, st) {
    debugPrint('push l10n lookup failed, using fallback: $e\n$st');
  }
  final service = PushService(
    connector: ref.watch(pushConnectorProvider),
    repository: ref.watch(pushEndpointRepositoryProvider),
    notifications: ref.watch(notificationServiceProvider),
    myMemberIds: () async {
      final memberships = await ref.read(myMembershipsProvider.future);
      return [for (final m in memberships) m.id];
    },
    pendingTitle: l10n?.pushPendingTitle ?? 'DesKilo',
    pendingBody:
        l10n?.pushPendingBody ?? 'Someone needs your confirmation.',
  );
  await service.start();
}
