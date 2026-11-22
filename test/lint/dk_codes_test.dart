// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3811 (part of #3657, i18n I11c) -- no DK code goes unread. Every code a
// migration raises (`using errcode = 'DK…'`) is either read by the app by its
// code, or named below as one a person never meets in the app, with its
// reason. A new refusal therefore arrives with words in the five languages,
// or with a stated reason why it needs none.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Codes the app does not read, each with its reason. A name here must be
/// raised by some migration and read by no app file.
const _notForTheApp = <String, String>{
  'DKGZZ':
      'a preview marker: the group and item-move functions raise it inside their own block to roll '
      'a preview back, and catch it there (0883)',
  'DKC14':
      'a payment claim naming a standalone invoice: the app offers no payment '
      'of one until the payment part of #4165 (B), where its words are '
      'mapped; the refusal is the server\'s guard for any other caller (0820)',
  'DKP02':
      'the app offers no plan to add to a room since plans are retired '
      '(#4042); a room keeps the plans it named already',
  'DKI02':
      'a dry-run marker: create_invoice_readiness raises it inside its '
      'own block and catches it there (0416)',
  'DKP01':
      'a probe marker: the membership-plan check raises it inside its '
      'own block and catches it there (0638)',
  'DKS01':
      'an answer to an assistant: a setup step that takes credentials '
      'is for the person in the app, never the assistant (0555)',
  'DKT01':
      'an answer to an assistant: a dated plan change the command would '
      'refuse is refused before the person is asked; the confirmation '
      'target raises it with the command\'s own reason, mcp_confirm '
      'answers it as conflict/refused and the assistant reads the reason '
      '(0817)',
  'DKU01':
      'a guard no screen offers: a billing customer is never given a '
      'booking, badge, role, plan, door or community place; the tables '
      'and members refuse it (0821)',
  'DKQ01':
      'a guard behind the quote screens (#4166 cut 2): the quote it names '
      'is chosen from the business\'s own list (0828)',
  'DKQ09':
      'a guard no screen offers: the invoice draft of a quote changes and '
      'issues only through the quote, never in the invoice editor (0828)',
  'DKR02':
      'an operator\'s refusal: a personal home cannot drop the '
      'workspace host role while it holds workspaces (0559)',
  'DKR03':
      'an operator\'s refusal: only a personal home names itself as one '
      '(0565)',
};

final _raised = RegExp(r"errcode\s*=\s*'(DK[A-Z0-9]{3})'");
final _read = RegExp(r"'(DK[A-Z0-9]{3})'");

void main() {
  final raised = <String>{
    for (final f in sqlFiles('supabase/migrations'))
      for (final m in _raised.allMatches(f.readAsStringSync())) m.group(1)!,
  };
  final read = <String>{
    for (final f in handWrittenDartFiles('lib'))
      for (final m in _read.allMatches(f.readAsStringSync())) m.group(1)!,
  };

  test('every DK code a migration raises is read by the app or named', () {
    final unread = [
      for (final code in raised.toList()..sort())
        if (!read.contains(code) && !_notForTheApp.containsKey(code)) code,
    ];
    expect(
      unread,
      isEmpty,
      reason:
          'map the code to its words in the app (refusal_text.dart, '
          'booking_error_text.dart), or name it in _notForTheApp with '
          'the reason a person never meets it there',
    );
  });

  test('a named code is raised and still unread', () {
    for (final MapEntry(key: code, value: reason) in _notForTheApp.entries) {
      expect(raised, contains(code), reason: '$code: $reason');
      expect(
        read,
        isNot(contains(code)),
        reason: '$code is read by the app now: remove it from the list',
      );
    }
  });
}
