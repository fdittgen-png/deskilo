// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/mcp/mcp_operations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/presentation/feature_names.dart';
import '../domain/action_confirmation.dart';
import '../providers/mcp_providers.dart';
import 'mcp_operation_labels.dart';

/// #1619 — the one place a person confirms a high-impact action an
/// assistant asked for: which workspace, which assistant, exactly what,
/// about whom or which invoice. Confirm and Decline are equal and
/// neither is preselected. What the server already decided (expired,
/// revoked, answered) is said, and nothing can be pressed.
///
/// Reached by `/mcp/confirm/:id`, as the signed-in person. No workspace
/// flag guards the route: a confirmation only exists for a workspace
/// whose owner exposed MCP with `mcpAccess` on (0271/0272), and the
/// server answers the bound person only.
class McpConfirmationScreen extends ConsumerStatefulWidget {
  const McpConfirmationScreen({super.key, required this.confirmationId});

  final String confirmationId;

  @override
  ConsumerState<McpConfirmationScreen> createState() =>
      _McpConfirmationScreenState();
}

class _McpConfirmationScreenState extends ConsumerState<McpConfirmationScreen> {
  ConfirmationStatus? _answered;
  bool _busy = false;

  Future<void> _respond(ActionConfirmation confirmation, bool accept) async {
    if (_busy) return;
    setState(() => _busy = true);
    ConfirmationStatus? result;
    await runGuarded(
      context,
      domain: 'mcp',
      message: 'confirmation answer failed',
      action: () async {
        result = await ref
            .read(confirmationAnswersProvider)
            .answer(confirmation, accept: accept);
      },
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _answered = result;
    });
    ref.invalidate(actionConfirmationProvider(widget.confirmationId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final confirmation = ref.watch(
      actionConfirmationProvider(widget.confirmationId),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mcpConfirmTitle),
      ),
      body: confirmation.when(
        loading: () => const LoadingView(),
        error: (e, _) => _message(
          l10n.mcpConfirmUnavailable,
          Icons.cloud_off_outlined,
        ),
        data: (c) => ListView(
          padding: AppSpacing.gutterAll,
          children: [
            if (_answered != null) _resultBanner(l10n, _answered!),
            if (_answered == null && !c.status.answerable)
              _resultBanner(l10n, c.status),
            if (c.status != ConfirmationStatus.notFound &&
                c.status != ConfirmationStatus.unavailable)
              ..._details(l10n, c),
            if (_answered == null && c.status.answerable) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.mcpConfirmConsequence,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('mcp-confirm-decline'),
                      onPressed: _busy ? null : () => _respond(c, false),
                      child: Text(l10n.mcpConfirmDecline),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('mcp-confirm-accept'),
                      onPressed: _busy ? null : () => _respond(c, true),
                      child: Text(l10n.mcpConfirmAccept),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _message(String text, IconData icon) => Padding(
    padding: AppSpacing.gutterAll,
    child: InlineBanner(
      key: const ValueKey('mcp-confirm-message'),
      icon: icon,
      text: text,
    ),
  );

  Widget _resultBanner(AppLocalizations l10n, ConfirmationStatus status) {
    final (text, icon, severity) = switch (status) {
      ConfirmationStatus.acknowledged || ConfirmationStatus.consumed => (
        l10n.mcpConfirmDone,
        Icons.check_circle_outline,
        InlineBannerSeverity.info,
      ),
      ConfirmationStatus.declined => (
        l10n.mcpConfirmDeclined,
        Icons.block,
        InlineBannerSeverity.info,
      ),
      ConfirmationStatus.expired => (
        l10n.mcpConfirmExpired,
        Icons.timer_off_outlined,
        InlineBannerSeverity.error,
      ),
      ConfirmationStatus.targetChanged || ConfirmationStatus.revoked => (
        l10n.mcpConfirmStale,
        Icons.sync_problem_outlined,
        InlineBannerSeverity.error,
      ),
      ConfirmationStatus.notFound => (
        l10n.mcpConfirmNotFound,
        Icons.search_off,
        InlineBannerSeverity.error,
      ),
      _ => (
        l10n.mcpConfirmUnavailable,
        Icons.cloud_off_outlined,
        InlineBannerSeverity.error,
      ),
    };
    return InlineBanner(
      key: ValueKey('mcp-confirm-status-${status.name}'),
      icon: icon,
      severity: severity,
      text: text,
    );
  }

  List<Widget> _details(AppLocalizations l10n, ActionConfirmation c) {
    final format = ref.watch(appFormatProvider);
    final target = c.target;
    final args = c.arguments;
    String? amount() => target['total_cents'] is int
        ? format.money(
            target['total_cents']! as int,
            currency: '${target['currency']}',
          )
        : null;
    final subject = switch (target['kind']) {
      'invoice' => [
        '${target['number'] ?? ''}',
        ?amount(),
        if (target['period'] != null) '${target['period']}',
      ].where((s) => s.isNotEmpty).join(' · '),
      'member' => '${target['name'] ?? ''}',
      'event' => '${target['type'] ?? ''}',
      _ => _setupSubject(l10n, target),
    };
    final change = switch (McpOperationId.of(c.operation)) {
      McpOperationId.requestMemberStatusChange =>
        l10n.mcpConfirmNewStatus('${args['status']}'),
      McpOperationId.requestSubscriptionChange =>
        l10n.mcpConfirmNewShare('${args['pct']}'),
      McpOperationId.respondToValidation =>
        args['accept'] == true
            ? l10n.mcpConfirmApprove
            : l10n.mcpConfirmRefuse,
      McpOperationId.requestInvoiceIssue =>
        l10n.mcpConfirmPeriod('${args['period']}'),
      _ => _setupChange(l10n, c.operation, target),
    };
    ListTile row(Key key, IconData icon, String title, String subtitle) =>
        ListTile(
          key: key,
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon),
          title: Text(title),
          subtitle: subtitle.isEmpty ? null : Text(subtitle),
        );
    return [
      row(
        const ValueKey('mcp-confirm-action'),
        Icons.bolt_outlined,
        mcpOperationLabel(l10n, c.operation),
        subject,
      ),
      if (change.isNotEmpty)
        row(
          const ValueKey('mcp-confirm-change'),
          Icons.edit_note_outlined,
          change,
          '',
        ),
      row(
        const ValueKey('mcp-confirm-workspace'),
        Icons.business_outlined,
        l10n.mcpConfirmWorkspace(c.workspaceName),
        '',
      ),
      row(
        const ValueKey('mcp-confirm-client'),
        Icons.smart_toy_outlined,
        l10n.mcpConfirmClient(c.clientName),
        '',
      ),
    ];
  }
}

/// What a setup request is about: the levels it sets, or the step.
String _setupSubject(AppLocalizations l10n, Map<String, Object?> target) =>
    switch (target['kind']) {
      'setup_levels' => _levelChanges(l10n, target['changes']),
      'setup_step' => l10n.setupStepTitle('${target['step']}'),
      _ => '',
    };

/// What a setup request changes: the features, or the step's new state.
String _setupChange(
  AppLocalizations l10n,
  String operation,
  Map<String, Object?> target,
) => switch (McpOperationId.of(operation)) {
  McpOperationId.applySetupLevels => _featureChanges(l10n, target),
  McpOperationId.markSetupStep =>
    target['marked'] == 'done'
        ? l10n.mcpConfirmStepDone
        : l10n.mcpConfirmStepLater,
  _ => '',
};

/// Each process whose level a change of levels sets, in words.
String _levelChanges(AppLocalizations l10n, Object? changes) => [
  if (changes is List)
    for (final c in changes.whereType<Map<Object?, Object?>>())
      l10n.mcpConfirmLevel(
        l10n.setupProcessName('${c['process']}'),
        l10n.setupLevelName('${c['process']}_${c['to']}'),
      ),
].join(' · ');

/// Every feature a change of levels switches on and off, by name:
/// the person confirms exactly what changes.
String _featureChanges(AppLocalizations l10n, Map<String, Object?> target) {
  String names(Object? keys) => [
    if (keys is List)
      for (final key in keys)
        if (WorkspaceFeature.values.where((f) => f.dbKey == key).firstOrNull
            case final feature?)
          featureName(l10n, feature),
  ].join(', ');
  final on = names(target['switch_on']);
  final off = names(target['switch_off']);
  return [
    if (on.isNotEmpty) l10n.mcpConfirmSwitchOn(on),
    if (off.isNotEmpty) l10n.mcpConfirmSwitchOff(off),
  ].join('\n');
}
