// SPDX-License-Identifier: 0BSD
import 'package:deskilo/features/money/domain/statement.dart';
import 'package:deskilo/features/workspace/domain/overage_policy.dart';
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

    test('a pre-0041 payload defaults the overage fields', () {
      final statement = Statement.fromRpc(rpcResult());

      expect(statement.overagePolicy, OveragePolicy.blocked);
      expect(statement.overageRateCents, 0);
      expect(statement.grantedHalfDays, 0);
      expect(statement.remainingHalfDays, 0);
    });

    test('the 0041 payload carries the policy, grant, cap and remaining', () {
      final statement = Statement.fromRpc({
        ...rpcResult(),
        'used_half_days': 20,
        'extra_half_days': 0,
        'overage_cents': 0,
        'overage_policy': 'payg',
        'overage_rate_cents': 800,
        'granted_half_days': 4,
        'remaining_half_days': 6,
      });

      expect(statement.overagePolicy, OveragePolicy.payg);
      expect(statement.overageRateCents, 800);
      expect(statement.grantedHalfDays, 4);
      expect(statement.remainingHalfDays, 6);
      // included 22 + granted 4 = cap 26; used 20 → not yet at the cap.
      expect(statement.capHalfDays, 26);
      expect(statement.isCapReached, isFalse);
    });

    test('an unknown overage_policy falls back to blocked', () {
      final statement = Statement.fromRpc({
        ...rpcResult(),
        'overage_policy': 'something-new',
      });

      expect(statement.overagePolicy, OveragePolicy.blocked);
    });
  });
}
