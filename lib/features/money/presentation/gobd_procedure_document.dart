// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Verfahrensdokumentation that travels in the GoBD package, and the
// words of a refused DATEV export. The document is generated from the live
// facts of the space (the server's schema version, its number sequences,
// its country's retention clocks), in the language of the person who
// exports it, as Markdown an auditor reads in any editor.
import 'package:intl/intl.dart';

import '../../../core/instance/schema_compatibility.dart';
import '../../../core/vat/retention.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/datev_problem.dart';
import '../domain/number_sequence.dart';
import 'widgets/retention_clocks_tile.dart';

/// The Verfahrensdokumentation's file name in the package.
const String gobdProcedureFileName = 'verfahrensdokumentation.md';

/// The facts the Verfahrensdokumentation states.
typedef GobdProcedureFacts = ({
  String workspace,
  String country,
  DateTime from,
  DateTime to,
  DateTime generatedAt,
  DateTime? fiscalYearStart,

  /// The server's schema version; null when it could not be read.
  int? serverSchema,
  List<NumberSequence> sequences,
});

/// The Verfahrensdokumentation of [f] in [l10n]'s language.
String buildGobdProcedureDocument(AppLocalizations l10n, GobdProcedureFacts f) {
  final day = DateFormat.yMd(l10n.localeName);
  final serverSchema = f.serverSchema;
  final lines = <String>[
    '# ${l10n.gobdProcedureTitle(f.workspace)}',
    '',
    l10n.gobdProcedureGenerated(
      day.format(f.generatedAt),
      day.format(f.from),
      day.format(f.to),
    ),
    '',
    '## ${l10n.gobdProcedureSystemHeading}',
    '',
    l10n.gobdProcedureSystemBody,
    '',
    '## ${l10n.gobdProcedureVersionHeading}',
    '',
    '- ${serverSchema == null ? l10n.gobdProcedureSchemaUnknown : l10n.gobdProcedureSchemaLive('$serverSchema')}',
    '- ${l10n.gobdProcedureSchemaApp('$requiredSchemaVersion')}',
    '',
    '## ${l10n.gobdProcedureImmutableHeading}',
    '',
    l10n.gobdProcedureImmutableBody,
    '',
    '## ${l10n.numberSequencesTitle}',
    '',
    l10n.numberSequencesIntro,
    '',
    for (final s in f.sequences) '- ${_sequence(l10n, s)}',
    '',
    '## ${l10n.retentionTitle}',
    '',
    for (final r in retentionRules(f.country))
      '- ${retentionClassName(l10n, r.docClass)}: '
          '${retentionRuleText(l10n, r)}; '
          '${l10n.gobdProcedureRetentionUntil(day.format(retentionRuleUntil(r, f.to, fiscalYearStart: f.fiscalYearStart)))}'
          '${r.confirmed ? '' : ' (${l10n.retentionUnconfirmed})'}. '
          '${r.source}',
    '',
    '## ${l10n.gobdProcedureHandoverHeading}',
    '',
    l10n.gobdProcedureHandoverBody,
    '',
    '## ${l10n.gobdProcedureExportsHeading}',
    '',
    l10n.gobdProcedureExportsBody,
  ];
  return '${lines.join('\n')}\n';
}

String _sequence(AppLocalizations l10n, NumberSequence s) {
  final journal = switch (s.journal) {
    'credit_note' => l10n.numberSequenceJournalCreditNote,
    'vat_declaration' => l10n.numberSequenceJournalVatDeclaration,
    'member' => l10n.numberSequenceJournalMember,
    'payment' => l10n.numberSequenceJournalPayment,
    'invoice' => l10n.numberSequenceJournalInvoice,
    _ => s.journal,
  };
  final datePart = switch (s.datePart) {
    NumberDatePart.none => l10n.numberSequenceDateNone,
    NumberDatePart.year => l10n.numberSequenceDateYear,
    NumberDatePart.yearMonth => l10n.numberSequenceDateYearMonth,
  };
  final reset = switch (s.reset) {
    NumberReset.never => l10n.numberSequenceResetNever,
    NumberReset.yearly => l10n.numberSequenceResetYearly,
    NumberReset.monthly => l10n.numberSequenceResetMonthly,
  };
  return [
    '$journal — ${l10n.numberSequencePrefix}: «${s.prefix}»',
    '${l10n.numberSequenceSuffix}: «${s.suffix}»',
    '${l10n.numberSequenceDatePart}: $datePart',
    '${l10n.numberSequenceDigits}: ${s.digits}',
    '${l10n.numberSequenceReset}: $reset',
    '${l10n.numberSequenceNext}: ${s.nextValue}',
  ].join(' · ');
}

/// Why a DATEV export was refused, in words, one problem per clause.
String datevProblemsText(AppLocalizations l10n, List<DatevProblem> problems) {
  final rate = NumberFormat.decimalPattern(l10n.localeName);
  return problems
      .map(
        (p) => switch (p) {
          DatevConsultantNumber(:final given) => l10n.datevProblemConsultant(
            given,
          ),
          DatevClientNumber(:final given) => l10n.datevProblemClient(given),
          DatevAccountLength(:final account, :final length) =>
            l10n.datevProblemAccountLength(account, '$length'),
          DatevMemberNumber(:final member, :final number) =>
            l10n.datevProblemMemberNumber(member, number),
          DatevDebtorClash(:final account, :final members) =>
            l10n.datevProblemDebtorClash(members.join(', '), account),
          DatevTaxKeyMissing(:final percent, :final account) =>
            l10n.datevProblemTaxKey(rate.format(percent), account),
          DatevAutomaticClash(:final percent, :final account) =>
            l10n.datevProblemAutomatic(rate.format(percent), account),
        },
      )
      .join('; ');
}
