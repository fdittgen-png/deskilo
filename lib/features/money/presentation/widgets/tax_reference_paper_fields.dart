// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3852 -- the tax reference editor's form of a `document_paper` row: the
// usual paper of a country's documents (a choice of the version form) and the
// papers they may use, typed as `A4, Letter`; empty: both.
import 'package:deskilo_document_model/paper.dart';
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';

import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';

/// The papers the form offers as the usual one.
final List<String> paperWires = [for (final p in Paper.values) p.wire];

List<String> _papersOf(FormControllers fields) => [
  for (final p in fields.text('papers').split(','))
    if (p.trim().isNotEmpty) p.trim(),
];

/// The text of the papers field, from the version copied.
Map<String, String> documentPaperTexts(TaxValue? v) => {
  'papers': v is DocumentPaperValue ? (v.papers ?? const []).join(', ') : '',
};

/// The refusals of the form: papers the app prints on, each once, holding
/// the usual one.
FieldErrors documentPaperFieldErrors(
  AppLocalizations l10n,
  FormControllers fields,
  Map<String, String> choice,
) {
  final papers = _papersOf(fields);
  return {
    if (papers.isNotEmpty &&
        (papers.any((p) => Paper.fromWire(p) == null) ||
            papers.toSet().length != papers.length ||
            !papers.contains(choice['paper'])))
      'papers': l10n.taxRefInvalidPapers,
  };
}

/// The `document_paper` value the form stands for: A4 is what no paper
/// means, and no papers means both.
DocumentPaperValue documentPaperValueOf(
  FormControllers fields,
  Map<String, String> choice,
) => DocumentPaperValue(
  paper: choice['paper'] == Paper.a4.wire ? null : choice['paper'],
  papers: _papersOf(fields).isEmpty ? null : _papersOf(fields),
);
