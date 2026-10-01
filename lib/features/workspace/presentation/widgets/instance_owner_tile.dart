// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/instance_responsibles.dart';
import '../../providers/instance_providers.dart';

/// #1829 — the Settings entry naming who answers for this installation.
/// Everyone sees it; the sheet it opens lets the owner delegate and a new
/// instance's creator take ownership. Hidden while the server has not said
/// (an older server, or Demo), so it never shows an empty promise.
class InstanceOwnerTile extends ConsumerWidget {
  const InstanceOwnerTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(instanceResponsiblesProvider).value;
    if (info == null || info.installationId.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final subtitle = info.claimable
        ? (l10n?.instanceClaimTitle ?? 'Take ownership')
        : info.owners.isEmpty
        ? (l10n?.instanceOwnerNone ?? 'No instance owner is set yet.')
        : info.owners.map((o) => o.name).join(', ');
    return ListTile(
      key: const ValueKey('instance-owner-tile'),
      leading: const Icon(Icons.verified_user_outlined),
      title: Text(l10n?.instanceOwnerTitle ?? 'Instance owner'),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const InstanceOwnerSheet(),
      ),
    );
  }
}

class InstanceOwnerSheet extends ConsumerStatefulWidget {
  const InstanceOwnerSheet({super.key});

  @override
  ConsumerState<InstanceOwnerSheet> createState() => _InstanceOwnerSheetState();
}

class _InstanceOwnerSheetState extends ConsumerState<InstanceOwnerSheet> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _outcome;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  AppLocalizations? get _l10n => AppLocalizations.of(context);

  Future<void> _run(String message, Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    await runGuarded(
      context,
      domain: 'instance',
      message: message,
      action: action,
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _delegate() => _run('delegate instance role failed', () async {
    final outcome = await ref.read(instanceRolesProvider).delegate(_email.text);
    if (outcome == DelegationOutcome.delegated) _email.clear();
    ref.invalidate(instanceResponsiblesProvider);
    if (mounted) setState(() => _outcome = _outcomeText(outcome));
  });

  Future<void> _withdraw(InstanceResponsible who) async {
    final id = who.userId;
    if (id == null) return;
    final l10n = _l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          l10n?.instanceDelegateWithdrawTitle ?? 'Withdraw this delegation?',
        ),
        content: Text(
          '${who.name} · ${who.email}\n'
          '${l10n?.instanceDelegateWithdrawBody ?? 'They lose access to the installation-wide setup immediately.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('instance-withdraw-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n?.instanceDelegateWithdrawConfirm ?? 'Withdraw'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await _run('withdraw instance delegation failed', () async {
      await ref.read(instanceRolesProvider).withdraw(id);
      ref.invalidate(instanceResponsiblesProvider);
      if (mounted) {
        setState(
          () => _outcome =
              _l10n?.instanceDelegationWithdrawn ?? 'Delegation withdrawn.',
        );
      }
    });
  }

  Future<void> _claim() => _run('claim instance ownership failed', () async {
    final claimed = await ref.read(instanceRolesProvider).claim();
    ref.invalidate(instanceResponsiblesProvider);
    if (!mounted) return;
    setState(
      () => _outcome = claimed
          ? (_l10n?.instanceClaimDone ?? 'You are now the instance owner.')
          : (_l10n?.instanceClaimFailed ?? 'Ownership could not be taken.'),
    );
  });

  String _outcomeText(DelegationOutcome outcome) {
    final l10n = _l10n;
    return switch (outcome) {
      DelegationOutcome.delegated => l10n?.instanceDelegated ?? 'Delegated.',
      DelegationOutcome.unchanged =>
        l10n?.instanceDelegateUnchanged ?? 'This person already is a delegate.',
      DelegationOutcome.noAccount =>
        l10n?.instanceDelegateNoAccount ??
            'No account uses this e-mail address.',
      DelegationOutcome.unconfirmed =>
        l10n?.instanceDelegateUnconfirmed ??
            'This account has not confirmed its e-mail address yet.',
      DelegationOutcome.alreadyOwner =>
        l10n?.instanceDelegateAlreadyOwner ??
            'The owner does not need a delegation.',
      DelegationOutcome.unavailable =>
        l10n?.instanceDelegateUnavailable ??
            'This server cannot delegate yet.',
    };
  }

  Future<void> _copy(String email) async {
    await Clipboard.setData(ClipboardData(text: email));
    if (!mounted) return;
    AppSnack.success(
      context,
      _l10n?.instanceOwnerCopied ?? 'E-mail address copied.',
    );
  }

  Widget _person(
    InstanceResponsible who, {
    Widget? action,
    required String keyId,
  }) {
    final l10n = _l10n;
    return ListTile(
      key: ValueKey('instance-person-$keyId'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.person_outline),
      title: Text(who.name),
      subtitle: Text(who.email),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: ValueKey('instance-copy-$keyId'),
            tooltip: l10n?.instanceOwnerCopyEmail ?? 'Copy e-mail address',
            icon: const Icon(Icons.copy_outlined),
            onPressed: () => _copy(who.email),
          ),
          ?action,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final theme = Theme.of(context);
    final info =
        ref.watch(instanceResponsiblesProvider).value ??
        InstanceResponsibles.unavailable;
    return SafeArea(
      child: Padding(
        key: const ValueKey('instance-owner-sheet'),
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n?.instanceOwnerTitle ?? 'Instance owner',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                l10n?.instanceOwnerHelp ??
                    'This installation is shared by all its workspaces. The instance owner answers for it: contact them about anything that concerns the whole installation, such as assistants.',
              ),
              const SizedBox(height: 8),
              if (info.owners.isEmpty)
                Text(
                  l10n?.instanceOwnerNone ?? 'No instance owner is set yet.',
                  key: const ValueKey('instance-owner-none'),
                ),
              for (var i = 0; i < info.owners.length; i++)
                _person(info.owners[i], keyId: 'owner-$i'),
              if (info.you != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    info.isOwner
                        ? (l10n?.instanceYouAreOwner ??
                              'You are the instance owner.')
                        : (l10n?.instanceYouAreDelegate ??
                              'You are a delegate of the instance owner.'),
                    key: const ValueKey('instance-you'),
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              if (info.claimable) ...[
                const Divider(),
                Text(
                  l10n?.instanceClaimTitle ?? 'Take ownership',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n?.instanceClaimBody ??
                      'You created this instance and no owner has been set. Taking ownership makes you the person who answers for it.',
                ),
                const SizedBox(height: 8),
                FilledButton(
                  key: const ValueKey('instance-claim'),
                  onPressed: _busy ? null : _claim,
                  child: Text(l10n?.instanceClaimButton ?? 'Take ownership'),
                ),
              ],
              if (info.owners.isNotEmpty) ...[
                const Divider(),
                Text(
                  l10n?.instanceDelegatesTitle ?? 'Delegates',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n?.instanceDelegatesHelp ??
                      'A delegate can run the installation-wide setup for assistants. Delegates cannot delegate further and see no other workspace.',
                ),
                if (info.delegates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l10n?.instanceDelegatesNone ?? 'No delegates.',
                      key: const ValueKey('instance-delegates-none'),
                    ),
                  ),
                for (var i = 0; i < info.delegates.length; i++)
                  _person(
                    info.delegates[i],
                    keyId: 'delegate-$i',
                    action: info.isOwner
                        ? IconButton(
                            key: ValueKey('instance-withdraw-$i'),
                            tooltip:
                                l10n?.instanceDelegateWithdraw ??
                                'Withdraw the delegation',
                            icon: const Icon(Icons.person_remove_outlined),
                            onPressed: _busy
                                ? null
                                : () => _withdraw(info.delegates[i]),
                          )
                        : null,
                  ),
              ],
              if (info.isOwner) ...[
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('instance-delegate-email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText:
                        l10n?.instanceDelegateFieldLabel ??
                        'E-mail address of an account',
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _busy ? null : _delegate(),
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  key: const ValueKey('instance-delegate-add'),
                  onPressed: _busy ? null : _delegate,
                  child: Text(l10n?.instanceDelegateAdd ?? 'Delegate the role'),
                ),
              ],
              if (_outcome != null) ...[
                const SizedBox(height: 8),
                Text(
                  _outcome!,
                  key: const ValueKey('instance-outcome'),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
