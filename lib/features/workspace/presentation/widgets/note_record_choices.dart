// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/domain/event_decision.dart';
import '../../../events/presentation/event_labels.dart';
import '../../../events/providers/event_providers.dart';
import '../../../money/domain/ledger_entry.dart';
import '../../../money/presentation/invoice_status.dart';
import '../../../money/providers/money_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../domain/member_note_refs.dart';
import '../../providers/workspace_providers.dart';
import '../reference_locale.dart';
import 'note_record_open.dart';
import 'ref_picker_sheet.dart';

/// What a record reference of one kind can point at.
///
/// Every choice carries TWO labels, and they are never interchangeable:
///
///   * [candidates] hold the one shown in the picker, written in the
///     reader's own language — it is read once and thrown away;
///   * [baked] holds the one written into the message, which #1179
///     settled is the WORKSPACE's language, because a reference label
///     is frozen at composition and every later reader gets it.
///
/// Extracted from the composer (#1179): building these lists is a
/// different job from editing a message, it is the half that grew, and
/// it is the half a test can reach without a text field.
typedef NoteRecordChoices = ({
  List<RefCandidate> candidates,
  Map<String, String> baked,
  // The dimensions the candidates can be filtered by, and how an amount
  // is written for the range filter (#2234).
  List<RefFacet> facets,
  String Function(int cents)? formatAmount,
});

/// Everything of [kind] this member may reference right now.
///
/// Reads providers and awaits, so the CALLER re-checks `mounted` before
/// using the result — this function has no widget to be disposed with.
Future<NoteRecordChoices> noteRecordChoices(
  WidgetRef ref,
  BuildContext context,
  NoteRecordKind kind,
) async {
  final l10n = AppLocalizations.of(context);
  final localeName = Localizations.maybeLocaleOf(context)?.toString();
  final bakedLocale = referenceLocale(ref, context);
  final bakedL10n = referenceL10n(ref, context);
  final candidates = <RefCandidate>[];
  final baked = <String, String>{};
  var facets = <RefFacet>[];
  String Function(int cents)? formatAmount;
  RefFacet facet(String key, String label, {bool quick = false}) =>
      RefFacet(key: key, label: label, quick: quick);
  RefFacetValue month(DateTime at) {
    final id = '${at.year}-${at.month.toString().padLeft(2, '0')}';
    return (id: id, label: id);
  }

  switch (kind) {
    case NoteRecordKind.alert:
    case NoteRecordKind.validation:
      final events = await ref.read(eventsProvider.future);
      final names = ref.read(memberNamesProvider).value ?? const <String, String>{};
      final decisions = ref.read(eventDecisionsProvider).value ?? const <String, List<EventDecision>>{};
      for (final event in events) {
        // A validation reference is about a decision: an event nobody
        // was ever asked about has no trail to point at.
        if (kind == NoteRecordKind.validation &&
            !event.isPending &&
            (decisions[event.id] ?? const []).isEmpty) {
          continue;
        }
        final who = names[event.subjectMemberId] ?? '';
        String label(AppLocalizations? strings, String? locale) {
          final when = DateFormat.MMMd(locale)
              .add_Hm()
              .format(event.createdAt.toLocal());
          return [eventTypeLabel(strings, event.type), who, when]
              .where((p) => p.isNotEmpty)
              .join(' · ');
        }

        baked[event.id] = label(bakedL10n, bakedLocale);
        final created = event.createdAt.toLocal();
        candidates.add(refCandidate(
          id: event.id,
          label: label(l10n, localeName),
          icon: noteRecordIcon(kind),
          extraKeywords: event.status.name,
          at: created,
          facets: {
            'status': event.isPending
                ? (id: 'pending', label: l10n?.refStatusPending ?? 'Pending')
                : (id: 'decided', label: l10n?.refStatusDecided ?? 'Decided'),
            'type': (
              id: event.type.name,
              label: eventTypeLabel(l10n, event.type),
            ),
            if (who.isNotEmpty)
              'person': (id: event.subjectMemberId, label: who),
            'month': month(created),
          },
        ));
      }
      facets = [
        facet('status', l10n?.refFacetStatus ?? 'Status', quick: true),
        facet('type', l10n?.refFacetType ?? 'Type'),
        facet('person', l10n?.refFacetPerson ?? 'Person'),
        facet('month', l10n?.refFacetMonth ?? 'Month'),
      ];
    case NoteRecordKind.invoice:
    case NoteRecordKind.refund:
      final invoices = await ref.read(invoicesProvider.future);
      final matches = ref.read(invoiceMatchesProvider).value ?? const {};
      final names = ref.read(memberNamesProvider).value ?? const <String, String>{};
      final moneyOf = moneyFormat(
          ref.read(currentWorkspaceProvider).value?.currencyCode ?? 'EUR');
      formatAmount = moneyOf.formatMinor;
      for (final invoice in invoices) {
        // A number, a name and a period: nothing here is translated, so
        // the two languages produce the same words.
        final label = <String>[
          invoice.number,
          names[invoice.memberId] ?? invoice.memberName,
          invoice.period ?? '',
        ].where((p) => p.isNotEmpty).join(' · ');
        baked[invoice.id] = label;
        // Where it stands: still owed, settled, refunded or cancelled —
        // the same derivation the archive and the open cards use.
        final standing = switch (invoiceLifecycleOf(invoice, matches[invoice.id])) {
          InvoiceLifecycle.open ||
          InvoiceLifecycle.awaitingValidation ||
          InvoiceLifecycle.partiallyPaid =>
            (id: 'open', label: l10n?.refStatusOpen ?? 'Open (unpaid)'),
          InvoiceLifecycle.paid ||
          InvoiceLifecycle.remainderCancelled =>
            (id: 'paid', label: l10n?.refStatusPaid ?? 'Paid'),
          InvoiceLifecycle.refunded =>
            (id: 'refunded', label: l10n?.refStatusRefunded ?? 'Refunded'),
          InvoiceLifecycle.erroneous =>
            (id: 'cancelled', label: l10n?.refStatusCancelled ?? 'Cancelled'),
        };
        final person = names[invoice.memberId] ?? invoice.memberName;
        candidates.add(refCandidate(
          id: invoice.id,
          label: label,
          detail: invoice.title.isEmpty ? null : invoice.title,
          icon: noteRecordIcon(kind),
          extraKeywords: standing.label,
          amountCents: invoice.totalCents,
          at: invoice.issuedAt,
          facets: {
            'status': standing,
            'type': invoice.isCreditNote
                ? (
                    id: 'credit_note',
                    label: l10n?.refTypeCreditNote ?? 'Credit note',
                  )
                : (id: 'invoice', label: l10n?.refTypeInvoice ?? 'Invoice'),
            if (person.isNotEmpty) 'person': (id: invoice.memberId, label: person),
            'month': invoice.period != null
                ? (id: invoice.period!, label: invoice.period!)
                : month(invoice.issuedAt),
          },
        ));
      }
      facets = [
        facet('status', l10n?.refFacetStatus ?? 'Status', quick: true),
        facet('person', l10n?.refFacetPerson ?? 'Person'),
        facet('month', l10n?.refFacetMonth ?? 'Month'),
        facet('type', l10n?.refFacetType ?? 'Type'),
      ];
    case NoteRecordKind.payment:
      final ledger = await ref.read(myLedgerProvider.future);
      final money = moneyFormat(
          ref.read(currentWorkspaceProvider).value?.currencyCode ?? 'EUR');
      final seen = <String>{};
      for (final entry in ledger) {
        if (entry.kind != LedgerKind.credit ||
            entry.category != LedgerCategory.payment) {
          continue;
        }
        // The reference names the MONTH: that is the page a payment
        // opens on, and two payments in one month share it.
        if (!seen.add(entry.period)) continue;
        String label(AppLocalizations? strings) =>
            '${strings?.noteRefPayment ?? 'Payment'} · '
            '${entry.period} · ${money.formatMinor(entry.amountCents)}';
        baked[entry.period] = label(bakedL10n);
        candidates.add(refCandidate(
          id: entry.period,
          label: label(l10n),
          detail: entry.description.isEmpty ? null : entry.description,
          icon: noteRecordIcon(kind),
          amountCents: entry.amountCents,
          at: entry.createdAt.toLocal(),
          facets: {'month': (id: entry.period, label: entry.period)},
        ));
      }
      formatAmount = money.formatMinor;
      facets = [facet('month', l10n?.refFacetMonth ?? 'Month', quick: true)];
  }
  return (
    candidates: candidates,
    baked: baked,
    facets: facets,
    formatAmount: formatAmount,
  );
}
