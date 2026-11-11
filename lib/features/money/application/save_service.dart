// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3552 — the one write of a service, from the services screen and from the
// setup guide's services step alike: the draft is checked here (a name, a
// price, a duration in range) before anything is sent; the sheet shows each
// problem under its own field.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/commercial_terms_repository.dart';
import '../domain/service_item.dart';
import '../providers/money_queries_providers.dart';

part 'save_service.g.dart';

/// What the editor holds when the owner saves.
class ServiceDraft {
  const ServiceDraft({
    required this.name,
    required this.priceCents,
    this.active = true,
    this.vatRateId = '',
    this.supplyClass = SupplyClass.property,
    this.details = const ServiceDetails(),
    this.durationValid = true,
  });

  final String name;

  /// Null when the typed price is not a price.
  final int? priceCents;
  final bool active;

  /// '' = the workspace's default rate.
  final String vatRateId;
  final SupplyClass supplyClass;
  final ServiceDetails details;

  /// False when the typed duration is not whole minutes in range.
  final bool durationValid;
}

/// A field of the draft that cannot be saved as it is.
enum ServiceProblem { name, price, duration }

/// The problems of [draft], none when it can be saved.
Set<ServiceProblem> serviceProblems(ServiceDraft draft) => {
  if (draft.name.trim().isEmpty) ServiceProblem.name,
  if (draft.priceCents == null || draft.priceCents! < 0) ServiceProblem.price,
  if (!draft.durationValid) ServiceProblem.duration,
};

class SaveService {
  const SaveService(this._terms);
  final CommercialTermsRepository _terms;

  /// Creates [draft] in [workspaceId]'s catalogue, or updates [serviceId].
  /// Throws [ArgumentError] for a draft with problems: nothing is sent.
  Future<ServiceItem> save(
    String workspaceId,
    ServiceDraft draft, {
    String? serviceId,
  }) {
    if (serviceProblems(draft).isNotEmpty) {
      throw ArgumentError('the service draft has problems');
    }
    final vat = draft.vatRateId.isEmpty ? null : draft.vatRateId;
    return serviceId == null
        ? _terms.createService(
            workspaceId,
            name: draft.name.trim(),
            priceCents: draft.priceCents!,
            vatRateId: vat,
            supplyClass: draft.supplyClass,
            details: draft.details,
          )
        : _terms.updateService(
            serviceId,
            ServiceChange(
              name: draft.name.trim(),
              priceCents: draft.priceCents,
              active: draft.active,
              vatRateId: draft.vatRateId,
              supplyClass: draft.supplyClass,
              details: draft.details,
            ),
          );
  }
}

/// The one write of a service.
@riverpod
SaveService saveService(Ref ref) =>
    SaveService(ref.watch(commercialTermsProvider));
