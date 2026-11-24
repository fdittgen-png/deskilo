// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4442 -- how a unit of a line reads: the label the business gave it, else its symbol (km, kg, m²), else the app's word
// for a piece.
import '../../../../l10n/app_localizations.dart';

String lineUnitName(AppLocalizations l10n, {required String code, String? label}) => label ?? switch (code) {
  'piece' => l10n.standaloneUnitPiece,
  'm2' => 'm²',
  final c => c,
};
