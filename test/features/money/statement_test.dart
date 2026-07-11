// SPDX-License-Identifier: MIT
import 'package:deskilo/features/money/domain/statement.dart';
import 'package:flutter_test/flutter_test.dart';

/// The exact jsonb shape the 0015 `member_statement` body returns —
/// WITHOUT the #170 supplement field.
Map<String, dynamic> rpcResult() => <String, dynamic>{
      'period': '2026-07',
      'subscription_pct': 50,
      'fee_cents': 15000,
      'included_half_days': 22,
      'open_days': 22,
      'used_half_days': 24,
      'extra_half_days': 2,
      'overage_cents': 1600,
      'credits_cents': 15000,
      'balance_cents': -1600,
    };

void main() {
  group('Statement.fromRpc', () {
    test('parses the pre-#170 payload; the supplement defaults to 0', () {
      final statement = Statement.fromRpc(rpcResult());

      expect(statement.period, '2026-07');
      expect(statement.subscriptionPct, 50);
      expect(statement.feeCents, 15000);
      expect(statement.includedHalfDays, 22);
      expect(statement.openDays, 22);
      expect(statement.usedHalfDays, 24);
      expect(statement.extraHalfDays, 2);
      expect(statement.overageCents, 1600);
      expect(statement.creditsCents, 15000);
      expect(statement.balanceCents, -1600);
      // Backward compatibility: an old member_statement body omits the
      // field entirely — the client must read 0, not crash.
      expect(statement.accessorySupplementCents, 0);
    });

    test('parses the 0024 payload with accessory_supplement_cents', () {
      final statement = Statement.fromRpc({
        ...rpcResult(),
        'accessory_supplement_cents': 900,
        'balance_cents': -2500,
      });

      expect(statement.accessorySupplementCents, 900);
      // The balance already carries the supplement server-side — the
      // client never re-derives it.
      expect(statement.balanceCents, -2500);
      expect(statement.isSettled, isFalse);
    });

    test('an explicit 0 supplement parses as 0', () {
      final statement = Statement.fromRpc({
        ...rpcResult(),
        'accessory_supplement_cents': 0,
      });

      expect(statement.accessorySupplementCents, 0);
    });
  });
}
