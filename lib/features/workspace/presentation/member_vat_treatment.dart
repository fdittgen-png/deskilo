// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/vat/place_of_supply.dart';
import '../../../core/vat/supply_class.dart';
import '../../../core/vat/vat_treatment.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/member.dart';
import '../providers/workspace_providers.dart';

/// #985 — the counterparty dimension of VAT: who [member] is for tax.
String vatTreatmentName(AppLocalizations l10n, VatTreatment t) => switch (t) {
      VatTreatment.auto => l10n.vatTreatmentAuto,
      VatTreatment.domestic => l10n.vatTreatmentDomestic,
      VatTreatment.reverseCharge =>
        l10n.vatTreatmentReverseCharge,
      VatTreatment.export => l10n.vatTreatmentExport,
      VatTreatment.exempt => l10n.vatTreatmentExempt,
    };

/// #985 (migration 0182) — who [member] is for VAT, and the reason an
/// exempt buyer prints. Whoever may issue invoices; the server checks.
Future<void> pickMemberVatTreatment(
  BuildContext context,
  WidgetRef ref,
  Member member,
) async {
  final l10n = context.l10n;
  var chosen = VatTreatment.fromWire(member.vatTreatment);
  final reason = TextEditingController(text: member.vatExemptionReason);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: HelpDotTitle(
          l10n.memberVatTreatmentLabel,
          l10n.helpTopicVat,
          anchor: HelpAnchor.membersVatTreatment,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.memberVatTreatmentExplainer,
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
            // #2354 — what the chosen treatment does to each kind of line,
            // read from the one rule the server applies (its SQL twin is
            // public.supply_vat_category), for a business elsewhere in the EU.
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: _TreatmentExample(treatment: chosen),
            ),
            if (chosen == VatTreatment.reverseCharge) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n
                    .vatTreatmentReverseChargeHint,
                key: const Key('vat-treatment-reverse-charge-hint'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (chosen == VatTreatment.exempt) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('vat-treatment-reason'),
                controller: reason,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: l10n.vatTreatmentReasonField,
                  counterText: '',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('member-vat-treatment-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const Key('vat-treatment-save'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonSave),
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
    errorText: l10n.workspaceGenericError,
    action: () => ref
        .read(workspaceRepositoryProvider)
        .setMemberVatTreatment(member.id, chosen.wire, text),
  )) {
    return;
  }
  ref.invalidate(workspaceMembersProvider);
}

/// #2354 — the two kinds of line under [treatment], for a business
/// customer in another EU country of a French seller that charges VAT.
class _TreatmentExample extends StatelessWidget {
  const _TreatmentExample({required this.treatment});

  final VatTreatment treatment;

  @override
  Widget build(BuildContext context) {
    final l10n =
        context.l10n;
    String outcome(SupplyClass supply) => switch (supplyVatCategory(
          treatment: treatment,
          supply: supply,
          sellerVatRegistered: true,
          sellerCountry: 'FR',
          buyerCountry: 'DE',
          buyerCapacity: 'business',
        )) {
          'AE' => l10n.vatTreatmentReverseCharge,
          'G' => l10n.vatTreatmentExport,
          'E' => l10n.vatTreatmentExempt,
          _ => l10n.vatTreatmentDomestic,
        };
    final style = Theme.of(context).textTheme.bodySmall;
    return Column(
      key: const Key('vat-treatment-example'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.vatTreatmentExampleTitle, style: style),
        Text(
          l10n.vatTreatmentExamplePremises(outcome(SupplyClass.property)),
          key: const Key('vat-treatment-example-premises'),
          style: style,
        ),
        Text(
          l10n.vatTreatmentExampleGeneral(outcome(SupplyClass.general)),
          key: const Key('vat-treatment-example-general'),
          style: style,
        ),
      ],
    );
  }
}
