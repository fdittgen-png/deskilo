// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup step "invoice numbering": the invoice series' own card from the
// number sequences screen (format, live next number, Save), and beside it
// the number the next invoice will carry, formatted by the series itself
// from the stored next value. Nothing here draws a number: the database
// takes one only when an invoice is issued.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/setup_step_layout.dart';
import '../../domain/number_sequence.dart';
import '../../providers/money_providers.dart';
import '../screens/number_sequences_screen.dart';

/// The journal whose numbers invoices carry.
const _invoiceJournal = 'invoice';

class SetupNumberingStep extends ConsumerWidget {
  const SetupNumberingStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(numberSequencesProvider)) {
        AsyncValue(hasValue: true, :final value) => _page(
          context,
          ref,
          (value ?? const <NumberSequence>[])
                  .where((s) => s.journal == _invoiceJournal)
                  .firstOrNull ??
              NumberSequence.defaultsFor(_invoiceJournal),
        ),
        AsyncError() => Padding(
          padding: AppSpacing.lgAll,
          child: InlineBanner(
            key: const ValueKey('setup-numbering-failed'),
            icon: Icons.error_outline,
            text: context.l10n.setupStepLoadFailed,
          ),
        ),
        _ => const LoadingView(),
      };

  Widget _page(BuildContext context, WidgetRef ref, NumberSequence invoice) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SetupStepLayout(
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.setupStepHint('numbering')),
          const FormGap.large(),
          InlineBanner(
            key: const ValueKey('setup-numbering-lock'),
            icon: Icons.lock_outline,
            severity: InlineBannerSeverity.info,
            text: l10n.setupGrowNumberingLock,
          ),
          const FormGap(),
          NumberSequenceCard(sequence: invoice),
        ],
      ),
      preview: Column(
        key: const ValueKey('setup-numbering-preview'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.setupGrowNumberingPreviewNote),
          const FormGap.small(),
          Text(
            invoice.format(invoice.nextValue, ref.watch(clockProvider).now()),
            key: const ValueKey('setup-numbering-next'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const FormGap.small(),
          Text(
            l10n.setupGrowNumberingNothingTaken,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
