// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4168 -- Me names the kind each of my businesses set: a freelancer is a
// Freelancer in its row, a business that chose no kind shows none, and a kind
// that cannot be read never takes the page with it.
import 'package:deskilo/features/me/presentation/me_shell.dart';
import 'package:deskilo/features/workspace/domain/my_business_kinds.dart';
import 'package:deskilo/features/workspace/providers/my_business_kind_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'me_app.dart';

class _Kinds implements MyBusinessKindsReader {
  _Kinds(this.answer);

  final Map<String, String> answer;

  @override
  Future<Map<String, String>> read() async => answer;
}

class _Failing implements MyBusinessKindsReader {
  @override
  Future<Map<String, String>> read() async => throw StateError('offline');
}

Future<AppLocalizations> _open(
  WidgetTester tester,
  MyBusinessKindsReader reader,
) async {
  final router = await pumpMeApp(
    tester,
    workspace: twoSpaces(),
    extraOverrides: [myBusinessKindsReaderProvider.overrideWithValue(reader)],
  );
  await goTo(tester, router, '/me');
  return AppLocalizations.of(tester.element(find.byType(MeShell)))!;
}

void main() {
  testWidgets('a business that set the kind Freelancer is named so, and a '
      'business that set none is not given one', (tester) async {
    final words = await _open(tester, _Kinds({'ws-1': 'freelancer'}));

    expect(
      find.textContaining(words.businessKindNameFreelancer),
      findsOneWidget,
    );
    expect(find.textContaining(words.businessKindNameCoworking), findsNothing);
  });

  testWidgets('a kind that cannot be read leaves the businesses listed, and '
      'says nothing of a kind', (tester) async {
    final words = await _open(tester, _Failing());

    expect(find.byKey(const ValueKey('me-space-ws-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('me-space-ws-2')), findsOneWidget);
    expect(find.textContaining(words.businessKindNameFreelancer), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a kind this app does not know is shown as its own code', (
    tester,
  ) async {
    await _open(tester, _Kinds({'ws-2': 'atelier'}));

    expect(find.textContaining('atelier'), findsOneWidget);
  });
}
