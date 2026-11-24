// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4436 -- the till says why a sale was refused for its lots, read from the refusal's keys (DKG03, "scope": "lots",
// 0947): goods past their date say so with what is fit to sell and what is past its date; too little says only what is
// there; a refusal without that detail keeps the generic words. Shown as the till shows a problem.
import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/l10n/context_l10n.dart';
import 'package:deskilo/features/money/presentation/till_text.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

PostgrestException _dkg03(String? details) => PostgrestException(
  message: 'not that much on hand at this place',
  code: DkCode.dkg03,
  details: details,
);

class _Problem extends StatelessWidget {
  const _Problem(this.problem);

  final Object problem;

  @override
  Widget build(BuildContext context) => Text(
    tillProblemText(context.l10n, problem),
    key: const ValueKey('problem'),
  );
}

String _shown(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('problem'))).data!;

void main() {
  testWidgets(
    'the till says why a sale was refused for its lots: past its date, too little, or nothing more known',
    (tester) async {
      await pumpApp(
        tester,
        _Problem(
          _dkg03(
            '{"scope": "lots", "reason": "expired", "item_id": "i-1", "asked": "1", "held": "0", "expired": "3"}',
          ),
        ),
      );
      expect(_shown(tester), _en.counterLotsExpired('0', '1', '3'));

      await pumpApp(
        tester,
        _Problem(
          _dkg03(
            '{"scope": "lots", "reason": "not_enough", "item_id": "i-1", "asked": "2", "held": "1", "expired": "0"}',
          ),
        ),
      );
      expect(_shown(tester), _en.counterLotsShort('1', '2'));

      await pumpApp(tester, _Problem(_dkg03(null)));
      expect(
        _shown(tester),
        _en.refusalStockNotEnough,
        reason: 'without the detail the generic words stand',
      );
    },
  );
}
