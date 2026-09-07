// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/trace/guarded.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/member.dart';
import '../providers/workspace_providers.dart';
import '../../../core/vat/vat_treatment.dart';

/// #985 — the counterparty dimension of VAT: who [member] is for tax.
String vatTreatmentName(AppLocalizations? l10n, VatTreatment t) => switch (t) {
      VatTreatment.auto => l10n?.vatTreatmentAuto ?? 'Automatic',
      VatTreatment.domestic => l10n?.vatTreatmentDomestic ?? 'Domestic VAT',
      VatTreatment.reverseCharge =>
        l10n?.vatTreatmentReverseCharge ?? 'Reverse charge',
      VatTreatment.export => l10n?.vatTreatmentExport ?? 'Outside the EU',
      VatTreatment.exempt => l10n?.vatTreatmentExempt ?? 'Exempt buyer',
    };

/// #985 (migration 0182) — who [member] is for VAT, and the reason an
/// exempt buyer prints. Whoever may issue invoices; the server checks.
Future<void> pickMemberVatTreatment(
  BuildContext context,
  WidgetRef ref,
  Member member,
) async {
  final l10n = AppLocalizations.of(context);
  var chosen = VatTreatment.fromWire(member.vatTreatment);
  final reason = TextEditingController(text: member.vatExemptionReason);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: HelpDotTitle(
          l10n?.memberVatTreatmentLabel ?? 'VAT treatment',
          l10n?.helpTopicVat ?? 'VAT',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n?.memberVatTreatmentExplainer ??
                  'Who this member is for VAT: the automatic rule (reverse '
                      'charge for a business in another EU state), domestic '
                      'VAT regardless, reverse charge, outside the EU, or an '
                      'exempt buyer with the reason printed on the invoice.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final t in VatTreatment.values)
                  ChoiceChip(
                    key: Key('vat-treatment-${t.wire}'),
                    label: Text(vatTreatmentName(l10n, t)),
                    selected: chosen == t,
                    onSelected: (_) => setState(() => chosen = t),
                  ),
              ],
            ),
            if (chosen == VatTreatment.exempt) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('vat-treatment-reason'),
                controller: reason,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: l10n?.vatTreatmentReasonField ??
                      'Exemption reason (printed on the invoice)',
                  counterText: '',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
          ),
          FilledButton(
            key: const Key('vat-treatment-save'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n?.commonSave ?? 'Save'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  final text = chosen == VatTreatment.exempt ? reason.text.trim() : '';
  if (chosen.wire == member.vatTreatment && text == member.vatExemptionReason) {
    return;
  }
  if (!await runGuarded(
    context,
    domain: 'workspace',
    message: 'vat treatment update failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () => ref
        .read(workspaceRepositoryProvider)
        .setMemberVatTreatment(member.id, chosen.wire, text),
  )) {
    return;
  }
  ref.invalidate(workspaceMembersProvider);
}
