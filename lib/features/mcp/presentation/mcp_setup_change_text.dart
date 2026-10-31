// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What an assistant's setup write changes, in the words of the screens that
// make the same change: the opening days and hours, the closure days, a
// number series. The person confirms exactly the server's proposal: every
// field it changes, from its current value to the new one.
import 'package:intl/intl.dart';

import '../../../core/i18n/app_format.dart';
import '../../../l10n/app_localizations.dart';

class McpSetupChangeText {
  const McpSetupChangeText(this._l10n, this._format);

  final AppLocalizations _l10n;
  final AppFormat _format;

  /// What the change is about, or null for a target of another kind.
  String? subject(Map<String, Object?> target) => switch (target['kind']) {
    'workspace_basics' => _l10n.setupStepTitle('basics'),
    'opening_hours' => _l10n.availabilityWorkHoursTitle,
    'closure_days' => [
      if (target['days'] case final List<Object?> days)
        for (final day in days)
          if (DateTime.tryParse('$day') case final date?)
            // A calendar day, not an instant: no zone to convert.
            DateFormat.yMMMd(_format.locale).format(date),
    ].join(', '),
    'number_sequence' => _journal('${target['journal']}'),
    _ => null,
  };

  /// What it changes, one line per field, or null for another kind.
  String? change(Map<String, Object?> target) => switch (target['kind']) {
    'workspace_basics' || 'opening_hours' || 'number_sequence' => [
      if (target['changes'] case final List<Object?> changes)
        for (final c in changes.whereType<Map<Object?, Object?>>())
          _l10n.mcpConfirmFieldChange(
            _field('${c['field']}'),
            _value('${c['field']}', c['from']),
            _value('${c['field']}', c['to']),
          ),
    ].join('\n'),
    'closure_days' =>
      '${target['reason'] ?? ''}'.isEmpty
          ? ''
          : _l10n.mcpConfirmClosureReason('${target['reason']}'),
    _ => null,
  };

  String _field(String field) => switch (field) {
    'timezone' => _l10n.workspaceTimezoneLabel,
    'default_locale' => _l10n.languageTitle,
    'address' => _l10n.workspaceAddressLabel,
    'open_weekdays' => _l10n.availabilityOpenWeekdays,
    'work_start_minutes' => _l10n.availabilityWorkStart,
    'half_boundary_minutes' => _l10n.availabilityHalfBoundary,
    'work_end_minutes' => _l10n.availabilityWorkEnd,
    'prefix' => _l10n.numberSequencePrefix,
    'suffix' => _l10n.numberSequenceSuffix,
    'date_part' => _l10n.numberSequenceDatePart,
    'digits' => _l10n.numberSequenceDigits,
    'reset' => _l10n.numberSequenceReset,
    'next_value' => _l10n.numberSequenceNext,
    _ => field,
  };

  String _value(String field, Object? value) => switch (field) {
    'open_weekdays' => [
      if (value is List)
        for (final d in value.whereType<num>())
          // 1 January 2024 was a Monday: ISO weekday d is the d-th.
          DateFormat.E(_format.locale).format(DateTime(2024, 1, d.toInt())),
    ].join(', '),
    'work_start_minutes' || 'half_boundary_minutes' || 'work_end_minutes'
        when value is num =>
      _format.wallTime(DateTime(2024, 1, 1, 0, value.toInt())),
    'date_part' => switch (value) {
      'year' => _l10n.numberSequenceDateYear,
      'year_month' => _l10n.numberSequenceDateYearMonth,
      _ => _l10n.numberSequenceDateNone,
    },
    'reset' => switch (value) {
      'yearly' => _l10n.numberSequenceResetYearly,
      'monthly' => _l10n.numberSequenceResetMonthly,
      _ => _l10n.numberSequenceResetNever,
    },
    'timezone' || 'default_locale' || 'address'
        when '${value ?? ''}'.isEmpty =>
      '—',
    _ when '${value ?? ''}'.isEmpty => _l10n.numberSequenceDateNone,
    _ => '$value',
  };

  String _journal(String journal) => switch (journal) {
    'credit_note' => _l10n.numberSequenceJournalCreditNote,
    'vat_declaration' => _l10n.numberSequenceJournalVatDeclaration,
    'member' => _l10n.numberSequenceJournalMember,
    'payment' => _l10n.numberSequenceJournalPayment,
    _ => _l10n.numberSequenceJournalInvoice,
  };
}
