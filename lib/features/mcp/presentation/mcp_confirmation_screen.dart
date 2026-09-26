// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/format_controller.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/action_confirmation.dart';
import '../providers/mcp_providers.dart';

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
  ConsumerState<McpConfirmationScreen> createState() => _McpConfirmationScreenState();
}

class _McpConfirmationScreenState extends ConsumerState<McpConfirmationScreen> {
  ConfirmationStatus? _answered;
  bool _busy = false;

  Future<void> _respond(bool accept) async {
    if (_busy) return;
    setState(() => _busy = true);
    ConfirmationStatus? result;
    await runGuarded(
      context,
      domain: 'mcp',
      message: 'confirmation answer failed',
      action: () async {
        result = await ref
            .read(actionConfirmationRepositoryProvider)
            .respond(widget.confirmationId, accept: accept);
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
    final l10n = AppLocalizations.of(context);
    final confirmation = ref.watch(actionConfirmationProvider(widget.confirmationId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n?.mcpConfirmTitle ?? 'Confirm an assistant request')),
      body: confirmation.when(
        loading: () => const LoadingView(),
        error: (e, _) => _message(
          l10n?.mcpConfirmUnavailable ??
              'This request could not be loaded. Try again from the link.',
          Icons.cloud_off_outlined,
        ),
        data: (c) => ListView(
          padding: AppSpacing.gutterAll,
          children: [
            if (_answered != null) _resultBanner(l10n, _answered!),
            if (_answered == null && !c.status.answerable) _resultBanner(l10n, c.status),
            if (c.status != ConfirmationStatus.notFound &&
                c.status != ConfirmationStatus.unavailable)
              ..._details(l10n, c),
            if (_answered == null && c.status.answerable) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n?.mcpConfirmConsequence ??
                    'Confirming lets the assistant send this exact request once. '
                        'The workspace\'s own validation rules still apply.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('mcp-confirm-decline'),
                    onPressed: _busy ? null : () => _respond(false),
                    child: Text(l10n?.mcpConfirmDecline ?? 'Decline'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('mcp-confirm-accept'),
                    onPressed: _busy ? null : () => _respond(true),
                    child: Text(l10n?.mcpConfirmAccept ?? 'Confirm'),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _message(String text, IconData icon) => Padding(
        padding: AppSpacing.gutterAll,
        child: InlineBanner(key: const ValueKey('mcp-confirm-message'), icon: icon, text: text),
      );

  Widget _resultBanner(AppLocalizations? l10n, ConfirmationStatus status) {
    final (text, icon, severity) = switch (status) {
      ConfirmationStatus.acknowledged || ConfirmationStatus.consumed => (
          l10n?.mcpConfirmDone ??
              'Confirmed. The assistant can now send the request.',
          Icons.check_circle_outline,
          InlineBannerSeverity.info,
        ),
      ConfirmationStatus.declined => (
          l10n?.mcpConfirmDeclined ?? 'Declined. Nothing was done.',
          Icons.block,
          InlineBannerSeverity.info,
        ),
      ConfirmationStatus.expired => (
          l10n?.mcpConfirmExpired ??
              'This request expired. Ask the assistant to send it again.',
          Icons.timer_off_outlined,
          InlineBannerSeverity.error,
        ),
      ConfirmationStatus.targetChanged || ConfirmationStatus.revoked => (
          l10n?.mcpConfirmStale ??
              'This request no longer matches the current data or your access. '
                  'Nothing was done.',
          Icons.sync_problem_outlined,
          InlineBannerSeverity.error,
        ),
      ConfirmationStatus.notFound => (
          l10n?.mcpConfirmNotFound ?? 'There is no such request for you.',
          Icons.search_off,
          InlineBannerSeverity.error,
        ),
      _ => (
          l10n?.mcpConfirmUnavailable ??
              'This request could not be loaded. Try again from the link.',
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

  List<Widget> _details(AppLocalizations? l10n, ActionConfirmation c) {
    final format = ref.watch(appFormatProvider);
    final target = c.target;
    final args = c.arguments;
    String? amount() => target['total_cents'] is int
        ? format.money(target['total_cents']! as int, currency: '${target['currency']}')
        : null;
    final subject = switch (target['kind']) {
      'invoice' => [
          '${target['number'] ?? ''}',
          ?amount(),
          if (target['period'] != null) '${target['period']}',
        ].where((s) => s.isNotEmpty).join(' · '),
      'member' => '${target['name'] ?? ''}',
      'event' => '${target['type'] ?? ''}',
      _ => '',
    };
    final change = switch (c.operation) {
      'request_member_status_change' => l10n?.mcpConfirmNewStatus('${args['status']}') ??
          'New status: ${args['status']}',
      'request_subscription_change' => l10n?.mcpConfirmNewShare('${args['pct']}') ??
          'New subscription share: ${args['pct']} %',
      'respond_to_validation' => args['accept'] == true
          ? (l10n?.mcpConfirmApprove ?? 'Your answer: approve')
          : (l10n?.mcpConfirmRefuse ?? 'Your answer: refuse'),
      'request_invoice_issue' => l10n?.mcpConfirmPeriod('${args['period']}') ??
          'Period: ${args['period']}',
      _ => '',
    };
    ListTile row(Key key, IconData icon, String title, String subtitle) => ListTile(
          key: key,
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon),
          title: Text(title),
          subtitle: subtitle.isEmpty ? null : Text(subtitle),
        );
    return [
      row(const ValueKey('mcp-confirm-action'), Icons.bolt_outlined,
          _operationLabel(l10n, c.operation), subject),
      if (change.isNotEmpty)
        row(const ValueKey('mcp-confirm-change'), Icons.edit_note_outlined, change, ''),
      row(const ValueKey('mcp-confirm-workspace'), Icons.business_outlined,
          l10n?.mcpConfirmWorkspace(c.workspaceName) ?? 'Workspace: ${c.workspaceName}', ''),
      row(const ValueKey('mcp-confirm-client'), Icons.smart_toy_outlined,
          l10n?.mcpConfirmClient(c.clientName) ?? 'Asked by: ${c.clientName}', ''),
    ];
  }

  static String _operationLabel(AppLocalizations? l10n, String op) => switch (op) {
        'request_invoice_issue' => l10n?.mcpOpInvoiceIssue ?? 'Issue an invoice',
        'request_invoice_void' => l10n?.mcpOpInvoiceVoid ?? 'Void an invoice',
        'request_refund' => l10n?.mcpOpRefund ?? 'Refund an invoice',
        'request_member_status_change' =>
          l10n?.mcpOpMemberStatus ?? 'Change a member\'s status',
        'request_subscription_change' =>
          l10n?.mcpOpSubscription ?? 'Change a member\'s subscription share',
        'respond_to_validation' => l10n?.mcpOpRespond ?? 'Answer a validation request',
        _ => op,
      };
}
