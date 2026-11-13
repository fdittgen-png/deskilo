// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3813 (part of #3657, i18n I11e) -- a lease settlement's texts, printed
// from the facts the server froze with them (0744) in the reader's language:
// a term's period, a schedule's supplier. What this reader cannot read (no
// facts, an unknown kind or version, unreadable values) prints the stored
// text, never an empty or invented one.
import '../../../l10n/app_localizations.dart';
import '../domain/expense_schedule.dart';
import '../domain/premises_lease.dart';

/// [term]'s label, from its facts when it has readable ones.
String leaseTermLabel(
  AppLocalizations l10n,
  String Function(DateTime day) dates,
  LeaseTerm term,
) => _factsText(l10n, dates, term.textFacts) ?? term.label;

/// [schedule]'s title, from its facts when it has readable ones.
String scheduleTitle(
  AppLocalizations l10n,
  String Function(DateTime day) dates,
  ExpenseSchedule schedule,
) => _factsText(l10n, dates, schedule.textFacts) ?? schedule.title;

String? _factsText(
  AppLocalizations l10n,
  String Function(DateTime day) dates,
  Map<String, Object?>? facts,
) {
  if (facts == null || facts['version'] != 1) return null;
  final values = facts['values'];
  if (values is! Map) return null;
  switch (facts['kind']) {
    case 'settlement_period':
      final from = DateTime.tryParse('${values['from']}');
      final to = DateTime.tryParse('${values['to']}');
      if (from == null || to == null) return null;
      return l10n.leaseSettlementPeriod(dates(from), dates(to));
    case 'service_charge_settlement':
      final supplier = values['supplier'];
      if (supplier is! String) return null;
      return l10n.serviceChargeSettlementOf(supplier);
  }
  return null;
}
