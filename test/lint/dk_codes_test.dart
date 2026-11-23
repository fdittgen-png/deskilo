// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3811 (part of #3657, i18n I11c) -- no DK code goes unread. Every code a
// migration raises (`using errcode = 'DK…'`) is either read by the app by its
// code, or named below as one a person never meets in the app, with its
// reason. A new refusal therefore arrives with words in the five languages,
// or with a stated reason why it needs none.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/build_dk_codes.dart';
import 'lint_sources.dart';

/// Codes the app does not read, each with its reason. A name here must be
/// raised by some migration and read by no app file.
const _notForTheApp = <String, String>{
  'DKL03':
      'the server\'s guard that a finalized counter receipt, its lines and a tender\'s amount are never edited: '
      'no screen edits them, and a correction is a new receipt (0893)',
  'DKL09':
      'the versioned reader of a frozen counter receipt refusing a version it does not know: a reader\'s guard, '
      'never a user action (0893)',
  'DKGZZ':
      'a preview marker: the group and item-move functions raise it inside their own block to roll '
      'a preview back, and catch it there (0883)',
  'DKC14':
      'a payment claim naming a standalone invoice: the app offers no payment '
      'of one until the payment part of #4165 (B), where its words are '
      'mapped; the refusal is the server\'s guard for any other caller (0820)',
  'DKH01':
      'a billing-access code that cannot be used: the app offers the customer invitation in #4164 B2, where its '
      'words are mapped; the refusal is the server\'s guard for any other caller (0910)',
  'DKH02':
      'a billing-access invitation for a member: the seller\'s invitation screen arrives in #4164 B2 and offers it '
      'for billing customers only; the refusal is the server\'s guard (0910)',
  'DKH03':
      'revoking an unknown grant: the B2 screens name only grants they listed; the server\'s guard (0910)',
  'DKH04':
      'a revocation reason over 500 characters: the B2 form limits the field to that width; the server\'s guard (0910)',
  'DKH05':
      'a request id reused for another invitation: the app draws a fresh id per invitation; the server\'s guard (0910)',
  'DKC16':
      'a standalone payment naming a monthly invoice: the app offers no '
      'standalone payment until the client part of #4165 (B2), where its '
      'words are mapped; the refusal is the server\'s guard for any other caller (0901)',
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

/// #4415 -- RATCHET: how many codes a person never meets in the app. A new
/// refusal arrives with its words; this list only shortens.
const _notForTheAppCeiling = 20;

final _raised = RegExp(
  r"errcode\s*=\s*'(DK[A-Z0-9]{3})'"
  r"|\brefuse\(\s*'(DK[A-Z0-9]{3})'",
);

/// The DK codes [sql] raises: with `errcode = 'DK…'`, or through `public.refuse('DK…', …)` (#4415).
Set<String> raisedIn(String sql) => {
  for (final m in _raised.allMatches(sql)) (m.group(1) ?? m.group(2))!,
};
final _read = RegExp(r"'(DK[A-Z0-9]{3})'");
final _readConstant = RegExp(r'\bDkCode\.(dk[a-z0-9]{3})\b');

/// The DK codes [source] reads: quoted, or by their `DkCode` constant (#4417).
Set<String> readIn(String source) {
  // a mention in a comment reads nothing
  final code = source
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .map((l) => l.split(' //').first)
      .join('\n');
  return {
    for (final m in _read.allMatches(code)) m.group(1)!,
    for (final m in _readConstant.allMatches(code)) m.group(1)!.toUpperCase(),
  };
}

void main() {
  final raised = <String>{
    for (final f in sqlFiles('supabase/migrations'))
      ...raisedIn(f.readAsStringSync()),
  };
  final read = <String>{
    for (final f in handWrittenDartFiles('lib'))
      // the generated constants file names every code: it is no reader (#4417)
      if (!f.path.endsWith('lib/core/codes/dk_code.dart'))
        ...readIn(f.readAsStringSync()),
  };

  test('DkCode holds exactly the codes the migrations raise (SQL and Dart cannot differ)', () {
    final generated = File('lib/core/codes/dk_code.dart').readAsStringSync();
    final fromSql = raisedCodes('supabase/migrations');
    final inDart = RegExp(r"static const \w+ = '(DK[A-Z0-9]{3})';")
        .allMatches(generated)
        .map((m) => m.group(1)!)
        .toSet();
    expect(
      fromSql.toSet().difference(inDart),
      isEmpty,
      reason: 'a code the migrations raise is missing from DkCode: dart run tool/build_dk_codes.dart',
    );
    expect(
      inDart.difference(fromSql.toSet()),
      isEmpty,
      reason: 'DkCode holds a code no migration raises: dart run tool/build_dk_codes.dart',
    );
    expect(generated, dkCodeSource(fromSql), reason: 'dk_code.dart is not the generator\'s output');
  });

  test('a code is read quoted or by its constant', () {
    expect(readIn("case 'DKN01':"), {'DKN01'});
    expect(readIn('case DkCode.dkn01: x(DkCode.dkg07);'), {'DKN01', 'DKG07'});
    expect(readIn('final DkCodex = 1;'), isEmpty);
    expect(readIn("// DkCode.dkn01 and 'DKG07' in a comment\nfinal x = 1; // DkCode.dkg04"), isEmpty);
  });

  test('a code is raised by errcode or through the refusal helper', () {
    expect(raisedIn("raise exception 'x' using errcode = 'DKG07';"), {'DKG07'});
    expect(raisedIn("perform public.refuse('DKG11', '{}'::jsonb, 'w');"), {'DKG11'});
    expect(raisedIn("perform refuse(\n  'DKL12', null);"), {'DKL12'});
    expect(raisedIn("select 'DKG99' as note;"), isEmpty);
  });

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

  test('the list of codes the app does not read holds its ceiling', () {
    expect(
      _notForTheApp.length,
      lessThanOrEqualTo(_notForTheAppCeiling),
      reason: 'give the new refusal its words instead of naming it here (#4415)',
    );
    expect(
      _notForTheApp.length,
      _notForTheAppCeiling,
      reason: 'it fell: lower _notForTheAppCeiling to ${_notForTheApp.length}',
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
