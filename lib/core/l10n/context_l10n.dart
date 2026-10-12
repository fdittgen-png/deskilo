// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

/// The strings of the app, never null (#2388).
///
/// `AppLocalizations.of(context)` is nullable only for a widget pumped
/// without the localisation delegates (a bare test harness, the boot
/// screen before `MaterialApp` exists). Every call site used to write each
/// string twice — `l10n?.key ?? 'English'` — and the English in Dart
/// drifted from the ARB. Here the missing delegates read the English ARB
/// instead, so the ARB is the only place a string is written.
extension ContextL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this) ?? englishL10n;
}

/// The English strings, from the ARB — what a context without delegates
/// reads.
final AppLocalizations englishL10n = lookupAppLocalizations(const Locale('en'));
