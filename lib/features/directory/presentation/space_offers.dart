// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — a published space page says plainly what I can do there.
//
// A member enters; anyone else may request a membership through the
// existing admission path (0303). Contacting the hosts in the app is its
// own action (#1824), and visitor access is out of scope.
//
// #3554 — never more than two buttons, exactly one filled, in the same
// order on every screen. Which is filled follows what the business
// published, not its kind: one that takes inquiries and publishes services
// is reached by the inquiry first; one that takes none offers no message
// (its e-mail, if published, can be copied instead).
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
import '../providers/pending_admissions_provider.dart';

class SpaceOffers extends ConsumerStatefulWidget {
  const SpaceOffers({
    super.key,
    required this.workspace,
    required this.onRequest,
    this.contact,
  });

  final PublicWorkspace workspace;

  /// The admission request, as the page already made it; true when the
  /// server took it (#3683: then the button gives way to "Request pending").
  final Future<bool> Function() onRequest;

  /// The inquiry to the hosts, with its words and whether it is the one
  /// filled action; null where the business takes no inquiries.
  final ({String label, VoidCallback open, bool primary})? contact;

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

  /// Whether an answer this page needs is not there yet, and the failure of
  /// one that failed: nothing is offered while either read is running or has
  /// failed (#3683, #3696).
  ({bool unknown, Object? failure}) _reads({required bool here}) {
    final reads = [
      if (here) ref.watch(myWorkspacesProvider),
      ref.watch(pendingAdmissionsProvider),
    ];
    final failed = reads
        // #4414 kept: picks the failure the caller shows
        .where((r) => r.hasError && !r.isLoading && !r.hasValue)
        .firstOrNull;
    return (unknown: reads.any((r) => !r.hasValue), failure: failed?.error);
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
    final (:unknown, :failure) = _reads(here: here);
    final pending =
        _pending ||
        (ref.watch(pendingAdmissionsProvider).value?.contains(workspace.id) ??
            false);
    final email = workspace.text('email').trim();
    final contact = widget.contact;
    Widget contactButton({required bool filled}) {
      const icon = Icon(Icons.contact_support_outlined);
      final label = Text(contact!.label);
      return filled
          ? FilledButton.icon(
              key: const ValueKey('write-to-hosts'),
              icon: icon,
              label: label,
              onPressed: contact.open,
            )
          : OutlinedButton.icon(
              key: const ValueKey('write-to-hosts'),
              icon: icon,
              label: label,
              onPressed: contact.open,
            );
    }

    final contactFirst = mine == null && (contact?.primary ?? false);
    final joinIcon = Icon(
      pending ? Icons.hourglass_top : Icons.person_add_outlined,
    );
    final joinLabel = Text(
      pending ? l.portalRequestPending : l.portalRequestProfile,
    );
    final onJoin = unknown || _sending || pending ? null : _request;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          if (contactFirst) contactButton(filled: true),
          if (mine != null)
            FilledButton.icon(
              key: const ValueKey('portal-enter'),
              icon: const Icon(Icons.login),
              label: Text(l.portalEnterSpace),
              onPressed: () => enterSpace(context, ref, mine),
            )
          else if (failure != null)
            ReadFailureBanner(
              error: failure,
              onRetry: () => ref
                ..invalidate(myWorkspacesProvider)
                ..invalidate(pendingAdmissionsProvider),
            )
          else if (contactFirst)
            OutlinedButton.icon(
              key: const ValueKey('portal-request-membership'),
              icon: joinIcon,
              label: joinLabel,
              onPressed: onJoin,
            )
          else
            FilledButton.icon(
              key: const ValueKey('portal-request-membership'),
              icon: joinIcon,
              label: joinLabel,
              onPressed: onJoin,
            ),
          if (contact != null && !contactFirst) contactButton(filled: false),
          if (contact == null && email.isNotEmpty)
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
