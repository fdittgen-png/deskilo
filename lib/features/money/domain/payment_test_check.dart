// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The online-payments step's test (RPC `payment_test_check`): what a
// member's checkout would do with the keys a space holds, read without
// making a payment. It never carries a secret, only a mode per provider,
// and nothing is charged or written while it is read. Whether the
// provider accepts the keys and confirms a payment back is beyond it.
import '../../../core/data/json_reader.dart';
import 'payment_provider.dart';

/// What a provider's stored key says about the money it moves.
enum PaymentKeyMode {
  /// The provider's test mode: no real money moves.
  test,

  /// A live key: a checkout charges a real card.
  live,

  /// A key whose shape names no mode.
  unknown,

  /// The space holds no such field: the installation's own setting
  /// decides, which the test cannot read.
  installation;

  static PaymentKeyMode fromWire(String? name) =>
      values.where((m) => m.name == name).firstOrNull ?? unknown;
}

/// The test's answer for the space as a whole.
enum PaymentTestVerdict {
  /// No provider is connected: there is nothing to test.
  noProvider('no_provider'),

  /// Every provider holds a test key.
  testKeys('test_keys'),

  /// At least one provider holds a live key.
  liveKeys('live_keys'),

  /// Some key could not be read as test or live.
  unverified('unverified');

  const PaymentTestVerdict(this.wireName);

  final String wireName;

  static PaymentTestVerdict fromWire(String? name) =>
      values.where((v) => v.wireName == name).firstOrNull ?? unverified;
}

class PaymentTestCheck {
  const PaymentTestCheck({
    required this.verdict,
    required this.takesPayments,
    this.modes = const {},
  });

  factory PaymentTestCheck.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'payment_test_check');
    return PaymentTestCheck(
      verdict: PaymentTestVerdict.fromWire(r.stringOrNull('verdict')),
      takesPayments: r.boolOr('takes_payments', fallback: false),
      modes: {
        for (final p in r.list('providers').map(JsonReader.of))
          ?PaymentProvider.fromWire(p.stringOrNull('provider')):
              PaymentKeyMode.fromWire(p.stringOrNull('mode')),
      },
    );
  }

  final PaymentTestVerdict verdict;

  /// Whether the space opens payment orders at all: a development space
  /// never does, whatever its keys.
  final bool takesPayments;

  /// The mode of each connected provider's key.
  final Map<PaymentProvider, PaymentKeyMode> modes;
}
