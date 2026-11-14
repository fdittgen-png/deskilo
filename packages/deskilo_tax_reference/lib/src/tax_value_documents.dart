// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The values of the rows that say how a country's documents are made: the
// languages they are written in (#3850) and the papers they are printed on
// (#3852).
part of 'tax_value.dart';

/// #3850 -- `document_language` (key `document`, the seller's country): its official [languages]
/// (ISO 639-1), usual first; whether an invoice may be in its customer's language; and the
/// language a subdivision (ISO 3166-2 without the country) requires.
class DocumentLanguageValue extends TaxValue {
  const DocumentLanguageValue({required this.languages, required this.customerLanguage, this.requiredBySubdivision = const {}});
  DocumentLanguageValue.read(JsonReader r) : this(languages: r.strings('languages'), customerLanguage: r.boolOr('customer_language', fallback: false),
      requiredBySubdivision: {for (final e in r.objectOrEmpty('required_by_subdivision').entries) if (e.value case final String l) e.key: l});
  final List<String> languages;
  final bool customerLanguage;
  final Map<String, String> requiredBySubdivision;
  @override
  TaxDomain get domain => TaxDomain.documentLanguage;
  @override
  Map<String, Object?> toJson() => {'languages': languages, 'customer_language': customerLanguage,
        if (requiredBySubdivision.isNotEmpty) 'required_by_subdivision': requiredBySubdivision};
}

/// #3852 -- `document_paper`: the usual paper, `A4` or `Letter` (null: A4), and the papers its documents may use (null: both).
class DocumentPaperValue extends TaxValue {
  const DocumentPaperValue({this.paper, this.papers});
  DocumentPaperValue.read(JsonReader r) : this(paper: r.stringOrNull('paper'), papers: r.raw('papers') == null ? null : r.strings('papers'));
  final String? paper;
  final List<String>? papers;
  @override
  TaxDomain get domain => TaxDomain.documentPaper;
  @override
  Map<String, Object?> toJson() => {'paper': ?paper, 'papers': ?papers};
}
