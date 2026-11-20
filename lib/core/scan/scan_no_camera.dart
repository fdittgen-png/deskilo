// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../l10n/app_localizations.dart';

/// #3621 — the one line shown where there is no camera scanner: the browser
/// says so in the browser's words, a desktop or other program in its own.
String scanNoCameraSentence(AppLocalizations l10n) =>
    kIsWeb ? l10n.scanCameraWebUnavailable : l10n.scanCameraProgramUnavailable;
