// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1827 B — the installation's assistant switches, for the instance
// operator: the second factor every change needs, the runtime switch with
// what still blocks it, the database administrators, and the assistants'
// OAuth clients. The server decides who may (0340 `instance_*`); this
// screen only shows what it answered and asks for what the person chose.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/labeled_rows.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/instance_operator.dart';
import '../domain/mcp_onboarding.dart';
import '../providers/assistant_setup_providers.dart';
import '../providers/mcp_providers.dart';
import 'eligibility_review_screen.dart' show SecondFactorSheet;
import 'widgets/instance_console_sections.dart';

class InstanceAssistantsScreen extends ConsumerStatefulWidget {
  const InstanceAssistantsScreen({super.key});

  @override
  ConsumerState<InstanceAssistantsScreen> createState() =>
      _InstanceAssistantsScreenState();
}

class _InstanceAssistantsScreenState
    extends ConsumerState<InstanceAssistantsScreen> {
  InstanceMcpOverview? _overview;
  InstanceNotices _notices = InstanceNotices.empty;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
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
    // #2145 — the installation notices, beside the overview; a server
    // without them reads none.
    var notices = InstanceNotices.empty;
    if (overview != null && mounted) {
      await runGuarded(
        context,
        domain: 'mcp',
        message: 'instance notices failed',
        action: () async {
          ref.invalidate(myInstanceNoticesProvider);
          notices = await ref.read(myInstanceNoticesProvider.future);
        },
      );
    }
    if (!mounted) return;
    setState(() {
      _overview = overview;
      _notices = notices;
      _loading = false;
    });
  }

  /// #2145 — a change whose refusal the console can explain.
  Future<void> _explained(
    String message,
    Future<void> Function() action,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (e, st) {
      TraceLogger.instance.error('mcp', message, error: e, stackTrace: st);
      if (mounted) {
        final l10n = context.l10n;
        AppSnack.error(
          context,
          instanceRefusalText(l10n, e) ??
              l10n.mcpNextUnavailable,
        );
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ref.invalidate(myInstanceNoticesProvider);
    await _load();
  }

  /// #2145 — asks the deployed endpoint (pg_net answers asynchronously),
  /// then reads the settled probe.
  Future<void> _checkServer() => _explained(
    'endpoint probe failed',
    () => ref.read(mcpOnboardingCommandsProvider).checkServer(),
  );

  Future<void> _grant(InstanceMember person) async {
    final answer = await showDialog<({String reason, int days})>(
      context: context,
      builder: (_) => InstanceGrantDialog(name: person.name),
    );
    if (answer == null || !mounted) return;
    await _explained(
      'operator grant failed',
      () => ref
          .read(mcpOnboardingCommandsProvider)
          .grant(
            subjectId: person.userId,
            reason: answer.reason,
            days: answer.days,
          ),
    );
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
        await showAppSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (_) =>
              SecondFactorSheet(review: ref.read(eligibilityReviewProvider)),
        ) ??
        false;
    if (ok && mounted) await _load();
  }

  Future<void> _turnOn(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.instanceTurnOn),
        content: Text(
          l10n.instanceTurnOnConfirm,
        ),
        actions: [
          TextButton(
            key: const ValueKey('instance-assistants-text-button'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('instance-turn-on-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.instanceTurnOn),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _explained(
      'runtime on failed',
      () => ref.read(assistantAccessProvider).setRuntime(enabled: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final o = _overview;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.instanceTitle),
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
                text: l10n.instanceNotOperator,
              ),
            )
          : ListView(
              padding: AppSpacing.gutterAll,
              children: [
                Text(
                  l10n.instanceIntro,
                ),
                const SizedBox(height: AppSpacing.md),
                if (!o.secondFactor) ...[
                  InlineBanner(
                    key: const ValueKey('instance-second-factor-needed'),
                    icon: Icons.verified_user_outlined,
                    severity: InlineBannerSeverity.info,
                    text:
                        l10n.instanceSecondFactorNeeded,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const ValueKey('instance-second-factor'),
                      onPressed: _secondFactor,
                      child: Text(
                        l10n.instanceConfirmSecondFactor,
                      ),
                    ),
                  ),
                ],
                InstanceNoticesBanner(
                  notices: _notices,
                  onMarkAllRead: _busy
                      ? null
                      : () => _explained(
                          'notices read failed',
                          () => ref
                              .read(mcpOnboardingCommandsProvider)
                              .markNoticesRead(),
                        ),
                ),
                InstanceEndpointSection(
                  overview: o,
                  onCheck: o.secondFactor && !_busy ? _checkServer : null,
                ),
                const Divider(height: AppSpacing.xl),
                _runtime(l10n, o),
                const Divider(height: AppSpacing.xl),
                _administrators(l10n, o),
                const Divider(height: AppSpacing.xl),
                InstanceAccessSection(
                  overview: o,
                  onGrant: o.secondFactor && !_busy ? _grant : null,
                ),
                const Divider(height: AppSpacing.xl),
                _clients(l10n, o),
                _loopback(l10n, o),
              ],
            ),
    );
  }

  Widget _heading(String text) => SectionHeading(text);

  Widget _runtime(AppLocalizations l10n, InstanceMcpOverview o) {
    final can = o.secondFactor && !_busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(
          l10n.instanceRuntimeTitle,
        ),
        ListTile(
          key: ValueKey('instance-runtime-${o.enabled ? 'on' : 'off'}'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            o.enabled ? Icons.toggle_on : Icons.toggle_off_outlined,
          ),
          title: Text(
            o.enabled
                ? (l10n.instanceRuntimeOn)
                : (l10n.instanceRuntimeOff),
          ),
        ),
        if (!o.enabled && !endpointReady(o.endpointProbe))
          Text(
            key: const ValueKey('instance-turn-on-needs-probe'),
            l10n.instanceTurnOnNeedsProbe,
          ),
        if (!o.enabled && o.blockers.isNotEmpty)
          Text(
            key: const ValueKey('instance-blockers'),
            '${l10n.instanceBlockers} '
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
                  child: Text(l10n.instanceTurnOff),
                )
              : FilledButton(
                  key: const ValueKey('instance-turn-on'),
                  // #2145 — Turn on needs a fresh check of the deployed
                  // endpoint (0360); the check comes first.
                  onPressed: can && o.ready && endpointReady(o.endpointProbe)
                      ? () => _turnOn(l10n)
                      : null,
                  child: Text(
                    l10n.instanceTurnOn,
                  ),
                ),
        ),
      ],
    );
  }

  String _blocker(AppLocalizations l10n, String code) => switch (code) {
    'no_database_administrator' =>
      l10n.instanceBlockerNoAdmin,
    _ => code,
  };

  Widget _administrators(AppLocalizations l10n, InstanceMcpOverview o) {
    final can = o.secondFactor && !_busy;
    String name(InstanceMember m) =>
        m.me ? '${m.name} (${l10n.instanceYou})' : m.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(l10n.instanceAdminsTitle),
        Text(
          l10n.instanceAdminsHelp,
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
              child: Text(l10n.instanceRemoveAdmin),
            ),
          ),
        if (o.candidates.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              key: const ValueKey('instance-no-candidates'),
              l10n.instanceNoCandidates,
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
              child: Text(l10n.instanceMakeAdmin),
            ),
          ),
      ],
    );
  }

  /// #2145 — the family a client was recognised as, by its exact
  /// redirects (0359); null for anything else.
  String? _family(AppLocalizations l10n, String? family) => switch (family) {
    'claude' => l10n.instanceFamilyClaude,
    'chatgpt' => l10n.instanceFamilyChatgpt,
    'loopback' =>
      l10n.instanceFamilyLoopback,
    _ => null,
  };

  /// #2145 — one audited switch for assistants that answer on the
  /// person's own computer (Claude Code, Cursor, VS Code).
  Widget _loopback(AppLocalizations l10n, InstanceMcpOverview o) =>
      SwitchListTile(
        key: ValueKey(
          'instance-loopback-${o.allowLoopbackClients ? 'on' : 'off'}',
        ),
        contentPadding: EdgeInsets.zero,
        title: Text(
          l10n.instanceLoopbackTitle,
        ),
        subtitle: Text(
          l10n.instanceLoopbackHelp,
        ),
        value: o.allowLoopbackClients,
        onChanged: o.secondFactor && !_busy
            ? (on) => _change(
                'loopback switch failed',
                () => ref
                    .read(mcpOnboardingCommandsProvider)
                    .allowLoopbackClients(on),
              )
            : null,
      );

  Widget _clients(AppLocalizations l10n, InstanceMcpOverview o) {
    final can = o.secondFactor && !_busy;
    String status(InstanceClient c) => switch (c.status) {
      'active' => l10n.instanceClientApproved,
      'revoked' => l10n.instanceClientBlocked,
      _ => l10n.instanceClientWaiting,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(l10n.instanceClientsTitle),
        Text(
          l10n.instanceClientsHelp,
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
                    child: Text(l10n.instanceBlock),
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
                    child: Text(l10n.instanceApprove),
                  ),
          ),
      ],
    );
  }
}
