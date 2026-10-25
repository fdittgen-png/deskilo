// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — the owners of the sheets in core/navigation/feature_sheets.dart,
// composed here where every feature is visible: money, profile and the
// workspace's messenger open them without importing the calendar, money
// or members feature.
import 'package:flutter_riverpod/misc.dart' show Override;

import '../core/navigation/feature_sheets.dart'
    show FeatureSheet, featureSheetsProvider, memberProfileOpenerProvider;
import '../features/calendar/presentation/widgets/access_sheet.dart';
import '../features/members/presentation/member_profile_link.dart';
import '../features/money/presentation/screens/tax_reference_screen.dart';

/// Puts the openers in a scope's overrides (main.dart, the demonstration,
/// the widget tests' standard scope).
final List<Override> featureSheetsFromApp = [
  featureSheetsProvider.overrideWithValue({
    FeatureSheet.dataAccess: showAccessSheet,
    FeatureSheet.taxReferenceEditor: (context, ref) =>
        showTaxReferenceScreen(context, canEdit: true),
  }),
  memberProfileOpenerProvider.overrideWithValue(openMemberProfile),
];
