// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/money/domain/counter_till.dart';
import 'package:deskilo/features/money/domain/embedded_till_profile.dart';
import 'package:deskilo/features/money/domain/embedded_till_values.dart';

/// Exports a bounded diagnostic profile from the current till's key shape.
void main(List<String> args) {
  if (args.length == 3 && args.first == 'line-total') {
    final total = embeddedLineTotal(args[1], args[2]);
    if (total == null) {
      stderr.writeln('line_refused');
      exitCode = 1;
    } else {
      stdout.writeln(total);
    }
    return;
  }
  if (args.length != 2) {
    stderr.writeln(
      'usage: dart run tool/embedded_till_profile.dart <source.json> <profile.json> | line-total <minor> <quantity>',
    );
    exitCode = 64;
    return;
  }
  try {
    final input = File(args[0]).readAsStringSync();
    if (utf8.encode(input).length > EmbeddedTillLimits.responseBytes)
      throw const FormatException('payload_too_large');
    final source = (jsonDecode(input) as Map).cast<String, Object?>();
    final profile = EmbeddedTillProfile.project(
      profileId: source['profile_id']! as String,
      revision: source['revision']! as int,
      currency: source['currency']! as String,
      minorDigits: source['minor_digits']! as int,
      keys: [
        for (final raw in source['keys']! as List)
          _key((raw as Map).cast<String, Object?>()),
      ],
    );
    File(args[1]).writeAsStringSync('${profile.encode()}\n');
    stdout.writeln(
      'profile_valid pages=${profile.pageCount} keys=${profile.keyCount} financial_actions_enabled=false',
    );
  } on EmbeddedTillProfileRefused catch (error, stack) {
    stderr.writeln('profile_refused: ${error.code}');
    stderr.writeln(stack);
    exitCode = 65;
  } on Object catch (error, stack) {
    stderr.writeln('profile_refused: $error');
    stderr.writeln(stack);
    exitCode = 1;
  }
}

TillKey _key(Map<String, Object?> value) {
  int? gross;
  if (value.containsKey('gross_minor')) {
    final raw = value['gross_minor'];
    final parsed = raw is String ? embeddedMinorOf(raw) : null;
    if (parsed == null || parsed.isNegative)
      throw const FormatException('invalid_money');
    gross = parsed.toInt();
    if (BigInt.from(gross) != parsed)
      throw const FormatException('invalid_money');
  }
  return TillKey(
    id: value['id']! as String,
    name: value['name']! as String,
    unit: value['unit']! as String,
    grossMinor: gross,
  );
}
