// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../domain/package.dart';
import '../../domain/subscription_levels.dart';
import '../../domain/vat_rate.dart';
import '../vat_price_label.dart';

/// A billing editor section title with its help dot.
class BillingSectionHeader extends StatelessWidget {
  const BillingSectionHeader({
    super.key,
    required this.title,
    required this.anchor,
    this.small = false,
  });

  final String title;

  /// A [HelpAnchor] id.
  final String anchor;

  /// A sub-heading (titleSmall) instead of a section title (titleMedium).
  final bool small;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(
          title,
          style: small ? textTheme.titleSmall : textTheme.titleMedium,
        ),
        HelpDot(context.l10n.helpTopicBilling, anchor: anchor),
      ],
    );
  }
}

/// The one VAT fact every price on the billing page shares: they are
/// GROSS, taxed at the tariff's rate. Nothing when no VAT is charged.
class BillingVatHint extends StatelessWidget {
  const BillingVatHint({
    super.key,
    required this.chargesVat,
    required this.rates,
    required this.tariffRateId,
  });

  final bool chargesVat;
  final List<VatRate> rates;

  /// '' = the workspace default rate.
  final String tariffRateId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rate = vatRateSuffix(
      chargesVat: chargesVat,
      rates: rates,
      vatRateId: tariffRateId,
    );
    if (rate == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Text(
        tariffRateId.isEmpty
            ? (l10n.billingPricesVatHint(rate))
            : (l10n.billingTariffVatHint(rate)),
        key: const ValueKey('billing-vat-hint'),
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// The preset percent chips and the owner's extra levels.
class BillingLevelChips extends StatelessWidget {
  const BillingLevelChips({
    super.key,
    required this.enabledPresets,
    required this.extraLevels,
    required this.onPresetSelected,
    required this.onExtraDeleted,
  });

  final Set<int> enabledPresets;
  final List<int> extraLevels;
  final void Function(int preset, {required bool selected}) onPresetSelected;
  final ValueChanged<int> onExtraDeleted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final preset in SubscriptionLevels.presets)
          FilterChip(
            key: ValueKey('billing-percent-value-$preset'),
            label: Text(l10n.percentValue(preset)),
            selected: enabledPresets.contains(preset),
            onSelected: (selected) =>
                onPresetSelected(preset, selected: selected),
          ),
        for (final level in extraLevels)
          InputChip(
            label: Text(l10n.percentValue(level)),
            onDeleted: () => onExtraDeleted(level),
          ),
      ],
    );
  }
}

/// The field adding one extra subscription level.
class BillingNewLevelRow extends StatelessWidget {
  const BillingNewLevelRow({
    super.key,
    required this.controller,
    required this.onAdd,
  });

  final TextEditingController controller;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('billing-level-value'),
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.billingLevelValue),
            onSubmitted: (_) => onAdd(),
          ),
        ),
        IconButton(
          key: const ValueKey('billing-add-level'),
          icon: const Icon(Icons.add),
          tooltip: l10n.billingAddLevel,
          onPressed: onAdd,
        ),
      ],
    );
  }
}

/// One package row: "2 days · 200.00 EUR · incl. VAT 20 %" — currency and
/// the pack's own VAT rate — with its active switch.
class BillingPackageTile extends StatelessWidget {
  const BillingPackageTile({
    super.key,
    required this.package,
    required this.currencyCode,
    required this.chargesVat,
    required this.rates,
    required this.onToggle,
  });

  final Package package;
  final String currencyCode;
  final bool chargesVat;
  final List<VatRate> rates;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final price = '${centsToMajor(package.priceCents)} $currencyCode'.trim();
    final summary = l10n.billingPackageSummary(package.days, price);
    final rate = vatRateSuffix(
      chargesVat: chargesVat,
      rates: rates,
      vatRateId: package.vatRateId,
    );
    final vatLabel = rate == null ? null : (l10n.priceVatIncluded(rate));
    return ListTile(
      key: ValueKey('package-${package.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text(package.name),
      subtitle: Text(vatLabel == null ? summary : '$summary · $vatLabel'),
      trailing: Switch(
        key: ValueKey('billing-switch-${package.id}'),
        value: package.active,
        onChanged: (_) => onToggle(),
      ),
    );
  }
}

/// The new-package fields: name, day count, price, and the add button.
class BillingNewPackageRow extends StatelessWidget {
  const BillingNewPackageRow({
    super.key,
    required this.name,
    required this.days,
    required this.price,
    required this.onAdd,
  });

  final TextEditingController name;
  final TextEditingController days;
  final TextEditingController price;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: name,
            decoration: InputDecoration(labelText: l10n.billingPackageName),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: days,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.billingPackageDays),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextField(
            controller: price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.billingPackagePrice),
          ),
        ),
        IconButton(
          key: const ValueKey('billing-add-package'),
          icon: const Icon(Icons.add_circle_outline),
          tooltip: l10n.billingAddPackage,
          onPressed: onAdd,
        ),
      ],
    );
  }
}
