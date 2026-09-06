// SPDX-License-Identifier: 0BSD
//
// #970 — demo mode: the registry of personal strings and the switch.
import 'package:deskilo/core/demo/demo_mode.dart';
import 'package:deskilo/features/profile/domain/personal_info.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_pref_stores.dart';

void main() {
  setUp(demoSensitive.clear);

  test('a paragraph matches when it carries a registered string: short '
      'ones as whole words, longer ones anywhere', () {
    demoSensitive.addAll(['Flo', 'guilhem.martin@kaloa.fr', '4 rue Silène', '', 'ab']);
    expect(demoSensitive.values, hasLength(3), reason: 'blanks and two letters ignored');
    expect(demoSensitive.matches('Flo'), isTrue);
    expect(demoSensitive.matches('Flo · Owner'), isTrue);
    expect(demoSensitive.matches('Floor plan'), isFalse, reason: 'a short name is a word, not a prefix');
    expect(demoSensitive.matches('Mail: GUILHEM.MARTIN@kaloa.fr'), isTrue, reason: 'case does not matter');
    expect(demoSensitive.matches('4 rue Silène\n34120 PÉZENAS'), isTrue);
    expect(demoSensitive.matches('Total 100,00 €'), isFalse);
    expect(demoSensitive.matches(''), isFalse);
  });

  test('an identity, a profile and their printed forms are all registered', () {
    const info = PersonalInfo(
      firstName: 'Guilhem', lastName: 'Martin', company: 'SASU KaloA',
      street: '209 rue Jean Bart', postalCode: '31670', city: 'Labège',
      email: 'g@kaloa.fr', countryCode: 'FR',
    );
    demoSensitive.addAll(sensitiveOfPersonalInfo(info));
    expect(demoSensitive.matches('Guilhem MARTIN'), isTrue, reason: 'personName');
    expect(demoSensitive.matches('SASU KaloA'), isTrue);
    expect(demoSensitive.matches('31670 LABÈGE'), isTrue, reason: 'the postal block line');
    expect(demoSensitive.matches('g@kaloa.fr'), isTrue);
    demoSensitive.addAll(sensitiveOfProfile(const Profile(id: 'u1', displayName: 'Flo', whatsapp: '+33600000000')));
    expect(demoSensitive.matches('+33600000000'), isTrue);
  });

  test('the controller reads "on" and persists a change', () async {
    final store = InMemoryDemoModeStore(value: 'on');
    final container = ProviderContainer(
        overrides: [demoModeStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    expect(await container.read(demoModeControllerProvider.future), isTrue);
    await container.read(demoModeControllerProvider.notifier).set(false);
    expect(store.value, isNull);
  });
}
