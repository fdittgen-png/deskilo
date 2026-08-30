// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../calendar/presentation/widgets/access_sheet.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/domain/workspace_permission.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/package.dart';
import '../../domain/service_item.dart';
import '../../providers/money_providers.dart';

/// #739 — the member's own prices against the workspace tariff, on the
/// Statement face: what everyone pays, what I pay, since when — and who
/// can see this (the GDPR sheet, with the log of who did).
class NegotiationCard extends ConsumerWidget {
  const NegotiationCard({
    super.key,
    required this.memberId,
    required this.currency,
  });

  final String memberId;
  final MoneyFormat currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(priceNegotiationProvider(memberId));
    final value = async.value;
    if (value == null) return const SizedBox.shrink();
    final deal = value.active;
    final pending = value.pending;
    final services = ref.watch(servicesProvider).value ?? const <ServiceItem>[];
    final packages = ref.watch(packagesProvider).value ?? const <Package>[];
    final monthFormat = DateFormat.yMMMM(
      Localizations.maybeLocaleOf(context)?.toString(),
    );

    Widget row(String label, String defaults, String? mine, {Key? key}) =>
        Padding(
          key: key,
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(flex: 3, child: Text(label)),
            Expanded(
              flex: 2,
              child: Text(
                defaults,
                textAlign: TextAlign.end,
                style: mine != null
                    ? TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        decoration: TextDecoration.lineThrough,
                      )
                    : null,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                mine ?? '—',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontWeight: mine != null ? FontWeight.bold : null,
                  color: mine != null ? theme.colorScheme.primary : null,
                ),
              ),
            ),
          ]),
        );

    return Card(
      key: const ValueKey('negotiation-card'),
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.handshake_outlined),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n?.negotiationCardTitle ?? 'My negotiated prices',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (pending != null)
                Chip(
                  key: const ValueKey('negotiation-pending'),
                  label: Text(
                      l10n?.negotiationPendingBadge ?? 'awaiting validation'),
                  visualDensity: VisualDensity.compact,
                ),
            ]),
            const SizedBox(height: 4),
            Text(
              deal == null
                  ? (pending != null
                      ? (l10n?.negotiationPending ??
                          'A deal is awaiting validation.')
                      : (l10n?.negotiationOnTariff ??
                          'You are on the workspace tariff.'))
                  : (l10n?.negotiationActiveSince(
                          monthFormat.format(deal.validFrom)) ??
                      'Your deal applies since '
                          '${monthFormat.format(deal.validFrom)}.'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              const Expanded(flex: 3, child: SizedBox()),
              Expanded(
                flex: 2,
                child: Text(l10n?.negotiationDefaultColumn ?? 'Tariff',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelSmall),
              ),
              Expanded(
                flex: 2,
                child: Text(l10n?.negotiationMineColumn ?? 'Mine',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelSmall),
              ),
            ]),
            if (deal?.subscriptionPct != null)
              row(
                l10n?.negotiationOccupation ?? 'Occupation',
                '${deal!.previousSubscriptionPct ?? '—'} %',
                '${deal.subscriptionPct} %',
                key: const ValueKey('negotiation-row-occupation'),
              ),
            row(
              l10n?.negotiationFee ?? 'Monthly fee',
              currency.formatMinor(value.defaultFeeCents),
              deal?.feeCents == null
                  ? null
                  : currency.formatMinor(deal!.feeCents!),
              key: const ValueKey('negotiation-row-fee'),
            ),
            row(
              l10n?.negotiationOverage ?? 'Overage per half-day',
              currency.formatMinor(value.defaultOverageFeeCents),
              deal?.overageFeeCents == null
                  ? null
                  : currency.formatMinor(deal!.overageFeeCents!),
              key: const ValueKey('negotiation-row-overage'),
            ),
            row(
              l10n?.negotiationDiscount ?? 'Discount on supplements',
              '0 %',
              deal?.discountPercent == null
                  ? null
                  : '${_pct(deal!.discountPercent!)} %',
              key: const ValueKey('negotiation-row-discount'),
            ),
            // #744 — negotiated items against the catalogue.
            for (final item in services)
              if (deal?.itemPrice('services', item.id) != null)
                row(
                  item.name,
                  currency.formatMinor(item.priceCents),
                  currency.formatMinor(deal!.itemPrice('services', item.id)!),
                  key: ValueKey('negotiation-item-${item.id}'),
                ),
            for (final pkg in packages)
              if (deal?.itemPrice('packages', pkg.id) != null)
                row(
                  pkg.name,
                  currency.formatMinor(pkg.priceCents),
                  currency.formatMinor(deal!.itemPrice('packages', pkg.id)!),
                  key: ValueKey('negotiation-item-${pkg.id}'),
                ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey('negotiation-who-can-see'),
                onPressed: () => showAccessSheet(context, ref),
                icon: const Icon(Icons.shield_outlined, size: 18),
                label: Text(l10n?.negotiationWhoCanSee ?? 'Who can see this'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _pct(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

/// The proposal sheet an owner or finance admin uses for a member
/// (#739): each field optional, the tariff shown as placeholder, the
/// deal goes through validation.
Future<void> showPriceNegotiationSheet(
  BuildContext context,
  WidgetRef ref, {
  required String memberId,
  required String memberName,
  required MoneyFormat currency,
  bool readOnly = false,
}) async {
  final l10n = AppLocalizations.of(context);
  final current = await ref.read(priceNegotiationProvider(memberId).future);
  if (!context.mounted) return;
  final fee = TextEditingController(
      text: current.active?.feeCents == null
          ? ''
          : (current.active!.feeCents! / 100).toStringAsFixed(2));
  final overage = TextEditingController(
      text: current.active?.overageFeeCents == null
          ? ''
          : (current.active!.overageFeeCents! / 100).toStringAsFixed(2));
  final discount = TextEditingController(
      text: current.active?.discountPercent == null
          ? ''
          : NegotiationCard._pct(current.active!.discountPercent!));
  final note = TextEditingController(text: current.active?.note ?? '');
  // #744 — the occupation and the items.
  final levels = await ref.read(subscriptionLevelsProvider.future);
  final services = await ref.read(servicesProvider.future);
  final packages = await ref.read(packagesProvider.future);
  if (!context.mounted) return;
  int? pct = current.active?.subscriptionPct;
  final options = {...levels.offeredLevels, ?pct}.toList()..sort();
  final itemCtl = <String, TextEditingController>{
    for (final s in services)
      'services:${s.id}': TextEditingController(
          text: current.active?.itemPrice('services', s.id) == null
              ? ''
              : (current.active!.itemPrice('services', s.id)! / 100)
                  .toStringAsFixed(2)),
    for (final p in packages)
      'packages:${p.id}': TextEditingController(
          text: current.active?.itemPrice('packages', p.id) == null
              ? ''
              : (current.active!.itemPrice('packages', p.id)! / 100)
                  .toStringAsFixed(2)),
  };
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => SingleChildScrollView(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${l10n?.negotiationProposeTitle ?? 'Price negotiation'} · $memberName',
              style: Theme.of(sheetContext).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            l10n?.negotiationProposeHint ??
                'Leave a field empty to keep the tariff. The deal goes '
                    'through validation before it applies.',
            style: Theme.of(sheetContext).textTheme.bodySmall,
          ),
          if (current.pending != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n?.negotiationPending ?? 'A deal is awaiting validation.',
              key: const ValueKey('negotiation-sheet-pending'),
              style: TextStyle(color: Theme.of(sheetContext).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<int?>(
            key: const ValueKey('negotiation-occupation'),
            initialValue: pct,
            decoration: InputDecoration(
              labelText: l10n?.negotiationOccupation ?? 'Occupation',
              helperText: l10n?.negotiationOccupationHint ??
                  'The share of open days included each month; applied to '
                      'the member once validated.',
              helperMaxLines: 2,
            ),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text(l10n?.negotiationKeepCurrent ?? 'Keep current'),
              ),
              for (final v in options)
                DropdownMenuItem<int?>(
                    value: v,
                    child: Text(l10n?.negotiationPercent(v) ?? '$v %')),
            ],
            onChanged: readOnly ? null : (v) => setSheetState(() => pct = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('negotiation-fee'),
            readOnly: readOnly,
            controller: fee,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n?.negotiationFee ?? 'Monthly fee',
              hintText: currency.formatMinor(current.defaultFeeCents),
              suffixText: currency.currencyName,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('negotiation-overage'),
            readOnly: readOnly,
            controller: overage,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n?.negotiationOverage ?? 'Overage per half-day',
              hintText: currency.formatMinor(current.defaultOverageFeeCents),
              suffixText: currency.currencyName,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('negotiation-discount'),
            readOnly: readOnly,
            controller: discount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n?.negotiationDiscount ?? 'Discount on supplements',
              hintText: '0',
              suffixText: '%',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('negotiation-note'),
            readOnly: readOnly,
            controller: note,
            decoration: InputDecoration(labelText: l10n?.negotiationNote ?? 'Note'),
          ),
          if (services.isNotEmpty || packages.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(l10n?.negotiationItems ?? 'Services and packages',
                style: Theme.of(sheetContext).textTheme.titleSmall),
            Text(
              l10n?.negotiationItemsHint ??
                  'A unit price for this member; empty keeps the catalogue.',
              style: Theme.of(sheetContext).textTheme.bodySmall,
            ),
            for (final s in services)
              TextField(
                key: ValueKey('negotiation-item-services-${s.id}'),
                readOnly: readOnly,
                controller: itemCtl['services:${s.id}'],
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: s.name,
                  hintText: currency.formatMinor(s.priceCents),
                  suffixText: currency.currencyName,
                ),
              ),
            for (final p in packages)
              TextField(
                key: ValueKey('negotiation-item-packages-${p.id}'),
                readOnly: readOnly,
                controller: itemCtl['packages:${p.id}'],
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: p.name,
                  hintText: currency.formatMinor(p.priceCents),
                  suffixText: currency.currencyName,
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            key: const ValueKey('negotiation-submit'),
            onPressed: readOnly || current.pending != null
                ? null
                : () => Navigator.of(sheetContext).pop(true),
            child: Text(l10n?.negotiationSubmit ?? 'Propose for validation'),
          ),
        ],
      ),
      ),
    ),
  );
  if (ok != true || readOnly || !context.mounted) return;
  int? cents(String raw) {
    final t = raw.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    return v == null ? null : (v * 100).round();
  }
  final discountPct = double.tryParse(discount.text.trim().replaceAll(',', '.'));
  final feeCents = cents(fee.text);
  final overageCents = cents(overage.text);
  final items = <String, Map<String, int>>{};
  for (final e in itemCtl.entries) {
    final v = cents(e.value.text);
    if (v == null) continue;
    final kind = e.key.split(':').first;
    final id = e.key.substring(kind.length + 1);
    (items[kind] ??= {})[id] = v;
  }
  if (feeCents == null &&
      overageCents == null &&
      pct == null &&
      discountPct == null &&
      items.isEmpty) {
    return;
  }
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'propose price negotiation failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () => ref.read(moneyRepositoryProvider).proposePriceNegotiation(
          memberId: memberId,
          feeCents: feeCents,
          overageFeeCents: overageCents,
          discountPercent: discountPct,
          note: note.text.trim(),
          subscriptionPct: pct,
          items: items,
        ),
  )) {
    return;
  }
  ref.invalidate(priceNegotiationProvider(memberId));
  if (!context.mounted) return;
  AppSnack.success(
    context,
    l10n?.negotiationProposed ?? 'Deal proposed — waiting for validation.',
  );
}

/// The member sheet's entry (#739): only an owner or a finance admin,
/// never for oneself, only while the feature is on.
class MemberNegotiationTile extends ConsumerWidget {
  const MemberNegotiationTile({
    super.key,
    required this.memberId,
    required this.memberName,
    required this.isOwner,
  });

  final String memberId;
  final String memberName;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final on = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.priceNegotiations);
    final me = ref.watch(myMemberProvider).value;
    // #749 — manage opens the proposal; view alone opens it read-only.
    final perms = ref.watch(myPermissionsProvider);
    final canManage =
        isOwner || perms.contains(WorkspacePermission.manageNegotiations);
    final canView =
        canManage || perms.contains(WorkspacePermission.viewNegotiations);
    if (!on || !canView || me == null || me.id == memberId) {
      return const SizedBox.shrink();
    }
    return ListTile(
      key: ValueKey('member-negotiation-$memberId'),
      leading: const Icon(Icons.handshake_outlined),
      title: Text(l10n?.negotiationProposeTitle ?? 'Price negotiation'),
      subtitle: canManage
          ? null
          : Text(l10n?.negotiationReadOnly ?? 'Read only'),
      onTap: () => showPriceNegotiationSheet(
        context,
        ref,
        memberId: memberId,
        memberName: memberName,
        currency: moneyFormat(
          ref.read(currentWorkspaceProvider).value?.currencyCode ?? 'EUR',
        ),
        readOnly: !canManage,
      ),
    );
  }
}
