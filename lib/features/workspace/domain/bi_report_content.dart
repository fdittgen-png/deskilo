// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What one analysis' dashboard says, as plain content: strings and numbers,
// no widgets and no localisation. The dashboard on screen and the PDF both
// render THIS, so the report is the screen on paper and the two cannot
// disagree.
//
// Pure Dart.
library;

import 'bi_analysis.dart';
import 'bi_query.dart';

/// One change chip of the hero.
class BiChipContent {
  const BiChipContent({
    required this.kind,
    required this.direction,
    required this.label,
  });

  final BiBarKind kind;
  final BiDirection direction;
  final String label;
}

/// One bar of the comparison, with the change that led to now.
class BiBarContent {
  const BiBarContent({
    required this.bar,
    required this.change,
    required this.direction,
  });

  final BiComparisonBar bar;
  final String? change;
  final BiDirection direction;
}

/// A whole and its parts.
class BiCompositionContent {
  const BiCompositionContent({
    required this.title,
    this.shares = const [],
    this.centreValue = '',
    this.centreLabel = '',
    this.formatValue,
    this.formatShare,
    this.none,
  });

  final String title;
  final List<BiShare> shares;
  final String centreValue;
  final String centreLabel;
  final String Function(num value)? formatValue;
  final String Function(double share)? formatShare;

  /// Why there is no composition, when there is none to show.
  final String? none;
}

class BiDashboardContent {
  const BiDashboardContent({
    required this.title,
    required this.period,
    required this.figure,
    required this.basis,
    required this.series,
    required this.forecast,
    required this.chips,
    required this.bars,
    required this.compositions,
    required this.notes,
    required this.format,
    required this.periodLabel,
    required this.shortLabel,
    required this.kindLabel,
    required this.projectedLabel,
    required this.noDataLabel,
    required this.partialLabel,
    required this.noComparisonLabel,
    required this.evolutionTitle,
    required this.compareTitle,
    required this.projectionBasis,
    this.narrative,
    this.provisionalNote,
    this.runRate,
    this.projectionNext,
  });

  final String title;
  final String period;
  final String figure;
  final String basis;
  final BiSeries series;
  final BiForecast? forecast;
  final List<BiChipContent> chips;
  final List<BiBarContent> bars;
  final List<BiCompositionContent> compositions;
  final List<String> notes;
  final String? narrative;
  final String? provisionalNote;
  final String? runRate;
  final String projectionBasis;
  final String? projectionNext;
  final String Function(num value) format;
  final String Function(BiPeriod period) periodLabel;
  final String Function(BiPeriod period) shortLabel;
  final String Function(BiBarKind kind) kindLabel;
  final String projectedLabel;
  final String noDataLabel;
  final String partialLabel;
  final String noComparisonLabel;
  final String evolutionTitle;
  final String compareTitle;
}
