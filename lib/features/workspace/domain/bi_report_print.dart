// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The printout of a report snapshot, as plain content: the provenance every
// copy carries, then the report's pages, each visual in its reading order —
// a figure card as its figure, a chart or a table as the table of its
// periods, a text as its text. The print preview on screen and the PDF both
// lay out THIS, from the snapshot's own values: nothing is summed, rounded
// into a new figure or converted here.
//
// The provenance (who, which report and revision, the period, the date
// basis, the currencies, the filters, when the figures were computed and
// their digest) and the qualification of a partial export are printed
// whatever the print layout says; the layout chooses only the paper, the
// margins, a typed header and footer line, the page breaks and whether the
// sources of each metric are listed.
//
// Words reach it as data ([BiPrintStrings]); pure Dart.
library;

import 'bi_query.dart';
import 'bi_report_definition.dart';
import 'bi_report_edit.dart';
import 'bi_report_snapshot.dart';
import 'kpi_contract.dart';

/// The words and formats of a printout; the app reads every one of them
/// from the catalogue of the reader's language.
class BiPrintStrings {
  const BiPrintStrings({
    required this.workspace,
    required this.report,
    required this.revision,
    required this.unsaved,
    required this.period,
    required this.dateBasis,
    required this.currency,
    required this.filters,
    required this.noFilters,
    required this.computed,
    required this.snapshot,
    required this.complete,
    required this.partial,
    required this.management,
    required this.leftOut,
    required this.unknown,
    required this.qualifiedMark,
    required this.failedMark,
    required this.columns,
    required this.formats,
  });

  final String workspace;
  final String report;
  final String Function(int revision) revision;
  final String unsaved;
  final String period;
  final String dateBasis;
  final String currency;
  final String filters;
  final String noFilters;
  final String computed;
  final String snapshot;
  final String complete;
  final String partial;
  final String management;
  final String leftOut;
  final String unknown;
  final String qualifiedMark;
  final String failedMark;

  /// Period, value, basis, status.
  final List<String> columns;
  final BiPrintFormats formats;
}

/// How values, periods, metrics and filters are written, in the reader's
/// language and locale.
class BiPrintFormats {
  const BiPrintFormats({
    required this.value,
    required this.number,
    required this.periodName,
    required this.metricTitle,
    required this.dateTime,
    required this.dateBasis,
    required this.coverage,
    required this.filter,
  });

  /// A figure's value in its unit (a share as a percentage, an amount in
  /// its own currency).
  final String Function(BiSnapshotFigure figure) value;
  final String Function(num value) number;
  final String Function(BiPeriod period) periodName;
  final String Function(String metricId) metricTitle;
  final String Function(DateTime at) dateTime;
  final String Function(KpiDateBasis basis) dateBasis;
  final String Function(KpiCoverage coverage) coverage;
  final String Function(BiReportFilter filter) filter;
}

class BiPrintLine {
  const BiPrintLine(this.label, this.value);
  final String label;
  final String value;
}

sealed class BiPrintBlock {
  const BiPrintBlock();
}

/// A figure card: its title, its value and what qualifies it.
final class BiPrintFigure extends BiPrintBlock {
  const BiPrintFigure({
    required this.title,
    required this.value,
    this.note = '',
  });
  final String title;
  final String value;
  final String note;
}

/// A chart or a table as the table of its periods. Its headings repeat on
/// every sheet it runs over.
final class BiPrintTable extends BiPrintBlock {
  const BiPrintTable({
    required this.title,
    required this.headings,
    required this.rows,
  });
  final String title;
  final List<String> headings;
  final List<List<String>> rows;
}

final class BiPrintText extends BiPrintBlock {
  const BiPrintText(this.text);
  final String text;
}

class BiPrintSection {
  const BiPrintSection({
    required this.title,
    required this.newSheet,
    required this.blocks,
  });
  final String title;

  /// Starts on a new sheet (every page after the first, when the layout
  /// breaks pages).
  final bool newSheet;
  final List<BiPrintBlock> blocks;
}

class BiPrintDocument {
  const BiPrintDocument({
    required this.style,
    required this.title,
    required this.provenance,
    required this.qualification,
    required this.sources,
    required this.sections,
    required this.sourceLine,
    this.management,
  });

  final BiPrintStyle style;
  final String title;
  final List<BiPrintLine> provenance;

  /// Complete, or partial and why: always printed.
  final String qualification;

  /// "Management information, not statutory accounts" for amounts.
  final String? management;

  /// One line per metric (id, version, unit, date basis, coverage) when the
  /// layout lists the sources.
  final List<String> sources;
  final List<BiPrintSection> sections;

  /// The footer of every sheet: workspace, report, filters, computation
  /// time and digest.
  final String sourceLine;
}

/// The printout of [s] in the words of [w].
BiPrintDocument biPrintDocument(BiReportSnapshot s, BiPrintStrings w) {
  final f = w.formats;
  final style = s.report.printStyle;
  final title = s.source.reportName;
  final revision = s.source.reportRevision;
  final filters = s.report.filters.isEmpty
      ? w.noFilters
      : s.report.filters.map(f.filter).join(', ');
  final hash = s.digest;
  final computed = f.dateTime(s.computedAt);
  return BiPrintDocument(
    style: style,
    title: title,
    provenance: [
      BiPrintLine(w.workspace, s.source.workspaceName),
      BiPrintLine(
        w.report,
        '$title · ${revision == null ? w.unsaved : w.revision(revision)}',
      ),
      BiPrintLine(w.period, f.periodName(s.period)),
      BiPrintLine(
        w.dateBasis,
        [
          for (final m in s.metrics)
            '${f.metricTitle(m.id)}: ${f.dateBasis(m.dateBasis)}',
        ].join('; '),
      ),
      BiPrintLine(
        w.currency,
        s.currencies.isEmpty ? '—' : (s.currencies.toList()..sort()).join(', '),
      ),
      BiPrintLine(w.filters, filters),
      BiPrintLine(w.computed, computed),
      BiPrintLine(w.snapshot, hash),
    ],
    qualification: s.partial ? w.partial : w.complete,
    management: s.financial ? w.management : null,
    sources: style.showSources
        ? [
            for (final m in s.metrics)
              '${f.metricTitle(m.id)} — ${m.id} v${m.version} · ${m.unit} · '
                  '${f.dateBasis(m.dateBasis)} · ${f.coverage(m.coverage)}',
          ]
        : const [],
    sections: [
      for (final (i, page) in s.report.pages.indexed)
        BiPrintSection(
          title: page.title,
          newSheet: style.pageBreaks && i > 0,
          blocks: _blocks(s, i, page, w),
        ),
    ],
    sourceLine: [
      s.source.workspaceName,
      title,
      filters,
      '${w.computed} $computed',
      hash,
    ].join(' · '),
  );
}

List<BiPrintBlock> _blocks(
  BiReportSnapshot s,
  int pageIndex,
  BiReportPage page,
  BiPrintStrings w,
) {
  final f = w.formats;
  final byId = {
    for (final v in s.visuals)
      if (v.item.pageIndex == pageIndex) v.item.visual.id: v,
  };
  final left = {
    for (final l in s.plan.leftOut)
      if (identical(l.page, page)) l.visual.id: l,
  };
  return [
    for (final visual in biVisualsInOrder(page.visuals))
      if (byId[visual.id] case final v?)
        _visualBlock(v, w)
      else if (left[visual.id] != null)
        BiPrintFigure(
          title: f.metricTitle(visual.metricId ?? visual.id),
          value: '—',
          note: w.leftOut,
        )
      else if (visual.text case final text?)
        BiPrintText(text),
  ];
}

BiPrintBlock _visualBlock(BiSnapshotVisual v, BiPrintStrings w) {
  final f = w.formats;
  final title = f.metricTitle(v.item.visual.metricId!);
  if (v.item.visual.type == BiVisualType.kpi) {
    final figure = v.figures.single;
    return BiPrintFigure(
      title: title,
      value: _value(figure, w),
      note: [
        f.periodName(figure.period),
        _status(figure, w),
      ].where((x) => x.isNotEmpty).join(' · '),
    );
  }
  return BiPrintTable(
    title: title,
    headings: w.columns,
    rows: [
      for (final figure in v.figures)
        [
          f.periodName(figure.period),
          _value(figure, w),
          _basis(figure, w),
          _status(figure, w),
        ],
    ],
  );
}

String _value(BiSnapshotFigure figure, BiPrintStrings w) =>
    figure.value == null ? w.unknown : w.formats.value(figure);

/// What a ratio is made of, as the server gave it: never recomputed from
/// the rounded value.
String _basis(BiSnapshotFigure figure, BiPrintStrings w) {
  final d = figure.measure.denominator;
  if (figure.failure != null || d == null) return '';
  return '${w.formats.number(figure.measure.numerator)} / ${w.formats.number(d)}';
}

String _status(BiSnapshotFigure figure, BiPrintStrings w) => switch (figure) {
  BiSnapshotFigure(failure: _?) => w.failedMark,
  BiSnapshotFigure(value: null) => w.unknown,
  BiSnapshotFigure(qualified: true) => w.qualifiedMark,
  _ => '',
};
