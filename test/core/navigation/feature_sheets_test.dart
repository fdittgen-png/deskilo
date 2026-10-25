// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — the sheets a feature opens across a boundary: unwired, an entry
// does nothing; wired, it opens its owner's sheet, and the composition
// root wires every sheet to the owner it names.
import 'dart:async';

import 'package:deskilo/app/feature_sheets_wiring.dart';
import 'package:deskilo/core/navigation/feature_sheets.dart';
import 'package:deskilo/features/calendar/presentation/widgets/access_sheet.dart';
import 'package:deskilo/features/members/presentation/member_profile_link.dart'
    as members;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester,
  List<Override> overrides,
  void Function(BuildContext context, WidgetRef ref) onTap,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => onTap(context, ref),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
}

void main() {
  testWidgets('unwired, opening a sheet or a profile does nothing', (
    tester,
  ) async {
    await _pump(tester, const [], (context, ref) {
      unawaited(openFeatureSheet(context, ref, FeatureSheet.dataAccess));
      unawaited(openMemberProfile(context, ref, memberId: 'member-1'));
    });
    expect(tester.takeException(), isNull);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('wired, each entry calls its own opener once', (tester) async {
    final opened = <String>[];
    await _pump(
      tester,
      [
        featureSheetsProvider.overrideWithValue({
          FeatureSheet.dataAccess: (context, ref) async =>
              opened.add('dataAccess'),
          FeatureSheet.taxReferenceEditor: (context, ref) async =>
              opened.add('taxReferenceEditor'),
        }),
        memberProfileOpenerProvider.overrideWithValue(
          (context, ref, {required memberId}) async =>
              opened.add('member:$memberId'),
        ),
      ],
      (context, ref) {
        unawaited(
          openFeatureSheet(context, ref, FeatureSheet.taxReferenceEditor),
        );
        unawaited(openMemberProfile(context, ref, memberId: 'member-2'));
      },
    );
    expect(opened, ['taxReferenceEditor', 'member:member-2']);
  });

  test('the composition root wires every sheet to its owner', () {
    final container = ProviderContainer(overrides: featureSheetsFromApp);
    addTearDown(container.dispose);
    final sheets = container.read(featureSheetsProvider);
    expect(sheets.keys.toSet(), FeatureSheet.values.toSet());
    expect(identical(sheets[FeatureSheet.dataAccess], showAccessSheet), isTrue);
    expect(
      identical(
        container.read(memberProfileOpenerProvider),
        members.openMemberProfile,
      ),
      isTrue,
    );
  });
}
