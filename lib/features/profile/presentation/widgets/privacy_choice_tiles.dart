// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1914 — two privacy choices on the Privacy & data screen: this
// space's own notice (read it, acknowledge it — an acknowledgment, not
// consent) and optional push delivery on this device.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/push/push_opt_out.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../application/privacy_choices.dart';
import '../../domain/privacy_notice.dart';
import '../../providers/profile_providers.dart';
import 'privacy_notice_view.dart';

/// The current space's notice, when it publishes one.
class SpaceNoticeTile extends ConsumerWidget {
  const SpaceNoticeTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notices = ref.watch(privacyNoticesProvider).value;
    final workspaceId = notices?.workspaceId;
    final notice = notices?.workspace;
    if (notice == null || workspaceId == null) return const SizedBox.shrink();
    final acknowledged = notices!.acknowledgedWorkspace(workspaceId);
    return ListTile(
      key: const ValueKey('privacy-space-notice'),
      leading: const Icon(Icons.article_outlined),
      title: Text(l10n.privacySpaceNotice),
      subtitle: Text(
        acknowledged
            ? (l10n.privacySpaceNoticeRead)
            : (l10n.privacySpaceNoticeUnread),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _show(context, ref, workspaceId, notice, acknowledged),
    );
  }

  Future<void> _show(
    BuildContext context,
    WidgetRef ref,
    String workspaceId,
    PrivacyNotice notice,
    bool acknowledged,
  ) async {
    final l10n = context.l10n;
    final acknowledge = await showAppSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.lgAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.privacySpaceNotice,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              PrivacyNoticeView(notice: notice),
              const SizedBox(height: AppSpacing.md),
              if (!acknowledged)
                FilledButton(
                  key: const ValueKey('privacy-space-notice-acknowledge'),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    l10n.privacySpaceNoticeAcknowledge,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (acknowledge != true || !context.mounted) return;
    if (!await runGuarded(
      context,
      domain: 'privacy',
      message: 'space notice acknowledgment failed',
      errorText:
          l10n.privacySpaceNoticeFailed,
      action: () => acknowledgeSpaceNotice(ref, workspaceId, notice.version),
    )) {
      return;
    }
    if (!context.mounted) return;
    AppSnack.success(
      context,
      l10n.privacySpaceNoticeRead,
    );
  }
}

/// Optional push delivery on this device.
class PushOptOutTile extends ConsumerWidget {
  const PushOptOutTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final optedOut = ref.watch(pushOptedOutProvider).value ?? false;
    return SwitchListTile(
      key: const ValueKey('privacy-push-on-device'),
      secondary: const Icon(Icons.notifications_outlined),
      title: Text(
        l10n.privacyPushOnDevice,
      ),
      subtitle: Text(
        l10n.privacyPushOnDeviceHint,
      ),
      value: !optedOut,
      onChanged: (on) async {
        await runGuarded(
          context,
          domain: 'privacy',
          message: 'push opt-out failed',
          errorText:
              l10n.privacyPushOnDeviceFailed,
          action: () => setPushOnThisDevice(ref, on: on),
        );
      },
    );
  }
}
