// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The procedures document of a Swiss fiscal-year archive (GeBüV art. 4):
// the sections every procedures document states from the live facts of the
// space, then what the record-keeping ordinance asks the interface to
// evidence: integrity (art. 3 and 9), access (art. 8), availability and
// carriers (art. 5 and 10). In the language of the person who exports it.
import '../../../l10n/app_localizations.dart';
import 'gobd_procedure_document.dart';

/// The procedures document of [f] in [l10n]'s language.
String buildSwissProcedureDocument(
  AppLocalizations l10n,
  GobdProcedureFacts f,
) {
  final lines = <String>[
    ...procedureSections(
      l10n,
      f,
      title: l10n.gebuevProcedureTitle(f.workspace),
      systemBody: l10n.gebuevProcedureSystemBody,
    ),
    '## ${l10n.gebuevProcedureIntegrityHeading}',
    '',
    l10n.gebuevProcedureIntegrityBody,
    '',
    '## ${l10n.gebuevProcedureAccessHeading}',
    '',
    l10n.gebuevProcedureAccessBody,
    '',
    '## ${l10n.gebuevProcedureCarriersHeading}',
    '',
    l10n.gebuevProcedureCarriersBody,
  ];
  return '${lines.join('\n')}\n';
}
