// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3553 — what the Demo's own installation publishes of a business of its
// own, as the server's projection does: its kinds (the primary first), the
// services it marked public (active ones only, at most twelve, in its order,
// each price in the business's own currency with its tax word) and whether
// it takes inquiries. Read live, so a service the owner marks public in
// Services is on the page and in the search at once. Only the business the
// Demo publishes has a page; the others publish nothing.
import '../../../features/directory/domain/public_facets.dart';
import '../../../features/money/domain/service_item.dart';
import '../../../features/workspace/domain/business_profile.dart';
import '../../../features/workspace/domain/workspace.dart';
import '../../../features/workspace/domain/workspace_feature.dart';
import '../data/public_directory_repository.dart';
import '../demo_setting_seed.dart';

/// The services a published card carries at most (the projection's limit).
const int _publishedServices = 12;

/// The tax word of a price of [workspace]: the Demo's houses state their
/// VAT; none of them adds a sales tax to a quoted price.
String _taxTreatment(Workspace workspace) =>
    workspace.vatRegime == 'vat_registered' ? 'included' : 'none';

/// The kinds [workspaceId] carries in the Demo's settings, the primary first;
/// the registry's default where it seeds none.
List<String> _kinds(String workspaceId) {
  final primary = demoSettingSeed
      .where((s) => s.workspaceId == workspaceId && s.key == businessKindKey)
      .map((s) => '${s.value}')
      .firstOrNull;
  return [primary ?? 'coworking'];
}

/// The offer [workspace] publishes, from its [services].
Map<String, Object?> _demoPublicOffer(
  Workspace workspace,
  List<ServiceItem> services,
) {
  final shown = [
    for (final s in services)
      if (s.active && s.isPublic) s,
  ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return {
    'name': workspace.name,
    'kinds': _kinds(workspace.id),
    'services': [
      for (final s in shown.take(_publishedServices))
        {
          'name': s.name,
          if (s.category.trim().isNotEmpty) 'category': s.category,
          'duration_minutes': ?s.durationMinutes,
          'price_minor': s.priceCents,
          'currency': workspace.currencyCode,
          'tax_treatment': _taxTreatment(workspace),
        },
    ],
    'takes_inquiries': effectiveFeatures(
      resolveEnabledFeatures(workspace.featureFlags),
    ).contains(WorkspaceFeature.spaceInquiries),
  };
}

/// A published page and its card carry what the owner marks public in
/// Services, read live: only a business with a page publishes an offer.
void wireDemoPublicOffer(
  FakeDirectoryRepository directory,
  Workspace? Function(String id) workspaceOf,
  Future<List<ServiceItem>> Function(String id) servicesOf,
  Map<String, Object?> Function(String id) bookingRulesOf,
) {
  directory
    ..placeBooking = ((id) {
    final workspace = workspaceOf(id);
    return workspace == null || effectiveFeatures(
      resolveEnabledFeatures(workspace.featureFlags)).contains(WorkspaceFeature.placeBooking);
    })
    ..timezoneOf = ((id) => workspaceOf(id)?.timezone ?? 'UTC')
    ..offer = (id) async {
  final workspace = workspaceOf(id);
  if (workspace == null || !directory.pages.containsKey(id)) return const {};
  final stored = directory.pages[id]!['document'] as Map;
  final hasPlaces = effectiveFeatures(resolveEnabledFeatures(workspace.featureFlags))
      .contains(WorkspaceFeature.placeBooking);
  final rules = bookingRulesOf(id);
  final hours = <String, Object?>{
    'timezone': workspace.timezone,
    if (hasPlaces) ...{
      'weekdays': rules['open_weekdays'],
      'start_minutes': rules['work_start_minutes'],
      'end_minutes': rules['work_end_minutes'],
    } else 'note': stored['opening_hours'],
  };
  return {
    ..._demoPublicOffer(workspace, await servicesOf(id)),
    for (final field in ['amenities', 'accessibility']) field: stored[field],
    'opening_hours': PublicOpeningHours.read(hours) == null ? null : hours,
  };
};
}
