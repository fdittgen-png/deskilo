// SPDX-License-Identifier: 0BSD
//
// #1232 — property-based tests, on the arithmetic that must never invent
// or lose a cent.
//
// The existing money tests are example-based and good: BR-S-02, BR-E-02,
// VATEX-EU-AE, per-rate rounding, credit notes. What an example cannot
// say is "for EVERY amount", and rounding bugs live exactly where nobody
// thought to write the example — 33 cents across 3 members, a 5.5% rate
// on 1 cent, a reversal of a split that was itself rounded.
//
// No `glados`, no new dependency: a seeded generator and a loop. Seeded
// because a property test that fails only sometimes is a flake, and a
// flake in the money suite is worse than no test. The seed is printed in
// every failure, so a red build is reproducible by running it again.
import 'dart:math';

import 'package:deskilo/core/format/cents.dart';
import 'package:deskilo/core/time/calendar_days.dart';
import 'package:deskilo/features/money/domain/expense_repartition.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:flutter_test/flutter_test.dart';

/// One fixed seed, so a failure here is a failure for everybody.
const int kSeed = 20260914;

/// How many cases each property gets. Large enough to reach the corners,
/// small enough that the whole file is under a second.
const int kCases = 2000;

void main() {
  group('VAT is split, never created', () {
    test('net + vat is always exactly the gross it came from', () {
      final random = Random(kSeed);
      const rates = [0.0, 2.1, 5.5, 7.7, 10.0, 19.0, 20.0, 21.0, 25.0];
      for (var i = 0; i < kCases; i++) {
        final gross = random.nextInt(5000000) - 1000000;
        final percent = rates[random.nextInt(rates.length)];
        final split = vatSplit(gross, percent);
        expect(
          split.netCents + split.vatCents,
          gross,
          reason: 'seed $kSeed case $i: vatSplit($gross, $percent) gave '
              'net ${split.netCents} + vat ${split.vatCents}, which is '
              'not $gross. A cent invented in a VAT split reaches an '
              'issued invoice, and an issued invoice is immutable.',
        );
      }
    });

    test('a zero or negative rate moves nothing into VAT', () {
      final random = Random(kSeed + 1);
      for (var i = 0; i < kCases; i++) {
        final gross = random.nextInt(1000000);
        final split = vatSplit(gross, i.isEven ? 0 : -1);
        expect(split.vatCents, 0, reason: 'seed $kSeed case $i');
        expect(split.netCents, gross, reason: 'seed $kSeed case $i');
      }
    });

    test('a bigger gross never yields a smaller net at the same rate', () {
      final random = Random(kSeed + 2);
      for (var i = 0; i < kCases; i++) {
        final a = random.nextInt(1000000);
        final b = a + random.nextInt(10000);
        expect(
          vatSplit(b, 20).netCents,
          greaterThanOrEqualTo(vatSplit(a, 20).netCents),
          reason: 'seed $kSeed case $i: $a -> $b went backwards',
        );
      }
    });
  });

  group('an expense is split, never created', () {
    RepartitionMember member(int i, Random random) => (
          id: 'm$i',
          name: 'Member $i',
          subscriptionPct: random.nextInt(101),
          usageDays: random.nextInt(31),
          customWeight: random.nextInt(11),
        );

    test('the shares add up to the amount EXACTLY, for every method, '
        'every size of community and every amount', () {
      final random = Random(kSeed + 3);
      for (var i = 0; i < kCases; i++) {
        final people = 1 + random.nextInt(40);
        final members = [for (var m = 0; m < people; m++) member(m, random)];
        final method =
            RepartitionMethod.values[random.nextInt(RepartitionMethod.values.length)];
        final amount = random.nextInt(2000000) - 1000000;

        final shares = distributeExpense(
          amountCents: amount,
          members: members,
          method: method,
        );
        if (shares.isEmpty) continue; // nobody had a weight, or amount 0

        final total = shares.fold<int>(0, (s, r) => s + r.amountCents);
        expect(
          total,
          amount,
          reason: 'seed $kSeed case $i: $amount over $people members by '
              '${method.name} distributed to $total. The shares become '
              'ledger charges, and a cent lost here is a cent the '
              'community paid and nobody owes.',
        );
      }
    });

    test('every share carries the sign of the amount — a reversal is all '
        'credits and never a mix', () {
      final random = Random(kSeed + 4);
      for (var i = 0; i < kCases; i++) {
        final people = 1 + random.nextInt(20);
        final members = [for (var m = 0; m < people; m++) member(m, random)];
        final amount = -(1 + random.nextInt(500000));
        final shares = distributeExpense(
          amountCents: amount,
          members: members,
          method: RepartitionMethod.equal,
        );
        for (final share in shares) {
          expect(share.amountCents, lessThanOrEqualTo(0),
              reason: 'seed $kSeed case $i: a reversal produced a CHARGE');
        }
      }
    });

    test('reversing a split gives back exactly what the split took', () {
      final random = Random(kSeed + 5);
      for (var i = 0; i < kCases; i++) {
        final people = 1 + random.nextInt(25);
        final members = [for (var m = 0; m < people; m++) member(m, random)];
        final amount = 1 + random.nextInt(1000000);
        const method = RepartitionMethod.subscription;

        final charged = distributeExpense(
            amountCents: amount, members: members, method: method);
        final reversed = distributeExpense(
            amountCents: -amount, members: members, method: method);
        if (charged.isEmpty) continue;

        expect(reversed.length, charged.length, reason: 'seed $kSeed case $i');
        for (var s = 0; s < charged.length; s++) {
          expect(
            charged[s].amountCents + reversed[s].amountCents,
            0,
            reason: 'seed $kSeed case $i: member ${charged[s].memberId} was '
                'charged ${charged[s].amountCents} and credited back '
                '${reversed[s].amountCents}. A repartition that does not '
                'undo itself leaves a residue on somebody\'s account for '
                'ever.',
          );
        }
      }
    });
  });

  group('a typed amount survives the round trip', () {
    test('every amount formats to something that parses back to itself', () {
      final random = Random(kSeed + 6);
      for (var i = 0; i < kCases; i++) {
        final minor = random.nextInt(100000000);
        expect(
          parseCentsInput(centsToMajor(minor)),
          minor,
          reason: 'seed $kSeed case $i: $minor rendered as '
              '"${centsToMajor(minor)}" and came back as '
              '${parseCentsInput(centsToMajor(minor))}. Every price field '
              'in the app does exactly this round trip when it opens.',
        );
      }
    });

    test('a comma is a decimal point, the way a French keyboard types it',
        () {
      final random = Random(kSeed + 7);
      for (var i = 0; i < kCases; i++) {
        final minor = random.nextInt(1000000);
        final typed = centsToMajor(minor);
        expect(
          parseCentsInput(typed.replaceAll('.', ',')),
          parseCentsInput(typed),
          reason: 'seed $kSeed case $i: "$typed" and its comma form '
              'disagree',
        );
      }
    });
  });

  group('calendar days are calendar days', () {
    test('adding n days and measuring the gap gives n back, across every '
        'month boundary and both DST edges of a year', () {
      final random = Random(kSeed + 8);
      for (var i = 0; i < kCases; i++) {
        final from = DateTime(
          2024 + random.nextInt(6),
          1 + random.nextInt(12),
          1 + random.nextInt(28),
          random.nextInt(24),
          random.nextInt(60),
        );
        final days = random.nextInt(800) - 400;
        expect(
          calendarDaysBetween(from, addCalendarDays(from, days)),
          days,
          reason: 'seed $kSeed case $i: $from + $days days measured back as '
              '${calendarDaysBetween(from, addCalendarDays(from, days))}. '
              'This pair computes an invoice due date and a payment term, '
              'and #1251 found it off by one twice a year.',
        );
      }
    });

    test('adding zero days changes nothing at all', () {
      final random = Random(kSeed + 9);
      for (var i = 0; i < kCases; i++) {
        final at = DateTime(
          2024 + random.nextInt(6),
          1 + random.nextInt(12),
          1 + random.nextInt(28),
          random.nextInt(24),
        );
        expect(addCalendarDays(at, 0), at, reason: 'seed $kSeed case $i');
      }
    });
  });
}
