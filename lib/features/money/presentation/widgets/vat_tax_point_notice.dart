// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2355 — the one-time owner notice for a French VAT-registered space that
// never chose when its VAT falls due. Before #2355 such a space declared
// on the invoice date; the legal rule for services in France is receipts
// (CGI art. 269-2-c), so it now declares on receipts — and its owner is
// told once, because the periods it declares move. Submitted declarations
// are stored figures and are not touched. Dismissed for good through the
// help-hint dismissal store; choosing an option under the legal identity
// ends it as well, since the space has then chosen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_hint_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/invoice_legal.dart';
import '../../domain/vat_regime.dart';
import '../vat_tax_point_labels.dart';

/// The id the dismissal is stored under.
const String vatTaxPointNoticeId = 'vat-tax-point-fr-receipts';

/// Whether a space in [country] under [vatRegime] with these
/// [invoiceLegal] settings is a French VAT-registered space that never
/// chose its tax point, and so moved to receipts with #2355.
bool needsVatTaxPointNotice({
  required String country,
  required String vatRegime,
  required Map<dynamic, dynamic> invoiceLegal,
}) =>
    country.trim().toUpperCase() == 'FR' &&
    vatRegimeFromWire(vatRegime) == VatRegime.vatRegistered &&
    InvoiceLegal.fromJson(invoiceLegal).vatTaxPoint == null;

class VatTaxPointNotice extends ConsumerWidget {
  const VatTaxPointNotice({super.key, required this.eligible});

  /// [needsVatTaxPointNotice] for the current space.
  final bool eligible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed = ref.watch(dismissedHelpHintsProvider).value;
    // Unknown until the store answers: never flash a notice already
    // dismissed.
    if (dismissed == null ||
        dismissed.contains(vatTaxPointNoticeId) ||
        !eligible) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: InlineBanner(
        key: const ValueKey('vat-tax-point-notice'),
        icon: Icons.info_outline,
        severity: InlineBannerSeverity.info,
        text: vatWords(AppLocalizations.of(context)).vatTaxPointNoticeFr,
        actionLabel: MaterialLocalizations.of(context).okButtonLabel,
        onAction: () => ref
            .read(dismissedHelpHintsProvider.notifier)
            .dismiss(vatTaxPointNoticeId),
      ),
    );
  }
}
