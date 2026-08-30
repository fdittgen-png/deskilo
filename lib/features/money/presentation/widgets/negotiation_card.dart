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
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
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
          TextField(
            key: const ValueKey('negotiation-fee'),
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
            controller: note,
            decoration: InputDecoration(labelText: l10n?.negotiationNote ?? 'Note'),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            key: const ValueKey('negotiation-submit'),
            onPressed: current.pending != null
                ? null
                : () => Navigator.of(sheetContext).pop(true),
            child: Text(l10n?.negotiationSubmit ?? 'Propose for validation'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  int? cents(String raw) {
    final t = raw.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    return v == null ? null : (v * 100).round();
  }
  final pct = double.tryParse(discount.text.trim().replaceAll(',', '.'));
  final feeCents = cents(fee.text);
  final overageCents = cents(overage.text);
  if (feeCents == null && overageCents == null && pct == null) return;
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
          discountPercent: pct,
          note: note.text.trim(),
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
    final allowed = isOwner ||
        ref.watch(myPermissionsProvider).contains(WorkspacePermission.viewFinances);
    if (!on || !allowed || me == null || me.id == memberId) {
      return const SizedBox.shrink();
    }
    return ListTile(
      key: ValueKey('member-negotiation-$memberId'),
      leading: const Icon(Icons.handshake_outlined),
      title: Text(l10n?.negotiationProposeTitle ?? 'Price negotiation'),
      onTap: () => showPriceNegotiationSheet(
        context,
        ref,
        memberId: memberId,
        memberName: memberName,
        currency: moneyFormat(
          ref.read(currentWorkspaceProvider).value?.currencyCode ?? 'EUR',
        ),
      ),
    );
  }
}
