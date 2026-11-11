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
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/async_read_body.dart';
import '../../auth/providers/auth_providers.dart';
import '../../workspace/domain/workspace.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/public_workspace.dart';

class SpaceOffers extends ConsumerStatefulWidget {
  const SpaceOffers({
    super.key,
    required this.workspace,
    required this.onRequest,
    this.secondary,
  });

  final PublicWorkspace workspace;

  /// The admission request, as the page already made it; true when the
  /// server took it (#3683: then the button gives way to "Request pending").
  final Future<bool> Function() onRequest;

  /// The outlined action beside the one filled action (Message the space).
  final Widget? secondary;

  @override
  ConsumerState<SpaceOffers> createState() => _SpaceOffersState();
}

class _SpaceOffersState extends ConsumerState<SpaceOffers> {
  bool _sending = false;
  bool _pending = false;

  /// One request at a time: a second tap while it runs does nothing.
  Future<void> _request() async {
    if (_sending || _pending) return;
    setState(() => _sending = true);
    var sent = false;
    try {
      sent = await widget.onRequest();
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _pending = sent;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = widget.workspace;
    final l = context.l10n;
    final signedIn = ref.watch(authStateProvider).value != null;
    // A membership can only be recognised on this server: the page's id
    // is that server's own workspace id.
    final here =
        signedIn &&
        workspace.source == ref.watch(connectedInstallationsProvider).origin;
    // #3683 -- a business of mine is recognised only once the list of my
    // businesses was read: while it loads or failed, no request is offered.
    final mine = here
        ? (ref.watch(myWorkspacesProvider).value ?? const <Workspace>[])
              .where((w) => w.id == workspace.id)
              .firstOrNull
        : null;
    final myRead = here ? ref.watch(myWorkspacesProvider) : null;
    final unknown = myRead != null && !myRead.hasValue;
    final email = workspace.text('email').trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          if (mine != null)
            FilledButton.icon(
              key: const ValueKey('portal-enter'),
              icon: const Icon(Icons.login),
              label: Text(l.portalEnterSpace),
              onPressed: () => enterSpace(context, ref, mine),
            )
          else if (unknown && myRead.hasError && !myRead.isLoading)
            ReadFailureBanner(
              error: myRead.error!,
              onRetry: () => ref.invalidate(myWorkspacesProvider),
            )
          else
            FilledButton.icon(
              key: const ValueKey('portal-request-membership'),
              icon: Icon(
                _pending ? Icons.hourglass_top : Icons.person_add_outlined,
              ),
              label: Text(
                _pending ? l.portalRequestPending : l.portalRequestProfile,
              ),
              onPressed: unknown || _sending || _pending ? null : _request,
            ),
          ?widget.secondary,
          if (email.isNotEmpty)
            TextButton.icon(
              key: const ValueKey('portal-copy-email'),
              icon: const Icon(Icons.copy_outlined),
              label: Text(l.portalCopyEmail),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: email));
                if (!context.mounted) return;
                AppSnack.success(context, l.portalEmailCopied);
              },
            ),
        ],
      ),
    );
  }
}
