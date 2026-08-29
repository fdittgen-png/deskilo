// SPDX-License-Identifier: 0BSD
import 'package:intl/intl.dart';

import '../../features/workspace/presentation/country_names.dart';
import '../../l10n/app_localizations.dart';

/// A format locale as a PERSON reads it (#713): `fr_CH` →
/// « Français (Suisse) · 1'234.56 ».
///
/// The tag was the picker's label for one release. It is a developer's
/// spelling: it tells the owner of a Geneva coworking nothing they can
/// act on, while the number sample — the one thing that differs between
/// `fr_FR` and `fr_CH` — was nowhere. Language and region in the
/// reader's own language, then the sample in the candidate's.
String formatLocaleLabel(AppLocalizations? l10n, String tag) {
  final parts = tag.split('_');
  final language = localizedLanguageName(l10n, parts.first);
  final region = parts.length > 1 ? localizedCountryName(l10n, parts[1]) : '';
  final sample = NumberFormat.decimalPattern(tag).format(1234.56);
  return region.isEmpty
      ? '$language · $sample'
      : '$language ($region) · $sample';
}
