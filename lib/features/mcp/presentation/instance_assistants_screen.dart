// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1827 B — the installation's assistant switches, for the instance
// operator: the second factor every change needs, the runtime switch with
// what still blocks it, the database administrators, and the assistants'
// OAuth clients. The server decides who may (0340 `instance_*`); this
// screen only shows what it answered and asks for what the person chose.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/instance_operator.dart';
import '../providers/assistant_setup_providers.dart';
import '../providers/mcp_providers.dart';
import 'eligibility_review_screen.dart' show SecondFactorSheet;

class InstanceAssistantsScreen extends ConsumerStatefulWidget {
  const InstanceAssistantsScreen({super.key});

  @override
  ConsumerState<InstanceAssistantsScreen> createState() =>
      _InstanceAssistantsScreenState();
}

class _InstanceAssistantsScreenState
    extends ConsumerState<InstanceAssistantsScreen> {
  InstanceMcpOverview? _overview;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    InstanceMcpOverview? overview;
    await runGuarded(
      context,
      domain: 'mcp',
      message: 'instance overview failed',
      action: () async =>
          overview = await ref.read(assistantAccessProvider).instanceOverview(),
    );
    if (!mounted) return;
    setState(() {
      _overview = overview;
      _loading = false;
    });
  }

  Future<void> _change(String message, Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    await runGuarded(context, domain: 'mcp', message: message, action: action);
    if (!mounted) return;
    setState(() => _busy = false);
    await _load();
  }

  Future<void> _secondFactor() async {
    final ok =
        await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (_) =>
              SecondFactorSheet(review: ref.read(eligibilityReviewProvider)),
        ) ??
        false;
    if (ok && mounted) await _load();
  }

  Future<void> _turnOn(AppLocalizations? l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.instanceTurnOn ?? 'Turn on for every workspace'),
        content: Text(
          l10n?.instanceTurnOnConfirm ?? 'Assistants become usable in every workspace that offers them. You can turn them off again at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('instance-turn-on-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n?.instanceTurnOn ?? 'Turn on for every workspace'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _change(
      'runtime on failed',
      () => ref.read(assistantAccessProvider).setRuntime(enabled: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final o = _overview;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.instanceTitle ?? 'Installation: assistants'),
      ),
      body: _loading
          ? const LoadingView()
          : o == null
          ? Padding(
              padding: AppSpacing.gutterAll,
              child: InlineBanner(
                key: const ValueKey('instance-not-operator'),
                icon: Icons.lock_outline,
                severity: InlineBannerSeverity.info,
                text: l10n?.instanceNotOperator ?? "Only the instance operator manages the installation's assistants.",
              ),
            )
          : ListView(
              padding: AppSpacing.gutterAll,
              children: [
                Text(
                  l10n?.instanceIntro ?? 'Switches for every workspace of this installation. Only the instance operator sees this page; every change needs your second factor and is recorded.',
                ),
                const SizedBox(height: AppSpacing.md),
                if (!o.secondFactor) ...[
                  InlineBanner(
                    key: const ValueKey('instance-second-factor-needed'),
                    icon: Icons.verified_user_outlined,
                    severity: InlineBannerSeverity.info,
                    text:
                        l10n?.instanceSecondFactorNeeded ??
                        'Changes here need your second factor on this session.',
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const ValueKey('instance-second-factor'),
                      onPressed: _secondFactor,
                      child: Text(
                        l10n?.instanceConfirmSecondFactor ??
                            'Confirm with my authenticator',
                      ),
                    ),
                  ),
                ],
                _runtime(l10n, o),
                const Divider(height: AppSpacing.xl),
                _administrators(l10n, o),
                const Divider(height: AppSpacing.xl),
                _clients(l10n, o),
                _loopback(l10n, o),
              ],
            ),
    );
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _runtime(AppLocalizations? l10n, InstanceMcpOverview o) {
    final can = o.secondFactor && !_busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(
          l10n?.instanceRuntimeTitle ?? 'Assistants on this installation',
        ),
        ListTile(
          key: ValueKey('instance-runtime-${o.enabled ? 'on' : 'off'}'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            o.enabled ? Icons.toggle_on : Icons.toggle_off_outlined,
          ),
          title: Text(
            o.enabled
                ? (l10n?.instanceRuntimeOn ?? 'On')
                : (l10n?.instanceRuntimeOff ?? 'Off'),
          ),
        ),
        if (!o.enabled && o.blockers.isNotEmpty)
          Text(
            key: const ValueKey('instance-blockers'),
            '${l10n?.instanceBlockers ?? 'Still missing:'} '
            '${o.blockers.map((b) => _blocker(l10n, b)).join(', ')}',
          ),
        Align(
          alignment: Alignment.centerRight,
          child: o.enabled
              ? OutlinedButton(
                  key: const ValueKey('instance-turn-off'),
                  onPressed: can
                      ? () => _change(
                          'runtime off failed',
                          () => ref
                              .read(assistantAccessProvider)
                              .setRuntime(enabled: false),
                        )
                      : null,
                  child: Text(l10n?.instanceTurnOff ?? 'Turn off'),
                )
              : FilledButton(
                  key: const ValueKey('instance-turn-on'),
                  onPressed: can && o.ready ? () => _turnOn(l10n) : null,
                  child: Text(
                    l10n?.instanceTurnOn ?? 'Turn on for every workspace',
                  ),
                ),
        ),
      ],
    );
  }

  String _blocker(AppLocalizations? l10n, String code) => switch (code) {
    'no_database_administrator' =>
      l10n?.instanceBlockerNoAdmin ?? 'a database administrator',
    _ => code,
  };

  Widget _administrators(AppLocalizations? l10n, InstanceMcpOverview o) {
    final can = o.secondFactor && !_busy;
    String name(InstanceMember m) =>
        m.me ? '${m.name} (${l10n?.instanceYou ?? 'you'})' : m.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(l10n?.instanceAdminsTitle ?? 'Database administrators'),
        Text(
          l10n?.instanceAdminsHelp ?? 'They decide who may use assistants. Only people who confirmed their identity for assistants can be chosen.',
        ),
        for (final a in o.administrators)
          ListTile(
            key: ValueKey('instance-admin-${a.userId}'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: Text(name(a)),
            trailing: TextButton(
              key: ValueKey('instance-remove-${a.userId}'),
              onPressed: can
                  ? () => _change(
                      'remove administrator failed',
                      () => ref
                          .read(assistantAccessProvider)
                          .revokeAdministrator(a.userId),
                    )
                  : null,
              child: Text(l10n?.instanceRemoveAdmin ?? 'Remove'),
            ),
          ),
        if (o.candidates.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              key: const ValueKey('instance-no-candidates'),
              l10n?.instanceNoCandidates ??
                  'Nobody else has confirmed their identity yet.',
            ),
          ),
        for (final c in o.candidates)
          ListTile(
            key: ValueKey('instance-candidate-${c.userId}'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text(name(c)),
            trailing: OutlinedButton(
              key: ValueKey('instance-make-admin-${c.userId}'),
              onPressed: can
                  ? () => _change(
                      'make administrator failed',
                      () => ref
                          .read(assistantAccessProvider)
                          .grantAdministrator(c.userId),
                    )
                  : null,
              child: Text(l10n?.instanceMakeAdmin ?? 'Make administrator'),
            ),
          ),
      ],
    );
  }

  /// #2145 — the family a client was recognised as, by its exact
  /// redirects (0359); null for anything else.
  String? _family(AppLocalizations? l10n, String? family) => switch (family) {
    'claude' => l10n?.instanceFamilyClaude ?? 'Claude',
    'chatgpt' => l10n?.instanceFamilyChatgpt ?? 'ChatGPT',
    'loopback' =>
      l10n?.instanceFamilyLoopback ?? 'Desktop or command-line assistant',
    _ => null,
  };

  /// #2145 — one audited switch for assistants that answer on the
  /// person's own computer (Claude Code, Cursor, VS Code).
  Widget _loopback(AppLocalizations? l10n, InstanceMcpOverview o) =>
      SwitchListTile(
        key: ValueKey(
          'instance-loopback-${o.allowLoopbackClients ? 'on' : 'off'}',
        ),
        contentPadding: EdgeInsets.zero,
        title: Text(
          l10n?.instanceLoopbackTitle ??
              'Allow desktop and command-line assistants',
        ),
        subtitle: Text(
          l10n?.instanceLoopbackHelp ??
              'Claude Code, Cursor, VS Code and other assistants that run on '
                  'a person\'s own computer. Each person still approves '
                  'their own connection.',
        ),
        value: o.allowLoopbackClients,
        onChanged: o.secondFactor && !_busy
            ? (on) => _change(
                'loopback switch failed',
                () => ref
                    .read(mcpOnboardingRepositoryProvider)
                    .setLoopbackClients(allowed: on),
              )
            : null,
      );

  Widget _clients(AppLocalizations? l10n, InstanceMcpOverview o) {
    final can = o.secondFactor && !_busy;
    String status(InstanceClient c) => switch (c.status) {
      'active' => l10n?.instanceClientApproved ?? 'Approved',
      'revoked' => l10n?.instanceClientBlocked ?? 'Blocked',
      _ => l10n?.instanceClientWaiting ?? 'Waiting for approval',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(l10n?.instanceClientsTitle ?? 'Assistant clients'),
        Text(
          l10n?.instanceClientsHelp ?? 'An assistant registers itself the first time someone connects it; it works only once approved here.',
        ),
        for (final c in o.clients)
          ListTile(
            key: ValueKey('instance-client-${c.clientId}-${c.status}'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.smart_toy_outlined),
            title: Text(c.name),
            subtitle: Text(
              [
                status(c),
                ?_family(l10n, c.family),
                if (c.redirectHosts.isNotEmpty) c.redirectHosts.join(', '),
              ].join(' · '),
            ),
            trailing: c.approved
                ? TextButton(
                    key: ValueKey('instance-block-${c.clientId}'),
                    onPressed: can
                        ? () => _change(
                            'block client failed',
                            () => ref
                                .read(assistantAccessProvider)
                                .setClient(c.clientId, active: false),
                          )
                        : null,
                    child: Text(l10n?.instanceBlock ?? 'Block'),
                  )
                : OutlinedButton(
                    key: ValueKey('instance-approve-${c.clientId}'),
                    onPressed: can
                        ? () => _change(
                            'approve client failed',
                            () => ref
                                .read(assistantAccessProvider)
                                .setClient(c.clientId, active: true),
                          )
                        : null,
                    child: Text(l10n?.instanceApprove ?? 'Approve'),
                  ),
          ),
      ],
    );
  }
}
