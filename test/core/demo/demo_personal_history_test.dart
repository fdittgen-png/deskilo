// SPDX-License-Identifier: AGPL-3.0-or-later
// History pagination retains equal-time documents from different businesses,
// and reads newly recorded payments without rebuilding the personal reader.
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/core/demo/demo_personal_repositories.dart';
import 'package:deskilo/core/demo/demo_personal_space.dart';
import 'package:deskilo/features/money/domain/account_activity.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

DemoPersonalSpace _business(String id, String currency, DateTime now) {
  final workspace =
      FakeWorkspaceRepository(
          workspaces: [
            Workspace(
              id: id,
              name: id,
              countryCode: 'CH',
              currencyCode: currency,
              timezone: 'Europe/Zurich',
              inviteCode: 'DEMO',
            ),
          ],
        )
        ..myMember = Member(
          id: '$id-member',
          workspaceId: id,
          userId: 'buyer',
          isOwner: false,
          isAdmin: false,
          status: MemberStatus.active,
        );
  final money = FakeMoneyRepository(clock: () => now)
    ..invoiceCommands.currency = currency
    ..invoiceIdentity = (workspaceId, memberId) => (
      memberName: 'Buyer',
      memberAddress: '',
      workspaceName: id,
      workspaceAddress: '',
      issuerName: 'Operator',
      seller: null,
      buyer: null,
    );
  return (workspaces: workspace, money: money);
}

void main() {
  test(
    'equal-time invoices page once; new payments and account changes follow',
    () async {
      final now = DateTime.utc(2027, 2, 9, 10);
      final spaces = [
        _business('first', 'CHF', now),
        _business('second', 'EUR', now),
      ];
      var user = 'buyer';
      final activity = demoPersonalActivity(
        spaces: () => spaces,
        currentUser: () => user,
      );
      final ids = <String>{};
      for (final space in spaces) {
        final member = space.workspaces.myMember;
        for (var index = 0; index < 30; index++) {
          final month = DateTime.utc(now.year, now.month - index);
          ids.add(
            await space.money.createInvoice(
              workspaceId: member.workspaceId,
              memberId: member.id,
              period: yearMonth(month.year, month.month),
            ),
          );
        }
      }
      expect(
        ids.length,
        60,
        reason: 'local counters are qualified by business',
      );
      final invoices = await everyActivityPage(
        (before) => activity.list(AccountActivityKind.invoices, before: before),
      );
      expect(invoices.map((i) => i.id).toSet(), ids);
      expect(invoices.length, ids.length);
      expect(await activity.list(AccountActivityKind.payments), isEmpty);
      spaces.first.money.seedPayment('first-member', 500);
      final payment = (await activity.list(AccountActivityKind.payments))
          .single;
      expect(payment.amountCents, 500);
      expect(payment.currency, 'CHF');
      expect(payment.occurredAt, now);
      user = 'unrelated';
      expect(await activity.list(AccountActivityKind.invoices), isEmpty);
      expect(await activity.list(AccountActivityKind.payments), isEmpty);
      expect((await activity.overview()).invoices, isEmpty);
    },
  );
}
