// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/second_factor.dart';
import '../../auth/providers/auth_providers.dart';
import '../application/eligibility_review.dart';
import '../domain/mcp_admin.dart';
import '../domain/mcp_context.dart';
import '../providers/mcp_providers.dart';
import 'mcp_operation_labels.dart';

/// #1627 — a database administrator reviews who may use assistants on
/// this database. Approval is not membership, a service or consent; it
/// only lets the person connect assistants where owners expose them.
/// Every decision needs a second factor, which the server checks itself;
/// the request the reviewer looked at is the one decided, or the answer
/// is that it changed.
class EligibilityReviewScreen extends ConsumerStatefulWidget {
  const EligibilityReviewScreen({super.key});

  @override
  ConsumerState<EligibilityReviewScreen> createState() =>
      _EligibilityReviewScreenState();
}

class _EligibilityReviewScreenState
    extends ConsumerState<EligibilityReviewScreen> {
  bool _busy = false;
  String? _outcome;

  /// #1809 — the maximum being edited; null until the server's is read.
  Set<String>? _maximum;
  String? _maximumOutcome;

  /// True once the session is at aal2: asks for the authenticator code
  /// when it is not. Every database decision passes here first. #1625 —
  /// [scope] is the installation the decision goes to: its own session
  /// is checked and verified, never the active backend's.
  Future<bool> _secondFactor(
    EligibilityReview review, [
    McpInstanceRef? scope,
  ]) async {
    var verified = false;
    await runGuarded(
      context,
      domain: 'mcp',
      message: 'second factor check failed',
      action: () async {
        verified = (await review.secondFactor(scope)).aal2;
      },
    );
    if (!verified && mounted) {
      verified =
          await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => SecondFactorSheet(
              review: ref.read(eligibilityReviewProvider),
              scope: scope,
            ),
          ) ??
          false;
    }
    return verified && mounted;
  }

  Future<void> _decide(EligibilityRequest request, bool approve) async {
    if (_busy) return;
    final review = ref.read(eligibilityReviewProvider);
    setState(() => _busy = true);
    final verified = await _secondFactor(review, request.scope);
    if (!mounted) return;
    if (!verified) {
      setState(() => _busy = false);
      return;
    }
    EligibilityDecisionStatus? status;
    await runGuarded(
      context,
      domain: 'mcp',
      message: 'eligibility decision failed',
      action: () async {
        status = await review.decide(request, approve: approve);
      },
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _outcome = status?.name;
    });
    ref.invalidate(eligibilityRequestsProvider);
  }

  /// #1809 — reads the maximum once the second factor is confirmed.
  Future<void> _unlockMaximum() async {
    if (_busy) return;
    setState(() => _busy = true);
    final verified = await _secondFactor(ref.read(eligibilityReviewProvider));
    if (!mounted) return;
    setState(() => _busy = false);
    if (verified) {
      ref
        ..invalidate(mcpDisclosureMaximumProvider)
        ..invalidate(eligibilityRequestsProvider);
    }
  }

  Future<void> _saveMaximum() async {
    final fields = _maximum;
    if (_busy || fields == null) return;
    final review = ref.read(eligibilityReviewProvider);
    setState(() => _busy = true);
    final verified = await _secondFactor(review);
    if (!mounted) return;
    if (!verified) {
      setState(() => _busy = false);
      return;
    }
    Set<String>? saved;
    await runGuarded(
      context,
      domain: 'mcp',
      message: 'disclosure maximum save failed',
      action: () async => saved = await review.setDisclosureMaximum({
        ...fields,
      }),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _maximumOutcome = saved == null ? 'refused' : 'saved';
      if (saved != null) _maximum = null;
    });
    if (saved != null) ref.invalidate(mcpDisclosureMaximumProvider);
  }

  Widget _disclosureMaximum(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final state = ref.watch(mcpDisclosureMaximumProvider);
    return Card(
      key: const ValueKey('mcp-maximum'),
      margin: const EdgeInsets.only(top: AppSpacing.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.mcpDisclosureTitle,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.mcpDisclosureMaximumExplain,
            ),
            if (_maximumOutcome != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: InlineBanner(
                  key: ValueKey('mcp-maximum-outcome-$_maximumOutcome'),
                  icon: Icons.info_outline,
                  severity: _maximumOutcome == 'saved'
                      ? InlineBannerSeverity.info
                      : InlineBannerSeverity.error,
                  text: _maximumOutcome == 'saved'
                      ? (l10n.mcpDisclosureMaximumSaved)
                      : (l10n.mcpDisclosureMaximumRefused),
                ),
              ),
            ...state.when(
              loading: () => const [LoadingView()],
              error: (e, _) => [
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.mcpDisclosureMaximumLocked,
                  key: const ValueKey('mcp-maximum-locked'),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  key: const ValueKey('mcp-maximum-unlock'),
                  onPressed: _busy ? null : _unlockMaximum,
                  child: Text(l10n.mcpDisclosureUnlock),
                ),
              ],
              data: (m) {
                final draft = _maximum ??= {...m.fields};
                return [
                  for (final field in m.available)
                    CheckboxListTile(
                      key: ValueKey('mcp-maximum-field-$field'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: draft.contains(field),
                      title: Text(mcpOptionalFieldLabel(l10n, field)),
                      onChanged: _busy
                          ? null
                          : (on) => setState(
                              () => (on ?? false)
                                  ? draft.add(field)
                                  : draft.remove(field),
                            ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton(
                    key: const ValueKey('mcp-maximum-save'),
                    onPressed: _busy ? null : _saveMaximum,
                    child: Text(
                      l10n.mcpDisclosureMaximumSave,
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final caps = ref.watch(myDatabaseCapabilitiesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mcpReviewTitle),
      ),
      body: caps.when(
        loading: () => const LoadingView(),
        error: (e, _) => _message(
          l10n.mcpAssistantsUnavailable,
        ),
        data: (c) => !c.databaseAdministrator
            ? _message(
                l10n.mcpReviewNotAdmin,
              )
            : ref
                  .watch(eligibilityRequestsProvider)
                  .when(
                    loading: () => const LoadingView(),
                    error: (e, _) => ListView(
                      children: [
                        _message(
                          l10n.mcpReviewUnavailable,
                        ),
                        Padding(
                          padding: AppSpacing.gutterH,
                          child: _disclosureMaximum(l10n),
                        ),
                      ],
                    ),
                    data: (requests) => ListView(
                      padding: AppSpacing.gutterAll,
                      children: [
                        if (_outcome != null) _outcomeBanner(l10n, _outcome!),
                        Text(
                          l10n.mcpReviewExplain,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (requests.isEmpty)
                          Text(
                            key: const ValueKey('mcp-review-empty'),
                            l10n.mcpReviewEmpty,
                          ),
                        for (final r in requests)
                          Card(
                            key: ValueKey('mcp-review-${r.requestId}'),
                            child: ListTile(
                              title: Text(r.email),
                              subtitle: Text(r.userId),
                              trailing: Wrap(
                                spacing: AppSpacing.sm,
                                children: [
                                  OutlinedButton(
                                    key: ValueKey(
                                      'mcp-review-reject-${r.requestId}',
                                    ),
                                    onPressed: _busy
                                        ? null
                                        : () => _decide(r, false),
                                    child: Text(
                                      l10n.mcpReviewReject,
                                    ),
                                  ),
                                  FilledButton(
                                    key: ValueKey(
                                      'mcp-review-approve-${r.requestId}',
                                    ),
                                    onPressed: _busy
                                        ? null
                                        : () => _decide(r, true),
                                    child: Text(
                                      l10n.mcpReviewApprove,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        _disclosureMaximum(l10n),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _message(String text) => Padding(
    padding: AppSpacing.gutterAll,
    child: InlineBanner(
      key: const ValueKey('mcp-review-message'),
      icon: Icons.info_outline,
      text: text,
    ),
  );

  Widget _outcomeBanner(AppLocalizations l10n, String outcome) {
    final (text, severity) = switch (outcome) {
      'decided' || 'replayed' => (
        l10n.mcpReviewDone,
        InlineBannerSeverity.info,
      ),
      'changed' => (
        l10n.mcpReviewChanged,
        InlineBannerSeverity.error,
      ),
      'secondFactorRequired' => (
        l10n.mcpReviewSecondFactor,
        InlineBannerSeverity.error,
      ),
      _ => (
        l10n.mcpReviewRefused,
        InlineBannerSeverity.error,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InlineBanner(
        key: ValueKey('mcp-review-outcome-$outcome'),
        icon: Icons.info_outline,
        severity: severity,
        text: text,
      ),
    );
  }
}

/// Reaches aal2 with the person's authenticator app: enrolls one when
/// there is none, then verifies a code. Pops true only when the server
/// accepted the code.
class SecondFactorSheet extends StatefulWidget {
  const SecondFactorSheet({super.key, required this.review, this.scope});
  final EligibilityReview review;

  /// The installation whose session is verified; null for this screen's.
  final McpInstanceRef? scope;

  @override
  State<SecondFactorSheet> createState() => _SecondFactorSheetState();
}

class _SecondFactorSheetState extends State<SecondFactorSheet> {
  final _code = TextEditingController();
  String? _factorId;
  TotpEnrollment? _enrollment;
  bool _busy = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await runGuarded(
      context,
      domain: 'mcp',
      message: 'second factor setup failed',
      action: () async {
        final state = await widget.review.secondFactor(widget.scope);
        if (state.verifiedTotpId != null) {
          _factorId = state.verifiedTotpId;
        } else {
          final e = await widget.review.enroll(widget.scope);
          _enrollment = e;
          _factorId = e.factorId;
        }
      },
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _verify() async {
    final id = _factorId;
    if (id == null || _busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    var ok = false;
    try {
      await widget.review.verify(id, _code.text.trim(), widget.scope);
      ok = true;
    } on Object catch (error, stack) {
      // trace-exempt: a wrong code is the person's to retry, said below.
      debugPrintStack(stackTrace: stack, label: '$error');
    }
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final e = _enrollment;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.mfaTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          if (e != null) ...[
            Text(
              l10n.mfaEnroll,
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: QrImageView(
                data: e.uri,
                size: 180,
                backgroundColor: Colors.white,
              ),
            ),
            SelectableText(
              e.secret,
              key: const ValueKey('mfa-secret'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          TextField(
            key: const ValueKey('mfa-code'),
            controller: _code,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              labelText: l10n.mfaCode,
              errorText: _failed
                  ? (l10n.mfaWrong)
                  : null,
            ),
            onSubmitted: (_) => _verify(),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const ValueKey('mfa-verify'),
            onPressed: _busy || _factorId == null ? null : _verify,
            child: Text(l10n.mfaVerify),
          ),
        ],
      ),
    );
  }
}
