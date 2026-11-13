// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3650 — a link for calling or messaging is built from a validated
// international number, and only in lib/core/phone/phone_entry.dart
// (whatsappLink, smsLink, telLink, and the shares that carry no number).
// A wa.me, sms: or tel: link written anywhere else could reach a number
// nobody validated: the national "06…" stored with a + in front once led
// to a chat that did not exist.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

const _helper = 'lib/core/phone/phone_entry.dart';

final _link = RegExp(r"""wa\.me|scheme:\s*'(?:sms|tel)'|['"](?:sms|tel):""");

void main() {
  test('no wa.me, sms: or tel: link is built outside the phone helper', () {
    final outside = [
      for (final f in handWrittenDartFiles('lib'))
        if (f.path.replaceAll(r'\', '/') case final path
            when !path.endsWith(_helper) && !path.contains('/l10n/'))
          for (final (i, line) in File(path).readAsLinesSync().indexed)
            if (_link.hasMatch(line) && !line.trimLeft().startsWith('//'))
              '$path:${i + 1}: ${line.trim()}',
    ];
    expect(
      outside,
      isEmpty,
      reason: 'build calling and messaging links with whatsappLink, smsLink '
          'or telLink from $_helper: they open only a validated number',
    );
  });

  test('the helper still builds them (the lint reads a real file)', () {
    expect(_link.hasMatch(File(_helper).readAsStringSync()), isTrue);
  });
}
