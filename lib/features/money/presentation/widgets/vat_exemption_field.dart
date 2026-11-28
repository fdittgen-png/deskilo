// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4501 -- the exemption reason of an exempt or out-of-scope VAT rate, picked from the VATEX codes: the VAT rate
// editor and the tax reference sheet show the same choice. Picking a code writes its legal wording in the business's
// document language; a stored wording no code has is shown as it is, as its own choice, until another is picked.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/dropdown_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/vat_exemption_reasons.dart';
import '../../providers/bank_statement_providers.dart' show currentWorkspaceProvider;
import '../invoice_documents.dart';

/// The name of [code] in the reader's language.
@visibleForTesting
String vatExemptionLabel(AppLocalizations l10n, String code) => switch (vatexArbStem(code)) {
  '79c' => l10n.vatex79cLabel,
  '132' => l10n.vatex132Label,
  '143' => l10n.vatex143Label,
  '148' => l10n.vatex148Label,
  '151' => l10n.vatex151Label,
  '309' => l10n.vatex309Label,
  _ => l10n.vatexOLabel,
};

/// The legal wording of [code] as an invoice prints it.
@visibleForTesting
String vatExemptionWording(AppLocalizations l10n, String code) => switch (vatexArbStem(code)) {
  '79c' => l10n.vatex79cText,
  '132' => l10n.vatex132Text,
  '143' => l10n.vatex143Text,
  '148' => l10n.vatex148Text,
  '151' => l10n.vatex151Text,
  '309' => l10n.vatex309Text,
  _ => l10n.vatexOLabel,
};

/// [code]'s wording in every language the app ships.
Iterable<String> _wordingsOf(String code) => [
  for (final locale in AppLocalizations.supportedLocales) vatExemptionWording(lookupAppLocalizations(locale), code),
];

/// The exemption reason of a rate of [category], stored as [value]; [onChanged] receives the picked code's wording.
class VatExemptionField extends ConsumerWidget {
  const VatExemptionField({
    required this.category,
    required this.value,
    required this.label,
    required this.onChanged,
    super.key,
  });

  final String category;
  final String value;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    ref.watch(currentWorkspaceProvider); // the business is read, so a pick writes its document language
    final code = vatExemptionCodeOfWording(category, value, _wordingsOf);
    final stored = value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppDropdownField<String>(
        key: const ValueKey('vat-exemption-reason'),
        label: label,
        value: code ?? (stored.isEmpty ? null : stored),
        items: [
          for (final c in vatExemptionCodesOf(category)) (c, vatExemptionLabel(l10n, c)),
          if (code == null && stored.isNotEmpty) (stored, stored),
        ],
        onChanged: (picked) {
          if (picked == null || picked == stored) return;
          // the wording is written in the business's document language, read when the code is picked
          onChanged(vatExemptionWording(lookupAppLocalizations(_supported(resolveMemberReportLanguage(ref))), picked));
        },
      ),
    );
  }
}

/// The tax reference sheet's exemption reason, held by [reason]: shown for a rate of category E or O, and for any rate
/// that holds one, so a stored wording stays visible until it is changed.
Widget taxReferenceExemptionField(TextEditingController reason, String category, String label) =>
    vatCategoryNamesExemption(category) || reason.text.trim().isNotEmpty
    ? VatExemptionField(
        key: ValueKey('tax-ref-reason-$category'),
        category: category,
        value: reason.text.trim(),
        label: label,
        onChanged: (wording) => reason.text = wording,
      )
    : const SizedBox.shrink();

Locale _supported(String language) =>
    AppLocalizations.supportedLocales.firstWhere((l) => l.languageCode == language, orElse: () => const Locale('en'));
