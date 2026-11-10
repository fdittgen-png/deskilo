// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/settings/setting_defaults.g.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/loading_view.dart';
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
  }) => ServiceEditor.open(
    context,
    ref,
    service: service,
    categories: [
      for (final s in ref.read(allServicesProvider).value ?? const <ServiceItem>[])
        s.category,
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final servicesAsync = ref.watch(allServicesProvider);
    final chargesVat =
        ref.watch(currentWorkspaceProvider).value?.vatRegime ==
            'vat_registered';
    final vatRates = ref.watch(vatRatesProvider).value ?? const <VatRate>[];
    final currency = appFormatOf(context).moneyIn(ref.watch(currentWorkspaceProvider).value?.currencyCode ?? SettingDefaults.localeDefaultCurrency);
    final inactiveColor = Theme.of(context).disabledColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.servicesTitle),
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('services-new'),
        tooltip: l10n.servicesNew,
        onPressed: () => _editSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: switch (servicesAsync) {
        AsyncData(value: final services) when services.isEmpty => Center(
            child: Text(l10n.servicesEmpty),
          ),
        AsyncData(value: final services) => ListView(
            // #1181 — the add button overlays this list; it ends above it.
            padding: const EdgeInsets.only(bottom: kFabSafeBottom),
            children: [
              // #3552 — grouped by category, the uncategorised last.
              for (final group in groupServicesByCategory(services)) ...[
                FormSection(
                  title: group.category.isEmpty
                      ? l10n.servicesOtherCategory
                      : group.category,
                  children: [
                    for (final service in group.services)
                      _ServiceTile(
                        service: service,
                        chargesVat: chargesVat,
                        vatRates: vatRates,
                        currency: currency,
                        inactiveColor: inactiveColor,
                        onTap: () => _editSheet(context, ref, service: service),
                      ),
                  ],
                ),
              ],
            ],
          ),
        AsyncError() => Center(
            child: Text(
              l10n.workspaceGenericError,
            ),
          ),
        _ => const LoadingView(),
      },
    );
  }
}

/// One service: its price (with the VAT it includes), its duration, its
/// stock, and whether it is inactive.
class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.service,
    required this.chargesVat,
    required this.vatRates,
    required this.currency,
    required this.inactiveColor,
    required this.onTap,
  });

  final ServiceItem service;
  final bool chargesVat;
  final List<VatRate> vatRates;
  final MoneyFormat currency;
  final Color inactiveColor;
  final VoidCallback onTap;

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
      onTap: onTap,
    );
  }
}
