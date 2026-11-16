// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4078 — on the VAT page the names of the groups are the app's own words:
// they follow the interface's language, whatever the country's data says.
// What stays in the country's own words is the data: a rate's label and the
// example that follows a group's name come from the tax reference rows of
// that country (`rate`, `group_example`), not from the app's dictionary.
import 'package:deskilo/features/money/domain/vat_catalogue.dart';
import 'package:deskilo/features/money/presentation/widgets/vat_rate_editor.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  for (final language in const ['de', 'fr', 'en']) {
    testWidgets('in $language the group names above the examples are the '
        "interface's", (tester) async {
      final l10n = await AppLocalizations.delegate.load(Locale(language));
      final names = {
        'standard': l10n.vatGroupStandard,
        'intermediate': l10n.vatGroupIntermediate,
        'reduced': l10n.vatGroupReduced,
        'super_reduced': l10n.vatGroupSuperReduced,
        'zero': l10n.vatGroupZero,
        'exempt': l10n.vatGroupExempt,
        'not_subject': l10n.vatGroupNotSubject,
        'deposit': l10n.vatGroupDeposit,
        'excise': l10n.vatGroupExcise,
      };
      final examples = vatGroupExamples('FR');
      expect(examples, isNotEmpty, reason: 'the country has examples');
      await pumpApp(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            child: VatGroupSection(drafts: [], countryCode: 'FR'),
          ),
        ),
        locale: Locale(language),
        size: const Size(390, 1600),
      );
      await tester.pump();
      for (final e in examples) {
        expect(
          find.text('${names[e.group.wire]} — ${e.example}'),
          findsOneWidget,
          reason: '${e.group.wire} in $language',
        );
      }
      expect(find.text(l10n.vatGroupExamples), findsOneWidget);
    });
  }
}
