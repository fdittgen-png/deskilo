// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/shortcuts/app_shortcuts.dart';
import '../../../../core/shortcuts/shortcut_scope.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/adaptive/window_class.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../core/ui/kit/records_table.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/service_item.dart';
import '../../providers/money_providers.dart';
import '../vat_price_label.dart';
import '../widgets/service_sheet.dart';

/// Owner-only consumable-service catalog editor (#123): name and price
/// are configurable; services are deactivated, never deleted (bill lines
/// reference them).
class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  Future<void> _editSheet(
    BuildContext context,
    WidgetRef ref, {
    ServiceItem? service,
  }) async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    await ServiceEditor.open(
      context,
      ref,
      workspaceId: workspace.id,
      service: service,
      categories: [
        for (final s in ref.read(allServicesProvider).value ?? const <ServiceItem>[]) // empty-ok: only suggestions; an unread list proposes none
          s.category,
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final servicesAsync = ref.watch(allServicesProvider);
    final chargesVat =
        ref.watch(currentWorkspaceProvider).value?.vatRegime ==
            'vat_registered';
    final vatRates = ref.watch(vatRatesProvider).value ?? const <VatRate>[]; // empty-ok: an unread rate names no VAT suffix, never a wrong one
    final currency = appFormatOf(context).moneyIn(ref.watch(currentWorkspaceProvider).value?.currencyCode);
    final inactiveColor = Theme.of(context).disabledColor;
    final look = (
      chargesVat: chargesVat,
      vatRates: vatRates,
      currency: currency,
      inactiveColor: inactiveColor,
    );

    // #3614 — N: a new service, beside the table at the desk.
    return ShortcutScope(
      handlers: {
        AppShortcutId.newRecord: () => _editSheet(context, ref),
      },
      child: Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.servicesTitle),
        actions: [
          // #3614 — worded in the bar: a new service opens beside the table.
          OutlinedButton.icon(
            key: const ValueKey('services-new'),
            onPressed: () => _editSheet(context, ref),
            icon: const Icon(Icons.add),
            label: Text(l10n.servicesNew),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: switch (servicesAsync) {
        AsyncData(value: final services)
            when services.isEmpty => Center(child: Text(l10n.servicesEmpty)),
        // #3552 — on a phone, grouped by category, the uncategorised last.
        AsyncData(value: final services)
            when WindowClass.of(context) == WindowClass.compact =>
          ListView(
            children: [
              for (final group in groupServicesByCategory(services))
                FormSection(
                  title: group.category.isEmpty
                      ? l10n.servicesOtherCategory
                      : group.category,
                  children: [
                    for (final service in group.services)
                      InkWell(
                        key: ValueKey('services-tile-${service.id}'),
                        onTap: () =>
                            _editSheet(context, ref, service: service),
                        child: _ServiceTile(
                          service: service,
                          chargesVat: chargesVat,
                          vatRates: vatRates,
                          currency: currency,
                          inactiveColor: inactiveColor,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        // #3614 — a records table from a medium window; a service opens
        // in a side panel beside it.
        AsyncData(value: final services) => RecordsTable<ServiceItem>(
              tableId: 'services',
              rows: services,
              keyOf: (s) => s.id,
              searchText: (s) => '${s.name} ${s.category}',
              onOpen: (s) => _editSheet(context, ref, service: s),
              empty: Center(child: Text(l10n.servicesEmpty)),
              initialQuery: const RecordsQuery(sortColumn: 'name'),
              chips: [
                RecordChip(
                  id: 'active',
                  label: l10n.servicesActive,
                  keeps: (s) => s.active,
                ),
                RecordChip(
                  id: 'inactive',
                  label: l10n.servicesInactive,
                  keeps: (s) => !s.active,
                ),
              ],
              columns: _columns(context, look),
              cardBuilder: (context, s) => _ServiceTile(
                key: ValueKey('services-tile-${s.id}'),
                service: s,
                chargesVat: chargesVat,
                vatRates: vatRates,
                currency: currency,
                inactiveColor: inactiveColor,
              ),
            ),
        AsyncError() => Center(
            child: Text(
              l10n.workspaceGenericError,
            ),
          ),
        _ => const LoadingView(),
      },
    ),
    );
  }

  /// The table's columns: service, kind, unit, price, VAT and active.
  List<RecordColumn<ServiceItem>> _columns(BuildContext context, _Look look) {
    final l10n = context.l10n;
    Text muted(ServiceItem s, String text) => Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: s.active ? null : TextStyle(color: look.inactiveColor),
    );
    return [
      RecordColumn(
        id: 'name',
        label: l10n.eventTypeServiceCharge,
        flex: 3,
        hideable: false,
        sortKey: (s) => s.name.toLowerCase(),
        cell: (_, s) => muted(s, s.name),
      ),
      RecordColumn(
        id: 'category',
        label: l10n.servicesCategory,
        flex: 2,
        sortKey: (s) => s.category.toLowerCase(),
        cell: (_, s) => muted(
          s,
          s.category.isEmpty ? l10n.servicesOtherCategory : s.category,
        ),
      ),
      RecordColumn(
        id: 'unit',
        label: l10n.scheduleUnitLabel,
        flex: 2,
        cell: (_, s) => muted(s, _unitOf(l10n, s)),
      ),
      RecordColumn(
        id: 'price',
        label: l10n.servicesPrice,
        numeric: true,
        flex: 2,
        sortKey: (s) => s.priceCents,
        cell: (_, s) => muted(s, look.currency.formatMinor(s.priceCents)),
      ),
      RecordColumn(
        id: 'vat',
        label: l10n.vatTitle,
        flex: 2,
        cell: (context, s) {
          final rate = vatRateSuffix(
            chargesVat: look.chargesVat,
            rates: look.vatRates,
            vatRateId: s.vatRateId,
            format: appFormatOf(context),
          );
          // #537 — a gross price under a VAT-charging regime NAMES its tax.
          return muted(s, rate == null ? '' : l10n.priceVatIncluded(rate));
        },
      ),
      RecordColumn(
        id: 'active',
        label: l10n.servicesActive,
        flex: 2,
        sortKey: (s) => s.active ? 0 : 1,
        cell: (_, s) => s.active
            ? const Icon(Icons.check, size: 18)
            : muted(s, l10n.servicesInactive),
      ),
    ];
  }

  /// What a service is counted in: its duration, its shelf, or nothing.
  static String _unitOf(AppLocalizations l10n, ServiceItem s) {
    if (s.durationMinutes case final minutes?) {
      return l10n.servicesDurationShort(minutes);
    }
    // #731 — the shelf count for a supply.
    return switch (s.stock) {
      null => '',
      0 => l10n.serviceOutOfStock,
      final n => l10n.serviceStockCount(n),
    };
  }
}

/// How the services are drawn: the VAT regime and rates, the currency and
/// the colour of an inactive one.
typedef _Look = ({
  bool chargesVat,
  List<VatRate> vatRates,
  MoneyFormat currency,
  Color inactiveColor,
});

/// One service: its price (with the VAT it includes), its duration, its
/// stock, and whether it is inactive.
class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    super.key,
    required this.service,
    required this.chargesVat,
    required this.vatRates,
    required this.currency,
    required this.inactiveColor,
  });

  final ServiceItem service;
  final bool chargesVat;
  final List<VatRate> vatRates;
  final MoneyFormat currency;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rate = vatRateSuffix(
      chargesVat: chargesVat,
      rates: vatRates,
      vatRateId: service.vatRateId,
      format: appFormatOf(context),
    );
    // #731 — the shelf count for a supply.
    final stock = service.stock == null
        ? null
        : service.stock == 0
        ? l10n.serviceOutOfStock
        : l10n.serviceStockCount(service.stock!);
    final minutes = service.durationMinutes;
    return ListTile(
      key: ValueKey('services-price-vat-included-${service.id}'),
      leading: Icon(
        service.active
            ? Icons.local_cafe_outlined
            : Icons.do_not_disturb_on_outlined,
        color: service.active ? null : inactiveColor,
      ),
      title: Text(
        service.name,
        style: service.active ? null : TextStyle(color: inactiveColor),
      ),
      // #537 — a gross price under a VAT-charging regime NAMES its tax.
      subtitle: Text(
        [
          currency.formatMinor(service.priceCents),
          if (rate != null) l10n.priceVatIncluded(rate),
          if (minutes != null) l10n.servicesDurationShort(minutes),
          ?stock,
        ].join(' · '),
      ),
      trailing: service.active ? null : Text(l10n.servicesInactive),
    );
  }
}
