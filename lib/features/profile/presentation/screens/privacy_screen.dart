// SPDX-License-Identifier: 0BSD
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/help/help_hint.dart';
import '../../../../core/links/link_launcher.dart';
import '../../../../core/share/file_sharer.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../calendar/presentation/widgets/access_sheet.dart';
import '../../../calendar/providers/calendar_providers.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';

/// The policy the store listings, the README and the help all point at.
const kPrivacyPolicyUrl = 'https://fdittgen-png.github.io/deskilo/privacy.html';

/// Settings → Privacy & data (#719): the four GDPR rights a member
/// exercises themselves, on one screen, with the policy beside them.
///
/// WHY A SCREEN AND NOT A PARAGRAPH. A right you have to e-mail someone
/// to exercise is a right on paper. Who can see my data, who did, take
/// it with me, leave and be forgotten — each is a button that does the
/// thing, against a server that enforces the rule the button describes.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final features = ref.watch(enabledFeaturesSyncProvider);
    final exportOn = features.contains(WorkspaceFeature.memberDataExport);
    final isOwner = ref.watch(myMemberProvider).value?.isOwner ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.privacyTitle ?? 'Privacy & data')),
      body: ListView(children: [
        const HelpHint(HelpHintId.privacy),
        Padding(
          padding: AppSpacing.lgAll,
          child: Text(
            l10n?.privacyIntro ??
                'Your data stays in the EU, is never tracked or sold, and is '
                    'readable only by the roles the rules below name. These '
                    'are your rights under the GDPR — each one is a button.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        ListTile(
          key: const ValueKey('privacy-who-can-see'),
          leading: const Icon(Icons.shield_outlined),
          title: Text(l10n?.privacyWhoCanSee ?? 'Who can see my data'),
          subtitle: Text(l10n?.privacyWhoCanSeeHint ??
              'The rule per category, the people it names today, and who '
                  'actually looked.'),
          onTap: () => showAccessSheet(context, ref),
        ),
        if (exportOn)
          ListTile(
            key: const ValueKey('privacy-export'),
            leading: const Icon(Icons.download_outlined),
            title: Text(l10n?.privacyExport ?? 'Export my data'),
            subtitle: Text(l10n?.privacyExportHint ??
                'Everything you are the subject of, as one JSON file (art. 20).'),
            onTap: () => _export(context, ref),
          ),
        if (exportOn)
          ListTile(
            key: const ValueKey('privacy-erase'),
            leading: Icon(Icons.person_remove_outlined,
                color: theme.colorScheme.error),
            title: Text(
              l10n?.privacyErase ?? 'Leave this workspace and erase my data',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: Text(isOwner
                ? (l10n?.privacyEraseOwner ??
                    'An owner hands the workspace over first (Members & plans → Co-ownership).')
                : (l10n?.privacyEraseHint ??
                    'Cancels your bookings, blanks your messages, clears your '
                        'profile. Accounting records stay under the legal '
                        'retention, by id, not by name (art. 17).')),
            enabled: !isOwner,
            onTap: isOwner ? null : () => _erase(context, ref),
          ),
        ListTile(
          key: const ValueKey('privacy-policy'),
          leading: const Icon(Icons.policy_outlined),
          title: Text(l10n?.privacyPolicy ?? 'Privacy policy'),
          subtitle: const Text(kPrivacyPolicyUrl),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => ref.read(linkLauncherProvider)(Uri.parse(kPrivacyPolicyUrl)),
        ),
      ]),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    Map<String, dynamic>? data;
    final ok = await runGuarded(
      context,
      domain: 'privacy',
      message: 'export my data failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        data = await ref.read(calendarRepositoryProvider).exportMyData(workspace.id);
      },
    );
    if (!ok || data == null) return;
    final now = ref.read(clockProvider).now();
    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
    );
    await ref.read(fileSharerProvider)(
      bytes: bytes,
      fileName: 'deskilo-my-data-${now.toIso8601String().substring(0, 10)}.json',
      mimeType: 'application/json',
      text: l10n?.privacyExportShareText ?? 'My DesKilo data export',
    );
  }

  Future<void> _erase(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    // Irreversible — typed confirmation, like the workspace reset.
    final controller = TextEditingController();
    final phrase = l10n?.privacyEraseConfirmPhrase ?? 'ERASE';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n?.privacyErase ?? 'Leave this workspace and erase my data'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l10n?.privacyEraseConfirmHint(phrase) ??
              'This cannot be undone. Type $phrase to confirm.'),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('privacy-erase-phrase'),
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: phrase),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n?.directoryClose ?? 'Close'),
          ),
          FilledButton(
            key: const ValueKey('privacy-erase-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext)
                .pop(controller.text.trim() == phrase),
            child: Text(l10n?.privacyEraseConfirmButton ?? 'Erase'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await runGuarded(
      context,
      domain: 'privacy',
      message: 'erase my membership failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () =>
          ref.read(calendarRepositoryProvider).eraseMyMembership(workspace.id),
    );
    if (!ok || !context.mounted) return;
    AppSnack.success(context, l10n?.privacyErased ?? 'Your data has been erased.');
    await ref.read(authRepositoryProvider).signOut();
    if (context.mounted) context.go('/auth');
  }
}
