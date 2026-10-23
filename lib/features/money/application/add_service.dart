// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The services step of the setup guide adds a service through the
// catalogue's own write: a name and the price a member pays, at the
// workspace's default VAT rate and the default place of supply. The
// services screen keeps the rest (rate, place of supply, stock).
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/commercial_terms_repository.dart';
import '../domain/service_item.dart';
import '../providers/money_queries_providers.dart';

part 'add_service.g.dart';

class AddService {
  const AddService(this._terms);
  final CommercialTermsRepository _terms;

  /// Adds [name] at [priceCents] to [workspaceId]'s catalogue. Null,
  /// nothing sent, for a blank name or a negative price. Throws whatever
  /// the repository throws.
  Future<ServiceItem?> add(
    String workspaceId, {
    required String name,
    required int priceCents,
  }) async {
    if (name.trim().isEmpty || priceCents < 0) return null;
    return _terms.createService(
      workspaceId,
      name: name.trim(),
      priceCents: priceCents,
    );
  }
}

/// The services step's write of a new service.
@riverpod
AddService addService(Ref ref) =>
    AddService(ref.watch(commercialTermsProvider));
