// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3380 — the words of a SAF-T refusal. A Polish gap is structured data
// (code, field, subject, limit); every sentence comes from the ARB catalogue,
// so no English clause reaches a translated message.
import '../../../l10n/app_localizations.dart';
import '../domain/saf_t_financial.dart';

/// One refusal reason of [gap], in the language of [l10n].
String safTGapText(AppLocalizations l10n, SafTGap gap) {
  final polish = gap.polish;
  if (polish == null) return l10n.saftGap(gap.kind.name, gap.subject);
  final field = polish.field;
  return l10n.jpkKrPdGap(
    polish.code.name,
    field == null ? '' : l10n.jpkKrPdField(field.name),
    polish.subject.isEmpty ? '' : ' (${polish.subject})',
    '${polish.limit}',
  );
}
