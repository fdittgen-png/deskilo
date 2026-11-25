// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4178 (F4) -- commit a direct engagement: the customer, what is ordered and
// how much of it, before any invoice exists. Nothing is invoiced or paid by it.
// The quantity is read exactly, in the reader's number format; a mistake is
// shown under its field and nothing is sent. One request identity per attempt:
// a retry after a lost answer reuses it, so the server answers it once.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/failure/app_failure.dart';
import '../../../../core/format/decimal_input.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/dropdown_field.dart';
import '../../../../core/ui/form_kit.dart';
import '../../application/service_fulfilment_commands.dart';
import '../../domain/billing_customer.dart';
import '../../domain/service_fulfilment.dart';
import '../widgets/master_data_pickers.dart';
import 'engagement_text.dart';

/// Opens the sheet; true when an engagement was committed.
Future<bool> showDirectEngagementSheet(
  BuildContext context, {
  required ServiceFulfilmentCommands commands,
  required String workspaceId,
  required List<BillingParty> customers,
}) {
  final l10n = context.l10n;
  final fields = FormControllers({'description': '', 'quantity': '1', 'unit': ''});
  final locale = Localizations.localeOf(context).toLanguageTag();
  String? customer;
  String? requestId;
  var committed = false;
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.engagementDirectTitle,
      submitLabel: l10n.engagementSave,
      submitKey: const ValueKey('engagement-direct-save'),
      onDispose: fields.dispose,
      validate: () => {
        if (customer == null) 'customer': l10n.quoteChooseCustomer,
        if (fields['description'].text.trim().isEmpty) 'description': l10n.engagementRefusedIncomplete,
        if (exactQuantityFromInput(fields['quantity'].text, locale: locale).value == null)
          'quantity': l10n.engagementRefusedIncomplete,
      },
      onSubmit: () async {
        final quantity = exactQuantityFromInput(fields['quantity'].text, locale: locale).value!;
        final outcome = await commands.openDirect(
          workspaceId,
          requestId: requestId ??= newRequestId(),
          input: DirectEngagementInput(
            subjectId: customer!,
            description: fields['description'].text.trim(),
            quantity: quantity.text,
            unit: fields['unit'].text.trim(),
          ),
        );
        switch (outcome) {
          case CommandDone():
            committed = true;
            return null;
          case CommandRefused(refusal: Refusal(cause: final FulfilmentRefusal refusal)):
            requestId = null; // a refusal wrote nothing: the next try is a new request
            return engagementRefusalText(l10n, refusal);
          case _:
            return l10n.engagementUnreached; // the same request identity is kept
        }
      },
      builder: (context, refresh) => [
        AppDropdownField<String>(
          key: const ValueKey('engagement-direct-customer'),
          label: l10n.invoicingColCustomer,
          hint: l10n.quoteChooseCustomer,
          value: customer,
          items: [for (final c in customers) (c.subjectId, c.displayName)],
          onChanged: (v) {
            customer = v;
            refresh();
          },
        ),
        const FormGap(),
        AppTextField(
          key: const ValueKey('engagement-direct-description'),
          controller: fields['description'],
          fieldKey: 'description',
          label: l10n.engagementFieldDescription,
        ),
        const FormGap(),
        AppTextField(
          key: const ValueKey('engagement-direct-quantity'),
          controller: fields['quantity'],
          fieldKey: 'quantity',
          label: l10n.standaloneInvoiceLineQuantity,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]'))],
        ),
        const FormGap(),
        // #4471 -- the unit is one of the business's units of measure, never typed.
        UnitPickerField(
          key: const ValueKey('engagement-direct-unit'),
          workspaceId: workspaceId,
          value: fields['unit'].text,
          label: l10n.standaloneInvoiceLineUnit,
          onChanged: (code) {
            fields['unit'].text = code;
            refresh();
          },
        ),
      ],
    ),
  ).then((_) => committed);
}
