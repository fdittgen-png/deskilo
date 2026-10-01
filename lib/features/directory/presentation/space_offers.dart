// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — a published space page says plainly what I can do there.
//
// A member enters; anyone else may request a membership through the
// existing admission path (0303); when the space published an e-mail,
// it can be copied. Contacting the hosts in the app is its own action
// (#1824), and visitor access is out of scope.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/space_entry.dart';
import '../../../core/backend/connected_installation_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_providers.dart';
import '../../workspace/domain/workspace.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/public_workspace.dart';

class SpaceOffers extends ConsumerWidget {
  const SpaceOffers({
    super.key,
    required this.workspace,
    required this.onRequest,
  });

  final PublicWorkspace workspace;

  /// The admission request, as the page already made it.
  final Future<void> Function() onRequest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final signedIn = ref.watch(authStateProvider).value != null;
    // A membership can only be recognised on this server: the page's id
    // is that server's own workspace id.
    final here = signedIn &&
        workspace.source == ref.watch(connectedInstallationsProvider).origin;
    final mine = here
        ? (ref.watch(myWorkspacesProvider).value ?? const <Workspace>[])
            .where((w) => w.id == workspace.id)
            .firstOrNull
        : null;
    final email = workspace.text('email').trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          if (mine != null)
            FilledButton.icon(
              key: const ValueKey('portal-enter'),
              icon: const Icon(Icons.login),
              label: Text(l?.portalEnterSpace ?? 'Enter'),
              onPressed: () => enterSpace(context, ref, mine),
            )
          else
            FilledButton.icon(
              key: const ValueKey('portal-request-membership'),
              icon: const Icon(Icons.person_add_outlined),
              label: Text(
                l?.portalRequestProfile ?? 'Request a workspace profile',
              ),
              onPressed: onRequest,
            ),
          if (email.isNotEmpty)
            OutlinedButton.icon(
              key: const ValueKey('portal-copy-email'),
              icon: const Icon(Icons.copy_outlined),
              label: Text(l?.portalCopyEmail ?? 'Copy the e-mail'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: email));
                if (!context.mounted) return;
                AppSnack.success(context, l?.portalEmailCopied ?? 'E-mail copied');
              },
            ),
        ],
      ),
    );
  }
}
