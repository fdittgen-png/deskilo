// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4005 — a house abroad's own first task. While its birth record says its
// prices are still to be named, a card on its home and in Settings ›
// Organisation says what comes before its first sale in its country: 1. its
// tax rates (none to set where the country has no VAT); 2. its prices, the
// services and packages that arrived inactive, counted down. The page names
// each row's price (empty when the currency differs; the head's amount
// otherwise), its rate (proposed from the head's category when the house has
// exactly one rate of it) and activates it. It also says what is this house's
// own to set. "Done" closes the task; at none left it closes itself.
//
// It lives in the app layer: it reads the organisation's birth record and the
// money catalogue together, which neither feature imports from the other.
import 'dart:async';

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart'
    show TaxReferenceQueries, TaxReferenceSet;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/amount_input.dart';
import '../../core/i18n/country_names.dart';
import '../../core/l10n/context_l10n.dart';
import '../../core/navigation/routes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/ui/adaptive/task_surface.dart';
import '../../core/ui/form_kit.dart';
import '../../core/ui/master_data_field.dart';
import '../../features/money/domain/house_prices.dart';
import '../../features/money/domain/service_item.dart';
import '../../features/money/providers/money_providers.dart';
import '../../features/workspace/domain/organisation.dart';
import '../../features/workspace/domain/workspace.dart';
import '../../features/workspace/providers/organisation_providers.dart';
import '../../features/workspace/providers/workspace_tax_reference.dart';

/// Whether [workspace]'s country taxes sales without VAT (sales tax), by
/// the reference its context captured.
bool _noVat(TaxReferenceSet? reference, Workspace workspace) =>
    reference?.gateOf(workspace.countryCode)?.salesTaxMode ?? false;

/// The card of a house whose prices are still to be named; nothing
/// otherwise.
class HousePricesCard extends ConsumerWidget {
  const HousePricesCard({super.key, required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final birth = ref.watch(houseBirthProvider(workspace.id)).value;
    final services = ref.watch(allServicesProvider).value;
    final packages = ref.watch(allPackagesProvider).value;
    final rates = ref.watch(vatRatesProvider).value;
    if (birth == null ||
        !birth.pricesPending ||
        services == null ||
        packages == null ||
        rates == null) {
      return const SizedBox.shrink();
    }
    final left = houseRowsToName(services: services, packages: packages);
    if (left.isEmpty) return const SizedBox.shrink();
    final country = localizedCountryName(l10n, workspace.countryCode);
    final noVat = _noVat(watchWorkspaceTaxReference(ref), workspace);
    final taxed = rates.isNotEmpty;
    final pricesOpen = noVat || taxed;
    return Card(
      key: const ValueKey('house-prices-card'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                l10n.houseFirstSale(country),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (noVat)
              ListTile(
                key: const ValueKey('house-prices-no-vat'),
                leading: const Icon(Icons.check_circle_outline),
                title: Text(l10n.houseNoVat(country)),
              )
            else
              ListTile(
                key: const ValueKey('house-prices-rates'),
                leading: Icon(
                  taxed ? Icons.check_circle : Icons.radio_button_unchecked,
                ),
                title: Text(l10n.houseSetRates(country)),
                onTap: () => context.push(Routes.setupStep('vat')),
              ),
            ListTile(
              key: const ValueKey('house-prices-name'),
              enabled: pricesOpen,
              leading: const Icon(Icons.sell_outlined),
              title: Text(l10n.houseNamePrices(left.length)),
              subtitle: pricesOpen
                  ? null
                  : Text(l10n.houseNamePricesAfterRates),
              onTap: pricesOpen
                  ? () => HousePricesPage.open(context, workspace, birth)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// The page that names a house's prices.
class HousePricesPage extends ConsumerStatefulWidget {
  const HousePricesPage({
    super.key,
    required this.workspace,
    required this.birth,
  });

  final Workspace workspace;
  final HouseBirth birth;

  /// Opens the page as a task.
  static Future<void> open(
    BuildContext context,
    Workspace workspace,
    HouseBirth birth,
  ) => showTask<void>(
    context,
    size: TaskSize.standard,
    builder: (_) => HousePricesPage(workspace: workspace, birth: birth),
  );

  @override
  ConsumerState<HousePricesPage> createState() => _HousePricesPageState();
}

class _HousePricesPageState extends ConsumerState<HousePricesPage> {
  final _prices = <String, TextEditingController>{};
  final _rates = <String, TextEditingController>{};
  final _problems = <String, String>{};

  @override
  void dispose() {
    for (final c in [..._prices.values, ..._rates.values]) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _price(HouseRow row) => _prices.putIfAbsent(
    row.id,
    () => TextEditingController(
      // The head's amount travelled only in the same currency.
      text: widget.birth.amountsKept
          ? amountInputText(
              row.priceCents,
              currency: widget.workspace.currencyCode,
              locale: Localizations.localeOf(context).toString(),
            )
          : '',
    ),
  );

  Future<void> _activate(HouseRow row, List<VatRate> rates) async {
    final l10n = context.l10n;
    final read = readAmountInput(
      _price(row).text,
      locale: Localizations.localeOf(context).toString(),
      currency: widget.workspace.currencyCode,
      allowNegative: false,
    );
    final rate = switch (_rates[row.id]?.text.trim()) {
      final id? when rates.any((r) => r.id == id) => id,
      _ => null,
    };
    final problem = read.minor == null
        ? l10n.housePriceRequired
        : rates.isNotEmpty && rate == null
        ? l10n.houseRateRequired
        : null;
    setState(() {
      if (problem == null) {
        _problems.remove(row.id);
      } else {
        _problems[row.id] = problem;
      }
    });
    if (problem != null) return;
    final terms = ref.read(commercialTermsProvider);
    switch (row.kind) {
      case HouseRowKind.services:
        await terms.updateService(
          row.id,
          ServiceChange(
            priceCents: read.minor,
            vatRateId: rate ?? '',
            active: true,
          ),
        );
        ref
          ..invalidate(allServicesProvider)
          ..invalidate(servicesProvider);
      case HouseRowKind.packages:
        await terms.updatePackage(
          row.id,
          priceCents: read.minor,
          vatRateId: rate ?? '',
          active: true,
        );
        ref
          ..invalidate(allPackagesProvider)
          ..invalidate(packagesProvider);
    }
  }

  Future<void> _done() async {
    await ref
        .read(organisationCommandsProvider)
        .clearPricesPending(widget.workspace.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final services =
        ref.watch(allServicesProvider).value ??
        const []; // empty-ok: rows appear once read
    final packages =
        ref.watch(allPackagesProvider).value ??
        const []; // empty-ok: rows appear once read
    final rates = [
      for (final r
          in ref.watch(vatRatesProvider).value ??
              const <VatRate>[]) // empty-ok: no rate offered until read
        if (r.active) r,
    ];
    final rows = houseRowsToName(services: services, packages: packages);
    for (final row in rows) {
      _rates.putIfAbsent(
        row.id,
        () => TextEditingController(
          text: proposedHouseRate(row, widget.birth.rateHints, rates)?.id ?? '',
        ),
      );
    }
    final own = [
      (l10n.houseOwnFeeBands, '/billing'),
      (l10n.houseOwnLayout, '/report-editor'),
      (l10n.houseOwnLinks, '/documents'),
      (l10n.houseOwnPayment, '/payment-methods'),
    ];
    return SafeArea(
      child: ListView(
        key: const ValueKey('house-prices-page'),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            l10n.housePricesTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const FormGap(),
          for (final row in rows) ...[
            _HouseRowEditor(
              row: row,
              currency: widget.workspace.currencyCode,
              price: _price(row),
              rates: rates,
              rate: _rates[row.id]!,
              problem: _problems[row.id],
              onActivate: () => _activate(row, rates),
            ),
            const FormGap(),
          ],
          Text(
            l10n.houseOwnTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final (label, route) in own)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: ValueKey('house-own-$route'),
                onPressed: () => context.push(route),
                child: Text(label),
              ),
            ),
          const FormGap(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: const ValueKey('house-prices-later'),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.houseLater),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                key: const ValueKey('house-prices-done'),
                onPressed: rows.isEmpty ? () => unawaited(_done()) : null,
                child: Text(l10n.houseDone),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One row to name: its kind and name, its price, its rate and Activate.
class _HouseRowEditor extends StatelessWidget {
  const _HouseRowEditor({
    required this.row,
    required this.currency,
    required this.price,
    required this.rates,
    required this.rate,
    required this.problem,
    required this.onActivate,
  });

  final HouseRow row;
  final String currency;
  final TextEditingController price;
  final List<VatRate> rates;
  final TextEditingController rate;
  final String? problem;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kind = row.kind == HouseRowKind.services
        ? l10n.houseKindService
        : l10n.houseKindPackage;
    return Column(
      key: ValueKey('house-row-${row.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$kind · ${row.name}'),
        const FormGap.small(),
        AppAmountField(
          key: ValueKey('house-price-${row.id}'),
          controller: price,
          label: l10n.servicesPrice,
          currency: currency,
          allowNegative: false,
          helper: price.text.trim() == '0' ? l10n.houseFree : null,
          error: problem,
        ),
        if (rates.isNotEmpty) ...[
          const FormGap.small(),
          MasterDataField(
            controller: rate,
            label: l10n.houseRateLabel,
            fieldKey: 'rate-${row.id}',
            textKey: ValueKey('house-rate-${row.id}'),
            options: [
              for (final r in rates)
                MasterDataOption(code: r.id, name: r.label),
            ],
          ),
        ],
        const FormGap.small(),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton(
            key: ValueKey('house-activate-${row.id}'),
            onPressed: onActivate,
            child: Text(l10n.houseActivate),
          ),
        ),
      ],
    );
  }
}
