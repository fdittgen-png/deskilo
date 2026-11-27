// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4452 (E01A) -- what the embedded till terminal and the Deskilo adapter agree on before any sale: the protocol version, the
// capabilities a profile needs, the technical ceilings of one exchange, the money and quantity forms, and the three kinds of
// answer to a request (refused, uncertain, unsupported). The wire is an allowlist: an unknown major, a required capability the
// terminal lacks, an unknown kind or state is refused BEFORE a payment, and only an explicitly optional additive field is
// ignored. See docs/design/embedded-till-contract.md; the fixtures in contracts/embedded_till/v1 are what every language runs.

import '../../../core/failure/app_failure.dart' show TypedRefusal;

/// The protocol major this code speaks; a document of another major is refused.
const int terminalProtocolMajor = 1;

/// The highest minor this code reads; a lower minor of the same major is read, a higher one is read for what it names.
const int terminalProtocolMinor = 0;

/// The conservative technical ceilings of one exchange (memory, not business limits); E02 measures them before activation.
abstract final class TerminalBounds {
  static const int requestBytes = 8 * 1024;
  static const int responseBytes = 16 * 1024;
  static const int catalogueEntriesPerPage = 24;
  static const int keysPerPage = 8;
  static const int profilePages = 12;
  static const int labelBytes = 48;
}

/// What a profile may ask of a terminal: the terminal says which it implements, the profile which it requires.
enum TerminalCapability {
  basket('basket'),
  quantityKeypad('quantity_keypad'),
  cash('cash'),
  nextCustomer('next_customer'),
  categoryPages('category_pages'),
  tillSession('till_session'),
  cashMovement('cash_movement'),
  drawerCommand('drawer_command'),
  offlineCash('offline_cash');

  const TerminalCapability(this.wire);

  final String wire;

  static TerminalCapability? of(String wire) {
    for (final c in values) {
      if (c.wire == wire) return c;
    }
    return null;
  }
}

/// The capabilities of the first connected checkpoint: every profile of it needs exactly these.
const Set<TerminalCapability> connectedCheckoutCapabilities = {
  TerminalCapability.basket,
  TerminalCapability.quantityKeypad,
  TerminalCapability.cash,
  TerminalCapability.nextCustomer,
  TerminalCapability.categoryPages,
};

/// How a request ended, for the terminal: the server said no (nothing happened), the answer is not known (it may have
/// happened: the same request is reconciled, never made again), the exchange does not fit a ceiling, or the two sides do not
/// speak the same protocol.
enum TerminalOutcome { refused, uncertain, capacity, unsupported }

/// A document the terminal contract refuses, with the class of the answer and a stable code the fixtures name.
class TerminalContractRefused implements TypedRefusal {
  const TerminalContractRefused(this.outcome, this.code);

  final TerminalOutcome outcome;
  final String code;

  @override
  String toString() => 'TerminalContractRefused(${outcome.name}, $code)';
}

final RegExp _amountShape = RegExp(r'^(0|-?[1-9][0-9]{0,18})$');
final RegExp _quantityShape = RegExp(r'^[0-9]{1,12}(\.[0-9]{1,6})?$');
final BigInt _int64Max = BigInt.parse('9223372036854775807');
final BigInt _int64Min = BigInt.parse('-9223372036854775808');

/// An amount in minor units as a decimal string, checked to fit a signed 64-bit integer; null when it is not one.
BigInt? terminalAmountOf(String? text) {
  if (text == null || !_amountShape.hasMatch(text)) return null;
  final v = BigInt.parse(text);
  return v > _int64Max || v < _int64Min ? null : v;
}

/// The decimal digits of a currency's minor unit the terminal accepts: 0, 2 or 3 (the exponents of the currencies in use).
bool terminalExponentOk(int? exponent) => exponent == 0 || exponent == 2 || exponent == 3;

/// An exact quantity as the till writes it: up to 12 whole digits and 6 decimals, above zero; null when it is not one.
String? terminalQuantityOf(String? text) {
  if (text == null || !_quantityShape.hasMatch(text)) return null;
  return text.replaceAll('.', '').replaceAll('0', '').isEmpty ? null : text;
}

/// The sum of two amounts, or null when it leaves the signed 64-bit range: a total is checked, never wrapped.
BigInt? terminalAmountSum(BigInt a, BigInt b) {
  final s = a + b;
  return s > _int64Max || s < _int64Min ? null : s;
}

/// Checks the protocol and the capabilities of a document against what the terminal [implements].
/// Throws [TerminalContractRefused] (unsupported) for another major or a required capability that is unknown or not implemented.
void checkProtocol(Map<String, Object?> document, Set<TerminalCapability> implements) {
  final protocol = document['protocol'];
  if (protocol is! Map || protocol['major'] is! int || protocol['minor'] is! int) {
    throw const TerminalContractRefused(TerminalOutcome.unsupported, 'protocol_missing');
  }
  if (protocol['major'] != terminalProtocolMajor) {
    throw const TerminalContractRefused(TerminalOutcome.unsupported, 'protocol_major');
  }
  final required = document['capabilities_required'];
  if (required is! List) throw const TerminalContractRefused(TerminalOutcome.unsupported, 'capabilities_missing');
  for (final c in required) {
    final known = c is String ? TerminalCapability.of(c) : null;
    if (known == null) throw const TerminalContractRefused(TerminalOutcome.unsupported, 'capability_unknown');
    if (!implements.contains(known)) throw const TerminalContractRefused(TerminalOutcome.unsupported, 'capability_not_implemented');
  }
}
