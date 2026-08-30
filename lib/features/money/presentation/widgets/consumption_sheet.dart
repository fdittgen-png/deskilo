// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import '../../../../core/i18n/money_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/service_item.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../domain/price_negotiation.dart';
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
  // #744 — the subject's negotiated unit prices, when they have a deal.
  final negotiated = ref
      .read(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.priceNegotiations)
      ? (await ref
              .read(priceNegotiationProvider(subjectMemberId).future)
              .catchError((Object e, StackTrace st) {
            TraceLogger.instance.warn('money', 'negotiation lookup failed',
                error: e, stackTrace: st);
            return const PriceNegotiation(
                defaultFeeCents: 0, defaultOverageFeeCents: 0);
          }))
          .active
      : null;
  if (!context.mounted) return;
  if (services.isEmpty) {
    AppSnack.info(
      context,
      l10n?.consumptionNoServices ?? 'No active services to record.',
    );
    return;
  }

  final currency = moneyFormat(workspace.currencyCode);
  final period = TextEditingController(
    text: currentPeriod(ref.read(clockProvider).now()),
  );
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
              // #731 — labels grew a stock suffix; never let them clip.
              isExpanded: true,
              initialValue: service,
              decoration: InputDecoration(
                labelText: l10n?.consumptionService ?? 'Service',
              ),
              items: [
                for (final item in services)
                  DropdownMenuItem(
                    value: item,
                    // #731 — an empty shelf cannot be consumed.
                    enabled: item.stock != 0,
                    child: Text(
                      '${item.name} — '
                      '${currency.formatMinor(negotiated?.itemPrice('services', item.id) ?? item.priceCents)}'
                      '${item.stock == null ? '' : item.stock == 0 ? ' · ${l10n?.serviceOutOfStock ?? 'Out of stock'}' : ' · ${l10n?.serviceStockCount(item.stock!) ?? '${item.stock} in stock'}'}',
                      overflow: TextOverflow.ellipsis,
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
              key: const ValueKey('consumption-submit'),
              onPressed: service.stock != null && service.stock! < quantity
                  ? null
                  : () => Navigator.of(context).pop(true),
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
