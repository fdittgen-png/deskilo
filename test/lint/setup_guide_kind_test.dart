// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4319 — the five written setup guides open with the kind of business and
// name, in the section "what a business without places does not get", every
// step the app withholds from such a business (`setupStepsNeedingPlaces`),
// under the title the app gives it in that language.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/workspace/domain/setup_steps_for_kind.dart';
import 'package:flutter_test/flutter_test.dart';

const _guides = {
  'en': 'Setup-Guide.md',
  'fr': 'Guide-de-demarrage.md',
  'de': 'Einrichtungsanleitung.md',
  'es': 'Guia-de-puesta-en-marcha.md',
  'it': 'Guida-di-avvio.md',
};

const _anchors = [
  'setup.kind.overview',
  'setup.kind.choose',
  'setup.kind.without-places',
  'setup.kind.example',
];

/// The ARB key of a step's title: the step's own, but `limits` is named by its
/// help topic.
String _titleKey(String id) {
  if (id == 'limits') return 'helpTopicBookingLimits';
  final camel = id.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join();
  return 'setupStepTitle$camel';
}

void main() {
  for (final entry in _guides.entries) {
    test('the ${entry.key} setup guide starts with the kind and lists the withheld steps', () {
      final guide = File('docs/wiki/${entry.value}').readAsStringSync();
      final arb = jsonDecode(File('lib/l10n/app_${entry.key}.arb').readAsStringSync())
          as Map<String, Object?>;
      for (final a in _anchors) {
        expect(guide, contains('<!-- anchor: $a -->'), reason: '${entry.value} lacks $a');
      }
      final kindAt = guide.indexOf('<!-- anchor: ${_anchors.first} -->');
      expect(
        kindAt,
        lessThan(guide.indexOf('<!-- anchor: setup.before.overview -->')),
        reason: 'the kind of business comes before "Before you start"',
      );
      final from = guide.indexOf('<!-- anchor: setup.kind.without-places -->');
      final section = guide.substring(from, guide.indexOf('<!-- anchor: setup.kind.example -->'));
      for (final id in setupStepsNeedingPlaces) {
        final title = arb[_titleKey(id)]! as String;
        expect(section, contains('**$title**'), reason: 'step $id ("$title") is not named');
      }
    });
  }
}
