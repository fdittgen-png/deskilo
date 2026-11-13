// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3906 — where an accounting target's sign-in comes back to. The router
// took the code and the state out of the address and holds them in memory
// (arrived_accounting_sign_in.dart); this page takes them once and completes
// the sign-in with the person's own session: the server connects the books
// only for someone who may manage the connection. Nothing of the code or
// the state is shown, kept or written to the trace.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/arrived_accounting_sign_in.dart';
import '../../domain/accounting_connection.dart';
import '../../providers/accounting_connection_providers.dart';

class AccountingSignInReturnScreen extends ConsumerStatefulWidget {
  const AccountingSignInReturnScreen({super.key});

  @override
  ConsumerState<AccountingSignInReturnScreen> createState() =>
      _AccountingSignInReturnScreenState();
}

class _AccountingSignInReturnScreenState
    extends ConsumerState<AccountingSignInReturnScreen> {
  SignInCompletion? _outcome;

  late final ArrivedAccountingSignIn _arrived = ref.read(
    arrivedAccountingSignInProvider,
  );

  @override
  void initState() {
    super.initState();
    final back = _arrived.held;
    if (back == null) {
      // Opened again, or after a reload: the link was spent or lost.
      _outcome = SignInCompletion.expired;
    } else {
      _arrived.answering();
      unawaited(_complete(back));
    }
  }

  @override
  void dispose() {
    // Leaving the page spends what it held.
    _arrived.clear(closed: true);
    super.dispose();
  }

  Future<void> _complete(SignInReturn back) async {
    SignInCompletion outcome;
    try {
      outcome = await ref
          .read(accountingConnectionCommandProvider)
          .completeSignIn(back);
    } on Exception catch (e, st) {
      // The error names the request's failure, never what it carried.
      TraceLogger.instance.warn(
        'money',
        'accounting sign-in could not be completed: ${e.runtimeType}\n$st',
      );
      outcome = SignInCompletion.failed;
    }
    // Used once, whatever the answer.
    _arrived.clear();
    if (!mounted) return;
    if (outcome == SignInCompletion.connected) {
      ref.invalidate(accountingConnectionsProvider);
    }
    setState(() => _outcome = outcome);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final outcome = _outcome;
    // On the desk the breadcrumb already says this place: a bar holding
    // only that name would be an empty strip, so the page draws none and
    // still tells its name (the title draws nothing there).
    final title = l10n.hubAccountingTitle;
    final named = PageTitle.repeatsPlace(context, title);
    return Scaffold(
      appBar: named ? null : AppBar(title: PageTitle(title)),
      body: ListView(
        padding: AppSpacing.gutterAll,
        children: [
          if (named) PageTitle(title),
          if (outcome == null)
            Semantics(
              key: const ValueKey('accounting-sign-in-completing'),
              label: l10n.accountingSignInCompleting,
              child: const LoadingView(),
            )
          else
            _banner(l10n, outcome),
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton(
              key: const ValueKey('accounting-sign-in-back'),
              onPressed: outcome == null
                  ? null
                  : () => context.go('/money/accounting'),
              child: Text(l10n.accountingSignInBack),
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner(AppLocalizations l10n, SignInCompletion outcome) {
    final (text, icon, severity) = switch (outcome) {
      SignInCompletion.connected => (
        l10n.accountingSignInConnected,
        Icons.check_circle_outline,
        InlineBannerSeverity.info,
      ),
      SignInCompletion.refused => (
        l10n.accountingSignInRefused,
        Icons.block_outlined,
        InlineBannerSeverity.error,
      ),
      SignInCompletion.startedBySomeoneElse => (
        l10n.accountingSignInNotYours,
        Icons.person_off_outlined,
        InlineBannerSeverity.error,
      ),
      SignInCompletion.expired => (
        l10n.accountingSignInExpired,
        Icons.timer_off_outlined,
        InlineBannerSeverity.error,
      ),
      SignInCompletion.failed => (
        l10n.accountingSignInFailed,
        Icons.error_outline,
        InlineBannerSeverity.error,
      ),
    };
    return InlineBanner(
      key: ValueKey('accounting-sign-in-${outcome.name}'),
      icon: icon,
      text: text,
      severity: severity,
    );
  }
}
