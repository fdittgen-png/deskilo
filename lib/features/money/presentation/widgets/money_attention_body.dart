// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/app_localizations_en.dart';
import '../../../events/providers/attention_providers.dart';
import '../../../events/providers/notification_filter_providers.dart';

/// Finance counts have an explicit destination across every Money view.
class MoneyAttentionBody extends ConsumerWidget {
  const MoneyAttentionBody({required this.enabled, required this.child, super.key});
  final bool enabled;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final words = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final count = enabled ? ref.watch(workspaceAttentionProvider).money : 0;
    return Column(children: [
      if (enabled) ListTile(key: const ValueKey('money-alerts'),
        leading: count > 0 ? Badge.count(count: count, maxCount: 99,
          child: const Icon(Icons.notifications_outlined)) : const Icon(Icons.notifications_outlined),
        title: Text(words.uxFinanceAlerts), trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          if (!await runGuarded(context, domain: 'events', message: 'finance alerts filter failed',
            errorText: words.uxFinanceAlertsFailed,
            action: () => ref.read(notificationFilterProvider.notifier).showFinance())) { return; }
          if (!context.mounted) return;
          context.go('/events');
        }),
      Expanded(child: child),
    ]);
  }
}
