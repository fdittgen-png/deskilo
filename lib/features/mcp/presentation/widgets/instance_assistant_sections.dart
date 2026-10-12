// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/labeled_rows.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/instance_operator.dart';
import '../../providers/assistant_setup_providers.dart';
import '../../providers/mcp_providers.dart';
import 'instance_console_sections.dart' show endpointReady;

/// The installation console's switch sections. [change] runs a guarded
/// change and reloads; [busy] disables the buttons meanwhile.
class InstanceRuntimeSection extends ConsumerWidget {
  const InstanceRuntimeSection({
    super.key,
    required this.o,
    required this.busy,
    required this.change,
    required this.onTurnOn,
  });

  final InstanceMcpOverview o;
  final bool busy;
  final Future<void> Function(String message, Future<void> Function() action)
  change;
  final VoidCallback onTurnOn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final can = o.secondFactor && !busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(l10n.instanceRuntimeTitle),
        ListTile(
          key: ValueKey('instance-runtime-${o.enabled ? 'on' : 'off'}'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            o.enabled ? Icons.toggle_on : Icons.toggle_off_outlined,
          ),
          title: Text(
            o.enabled ? (l10n.instanceRuntimeOn) : (l10n.instanceRuntimeOff),
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
                      ? () => change(
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
                      ? onTurnOn
                      : null,
                  child: Text(l10n.instanceTurnOn),
                ),
        ),
      ],
    );
  }

  String _blocker(AppLocalizations l10n, String code) => switch (code) {
    'no_database_administrator' => l10n.instanceBlockerNoAdmin,
    _ => code,
  };
}

class InstanceAdministratorsSection extends ConsumerWidget {
  const InstanceAdministratorsSection({
    super.key,
    required this.o,
    required this.busy,
    required this.change,
  });

  final InstanceMcpOverview o;
  final bool busy;
  final Future<void> Function(String message, Future<void> Function() action)
  change;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final can = o.secondFactor && !busy;
    String name(InstanceMember m) =>
        m.me ? '${m.name} (${l10n.instanceYou})' : m.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(l10n.instanceAdminsTitle),
        Text(l10n.instanceAdminsHelp),
        for (final a in o.administrators)
          ListTile(
            key: ValueKey('instance-admin-${a.userId}'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: Text(name(a)),
            trailing: TextButton(
              key: ValueKey('instance-remove-${a.userId}'),
              onPressed: can
                  ? () => change(
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
                  ? () => change(
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
}

class InstanceClientsSection extends ConsumerWidget {
  const InstanceClientsSection({
    super.key,
    required this.o,
    required this.busy,
    required this.change,
  });

  final InstanceMcpOverview o;
  final bool busy;
  final Future<void> Function(String message, Future<void> Function() action)
  change;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final can = o.secondFactor && !busy;
    String status(InstanceClient c) => switch (c.status) {
      'active' => l10n.instanceClientApproved,
      'revoked' => l10n.instanceClientBlocked,
      _ => l10n.instanceClientWaiting,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(l10n.instanceClientsTitle),
        Text(l10n.instanceClientsHelp),
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
                        ? () => change(
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
                        ? () => change(
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

  /// #2145 — the family a client was recognised as, by its exact
  /// redirects (0359); null for anything else.
  String? _family(AppLocalizations l10n, String? family) => switch (family) {
    'claude' => l10n.instanceFamilyClaude,
    'chatgpt' => l10n.instanceFamilyChatgpt,
    'loopback' => l10n.instanceFamilyLoopback,
    _ => null,
  };
}

class InstanceLoopbackSwitch extends ConsumerWidget {
  const InstanceLoopbackSwitch({
    super.key,
    required this.o,
    required this.busy,
    required this.change,
  });

  final InstanceMcpOverview o;
  final bool busy;
  final Future<void> Function(String message, Future<void> Function() action)
  change;

  /// #2145 — one audited switch for assistants that answer on the
  /// person's own computer (Claude Code, Cursor, VS Code).
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SwitchListTile(
      key: ValueKey(
        'instance-loopback-${o.allowLoopbackClients ? 'on' : 'off'}',
      ),
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.instanceLoopbackTitle),
      subtitle: Text(l10n.instanceLoopbackHelp),
      value: o.allowLoopbackClients,
      onChanged: o.secondFactor && !busy
          ? (on) => change(
              'loopback switch failed',
              () => ref
                  .read(mcpOnboardingCommandsProvider)
                  .allowLoopbackClients(on),
            )
          : null,
    );
  }
}
