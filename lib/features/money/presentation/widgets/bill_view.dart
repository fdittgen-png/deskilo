// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/domain/workspace_event.dart';
import '../../../workspace/domain/overage_policy.dart';
import '../../../workspace/domain/payment_instructions.dart';
import '../../domain/bill_sections.dart';
import '../../domain/ledger_entry.dart';
import '../../domain/statement.dart';

/// The structured monthly bill (#132, ADR 0008): subscription, consumed
/// services, open positions awaiting validation, payments & credits, and
/// the balance footer. Grouping lives in [buildBillSections] so the PDF
/// export renders the exact same sections.
class BillView extends StatelessWidget {
  const BillView({
    super.key,
    required this.statement,
    required this.ledger,
    required this.pendingMoneyEvents,
    required this.currencyCode,
    required this.memberId,
    this.paymentInstructions = const PaymentInstructions(),
    this.onlinePaymentsEnabled = false,
    this.onPayOnline,
  });

  final Statement statement;
  final List<LedgerEntry> ledger;
  final List<WorkspaceEvent> pendingMoneyEvents;
  final String currencyCode;
  final String memberId;

  /// #155 — the workspace's how-to-pay details; rendered below the
  /// balance footer only while the statement is outstanding.
  final PaymentInstructions paymentInstructions;

  /// Whether the workspace enabled online payments (0043 scaffolding). When
  /// true and the statement is outstanding, the how-to-pay card shows a
  /// "Pay online" button that calls [onPayOnline] with the owed amount.
  final bool onlinePaymentsEnabled;

  /// Called with the outstanding amount in cents when the member taps the
  /// online-payment button. Owned by the Money screen (it has the ref to
  /// start the provider order and open the approval URL).
  final void Function(int amountCents)? onPayOnline;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(name: currencyCode);
    String money(int cents) => currency.format(cents / 100);

    final sections = buildBillSections(
      period: statement.period,
      memberId: memberId,
      ledger: ledger,
      pendingEvents: pendingMoneyEvents,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // At-a-glance usage for the current month (days included, used and
        // left) — the member's answer to "how much can I still book?".
        _EntitlementCard(statement: statement, money: money),
        const SizedBox(height: 8),
        _SubscriptionCard(statement: statement, money: money),
        if (sections.serviceEntries.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ServicesCard(sections: sections, money: money),
        ],
        if (sections.packageEntries.isNotEmpty) ...[
          const SizedBox(height: 8),
          _PackagesCard(entries: sections.packageEntries, money: money),
        ],
        if (sections.openPositions.isNotEmpty) ...[
          const SizedBox(height: 8),
          _OpenPositionsCard(positions: sections.openPositions, money: money),
        ],
        if (sections.creditEntries.isNotEmpty) ...[
          const SizedBox(height: 8),
          _CreditsCard(entries: sections.creditEntries, money: money),
        ],
        const SizedBox(height: 8),
        _BalanceFooter(statement: statement, money: money),
        // #155 — how to pay, only while something is owed (spec §7:
        // "shown on unpaid statements") and only when the owner configured
        // manual instructions or enabled online payments.
        if (!statement.isSettled &&
            (!paymentInstructions.isEmpty ||
                (onlinePaymentsEnabled && onPayOnline != null))) ...[
          const SizedBox(height: 8),
          _HowToPayCard(
            instructions: paymentInstructions,
            onPayOnline: onlinePaymentsEnabled && onPayOnline != null
                ? () => onPayOnline!(-statement.balanceCents)
                : null,
          ),
        ],
      ],
    );
  }
}

/// The workspace's payment instructions (#155): IBAN copies to the
/// clipboard, the PayPal.me link opens externally, the reference hint is
/// plain text. Purely informational — recording a payment stays the
/// separate spec §8 confirmation flow.
class _HowToPayCard extends StatelessWidget {
  const _HowToPayCard({required this.instructions, this.onPayOnline});

  final PaymentInstructions instructions;

  /// When non-null, a "Pay online" button heads the card (0043).
  final VoidCallback? onPayOnline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final paypalUri = instructions.paypalMeUri;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                l10n?.paymentInstructionsTitle ?? 'Payment instructions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (onPayOnline != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: FilledButton.icon(
                  key: const Key('pay-online-button'),
                  onPressed: onPayOnline,
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: Text(l10n?.payOnlineButton ?? 'Pay online with PayPal'),
                ),
              ),
            if (instructions.iban.trim().isNotEmpty)
              _CopyTile(
                key: const Key('howToPayIban'),
                icon: Icons.account_balance_outlined,
                // IBAN is a language-neutral banking acronym — the key
                // carries it verbatim in every locale.
                title: l10n?.paymentInstructionsIbanTitle ?? 'IBAN',
                value: instructions.iban.trim(),
                copiedMessage:
                    l10n?.paymentInstructionsIbanCopied ?? 'IBAN copied.',
              ),
            if (paypalUri != null)
              ListTile(
                key: const Key('howToPayPaypal'),
                leading: const Icon(Icons.open_in_new),
                // Brand name — reuses the #154 method label key.
                title: Text(l10n?.paymentMethodPaypal ?? 'PayPal'),
                subtitle: Text(paypalUri.toString()),
                onTap: () async {
                  try {
                    await launchUrl(
                      paypalUri,
                      mode: LaunchMode.externalApplication,
                    );
                  } catch (e, st) {
                    debugPrint('paypal launch failed: $e\n$st');
                    TraceLogger.instance.error(
                        'money', 'paypal launch failed',
                        error: e, stackTrace: st);
                  }
                },
              ),
            // #192 — Wero / Lydia / Wise: phone number, phone/username,
            // Wisetag or link. All copy to the clipboard like the IBAN;
            // the titles reuse the #154 method labels (brand names).
            if (instructions.wero.trim().isNotEmpty)
              _CopyTile(
                key: const Key('howToPayWero'),
                icon: Icons.smartphone_outlined,
                title: l10n?.paymentMethodWero ?? 'Wero',
                value: instructions.wero.trim(),
                copiedMessage: l10n?.paymentInstructionsValueCopied ??
                    'Copied to clipboard.',
              ),
            if (instructions.lydia.trim().isNotEmpty)
              _CopyTile(
                key: const Key('howToPayLydia'),
                icon: Icons.smartphone_outlined,
                title: l10n?.paymentMethodLydia ?? 'Lydia',
                value: instructions.lydia.trim(),
                copiedMessage: l10n?.paymentInstructionsValueCopied ??
                    'Copied to clipboard.',
              ),
            if (instructions.wise.trim().isNotEmpty)
              _CopyTile(
                key: const Key('howToPayWise'),
                icon: Icons.alternate_email,
                title: l10n?.paymentMethodWise ?? 'Wise',
                value: instructions.wise.trim(),
                copiedMessage: l10n?.paymentInstructionsValueCopied ??
                    'Copied to clipboard.',
              ),
            if (instructions.reference.trim().isNotEmpty)
              ListTile(
                key: const Key('howToPayReference'),
                leading: const Icon(Icons.tag_outlined),
                title: Text(
                  l10n?.paymentInstructionsReferenceLabel ??
                      'Payment reference hint',
                ),
                subtitle: Text(instructions.reference.trim()),
              ),
          ],
        ),
      ),
    );
  }
}

/// A how-to-pay row whose value copies to the clipboard on tap (#155
/// IBAN pattern, shared with the #192 Wero/Lydia/Wise rows).
class _CopyTile extends StatelessWidget {
  const _CopyTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.copiedMessage,
  });

  final IconData icon;
  final String title;
  final String value;
  final String copiedMessage;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
      trailing: const Icon(Icons.copy_outlined, size: 18),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: value));
        if (!context.mounted) return;
        AppSnack.success(context, copiedMessage);
      },
    );
  }
}

/// The prominent "this month" usage card: the days included in the
/// subscription, how many are used, and how many are left — plus a
/// policy-aware footer (pay-as-you-go rate, or a full-cap hint). Days are
/// half-days ÷ 2, so a single booked morning reads as 0.5 days.
class _EntitlementCard extends StatelessWidget {
  const _EntitlementCard({required this.statement, required this.money});

  final Statement statement;
  final String Function(int cents) money;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    final fmt = NumberFormat.decimalPattern(locale)..maximumFractionDigits = 1;
    String days(int halfDays) => fmt.format(halfDays / 2);

    final cap = statement.capHalfDays;
    final used = statement.usedHalfDays;
    final overCap = used > cap;
    final progress = cap <= 0
        ? (used > 0 ? 1.0 : 0.0)
        : (used / cap).clamp(0.0, 1.0);
    final barColor = overCap ? scheme.error : scheme.primary;

    final usedLabel = l10n?.entitlementDaysUsed(days(used), days(cap)) ??
        '${days(used)} of ${days(cap)} days used';
    final leftLabel =
        l10n?.entitlementDaysLeft(days(statement.remainingHalfDays)) ??
            '${days(statement.remainingHalfDays)} days left';

    // Policy-aware footer, precomputed to a plain string (keeps the
    // no-hardcoded-strings lint happy — no interpolation inside Text()).
    String? footer;
    switch (statement.overagePolicy) {
      case OveragePolicy.payg:
        // The band overage rate is per half-day; a whole extra day is two.
        final perDay = money(statement.overageRateCents * 2);
        footer = l10n?.entitlementPaygRate(perDay) ??
            'Extra days beyond your plan bill at $perDay each.';
      case OveragePolicy.blocked:
        if (statement.isCapReached) {
          footer = l10n?.entitlementBlockedFull ??
              "You've used all your days this month. Ask an admin for "
                  'more or request extra half-days below.';
        }
      case OveragePolicy.package:
        if (statement.isCapReached) {
          footer = l10n?.entitlementPackageFull ??
              "You've used all your days this month. Buy a package to "
                  'keep booking.';
        }
    }

    return Card(
      key: const Key('entitlement-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.entitlementTitle ?? 'This month',
              style: theme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    usedLabel,
                    style: theme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  leftLabel,
                  style: theme.bodyMedium?.copyWith(color: barColor),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: AppRadius.smAll,
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
                color: barColor,
              ),
            ),
            if (footer != null) ...[
              const SizedBox(height: 10),
              Text(
                footer,
                style: theme.bodySmall?.copyWith(
                  color: overCap ? scheme.error : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.statement, required this.money});

  final Statement statement;
  final String Function(int cents) money;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BillLine(
              label: l10n?.billSubscription(statement.subscriptionPct) ??
                  'Subscription ${statement.subscriptionPct}%',
              value: '−${money(statement.feeCents)}',
              emphasized: true,
            ),
            _BillLine(
              label: l10n?.billEntitlement(
                    statement.usedHalfDays,
                    statement.includedHalfDays,
                    statement.openDays,
                  ) ??
                  '${statement.usedHalfDays} of '
                      '${statement.includedHalfDays} half-days used '
                      '(${statement.openDays} open days)',
              value: '',
            ),
            if (statement.extraHalfDays > 0)
              _BillLine(
                label: l10n?.billOverage(statement.extraHalfDays) ??
                    '${statement.extraHalfDays} extra half-days',
                value: '−${money(statement.overageCents)}',
              ),
            // #170 — priced seat accessories per booked half-day; the
            // server only emits a non-zero amount while the owner has the
            // accessorySupplements feature on.
            if (statement.accessorySupplementCents > 0)
              _BillLine(
                label: l10n?.billAccessorySupplements ??
                    'Accessory supplements',
                value: '−${money(statement.accessorySupplementCents)}',
              ),
          ],
        ),
      ),
    );
  }
}

class _ServicesCard extends StatelessWidget {
  const _ServicesCard({required this.sections, required this.money});

  final BillSections sections;
  final String Function(int cents) money;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.billServices ?? 'Consumed services',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            for (final entry in sections.serviceEntries)
              _BillLine(
                label: entry.description.isEmpty
                    ? (l10n?.ledgerCategoryService ?? 'Service')
                    : entry.description,
                value: '−${money(entry.amountCents)}',
              ),
            const Divider(),
            _BillLine(
              label: l10n?.billServicesTotal ?? 'Services total',
              value: '−${money(sections.servicesTotalCents)}',
              emphasized: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _PackagesCard extends StatelessWidget {
  const _PackagesCard({required this.entries, required this.money});

  final List<LedgerEntry> entries;
  final String Function(int cents) money;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      key: const Key('packages-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.billPackages ?? 'Day packages',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            for (final entry in entries)
              _BillLine(
                label: entry.description.isEmpty
                    ? (l10n?.billPackages ?? 'Day packages')
                    : entry.description,
                value: '−${money(entry.amountCents)}',
              ),
          ],
        ),
      ),
    );
  }
}

class _OpenPositionsCard extends StatelessWidget {
  const _OpenPositionsCard({required this.positions, required this.money});

  final List<OpenPosition> positions;
  final String Function(int cents) money;

  String _label(AppLocalizations? l10n, WorkspaceEvent event) {
    switch (event.type) {
      case EventType.serviceCharge:
        final name = event.payload['name'] as String? ?? '';
        final quantity = (event.payload['quantity'] as num?)?.toInt() ?? 0;
        return '$name ×$quantity';
      case EventType.payment:
        return l10n?.eventTypePayment ?? 'Payment';
      case EventType.expense:
        return l10n?.eventTypeExpense ?? 'Expense';
      case EventType.quota:
        return l10n?.eventTypeQuota ?? 'Extra half-days';
      case EventType.roleChange:
      case EventType.reservation:
      case EventType.adjustment:
        return l10n?.eventTypeAdjustment ?? 'Adjustment';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final pendingColor = Colors.amber.shade800;
    return Card(
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: pendingColor),
        borderRadius: AppRadius.lgAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n?.billOpenPositions ?? 'Open positions',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: pendingColor),
                  ),
                ),
                Chip(
                  label: Text(
                    l10n?.billPendingBadge ?? 'pending validation',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: pendingColor),
                  ),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: pendingColor),
                  backgroundColor: scheme.surface,
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final position in positions)
              _BillLine(
                label: _label(l10n, position.event),
                value: position.isCredit
                    ? '+${money(position.amountCents)}'
                    : '−${money(position.amountCents)}',
              ),
          ],
        ),
      ),
    );
  }
}

class _CreditsCard extends StatelessWidget {
  const _CreditsCard({required this.entries, required this.money});

  final List<LedgerEntry> entries;
  final String Function(int cents) money;

  String _label(AppLocalizations? l10n, LedgerEntry entry) {
    return switch (entry.category) {
      LedgerCategory.expense =>
        l10n?.ledgerCategoryExpense ?? 'Expense reimbursement',
      LedgerCategory.adjustment =>
        l10n?.ledgerCategoryAdjustment ?? 'Adjustment',
      _ => l10n?.ledgerCategoryPayment ?? 'Payment',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.billPaymentsCredits ?? 'Payments & credits',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            for (final entry in entries)
              _BillLine(
                label: entry.description.isEmpty
                    ? _label(l10n, entry)
                    : entry.description,
                detail: DateFormat.yMMMd(
                  Localizations.maybeLocaleOf(context)?.toString(),
                ).format(entry.createdAt.toLocal()),
                value: '+${money(entry.amountCents)}',
              ),
          ],
        ),
      ),
    );
  }
}

class _BalanceFooter extends StatelessWidget {
  const _BalanceFooter({required this.statement, required this.money});

  final Statement statement;
  final String Function(int cents) money;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final color = statement.isSettled ? scheme.primary : scheme.error;
    final style = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.bold, color: color);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(l10n?.billBalance ?? 'Balance', style: style),
            ),
            Chip(
              label: Text(
                statement.isSettled
                    ? (l10n?.billSettled ?? 'Settled')
                    : (l10n?.billOutstanding ?? 'Outstanding'),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: color),
              ),
              visualDensity: VisualDensity.compact,
              side: BorderSide(color: color),
            ),
            const SizedBox(width: 12),
            Text(money(statement.balanceCents), style: style),
          ],
        ),
      ),
    );
  }
}

class _BillLine extends StatelessWidget {
  const _BillLine({
    required this.label,
    required this.value,
    this.detail,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final String? detail;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final style = emphasized ? theme.titleSmall : theme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: style),
                if (detail != null)
                  Text(detail!, style: theme.bodySmall),
              ],
            ),
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}
