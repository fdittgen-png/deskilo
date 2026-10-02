// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2014 B — a retried payment sends the same request id; only a
// definitive answer makes the next attempt a new request.
import 'package:deskilo/features/money/domain/payment_provider.dart';
import 'package:deskilo/features/money/domain/payment_request_ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var n = 0;
  PaymentRequestIds ids() => PaymentRequestIds(() => 'id-${++n}');
  const p = PaymentProvider.stripe;

  test('the same payment keeps its id; another payment gets its own', () {
    final r = ids();
    final a = r.idFor('ws', 'm', p, '2026-10', 2500);
    expect(r.idFor('ws', 'm', p, '2026-10', 2500), a);
    expect(r.idFor('ws', 'm', p, '2026-10', 2600), isNot(a));
    expect(
      r.idFor('ws', 'm', PaymentProvider.paypal, '2026-10', 2500),
      isNot(a),
    );
  });

  test('an unknown outcome keeps the id, a definitive answer drops it', () {
    final r = ids();
    final a = r.idFor('ws', 'm', p, '2026-10', 2500);
    for (final e in [
      const PaymentGatewayException(503, 'outcome_unknown'),
      const PaymentGatewayException(500, 'intent_insert_failed'),
      Exception('socket'),
    ]) {
      r.afterError('ws', 'm', p, '2026-10', 2500, e);
      expect(r.idFor('ws', 'm', p, '2026-10', 2500), a, reason: '$e');
    }
    r.afterError(
      'ws',
      'm',
      p,
      '2026-10',
      2500,
      const PaymentGatewayException(409, 'intent_failed'),
    );
    expect(r.idFor('ws', 'm', p, '2026-10', 2500), isNot(a));
  });

  test('a provider refusal (502) is definitive', () {
    expect(
      PaymentRequestIds.isDefinitive(
        const PaymentGatewayException(502, 'provider_error'),
      ),
      isTrue,
    );
  });

  test(
    'run reuses the id after an unknown outcome, not after a refusal',
    () async {
      final r = ids();
      final seen = <String>[];
      Future<void> attempt(int status) async {
        try {
          await r.run<void>('ws', 'm', p, '2026-10', 2500, (id) async {
            seen.add(id);
            throw PaymentGatewayException(status, 'x');
          });
        } on PaymentGatewayException {
          // expected: every attempt fails
        }
      }

      await attempt(503);
      await attempt(409);
      await attempt(503);
      expect(seen[1], seen[0]);
      expect(seen[2], isNot(seen[0]));
    },
  );
}
