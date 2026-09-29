// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/second_factor.dart';
import '../../auth/providers/auth_providers.dart';
import '../application/eligibility_review.dart';
import '../domain/mcp_admin.dart';
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
  /// when it is not. Every database decision passes here first.
  Future<bool> _secondFactor(EligibilityReview review) async {
    var verified = false;
    await runGuarded(
      context,
      domain: 'mcp',
      message: 'second factor check failed',
      action: () async {
        verified = (await review.secondFactor()).aal2;
      },
    );
    if (!verified && mounted) {
      verified =
          await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) =>
                SecondFactorSheet(review: ref.read(eligibilityReviewProvider)),
          ) ??
          false;
    }
    return verified && mounted;
  }

  Future<void> _decide(EligibilityRequest request, bool approve) async {
    if (_busy) return;
    final review = ref.read(eligibilityReviewProvider);
    setState(() => _busy = true);
    final verified = await _secondFactor(review);
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
      ref.invalidate(mcpDisclosureMaximumProvider);
      ref.invalidate(eligibilityRequestsProvider);
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

  Widget _disclosureMaximum(AppLocalizations? l10n) {
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
              l10n?.mcpDisclosureTitle ?? 'Optional details',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n?.mcpDisclosureMaximumExplain ??
                  'The most that owners on this database may let assistants see. It never '
                      'widens a workspace\'s policy or a person\'s consent.',
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
                      ? (l10n?.mcpDisclosureMaximumSaved ?? 'Maximum saved.')
                      : (l10n?.mcpDisclosureMaximumRefused ??
                            'The maximum was not saved. It needs your second factor.'),
                ),
              ),
            ...state.when(
              loading: () => const [LoadingView()],
              error: (e, _) => [
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n?.mcpDisclosureMaximumLocked ??
                      'Confirm with your second factor to see and change the maximum.',
                  key: const ValueKey('mcp-maximum-locked'),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  key: const ValueKey('mcp-maximum-unlock'),
                  onPressed: _busy ? null : _unlockMaximum,
                  child: Text(l10n?.mcpDisclosureUnlock ?? 'Confirm'),
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
                      l10n?.mcpDisclosureMaximumSave ?? 'Save the maximum',
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
    final l10n = AppLocalizations.of(context);
    final caps = ref.watch(myDatabaseCapabilitiesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.mcpReviewTitle ?? 'Assistant approvals'),
      ),
      body: caps.when(
        loading: () => const LoadingView(),
        error: (e, _) => _message(
          l10n?.mcpAssistantsUnavailable ??
              'Your assistant access could not be loaded. Try again later.',
        ),
        data: (c) => !c.databaseAdministrator
            ? _message(
                l10n?.mcpReviewNotAdmin ??
                    'Only this database\'s administrators review approvals.',
              )
            : ref
                  .watch(eligibilityRequestsProvider)
                  .when(
                    loading: () => const LoadingView(),
                    error: (e, _) => ListView(
                      children: [
                        _message(
                          l10n?.mcpReviewUnavailable ??
                              'The requests could not be loaded. A review needs your second factor; try again.',
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
                          l10n?.mcpReviewExplain ??
                              'Approving lets a person connect assistants on this database, in the '
                                  'workspaces whose owners allow it. It grants no membership or role.',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (requests.isEmpty)
                          Text(
                            key: const ValueKey('mcp-review-empty'),
                            l10n?.mcpReviewEmpty ?? 'No request is waiting.',
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
                                      l10n?.mcpReviewReject ?? 'Reject',
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
                                      l10n?.mcpReviewApprove ?? 'Approve',
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

  Widget _outcomeBanner(AppLocalizations? l10n, String outcome) {
    final (text, severity) = switch (outcome) {
      'decided' || 'replayed' => (
        l10n?.mcpReviewDone ?? 'Decision recorded.',
        InlineBannerSeverity.info,
      ),
      'changed' => (
        l10n?.mcpReviewChanged ??
            'This request changed or another administrator decided first. Nothing was done.',
        InlineBannerSeverity.error,
      ),
      _ => (
        l10n?.mcpReviewRefused ?? 'The decision was refused.',
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
  const SecondFactorSheet({super.key, required this.review});
  final EligibilityReview review;

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
    _load();
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
        final state = await widget.review.secondFactor();
        if (state.verifiedTotpId != null) {
          _factorId = state.verifiedTotpId;
        } else {
          final e = await widget.review.enroll();
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
      await widget.review.verify(id, _code.text.trim());
      ok = true;
    } catch (error, stack) {
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
    final l10n = AppLocalizations.of(context);
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
            l10n?.mfaTitle ?? 'Confirm with your authenticator',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          if (e != null) ...[
            Text(
              l10n?.mfaEnroll ??
                  'Scan this code with an authenticator app, or enter the key, then type the six digits it shows.',
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
              labelText: l10n?.mfaCode ?? 'Six-digit code',
              errorText: _failed
                  ? (l10n?.mfaWrong ??
                        'That code was not accepted. Try the current one.')
                  : null,
            ),
            onSubmitted: (_) => _verify(),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const ValueKey('mfa-verify'),
            onPressed: _busy || _factorId == null ? null : _verify,
            child: Text(l10n?.mfaVerify ?? 'Verify'),
          ),
        ],
      ),
    );
  }
}
