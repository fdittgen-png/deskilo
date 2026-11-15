// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3958 — what the reference business holds so that each of its features has a
// use case a persona can perform: the WhatsApp group, the plan and the booking
// rules, the saved invoice template, the online payments, the e-invoice
// channel, the customer who has no address, and the configuration a file carries. One function, called once by
// the fixture after its money is complete, so a use case added here never
// lengthens the fixture's own build.
import '../data/floor_plan_repository.dart';
import '../data/money/demo_outbox.dart' show demoMemberWithoutAddress;
import '../data/money_repository.dart';
import '../data/stores.dart' show InMemoryWorkspaceImport;
import '../data/workspace_repository.dart';
import 'demo_documents_seed.dart';
import 'demo_einvoice_seed.dart';
import 'demo_payment_seed.dart';
import 'demo_plan_booking_seed.dart';
import 'demo_whatsapp_seed.dart';

/// Seeds the use cases of the reference business over its finished stores.
void seedDemoUseCases({
  required FakeWorkspaceRepository workspaces,
  required FakeFloorPlanRepository floorPlan,
  required FakeMoneyRepository money,
  required DateTime now,
}) {
  seedDemoWhatsappGroup(workspaces); // #3963
  // #3960 — one customer has no address on file (demo_outbox.dart).
  workspaces.memberEmails.remove(demoMemberWithoutAddress);
  seedDemoPlanAndRules(workspaces, floorPlan); // #3964
  seedDemoInvoiceTemplate(money); // #3964
  seedDemoOnlinePayments(money, now); // #3961
  seedDemoEInvoiceChannel(money, now); // #3963
}

/// #3964 — the configuration the reference business exports to a file and a
/// second business reads: its fee bands, as the tree the server's export hands
/// back, so the export is the business's own records and not an empty file.
///
/// #4028 — each business's export states its currency and country, and a
/// file from a business counting in another currency is fenced on import.
InMemoryWorkspaceImport demoConfigurationImport(
        FakeMoneyRepository money, FakeWorkspaceRepository workspaces) =>
    InMemoryWorkspaceImport(placeOf: (id) {
      for (final w in workspaces.workspaces) {
        if (w.id == id) return (currency: w.currencyCode, country: w.countryCode);
      }
      return null;
    })
      ..configurations['ws-1'] = {
        'tables': {
          'fee_bands': [
            for (final b in money.feeBands)
              {
                'from_pct': b.fromPct,
                'to_pct': b.toPct,
                'fee_cents': b.feeCents,
                'overage_fee_cents': b.overageFeeCents,
              },
          ],
        },
      };
