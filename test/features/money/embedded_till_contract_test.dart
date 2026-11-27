// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4452 (E01A) -- the embedded till terminal contract, as the Dart producer reads the shared fixtures of
// contracts/embedded_till/v1. The TypeScript adapter (E03) and the C++ firmware (E02) run the same files; the digests in them
// were first computed by an independent Python implementation of the canonical form.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/money/domain/counter_till.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/embedded_till/embedded_till_canonical.dart';
import '../../helpers/embedded_till/embedded_till_contract.dart';
import '../../helpers/embedded_till/embedded_till_profile.dart';

Map<String, Object?> _fixture(String name) =>
    jsonDecode(File('contracts/embedded_till/v1/fixtures/$name.json').readAsStringSync()) as Map<String, Object?>;

void main() {
  group('terminal_contract_fixture_parity: the canonical form', () {
    for (final v in (_fixture('canonical_vectors')['vectors'] as List).cast<Map<String, Object?>>()) {
      test('${v['name']}', () {
        expect(canonicalJson(v['input']), v['canonical']);
        expect(sha256Hex(canonicalBytes(v['input'])), v['sha256']);
      });
    }
    test('a null and a float are refused, never written', () {
      for (final r in (_fixture('canonical_vectors')['refuse'] as List).cast<Map<String, Object?>>()) {
        expect(() => canonicalJson(jsonDecode(r['input_json'] as String)), throwsA(isA<CanonicalFormRefused>()), reason: '${r['name']}');
      }
    });
  });

  group('terminal_money_boundary', () {
    final money = _fixture('money_vectors');
    test('amounts are signed 64-bit decimal strings, exactly', () {
      for (final a in (money['amounts'] as List).cast<Map<String, Object?>>()) {
        expect(terminalAmountOf(a['text'] as String) != null, a['valid'], reason: 'amount "${a['text']}"');
      }
    });
    test('amounts above 2^53 keep every digit', () {
      expect(terminalAmountOf('9007199254740993').toString(), '9007199254740993');
      expect(terminalAmountOf('9223372036854775807').toString(), '9223372036854775807');
    });
    test('quantities are the till\'s exact decimals above zero', () {
      for (final q in (money['quantities'] as List).cast<Map<String, Object?>>()) {
        expect(terminalQuantityOf(q['text'] as String) != null, q['valid'], reason: 'quantity "${q['text']}"');
      }
    });
    test('the exponent is 0, 2 or 3', () {
      for (final e in (money['exponents'] as List).cast<Map<String, Object?>>()) {
        expect(terminalExponentOk(e['value'] as int), e['valid']);
      }
    });
    test('a sum that leaves 64 bits is refused, never wrapped', () {
      for (final s in (money['sums'] as List).cast<Map<String, Object?>>()) {
        expect(terminalAmountSum(terminalAmountOf(s['a'] as String)!, terminalAmountOf(s['b'] as String)!) != null, s['ok']);
      }
    });
  });

  group('terminal_protocol_evolution', () {
    final cases = _fixture('protocol_cases');
    final implemented = {for (final c in (cases['implements'] as List).cast<String>()) TerminalCapability.of(c)!};
    for (final c in (cases['cases'] as List).cast<Map<String, Object?>>()) {
      test('${c['name']}', () {
        final doc = (c['document'] as Map).cast<String, Object?>();
        final expect_ = c['expect'] as String;
        if (expect_ == 'accept') {
          expect(() => checkProtocol(doc, implemented), returnsNormally);
        } else {
          final want = expect_.split(':');
          expect(
            () => checkProtocol(doc, implemented),
            throwsA(isA<TerminalContractRefused>().having((e) => '${e.outcome.name}:${e.code}', 'answer', expect_)),
            reason: want.join(' '),
          );
        }
      });
    }
  });

  group('terminal_profile_projection and terminal_bounds', () {
    final inputs = (_fixture('profile_inputs')['cases'] as List).cast<Map<String, Object?>>();
    final expected = {for (final c in (_fixture('profile_expected')['cases'] as List).cast<Map<String, Object?>>()) c['name'] as String: c};
    for (final c in inputs) {
      test('${c['name']} projects to the fixture, digest included', () {
        final keys = [
          for (final k in (c['till_keys'] as List).cast<Map<String, Object?>>())
            TillKey(
              id: k['id']! as String,
              name: k['name']! as String,
              unit: k['unit']! as String,
              category: k['category'] as String?,
              colour: k['colour'] as String?,
              minAge: k['minAge'] as int?,
              weighed: k['weighed'] == true,
              depositItemId: k['depositItemId'] as String?,
            ),
        ];
        final p = projectDefaultProfile(keys, currency: c['currency']! as String, exponent: c['exponent']! as int);
        final want = expected[c['name']]!;
        expect(p.omitted, want['omitted']);
        expect(jsonDecode(jsonEncode(p.profile.toJson())), want['profile']);
      });
    }
    test('the bakery keeps its order, fixed quantities and says what it cannot do', () {
      final profile = (expected['bakery_default']!['profile']! as Map).cast<String, Object?>();
      final pages = (profile['pages']! as List).cast<Map<String, Object?>>();
      expect(pages.first['title'], isNull, reason: 'the keys with no category come first');
      final all = [for (final p in pages) ...(p['keys']! as List).cast<Map<String, Object?>>()];
      final cheese = all.firstWhere((k) => k['label'] == 'Cheese');
      final wine = all.firstWhere((k) => k['label'] == 'Red wine');
      final milk = all.firstWhere((k) => k['label'] == 'Oat milk');
      expect(cheese.containsKey('fixed_quantity'), isFalse, reason: 'a weighed item asks its quantity on the keypad');
      expect(wine['reason'], 'age_confirmation');
      expect(milk['reason'], 'deposit');
      expect(wine['state'], 'unavailable');
    });
    test('one key past a page or a page past the ceiling is named, not hidden', () {
      final p = (expected['over_the_page_ceiling']!['profile']! as Map).cast<String, Object?>();
      expect((p['pages']! as List).length, TerminalBounds.profilePages);
      expect(expected['over_the_page_ceiling']!['omitted'], 4);
      for (final page in (p['pages']! as List).cast<Map<String, Object?>>()) {
        expect((page['keys']! as List).length, lessThanOrEqualTo(TerminalBounds.keysPerPage));
      }
    });
    test('a label is cut at a character boundary to the terminal\'s width and says so', () {
      final long = (expected['bakery_default']!['profile']! as Map)['pages'] as List;
      final key = [for (final p in long.cast<Map<String, Object?>>()) ...(p['keys']! as List).cast<Map<String, Object?>>()].firstWhere((k) => k['shortened'] == true);
      expect(utf8.encode(key['label']! as String).length, lessThanOrEqualTo(TerminalBounds.labelBytes));
    });
    test('a profile\'s digest changes with any key and with nothing else', () {
      final a = projectDefaultProfile(const [TillKey(id: 'a', name: 'A', unit: 'piece')], currency: 'EUR', exponent: 2).profile;
      final b = projectDefaultProfile(const [TillKey(id: 'a', name: 'A', unit: 'piece')], currency: 'EUR', exponent: 2).profile;
      final c = projectDefaultProfile(const [TillKey(id: 'a', name: 'B', unit: 'piece')], currency: 'EUR', exponent: 2).profile;
      expect(a.digest, b.digest);
      expect(a.digest, isNot(c.digest));
    });
  });
}
