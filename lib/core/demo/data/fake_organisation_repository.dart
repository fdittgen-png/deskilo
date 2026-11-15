// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4006 — the Demo's organisations: the ones it was given, none by default
// (the Demo's reference organisation is seeded by #4009).
import '../../../features/workspace/domain/organisation.dart';

class FakeOrganisationRepository implements OrganisationRepository {
  FakeOrganisationRepository([List<Organisation> organisations = const []])
    : _organisations = List.of(organisations);

  final List<Organisation> _organisations;

  @override
  Future<List<Organisation>> myOrganisations() async =>
      List.unmodifiable(_organisations);
}
