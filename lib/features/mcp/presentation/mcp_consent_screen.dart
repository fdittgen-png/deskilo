// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/links/link_launcher.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../application/connect_assistant.dart';
import '../domain/mcp_connection.dart';
import '../providers/mcp_providers.dart';
import 'mcp_operation_labels.dart';

/// #1615 — Auth's OAuth server sends the person here with an
/// authorization id. The screen names the assistant, offers ONLY the
/// workspaces whose owner exposed MCP with the operations this person
/// may use there, and preselects nothing. Approve records the subset,
/// tells Auth yes and makes the connection usable; Deny tells Auth no.
/// Either way the browser goes back to the assistant.
///
/// No workspace flag guards the route: a workspace is only offered when
/// its owner turned `mcpAccess` on (0271), and the server refuses every
/// call made with an assistant's token (0276).
class McpConsentScreen extends ConsumerStatefulWidget {
  const McpConsentScreen({super.key, required this.authorizationId});

  final String authorizationId;

  @override
  ConsumerState<McpConsentScreen> createState() => _McpConsentScreenState();
}

class _McpConsentScreenState extends ConsumerState<McpConsentScreen> {
  /// workspace id → the operations chosen there; absent = not chosen.
  final _chosen = <String, Set<String>>{};
  bool _busy = false;
  bool _redirected = false;
  String? _outcome;

  Future<void> _go(String? url) async {
    if (url == null || _redirected) return;
    _redirected = true;
    await ref.read(linkLauncherProvider)(Uri.parse(url));
  }

  Future<void> _approve(AuthorizationRequest request) async {
    if (_busy) return;
    setState(() => _busy = true);
    ConnectResult? result;
    await runGuarded(
      context,
      domain: 'mcp',
      message: 'assistant connection failed',
      action: () async {
        result = await ref.read(connectAssistantProvider).connect(request, {
          for (final e in _chosen.entries) e.key: e.value.toList()..sort(),
        });
      },
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _outcome = result?.outcome.name;
    });
    if (result?.outcome == ConnectOutcome.connected) {
      await _go(result!.redirectTo);
    }
  }

  Future<void> _deny() async {
    if (_busy) return;
    setState(() => _busy = true);
    String? redirect;
    await runGuarded(
      context,
      domain: 'mcp',
      message: 'assistant refusal failed',
      action: () async {
        redirect = await ref
            .read(connectAssistantProvider)
            .deny(widget.authorizationId);
      },
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _outcome = redirect == null ? null : 'denied';
    });
    await _go(redirect);
  }

  Future<void> _requestEligibility() async {
    await runGuarded(
      context,
      domain: 'mcp',
      message: 'eligibility request failed',
      action: () => ref.read(connectAssistantProvider).requestEligibility(),
    );
    if (mounted) setState(() => _outcome = 'eligibilityRequested');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final consent = ref.watch(mcpConsentProvider(widget.authorizationId));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.mcpConsentTitle ?? 'Connect an assistant'),
      ),
      body: consent.when(
        loading: () => const LoadingView(),
        error: (e, _) => _banner(
          'mcp-consent-unavailable',
          l10n?.mcpConsentUnavailable ??
              'This connection request could not be loaded. Start again from the assistant.',
          Icons.cloud_off_outlined,
          InlineBannerSeverity.error,
        ),
        data: (c) {
          if (c.request.alreadyRedirectTo != null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _go(c.request.alreadyRedirectTo),
            );
            return _banner(
              'mcp-consent-already',
              l10n?.mcpConsentAlready ??
                  'This assistant is already connected. Returning to it.',
              Icons.check_circle_outline,
              InlineBannerSeverity.info,
            );
          }
          return ListView(
            padding: AppSpacing.gutterAll,
            children: [
              if (_outcome != null) _outcomeBanner(l10n, _outcome!),
              Text(
                l10n?.mcpConsentAsks(c.request.clientName) ??
                    '${c.request.clientName} asks to act for you in Deskilo.',
                key: const ValueKey('mcp-consent-client'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              if (!c.options.eligible) ...[
                _banner(
                  'mcp-consent-not-eligible',
                  l10n?.mcpConsentNotEligible ??
                      'This database has not approved assistants for you yet. '
                          'Ask for approval, then connect again.',
                  Icons.lock_outline,
                  InlineBannerSeverity.error,
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  key: const ValueKey('mcp-consent-request-eligibility'),
                  onPressed: _outcome == 'eligibilityRequested'
                      ? null
                      : _requestEligibility,
                  child: Text(
                    l10n?.mcpConsentRequestEligibility ?? 'Ask for approval',
                  ),
                ),
              ] else if (c.options.workspaces.isEmpty)
                _banner(
                  'mcp-consent-no-workspace',
                  l10n?.mcpConsentNoWorkspace ??
                      'None of your workspaces lets assistants in. Nothing can be connected.',
                  Icons.info_outline,
                  InlineBannerSeverity.info,
                )
              else ...[
                Text(
                  l10n?.mcpConsentChoose ??
                      'Choose each workspace and what it may do there. Nothing is chosen for you.',
                ),
                for (final w in c.options.workspaces) _workspace(l10n, w),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('mcp-consent-deny'),
                      onPressed: _busy || _redirected ? null : _deny,
                      child: Text(l10n?.mcpConsentDeny ?? 'Deny'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('mcp-consent-approve'),
                      onPressed:
                          _busy ||
                              _redirected ||
                              !c.options.eligible ||
                              !_chosen.values.any((ops) => ops.isNotEmpty)
                          ? null
                          : () => _approve(c.request),
                      child: Text(l10n?.mcpConsentApprove ?? 'Connect'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _workspace(AppLocalizations? l10n, ConsentWorkspace w) {
    final chosen = _chosen[w.id];
    return Card(
      key: ValueKey('mcp-consent-ws-${w.id}'),
      margin: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        children: [
          CheckboxListTile(
            key: ValueKey('mcp-consent-ws-toggle-${w.id}'),
            value: chosen != null && chosen.isNotEmpty,
            title: Text(w.name),
            onChanged: _busy
                ? null
                : (on) => setState(() {
                    if (on ?? false) {
                      _chosen[w.id] = {...w.operations};
                    } else {
                      _chosen.remove(w.id);
                    }
                  }),
          ),
          if (chosen != null)
            for (final op in w.operations)
              CheckboxListTile(
                key: ValueKey('mcp-consent-op-${w.id}-$op'),
                dense: true,
                contentPadding: const EdgeInsets.only(
                  left: AppSpacing.xl,
                  right: AppSpacing.md,
                ),
                value: chosen.contains(op),
                title: Text(mcpOperationLabel(l10n, op)),
                onChanged: _busy
                    ? null
                    : (on) => setState(
                        () =>
                            (on ?? false) ? chosen.add(op) : chosen.remove(op),
                      ),
              ),
        ],
      ),
    );
  }

  Widget _outcomeBanner(
    AppLocalizations? l10n,
    String outcome,
  ) => switch (outcome) {
    'connected' => _banner(
      'mcp-consent-connected',
      l10n?.mcpConsentConnected ?? 'Connected. Returning to the assistant.',
      Icons.check_circle_outline,
      InlineBannerSeverity.info,
    ),
    'denied' => _banner(
      'mcp-consent-denied',
      l10n?.mcpConsentDenied ?? 'Refused. The assistant gets nothing.',
      Icons.block,
      InlineBannerSeverity.info,
    ),
    'approvedNotFinalized' => _banner(
      'mcp-consent-partial',
      l10n?.mcpConsentPartial ??
          'The assistant was approved but the connection is not usable yet. '
              'Connect again from the assistant.',
      Icons.sync_problem_outlined,
      InlineBannerSeverity.error,
    ),
    'eligibilityRequested' => _banner(
      'mcp-consent-requested',
      l10n?.mcpConsentRequested ??
          'Approval requested. A database administrator will review it.',
      Icons.hourglass_top,
      InlineBannerSeverity.info,
    ),
    _ => const SizedBox.shrink(),
  };

  Widget _banner(
    String key,
    String text,
    IconData icon,
    InlineBannerSeverity severity,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: InlineBanner(
      key: ValueKey(key),
      icon: icon,
      severity: severity,
      text: text,
    ),
  );
}
