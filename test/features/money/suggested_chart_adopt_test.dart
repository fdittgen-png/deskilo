// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 — taking the suggested chart saves each account and maps it to the
// role it is proposed for, a rate group's account to its qualified role, so
// the posting engine finds every account it books. Expectations by hand.
import 'package:deskilo/core/demo/data/book_profile_repository.dart';
import 'package:deskilo/features/money/application/save_book_profile.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/vat_regime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the German chart is taken whole, the reduced rate on its own '
      'accounts', () async {
    final books = FakeBookProfileRepository();
    final outcome = await BookProfiles(books).adoptSuggested(
      suggestedAccounts(
        workspaceId: 'ws',
        issuerSiteId: 's1',
        countryCode: 'DE',
        regime: VatRegime.vatRegistered,
      ),
      effectiveFrom: DateTime(2026, 10, 21),
      current: const [],
    );
    expect(outcome, BookSaveOutcome.saved);
    String code(String id) => books.accounts.firstWhere((a) => a.id == id).code;
    expect(
      {
        for (final m in books.mappings)
          m.qualifier == null ? m.role.wire : '${m.role.wire}:${m.qualifier}':
              code(m.accountId),
      },
      {
        'customers': '10000',
        'revenue': '8400',
        'bank': '1200',
        'vat_output': '1776',
        'expenses': '4900',
        'suppliers': '70000',
        'vat_input': '1576',
        'write_off': '2400',
        'revenue:reduced': '8300',
        'vat_output:reduced': '1771',
        'vat_input:reduced': '1571',
      },
    );
    expect(
      books.mappings.every(
        (m) => m.effectiveFrom == DateTime.utc(2026, 10, 21),
      ),
      isTrue,
    );
    expect(
      missingForLocalBook(books.mappings, 's1', DateTime.utc(2026, 10, 21)),
      isEmpty,
      reason: 'a local book can start on the chart as taken',
    );
  });

  test('a stale save stops the adoption', () async {
    final books = FakeBookProfileRepository();
    final suggested = suggestedAccounts(
      workspaceId: 'ws',
      issuerSiteId: 's1',
      countryCode: 'FR',
      regime: VatRegime.vatRegistered,
    );
    final first = suggested.first;
    final stale = (
      account: BookAccount(
        id: 'gone',
        workspaceId: 'ws',
        issuerSiteId: 's1',
        code: first.account.code,
        name: first.account.name,
        type: first.account.type,
        isPosting: true,
        origin: AccountOrigin.suggested,
        revision: 3,
      ),
      role: first.role,
      qualifier: first.qualifier,
    );
    expect(
      await BookProfiles(books).adoptSuggested(
        [stale, ...suggested.skip(1)],
        effectiveFrom: DateTime(2026, 10, 21),
        current: const [],
      ),
      BookSaveOutcome.stale,
    );
    expect(books.accounts, isEmpty);
  });
}
