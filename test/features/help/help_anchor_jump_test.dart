// SPDX-License-Identifier: 0BSD
//
// #1016 — a help symbol names ONE object. The anchor resolves to that
// object's heading and the guide opens there; the topic can only find
// the first heading that happens to contain its words.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/help/presentation/screens/help_screen.dart';
import 'package:deskilo/features/help/providers/help_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../helpers/mock_providers.dart';

/// Two headings answer the topic "rate"; only one answers the anchor.
final _guide = '''
# Guide

## Getting started

${List.filled(40, 'A line of the introduction.').join('\n\n')}

## The rate a member pays

${List.filled(40, 'A line about what a member pays.').join('\n\n')}

## Setting the rates

${List.filled(40, 'A line about the rate table.').join('\n\n')}
''';

const _anchors = {'user.money.vat.rates': 'Setting the rates'};

List<Override> _overrides({bool withAnchors = true}) => [
      ...standardTestOverrides(),
      helpContentProvider.overrideWith((ref, languageCode) async => _guide),
      helpAnchorsProvider.overrideWith(
          (ref, languageCode) async => withAnchors ? _anchors : const {}),
    ];

Future<double> _openAt(WidgetTester tester, String query,
    {bool withAnchors = true}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: _overrides(withAnchors: withAnchors),
    child: const DeskiloApp(),
  ));
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  unawaited(GoRouter.of(context).push('/help?$query'));
  await tester.pumpAndSettle();
  expect(find.byType(HelpScreen), findsOneWidget);
  return tester
      .state<ScrollableState>(find
          .descendant(
              of: find.byType(HelpScreen), matching: find.byType(Scrollable))
          .first)
      .position
      .pixels;
}

void main() {
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('the anchor opens ITS object, past the heading the topic finds',
      (tester) async {
    final byTopic = await _openAt(tester, 'topic=rate');
    final byAnchor =
        await _openAt(tester, 'topic=rate&anchor=user.money.vat.rates');
    expect(byTopic, greaterThan(0));
    expect(byAnchor, greaterThan(byTopic),
        reason: 'the anchor names the later heading, the topic the earlier');
  });

  testWidgets('an unknown anchor falls back to the topic, never to nothing',
      (tester) async {
    final byTopic = await _openAt(tester, 'topic=rate');
    final unknown =
        await _openAt(tester, 'topic=rate&anchor=user.money.vat.nowhere');
    expect(unknown, byTopic);
  });

  testWidgets('a bundle without the anchor map behaves exactly as before',
      (tester) async {
    final byTopic = await _openAt(tester, 'topic=rate', withAnchors: false);
    final byAnchor = await _openAt(
        tester, 'topic=rate&anchor=user.money.vat.rates',
        withAnchors: false);
    expect(byAnchor, byTopic);
  });

  test('the anchor asset sits beside its guide', () {
    expect(helpAnchorAssetFor('fr'), 'assets/help/fr.anchors.json');
    expect(helpAnchorAssetFor('pt'), 'assets/help/en.anchors.json');
  });
}
