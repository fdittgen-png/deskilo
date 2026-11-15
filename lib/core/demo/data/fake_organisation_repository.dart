// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4006 — the Demo's organisations: the ones it was given, none by default;
// #4009 — or the ones its source states each time it is read (the Demo's
// reference organisation follows the person's memberships).
import '../../../features/workspace/domain/organisation.dart';

class FakeOrganisationRepository implements OrganisationRepository {
  FakeOrganisationRepository([List<Organisation> organisations = const []])
    : _organisations = List.of(organisations),
      _source = null;

  FakeOrganisationRepository.from(Future<List<Organisation>> Function() source)
    : _organisations = const [],
      _source = source;

  final List<Organisation> _organisations;
  final Future<List<Organisation>> Function()? _source;

  @override
  Future<List<Organisation>> myOrganisations() async =>
      List.unmodifiable(await _source?.call() ?? _organisations);
}
