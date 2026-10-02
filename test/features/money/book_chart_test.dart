// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1869 B — the chart of accounts of one issuer and the accounts each
// posting role maps to: codes are strings (leading zeroes kept), an
// account's type and whether it posts are distinct facts, a role maps
// only to a posting account of a type that fits it, mappings are
// versioned from a date, and a local book cannot start before its
// required roles are mapped. Expectations written by hand.
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/vat_regime.dart';
import 'package:flutter_test/flutter_test.dart';

BookAccount account(
  String id,
  String code,
  AccountType type, {
  bool posting = true,
  String issuer = 's1',
}) => BookAccount(
  id: id,
  workspaceId: 'ws',
  issuerSiteId: issuer,
  code: code,
  name: 'Account $code',
  type: type,
  isPosting: posting,
  origin: AccountOrigin.manual,
  revision: 1,
);

BookMapping mapping(
  BookRole role,
  String accountId,
  DateTime from, {
  String issuer = 's1',
}) => BookMapping(
  id: '${role.name}-$from',
  workspaceId: 'ws',
  issuerSiteId: issuer,
  role: role,
  accountId: accountId,
  effectiveFrom: from,
  revision: 1,
);

void main() {
  group('accounts', () {
    test('a code is a string: leading zeroes survive', () {
      final a = account('a', '0411', AccountType.asset);
      expect(validateBookAccount(a), isEmpty);
      expect(BookAccount.fromJson(a.toJson()).code, '0411');
    });

    test('a code is short and plain; a name is not empty', () {
      expect(validateBookAccount(account('a', '41 1', AccountType.asset)), [
        BookAccountProblem.invalidCode,
      ]);
      expect(validateBookAccount(account('a', '', AccountType.asset)), [
        BookAccountProblem.invalidCode,
      ]);
      expect(
        validateBookAccount(
          const BookAccount(
            id: 'a',
            workspaceId: 'ws',
            issuerSiteId: 's1',
            code: '411',
            name: ' ',
            type: AccountType.asset,
            isPosting: true,
            origin: AccountOrigin.manual,
            revision: 0,
          ),
        ),
        [BookAccountProblem.nameMissing],
      );
    });
  });

  group('mappings', () {
    final accounts = [
      account('cust', '411000', AccountType.asset),
      account('rev', '706000', AccountType.income),
      account('bank', '512000', AccountType.asset),
      account('group', '41', AccountType.asset, posting: false),
      account('other', '411000', AccountType.asset, issuer: 's2'),
    ];

    test('a role maps to a posting account of a type that fits it', () {
      expect(mappingProblem(BookRole.customers, accounts[0], 's1'), isNull);
      expect(
        mappingProblem(BookRole.revenue, accounts[0], 's1'),
        BookMappingProblem.typeMismatch,
      );
      expect(
        mappingProblem(BookRole.customers, accounts[3], 's1'),
        BookMappingProblem.notPosting,
      );
      expect(
        mappingProblem(BookRole.customers, accounts[4], 's1'),
        BookMappingProblem.otherIssuer,
        reason: 'one issuer never books into another issuer\'s chart',
      );
    });

    test('the mapping in force is the latest by the day, per issuer', () {
      final versions = [
        mapping(BookRole.revenue, 'rev', DateTime(2026, 1, 1)),
        mapping(BookRole.revenue, 'rev2', DateTime(2026, 7, 1)),
        mapping(BookRole.revenue, 'x', DateTime(2025, 1, 1), issuer: 's2'),
      ];
      expect(
        mappingOn(
          versions,
          's1',
          BookRole.revenue,
          DateTime(2026, 6, 30),
        )?.accountId,
        'rev',
      );
      expect(
        mappingOn(
          versions,
          's1',
          BookRole.revenue,
          DateTime(2026, 7, 1),
        )?.accountId,
        'rev2',
      );
      expect(
        mappingOn(versions, 's1', BookRole.revenue, DateTime(2025, 6, 1)),
        isNull,
      );
    });

    test('a local book needs customers, revenue and bank mapped', () {
      final day = DateTime(2026, 7, 1);
      expect(missingForLocalBook(const [], 's1', day), [
        BookRole.customers,
        BookRole.revenue,
        BookRole.bank,
      ]);
      final mapped = [
        mapping(BookRole.customers, 'cust', DateTime(2026, 1, 1)),
        mapping(BookRole.revenue, 'rev', DateTime(2026, 1, 1)),
        mapping(BookRole.bank, 'bank', DateTime(2026, 8, 1)),
      ];
      expect(missingForLocalBook(mapped, 's1', day), [
        BookRole.bank,
      ], reason: 'a mapping from August does not cover July');
      expect(missingForLocalBook(mapped, 's2', day), [
        BookRole.customers,
        BookRole.revenue,
        BookRole.bank,
      ]);
    });
  });

  test('the suggested chart is a set of drafts to review, not a guess '
      'written into the book', () {
    final drafts = suggestedAccounts(
      workspaceId: 'ws',
      issuerSiteId: 's1',
      countryCode: 'FR',
      regime: VatRegime.vatRegistered,
    );
    expect(drafts.map((a) => (a.code, a.type)), [
      ('411000', AccountType.asset),
      ('706000', AccountType.income),
      ('512000', AccountType.asset),
      ('445710', AccountType.liability),
      ('606000', AccountType.expense),
    ]);
    expect(drafts.every((a) => a.origin == AccountOrigin.suggested), isTrue);
    expect(
      drafts.every((a) => a.revision == 0),
      isTrue,
      reason: 'nothing saved until someone reviews it',
    );
    expect(
      suggestedAccounts(
        workspaceId: 'ws',
        issuerSiteId: 's1',
        countryCode: 'FR',
        regime: VatRegime.notSubject,
      ).map((a) => a.code),
      isNot(contains('445710')),
      reason: 'no output-VAT account where no VAT is charged',
    );
  });
}
