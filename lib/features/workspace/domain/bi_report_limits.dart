// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The bounds a saved report keeps in one workspace: its pages, its cards
// over all pages and the bytes of its stored definition. Each is a setting
// of the space (`bi.report_max_pages`, `bi.report_max_visuals`,
// `bi.report_max_bytes`) whose registry maximum is the platform guard the
// server never exceeds; `bi_view_save` refuses a report over either, the
// editor stops offering what would cross them.
//
// Pure Dart.
library;

import 'dart:convert';

import '../../../core/settings/setting_defaults.g.dart';
import '../../../core/settings/settings.dart';
import 'bi_report_definition.dart';

class BiReportLimits {
  const BiReportLimits({
    this.maxPages = SettingDefaults.biReportMaxPages,
    this.maxVisuals = SettingDefaults.biReportMaxVisuals,
    this.maxBytes = SettingDefaults.biReportMaxBytes,
  });

  static const pagesKey = 'bi.report_max_pages';
  static const visualsKey = 'bi.report_max_visuals';
  static const bytesKey = 'bi.report_max_bytes';

  /// The space's values; a registry that predates a key (an older server)
  /// keeps its default.
  factory BiReportLimits.fromSettings(SettingsSet? settings) {
    int read(String key, int fallback) =>
        settings != null && settings.definitions.containsKey(key)
        ? settings.read<int>(key)
        : fallback;
    return BiReportLimits(
      maxPages: read(pagesKey, SettingDefaults.biReportMaxPages),
      maxVisuals: read(visualsKey, SettingDefaults.biReportMaxVisuals),
      maxBytes: read(bytesKey, SettingDefaults.biReportMaxBytes),
    );
  }

  final int maxPages;
  final int maxVisuals;
  final int maxBytes;

  int visualsOf(BiReportDefinition report) =>
      report.pages.fold(0, (n, p) => n + p.visuals.length);

  /// Whether [report] stays within every bound.
  bool admits(BiReportDefinition report) =>
      report.pages.length <= maxPages &&
      visualsOf(report) <= maxVisuals &&
      utf8.encode(jsonEncode(report.toJson())).length <= maxBytes;

  /// Whether one more card fits in [report].
  bool canAddVisual(BiReportDefinition report) =>
      visualsOf(report) < maxVisuals;

  /// Whether one more page fits in [report].
  bool canAddPage(BiReportDefinition report) => report.pages.length < maxPages;
}
