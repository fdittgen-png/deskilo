// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/trace/guarded.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/service_item.dart';
import '../../providers/money_providers.dart';

/// Bottom sheet recording consumed services onto the monthly bill (#129,
/// ADR 0008): pick an ACTIVE service, a quantity (1–999) and a billing
/// period. Submitting creates a PENDING service_charge event — nothing
/// hits the ledger until the other side confirms.
///
/// [subjectMemberId] is my own member id on the Money tab; admins/owner
/// pass another member's id (with [subjectName] for the title) from the
/// members screen.
Future<void> showConsumptionSheet(
  BuildContext context,
  WidgetRef ref, {
  required String subjectMemberId,
  String? subjectName,
}) async {
  final l10n = AppLocalizations.of(context);
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null) return;
  final services = await ref.read(servicesProvider.future);
  if (!context.mounted) return;
  if (services.isEmpty) {
    AppSnack.info(
      context,
      l10n?.consumptionNoServices ?? 'No active services to record.',
    );
    return;
  }

  final currency = NumberFormat.simpleCurrency(name: workspace.currencyCode);
  final period = TextEditingController(text: currentPeriod());
  var service = services.first;
  var quantity = 1;
  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: StatefulBuilder(
        builder: (context, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              subjectName == null
                  ? (l10n?.consumptionAdd ?? 'Add consumption')
                  : (l10n?.consumptionAddForMember(subjectName) ??
                      'Add service for $subjectName'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ServiceItem>(
              initialValue: service,
              decoration: InputDecoration(
                labelText: l10n?.consumptionService ?? 'Service',
              ),
              items: [
                for (final item in services)
                  DropdownMenuItem(
                    value: item,
                    child: Text(
                      '${item.name} — '
                      '${currency.format(item.priceCents / 100)}',
                    ),
                  ),
              ],
              onChanged: (v) => setSheetState(() => service = v ?? service),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(l10n?.consumptionQuantity ?? 'Quantity'),
                ),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: quantity <= 1
                      ? null
                      : () => setSheetState(() => quantity--),
                ),
                Text(
                  '$quantity',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: quantity >= 999
                      ? null
                      : () => setSheetState(() => quantity++),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: period,
              decoration: InputDecoration(
                labelText: l10n?.consumptionPeriodLabel ??
                    'Billing period (YYYY-MM)',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                l10n?.moneySubmitPayment ?? 'Submit for confirmation',
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (submitted != true) return;

  final chosenPeriod = period.text.trim();
  if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(chosenPeriod)) return;
  if (!context.mounted) return;
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'record service charge failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () => ref.read(moneyRepositoryProvider).recordServiceCharge(
          workspaceId: workspace.id,
          subjectMemberId: subjectMemberId,
          serviceId: service.id,
          quantity: quantity,
          period: chosenPeriod,
        ),
  )) {
    return;
  }
  if (!context.mounted) return;
  AppSnack.success(
    context,
    l10n?.consumptionRecorded ??
        'Consumption recorded — waiting for confirmation.',
  );
  ref.invalidate(eventsProvider);
}
