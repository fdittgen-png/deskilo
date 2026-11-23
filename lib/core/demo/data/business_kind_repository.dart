// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3550 — the Demo's kinds of business: the rows 0703 seeds (and 0834's
// freelancer), with the profiles 0709 and 0834 give them. The kind is kept in the Demo's settings, as the
// server keeps it in the registry.
import '../../../features/workspace/domain/business_kind.dart';
import '../../../features/workspace/domain/business_profile.dart';
import '../../settings/settings.dart';

/// The profile of a kind without places (#3863: the Demo practice is
/// seeded with it).
const demoNoPlacesProfile = {
  'placeBooking': false,
  'moneyTab': true,
  'services': true,
  'invoicing': true,
  'onlinePayments': true,
  'messagesHub': true,
  'publicListings': true,
};

/// #4365 — the shop's profile: the stock, the catalogue and the purchases, no places, no provider, no public page.
const demoShopProfile = {
  'placeBooking': false,
  'moneyTab': true,
  'services': true,
  'invoicing': true,
  'purchases': true,
  'purchaseOrders': true,
  'stockManagement': true,
  'stockReceiving': true,
  'stockTakeOut': true,
  'stockLots': true,
  'stockReorder': true,
  'stockItemGroups': true,
  'stockScanning': true,
};

/// #4168 — the freelancer's profile: the money side of a one-person service
/// business, no places, no provider, no messages, no public page.
const demoFreelancerProfile = {
  'placeBooking': false,
  'moneyTab': true,
  'services': true,
  'invoicing': true,
  'billingCustomers': true,
  'customerQuotes': true,
  'standaloneInvoicing': true,
  'serviceFulfilment': true,
  'purchases': true,
};

class DemoBusinessKindRepository implements BusinessKindRepository {
  const DemoBusinessKindRepository(this._settings);

  final SettingsStore _settings;

  @override
  Future<List<BusinessKind>> kinds() async => const [
    BusinessKind(code: 'coworking', sortOrder: 10),
    BusinessKind(code: 'studio', sortOrder: 20, profile: demoNoPlacesProfile),
    BusinessKind(code: 'practice', sortOrder: 30, profile: demoNoPlacesProfile),
    BusinessKind(code: 'salon', sortOrder: 40, profile: demoNoPlacesProfile),
    BusinessKind(code: 'freelancer', sortOrder: 45, profile: demoFreelancerProfile),
    BusinessKind(code: 'shop', sortOrder: 47, profile: demoShopProfile),
    BusinessKind(code: 'service', sortOrder: 50, profile: demoNoPlacesProfile),
  ];

  @override
  Future<void> setKind(
    String workspaceId, {
    required String kind,
    required List<String> moreKinds,
  }) async {
    await _settings.setValue(
      workspaceId: workspaceId,
      key: businessKindKey,
      value: kind,
    );
    await _settings.setValue(
      workspaceId: workspaceId,
      key: businessMoreKindsKey,
      value: [
        for (final k in moreKinds)
          if (k != kind) k,
      ].join(','),
    );
  }

  @override
  Future<BusinessKindApplied> applyKind(
    String workspaceId, {
    required String requestId,
    required ReviewedKind reviewed,
    required Map<String, bool> flags,
    required Map<String, bool> expected,
  }) => throw const BusinessKindApplyUnsupported();
}
