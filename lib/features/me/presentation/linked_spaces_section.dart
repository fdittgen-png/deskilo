// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — my spaces on the other servers this account is linked to, in
// the same list, the server named only as a quiet subtitle.
//
// Reading them uses each server's own linked session. OPENING one still
// means pointing this app at that server: every screen of a space reads
// through the one client the app started with, so the honest path is
// the existing Server switch, prefilled — it says what it will do and
// asks for that server's sign-in. Nothing here pretends otherwise.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/backend/backend_settings.dart';
import '../../../core/backend/backend_uri.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/my_spaces.dart';
import '../providers/me_providers.dart';

class LinkedSpacesSection extends ConsumerWidget {
  const LinkedSpacesSection({super.key});

  Future<void> _open(BuildContext context, LinkedServerSpaces server,
      LinkedSpace space) async {
    final l10n = AppLocalizations.of(context);
    final go = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: AppSpacing.gutterAll,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(space.name, style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n?.meLinkedOpenBody(server.host) ??
                  'This space lives on ${server.host}. The app works with one '
                      'server at a time: opening it switches to that server and '
                      'asks you to sign in there.'),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                key: const ValueKey('linked-space-open'),
                icon: const Icon(Icons.swap_horiz),
                label: Text(l10n?.meLinkedOpen(server.host) ??
                    'Open on ${server.host}'),
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
    if (go != true || !context.mounted) return;
    await context.push(
      '/server',
      extra: BackendDescriptor(BackendEndpoint(server.source, server.key),
          label: server.host),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final servers = ref.watch(linkedServerSpacesProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final server in servers) ...[
          if (server.unavailable)
            InlineBanner(
              key: ValueKey('linked-unavailable-${server.host}'),
              icon: Icons.cloud_off_outlined,
              severity: InlineBannerSeverity.info,
              text: l10n?.meLinkedUnavailable(server.host) ??
                  '${server.host} did not answer: this list may be incomplete.',
              actionLabel: l10n?.commonRetry ?? 'Try again',
              onAction: () => ref.invalidate(linkedServerSpacesProvider),
            ),
          for (final space in server.spaces)
            Card(
              key: ValueKey('linked-space-${server.host}-${space.id}'),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.dns_outlined)),
                title: Text(space.name),
                subtitle: Text(space.standing == MySpaceStanding.pending
                    ? (l10n?.meLinkedPendingOn(server.host) ??
                        'Waiting for approval · ${server.host}')
                    : server.host),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(context, server, space),
              ),
            ),
        ],
      ],
    );
  }
}
