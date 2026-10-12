// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/links/link_launcher.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/identity_binding.dart';
import '../../workspace/providers/instance_providers.dart';
import '../application/connect_assistant.dart';
import '../domain/mcp_access_status.dart';
import '../domain/mcp_connection.dart';
import '../domain/mcp_onboarding.dart';
import '../providers/assistant_setup_providers.dart';
import '../providers/mcp_providers.dart';
import 'mcp_consent_refusal.dart';
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
  /// 0340 — consent needs a Google sign-in; read once per visit.
  late final Future<McpGoogleSignIn> _google =
      ref.read(assistantAccessProvider).googleSignIn();

  Widget _googleGate(AppLocalizations l10n) => FutureBuilder<McpGoogleSignIn>(
        future: _google,
        builder: (context, snap) {
          final state = mcpGoogleState(snap.data);
          if (!snap.hasData || state == McpGoogleState.ready) {
            return const SizedBox.shrink();
          }
          final link = state == McpGoogleState.linkGoogle;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _banner(
                  'mcp-consent-google-${state.name}',
                  link
                      ? (l10n.mcpNextLinkGoogle)
                      : (l10n.mcpNextSignInGoogle),
                  Icons.lock_outline,
                  InlineBannerSeverity.error,
                ),
                if (!link)
                  OutlinedButton(
                    key: const ValueKey('mcp-consent-sign-in-google'),
                    onPressed: () => runGuarded(
                      context,
                      domain: 'mcp',
                      message: 'google sign-in failed',
                      action: () =>
                          ref.read(assistantAccessProvider).signInWithGoogle(),
                    ),
                    child: Text(
                        l10n.mcpStatusSignInGoogle),
                  ),
              ],
            ),
          );
        },
      );
  /// workspace id → the operations chosen there; absent = not chosen.
  final _chosen = <String, Set<String>>{};

  /// #1809 — workspace id → the optional fields consented there; only
  /// ever the ones that workspace offers, and none unless ticked.
  final _fields = <String, Set<String>>{};
  bool _busy = false;
  bool _redirected = false;
  String? _outcome;

  /// #2145 — why the last approval was refused, when the server said; a
  /// refusal it did not explain is `failed`.
  McpConsentRefusal? _refusal;
  bool _failed = false;

  Future<void> _go(String? url) async {
    if (url == null || _redirected) return;
    _redirected = true;
    await ref.read(linkLauncherProvider)(Uri.parse(url));
  }

  Future<void> _approve(AuthorizationRequest request) async {
    if (_busy) return;
    setState(() => _busy = true);
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
                  for (final e in _chosen.entries)
                    e.key: e.value.toList()..sort(),
                },
                optionalFields: {
                  for (final e in _fields.entries)
                    if (_chosen.containsKey(e.key))
                      e.key: e.value.toList()..sort(),
                },
              );
        } catch (e) { // ignore: catch_no_st
          // trace-exempt: rethrown to runGuarded, which traces it; kept
          // here only to say WHY in the screen instead of nothing.
          failure = e;
          rethrow;
        }
      },
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _outcome = result?.outcome.name;
      _refusal = failure == null ? null : mcpConsentRefusal(failure!);
      _failed = failure != null && _refusal == null;
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
    final l10n = context.l10n;
    // #2145 — the client's approval is read first: an assistant the
    // operator has not approved never reaches Auth's authorization API
    // from here, and the person learns why and who decides. A server
    // before 0357 (or an unreadable answer) keeps the older path, where
    // the database still refuses an unapproved client.
    final gate = ref.watch(mcpConsentStatusProvider(widget.authorizationId));
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
      return _notApproved(l10n, client, status!.decider);
    }
    final consent = ref.watch(mcpConsentProvider(widget.authorizationId));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mcpConsentTitle),
      ),
      body: consent.when(
        loading: () => const LoadingView(),
        error: (e, _) => switch (mcpConsentRefusal(e)) {
          final r? => _banner(
            'mcp-consent-refused-${r.name}',
            mcpConsentRefusalText(l10n, r),
            Icons.lock_outline,
            InlineBannerSeverity.error,
          ),
          null => _banner(
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
            return _banner(
              'mcp-consent-already',
              l10n.mcpConsentAlready,
              Icons.check_circle_outline,
              InlineBannerSeverity.info,
            );
          }
          return ListView(
            padding: AppSpacing.gutterAll,
            children: [
              if (_outcome != null) _outcomeBanner(l10n, _outcome!),
              if (_refusal case final r?) _refusalBanner(l10n, r),
              if (_failed)
                _banner(
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
              if (client != null) _clientFacts(l10n, client),
              const SizedBox(height: AppSpacing.md),
              _googleGate(l10n),
              if (!c.options.eligible) ...[
                _banner(
                  'mcp-consent-not-eligible',
                  l10n.mcpConsentNotEligible,
                  Icons.lock_outline,
                  InlineBannerSeverity.error,
                ),
                if (status?.decider case final d?) _deciderLine(l10n, d),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  key: const ValueKey('mcp-consent-request-eligibility'),
                  onPressed: _outcome == 'eligibilityRequested'
                      ? null
                      : _requestEligibility,
                  child: Text(
                    l10n.mcpConsentRequestEligibility,
                  ),
                ),
              ] else if (c.options.workspaces.isEmpty)
                _banner(
                  'mcp-consent-no-workspace',
                  l10n.mcpConsentNoWorkspace,
                  Icons.info_outline,
                  InlineBannerSeverity.info,
                )
              else ...[
                Text(
                  l10n.mcpConsentChoose,
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
                      child: Text(l10n.mcpConsentDeny),
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

  Widget _workspace(AppLocalizations l10n, ConsentWorkspace w) {
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
                      _fields.remove(w.id);
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
          if (chosen != null && w.optionalFields.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Text(
                l10n.mcpConsentFieldsExplain,
                key: ValueKey('mcp-consent-fields-${w.id}'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            for (final field in w.optionalFields)
              CheckboxListTile(
                key: ValueKey('mcp-consent-field-${w.id}-$field'),
                dense: true,
                contentPadding: const EdgeInsets.only(
                  left: AppSpacing.xl,
                  right: AppSpacing.md,
                ),
                value: _fields[w.id]?.contains(field) ?? false,
                title: Text(mcpOptionalFieldLabel(l10n, field)),
                onChanged: _busy
                    ? null
                    : (on) => setState(() {
                        final set = _fields.putIfAbsent(w.id, () => {});
                        (on ?? false) ? set.add(field) : set.remove(field);
                      }),
              ),
          ],
        ],
      ),
    );
  }

  /// #2145 — an assistant the operator has not approved: the cause, who
  /// decides, and Deny. Nothing is asked of Auth but the refusal.
  Widget _notApproved(
    AppLocalizations l10n,
    ConsentClient client,
    ConsentDecider? decider,
  ) {
    final name = client.name.isEmpty ? client.clientId : client.name;
    final blocked = client.status == McpClientApproval.blocked;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mcpConsentTitle),
      ),
      body: ListView(
        padding: AppSpacing.gutterAll,
        children: [
          if (_outcome != null) _outcomeBanner(l10n, _outcome!),
          _banner(
            'mcp-consent-client-${client.status.name}',
            blocked
                ? (l10n.mcpConsentClientBlocked(name))
                : (l10n.mcpConsentClientWaiting(name)),
            Icons.lock_outline,
            InlineBannerSeverity.error,
          ),
          _clientFacts(l10n, client),
          if (!blocked && decider != null) _deciderLine(l10n, decider),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            key: const ValueKey('mcp-consent-deny'),
            onPressed: _busy || _redirected ? null : _deny,
            child: Text(l10n.mcpConsentDeny),
          ),
        ],
      ),
    );
  }

  /// Where the answer goes, and the family an approval covers.
  Widget _clientFacts(AppLocalizations l10n, ConsentClient client) {
    final host = client.redirectHost;
    final family = switch (client.family) {
      'claude' => l10n.mcpConsentFamilyClaude,
      'chatgpt' => l10n.mcpConsentFamilyChatgpt,
      'loopback' => l10n.mcpConsentFamilyLoopback,
      _ => null,
    };
    final approved = client.status == McpClientApproval.approved;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (host != null && host.isNotEmpty)
          Text(
            key: const ValueKey('mcp-consent-redirect-host'),
            l10n.mcpConsentRedirectHost(host),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (approved && family != null)
          Text(
            key: ValueKey('mcp-consent-family-${client.family}'),
            family,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  /// Who takes the open step: you (with the console), a named person, or
  /// nobody yet.
  Widget _deciderLine(AppLocalizations l10n, ConsentDecider d) {
    if (d.me) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            key: const ValueKey('mcp-consent-decider-me'),
            l10n.mcpConsentDeciderMe,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('mcp-consent-open-console'),
              onPressed: () => context.push('/installation/assistants'),
              child: Text(
                l10n.mcpConnectOpenInstallation,
              ),
            ),
          ),
        ],
      );
    }
    final name = d.displayName;
    return Text(
      key: ValueKey('mcp-consent-decider-${d.kind.name}'),
      name == null || name.isEmpty
          ? (l10n.mcpConsentDeciderNobody)
          : (l10n.mcpConsentDeciderAsk(name)),
    );
  }

  /// A refusal the server explained, with who can lift it when that is
  /// the installation's operator.
  Widget _refusalBanner(AppLocalizations l10n, McpConsentRefusal r) {
    var text = mcpConsentRefusalText(l10n, r);
    if (r == McpConsentRefusal.clientNotApproved) {
      final who = ref.watch(instanceResponsiblesProvider).value;
      final names = [
        for (final p in [...?who?.owners, ...?who?.delegates])
          if (p.name.isNotEmpty) p.name,
      ];
      if (names.isNotEmpty) {
        text = '$text ${l10n.mcpConnectWaitingOperator(names.join(', '))}';
      }
    }
    return _banner(
      'mcp-consent-refused-${r.name}',
      text,
      Icons.lock_outline,
      InlineBannerSeverity.error,
    );
  }

  Widget _outcomeBanner(
    AppLocalizations l10n,
    String outcome,
  ) => switch (outcome) {
    'connected' => _banner(
      'mcp-consent-connected',
      l10n.mcpConsentConnected,
      Icons.check_circle_outline,
      InlineBannerSeverity.info,
    ),
    'denied' => _banner(
      'mcp-consent-denied',
      l10n.mcpConsentDenied,
      Icons.block,
      InlineBannerSeverity.info,
    ),
    'approvedNotFinalized' => _banner(
      'mcp-consent-partial',
      l10n.mcpConsentPartial,
      Icons.sync_problem_outlined,
      InlineBannerSeverity.error,
    ),
    'eligibilityRequested' => _banner(
      'mcp-consent-requested',
      l10n.mcpConsentRequested,
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
