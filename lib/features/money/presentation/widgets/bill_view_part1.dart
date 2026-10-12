// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'bill_view.dart';


/// #510 — the month's invoice as the member reads it: number, state
/// chip, total, what was paid and what remains. A NEGATIVE document is
/// a credit note (#508): the workspace owes the refund, the member owes
/// nothing.
class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.settlement, required this.money});

  final PeriodSettlement settlement;
  final String Function(int cents) money;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final invoice = settlement.invoice;
    final isCreditNote = invoice.totalCents < 0;
    final title = isCreditNote
        ? (l10n.billCreditNoteCard(invoice.number))
        : (l10n.billInvoiceCard(invoice.number));
    final paid = settlement.match != null && !settlement.match!.pending
        ? settlement.match!.paidCents
        : 0;
    return Card(
      key: const ValueKey('bill-invoice-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                InvoiceStatusChip(status: settlement.lifecycle),
              ],
            ),
            const SizedBox(height: 4),
            _BillLine(
              label: l10n.billInvoiceTotal,
              detail: DateFormat.yMMMd(
                Localizations.maybeLocaleOf(context)?.toString(),
              ).format(invoice.issuedAt.toLocal()),
              value: money(invoice.totalCents),
            ),
            if (paid != 0 &&
                settlement.lifecycle == InvoiceLifecycle.partiallyPaid) ...[
              _BillLine(
                label: l10n.billInvoicePaid,
                value: money(paid),
              ),
              _BillLine(
                label: l10n.billInvoiceRemaining,
                value: money(settlement.remainingCents),
                emphasized: true,
              ),
            ],
            if (isCreditNote) ...[
              const SizedBox(height: 4),
              Text(
                settlement.lifecycle == InvoiceLifecycle.refunded
                    ? (l10n.billCreditNoteRefunded)
                    : (l10n.billCreditNoteDue),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The workspace's payment instructions (#155): IBAN copies to the
/// clipboard, the PayPal.me link opens externally, the reference hint is
/// plain text. Purely informational — recording a payment stays the
/// separate spec §8 confirmation flow.
/// Public since #711 so the bank-scheme labelling can be tested on its
/// own; the bill composes it, nothing else constructs it.
class HowToPayCard extends ConsumerWidget {
  const HowToPayCard({super.key, required this.instructions, this.onPayOnline});

  final PaymentInstructions instructions;

  /// When non-null, a "Pay online" button heads the card (0043).
  final VoidCallback? onPayOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final paypalUri = instructions.paypalMeUri;
    // (field, icon, brand label) of the #192 copy-to-clipboard methods —
    // one data row per method instead of three pasted tiles.
    final copyMethods = [
      (
        'Wero',
        instructions.wero.trim(),
        Icons.smartphone_outlined,
        l10n.paymentMethodWero,
      ),
      (
        'Lydia',
        instructions.lydia.trim(),
        Icons.smartphone_outlined,
        l10n.paymentMethodLydia,
      ),
      (
        'Wise',
        instructions.wise.trim(),
        Icons.alternate_email,
        l10n.paymentMethodWise,
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                l10n.paymentInstructionsTitle,
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
                  label: Text(l10n.payOnlineButton),
                ),
              ),
            // #711 — bank details for countries without IBAN, labelled
            // by the workspace's banking scheme.
            BankDetailTiles(instructions: instructions),
            if (instructions.iban.trim().isNotEmpty)
              CopyTile(
                key: const Key('howToPayIban'),
                icon: Icons.account_balance_outlined,
                // IBAN is a language-neutral banking acronym — the key
                // carries it verbatim in every locale.
                title: l10n.paymentInstructionsIbanTitle,
                value: instructions.iban.trim(),
                copiedMessage:
                    l10n.paymentInstructionsIbanCopied,
              ),
            if (paypalUri != null)
              ListTile(
                key: const Key('howToPayPaypal'),
                leading: const Icon(Icons.open_in_new),
                // Brand name — reuses the #154 method label key.
                title: Text(l10n.paymentMethodPaypal),
                subtitle: Text(paypalUri.toString()),
                // Launch failures are traced inside the shared link seam.
                onTap: () => ref.read(linkLauncherProvider)(paypalUri),
              ),
            // #192 — Wero / Lydia / Wise: phone number, phone/username,
            // Wisetag or link. All copy to the clipboard like the IBAN;
            // the titles reuse the #154 method labels (brand names).
            for (final (keySuffix, value, icon, title) in copyMethods)
              if (value.isNotEmpty)
                CopyTile(
                  key: Key('howToPay$keySuffix'),
                  icon: icon,
                  title: title,
                  value: value,
                  copiedMessage: l10n.paymentInstructionsValueCopied,
                ),
            if (instructions.reference.trim().isNotEmpty)
              ListTile(
                key: const Key('howToPayReference'),
                leading: const Icon(Icons.tag_outlined),
                title: Text(
                  l10n.paymentInstructionsReferenceLabel,
                ),
                subtitle: Text(instructions.reference.trim()),
              ),
          ],
        ),
      ),
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
    final l10n = context.l10n;
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

    final usedLabel = l10n.entitlementDaysUsed(days(used), days(cap));
    final leftLabel =
        l10n.entitlementDaysLeft(days(statement.remainingHalfDays));

    // Policy-aware footer, precomputed to a plain string (keeps the
    // no-hardcoded-strings lint happy — no interpolation inside Text()).
    String? footer;
    switch (statement.overagePolicy) {
      case OveragePolicy.payg:
        // The band overage rate is per half-day; a whole extra day is two.
        final perDay = money(statement.overageRateCents * 2);
        footer = l10n.entitlementPaygRate(perDay);
      case OveragePolicy.blocked:
        if (statement.isCapReached) {
          footer = l10n.entitlementBlockedFull;
        }
      case OveragePolicy.package:
        if (statement.isCapReached) {
          footer = l10n.entitlementPackageFull;
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
              l10n.entitlementTitle,
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
                Expanded(child: Text(
                  leftLabel,
                  style: theme.bodyMedium?.copyWith(color: barColor),
                )),
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
  const _SubscriptionCard({
    required this.statement,
    required this.money,
    required this.association,
  });

  final bool association;

  final Statement statement;
  final String Function(int cents) money;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BillLine(
              label: subscriptionLabel(reportStringsOf(l10n), statement.subscriptionPct,
                  association: association,
                  month: monthNameOf(l10n.localeName, statement.period)),
              value: '−${money(statement.feeCents)}',
              emphasized: true,
            ),
            _BillLine(
              label: l10n.billEntitlement(
                    statement.usedHalfDays,
                    statement.includedHalfDays,
                    statement.openDays,
                  ),
              value: '',
            ),
            if (statement.extraHalfDays > 0)
              _BillLine(
                label: l10n.billOverage(statement.extraHalfDays),
                value: '−${money(statement.overageCents)}',
              ),
            // #170 — priced seat accessories per booked half-day; the
            // server only emits a non-zero amount while the owner has the
            // accessorySupplements feature on.
            if (statement.accessorySupplementCents > 0)
              _BillLine(
                label: l10n.billAccessorySupplements,
                value: '−${money(statement.accessorySupplementCents)}',
              ),
            // 0050 — whole-level reservations priced per half-day.
            if (statement.levelSupplementCents > 0)
              _BillLine(
                label: l10n.levelSupplementLabel,
                value: '−${money(statement.levelSupplementCents)}',
              ),
            // 0057 — whole-office reservations priced per half-day.
            if (statement.officeSupplementCents > 0)
              _BillLine(
                label: l10n.officeSupplementLabel,
                value: '−${money(statement.officeSupplementCents)}',
              ),
            // 0059 — whole-desk reservations priced per half-day.
            if (statement.deskSupplementCents > 0)
              _BillLine(
                label: l10n.deskSupplementLabel,
                value: '−${money(statement.deskSupplementCents)}',
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
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.billServices,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            for (final entry in sections.serviceEntries)
              _BillLine(
                label: entry.description.isEmpty
                    ? (l10n.ledgerCategoryService)
                    : entry.description,
                value: '−${money(entry.amountCents)}',
              ),
            const Divider(),
            _BillLine(
              label: l10n.billServicesTotal,
              value: '−${money(sections.servicesTotalCents)}',
              emphasized: true,
            ),
          ],
        ),
      ),
    );
  }
}
