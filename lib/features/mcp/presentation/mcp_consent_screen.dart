// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/links/link_launcher.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../application/connect_assistant.dart';
import '../domain/mcp_connection.dart';
import '../domain/mcp_onboarding.dart';
import '../providers/assistant_setup_providers.dart';
import '../providers/mcp_consent_form_provider.dart';
import '../providers/mcp_providers.dart';
import 'mcp_consent_refusal.dart';
import 'widgets/mcp_consent_parts.dart';
import 'widgets/mcp_consent_workspace_card.dart';

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
  bool _redirected = false;

  Future<void> _go(String? url) async {
    if (url == null || _redirected) return;
    _redirected = true;
    await ref.read(linkLauncherProvider)(Uri.parse(url));
  }

  Future<void> _approve(AuthorizationRequest request) async {
    final form = ref.read(mcpConsentFormProvider.notifier);
    if (!form.begin()) return;
    final state = ref.read(mcpConsentFormProvider);
    ConnectResult? result;
    Object? failure;
    await runGuarded(
      context,
      domain: 'mcp',
      message: 'assistant connection failed',
      action: () async {
        try {
          result = await ref
              .read(connectAssistantProvider)
              .connect(
                request,
                {
                  for (final e in state.chosen.entries)
                    e.key: e.value.toList()..sort(),
                },
                optionalFields: {
                  for (final e in state.fields.entries)
                    if (state.chosen.containsKey(e.key))
                      e.key: e.value.toList()..sort(),
                },
              );
        } catch (e, st) {
          // trace-exempt: rethrown to runGuarded, which traces it; kept
          // here only to say WHY in the screen instead of nothing.
          failure = e;
          Error.throwWithStackTrace(e, st);
        }
      },
    );
    if (!mounted) return;
    final refusal = failure == null ? null : mcpConsentRefusal(failure!);
    form.finish(
      outcome: result?.outcome.name,
      refusal: refusal,
      failed: failure != null && refusal == null,
    );
    if (result?.outcome == ConnectOutcome.connected) {
      await _go(result!.redirectTo);
    }
  }

  Future<void> _deny() async {
    final form = ref.read(mcpConsentFormProvider.notifier);
    if (!form.begin()) return;
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
    form.finish(outcome: redirect == null ? null : 'denied');
    await _go(redirect);
  }

  Future<void> _requestEligibility() async {
    await runGuarded(
      context,
      domain: 'mcp',
      message: 'eligibility request failed',
      action: () => ref.read(connectAssistantProvider).requestEligibility(),
    );
    if (mounted) {
      ref.read(mcpConsentFormProvider.notifier).setOutcome('eligibilityRequested');
    }
  }
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // #2145 — the client's approval is read first: an assistant the
    // operator has not approved never reaches Auth's authorization API
    // from here, and the person learns why and who decides. A server
    // before 0357 (or an unreadable answer) keeps the older path, where
    // the database still refuses an unapproved client.
    final gate = ref.watch(mcpConsentStatusProvider(widget.authorizationId));
    final form = ref.watch(mcpConsentFormProvider);
    final status = gate.value;
    final client = status?.client;
    if (gate.isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.mcpConsentTitle),
        ),
        body: const LoadingView(),
      );
    }
    if (client != null && client.status != McpClientApproval.approved) {
      return ConsentNotApproved(
        client: client,
        decider: status!.decider,
        outcome: form.outcome,
        onDeny: form.busy || _redirected ? null : _deny,
      );
    }
    final consent = ref.watch(mcpConsentProvider(widget.authorizationId));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mcpConsentTitle),
      ),
      body: consent.when(
        loading: () => const LoadingView(),
        error: (e, _) => switch (mcpConsentRefusal(e)) {
          final r? => ConsentBanner(
            'mcp-consent-refused-${r.name}',
            mcpConsentRefusalText(l10n, r),
            Icons.lock_outline,
            InlineBannerSeverity.error,
          ),
          null => ConsentBanner(
            'mcp-consent-unavailable',
            l10n.mcpConsentUnavailable,
            Icons.cloud_off_outlined,
            InlineBannerSeverity.error,
          ),
        },
        data: (c) {
          if (c.request.alreadyRedirectTo != null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _go(c.request.alreadyRedirectTo),
            );
            return ConsentBanner(
              'mcp-consent-already',
              l10n.mcpConsentAlready,
              Icons.check_circle_outline,
              InlineBannerSeverity.info,
            );
          }
          return ListView(
            padding: AppSpacing.gutterAll,
            children: [
              if (form.outcome case final o?) ConsentOutcomeBanner(o),
              if (form.refusal case final r?) ConsentRefusalBanner(r),
              if (form.failed)
                ConsentBanner(
                  'mcp-consent-failed',
                  l10n.mcpConsentUnavailable,
                  Icons.sync_problem_outlined,
                  InlineBannerSeverity.error,
                ),
              Text(
                l10n.mcpConsentAsks(c.request.clientName),
                key: const ValueKey('mcp-consent-client'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (client != null) ConsentClientFacts(client),
              const SizedBox(height: AppSpacing.md),
              const ConsentGoogleGate(),
              if (!c.options.eligible) ...[
                ConsentBanner(
                  'mcp-consent-not-eligible',
                  l10n.mcpConsentNotEligible,
                  Icons.lock_outline,
                  InlineBannerSeverity.error,
                ),
                if (status?.decider case final d?) ConsentDeciderLine(d),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  key: const ValueKey('mcp-consent-request-eligibility'),
                  onPressed: form.outcome == 'eligibilityRequested'
                      ? null
                      : _requestEligibility,
                  child: Text(
                    l10n.mcpConsentRequestEligibility,
                  ),
                ),
              ] else if (c.options.workspaces.isEmpty)
                ConsentBanner(
                  'mcp-consent-no-workspace',
                  l10n.mcpConsentNoWorkspace,
                  Icons.info_outline,
                  InlineBannerSeverity.info,
                )
              else ...[
                Text(
                  l10n.mcpConsentChoose,
                ),
                for (final w in c.options.workspaces) ConsentWorkspaceCard(w),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('mcp-consent-deny'),
                      onPressed: form.busy || _redirected ? null : _deny,
                      child: Text(l10n.mcpConsentDeny),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('mcp-consent-approve'),
                      onPressed:
                          form.busy ||
                              _redirected ||
                              !c.options.eligible ||
                              !form.anyChosen
                          ? null
                          : () => _approve(c.request),
                      child: Text(l10n.mcpConsentApprove),
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
}
