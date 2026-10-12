// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_providers.dart';
import '../application/eligibility_review.dart';
import '../domain/mcp_admin.dart';
import '../domain/mcp_context.dart';
import '../providers/eligibility_review_form_provider.dart';
import '../providers/mcp_providers.dart';
import 'widgets/disclosure_maximum_card.dart';
import 'widgets/second_factor_sheet.dart';

export 'widgets/second_factor_sheet.dart' show SecondFactorSheet;

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
          await showAppSheet<bool>(
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
    final form = ref.read(eligibilityReviewFormProvider.notifier);
    if (!form.begin()) return;
    final review = ref.read(eligibilityReviewProvider);
    final verified = await _secondFactor(review, request.scope);
    if (!mounted) return;
    if (!verified) {
      form.release();
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
    form.decided(status?.name);
    ref.invalidate(eligibilityRequestsProvider);
  }

  /// #1809 — reads the maximum once the second factor is confirmed.
  Future<void> _unlockMaximum() async {
    final form = ref.read(eligibilityReviewFormProvider.notifier);
    if (!form.begin()) return;
    final verified = await _secondFactor(ref.read(eligibilityReviewProvider));
    if (!mounted) return;
    form.release();
    if (verified) {
      ref
        ..invalidate(mcpDisclosureMaximumProvider)
        ..invalidate(eligibilityRequestsProvider);
    }
  }

  Future<void> _saveMaximum() async {
    final form = ref.read(eligibilityReviewFormProvider.notifier);
    final fields = ref.read(eligibilityReviewFormProvider).maximum;
    if (fields == null || !form.begin()) return;
    final review = ref.read(eligibilityReviewProvider);
    final verified = await _secondFactor(review);
    if (!mounted) return;
    if (!verified) {
      form.release();
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
    form.maximumSaved(saved: saved != null);
    if (saved != null) ref.invalidate(mcpDisclosureMaximumProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final caps = ref.watch(myDatabaseCapabilitiesProvider);
    final form = ref.watch(eligibilityReviewFormProvider);
    final maximum = DisclosureMaximumCard(
      onUnlock: _unlockMaximum,
      onSave: _saveMaximum,
    );
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
                          child: maximum,
                        ),
                      ],
                    ),
                    data: (requests) => ListView(
                      padding: AppSpacing.gutterAll,
                      children: [
                        if (form.outcome case final o?) _outcomeBanner(l10n, o),
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
                                    onPressed: form.busy
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
                                    onPressed: form.busy
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
                        maximum,
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
