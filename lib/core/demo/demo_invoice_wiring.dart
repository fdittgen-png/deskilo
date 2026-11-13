// SPDX-License-Identifier: AGPL-3.0-or-later
// Newly issued demo invoices freeze the same business, buyer and actor that
// the current workspace and profile screens display.
import 'data/money/demo_invoice_identity.dart';
import 'data/profile_repository.dart';
import 'data/workspace_repository.dart';
import 'demo_personal_space.dart';

void wireDemoInvoiceIdentities(
  List<DemoPersonalSpace> spaces,
  FakeProfileRepository profiles,
  String Function() actor,
) {
  for (final space in spaces) {
    space.money.invoiceIdentity = (workspaceId, memberId) {
      final member = space.workspaces.memberOf(memberId);
      if (member == null || member.workspaceId != workspaceId) {
        throw StateError('the invoice buyer must belong to its business');
      }
      return demoInvoiceIdentityFor(space.workspaces, memberId: memberId,
        actorMemberId: actor(), profile: profiles.profiles
          .where((p) => p.id == member.userId).firstOrNull);
    };
  }
}
