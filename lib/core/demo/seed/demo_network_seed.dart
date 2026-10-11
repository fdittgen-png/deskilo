// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2327 — the processes that reach beyond the space's own walls: the
// public directory it is listed in, the visits its people pay to other
// spaces as guests, and the message requests that arrive from people
// outside the ones a member chose to be reachable by.
//
// The other spaces are invented and live only here; the people are the
// cast. Every instant with an hour goes through [demoAt], the space's
// own clock.
//
// #2405 — every listed space lives on the demo's own server
// ([kDemoServerOrigin]), so a visitor can follow a space from the map to
// its page, its conditions and a request, and each step is answered from
// the fixture: asking to join lands in the in-memory directory, writing
// to the hosts opens an inquiry in the in-memory messenger, and the hosts
// who would read it are invented. Nothing reaches a real space.
import 'dart:async';

import '../../../features/directory/domain/messenger.dart';
import '../../../features/directory/domain/public_workspace.dart';
import '../../../features/visits/domain/guest_participation.dart';
import '../../../features/workspace/domain/bi_saved_view.dart';
import '../data/connected_installations.dart';
import '../data/guest_participation_repository.dart';
import '../data/messenger_repository.dart';
import '../data/public_directory_repository.dart';
import '../demo_clock.dart';
import '../demo_dataset.dart';
import '../demo_persona.dart';
import 'demo_people_seed.dart';

/// The second space: a whole public page, from its presentation to its
/// conditions and the hosts who answer (#2405).
const demoNeighbourQuai = PublicWorkspace('demo-quai', kDemoServerOrigin, '', {
  'name': 'Le Quai Numérique',
  'address': '9 quai des Pêcheurs\n34200 Sète',
  'host_type': 'company',
  'description':
      'Twelve desks on the harbour, a meeting room and a terrace. '
      'Members come every day; guests are welcome for a day or two.',
  'plans':
      'Open Monday to Friday, 8:30–19:00. Day pass €18, a carnet of '
      'ten days €150, monthly membership €190. A first half-day visit '
      'is free: write to the hosts to arrange it.',
  'email': 'hello@quai-numerique.example.test',
  'website': 'https://quai-numerique.example.test',
  'latitude': '43.4028',
  'longitude': '3.6966',
  'contacts': [
    {'name': 'Inès Caradec', 'owner': true},
    {'name': 'Malo Ferrand', 'owner': false},
  ],
});

/// Its hosts, as the inquiry sheet names them before anything is written.
const demoQuaiHosts = [
  HostRosterEntry(name: 'Inès Caradec', role: 'owner'),
  HostRosterEntry(name: 'Malo Ferrand', role: 'admin'),
];

/// A third space, so the map has a region rather than a pair of pins.
const demoNeighbourHalles = PublicWorkspace(
  'demo-halles',
  kDemoServerOrigin,
  '',
  {
    'name': 'La Fabrique des Halles',
    'address': '2 rue des Halles\n34500 Béziers',
    'host_type': 'association',
    'description': 'A members’ association: a workshop, desks and a kitchen.',
    'plans': 'Membership €25 a year, then €10 a day. Workshop by appointment.',
    'email': 'contact@fabrique-halles.example.test',
    'latitude': '43.3442',
    'longitude': '3.2158',
    'contacts': [
      {'name': 'Yann Le Berre', 'owner': true},
    ],
  },
);

const _demoSpaceDescription =
    'Eight desks and a meeting room above the market '
    'square. Day passes, carnets and monthly memberships.';
// The carnets are the ones the space sells (`seedDemoCarnets`); the
// monthly fees rise every January of the history, so none is quoted.
const _demoSpacePlans =
    'Carnets of 10 half-days (€150) or 20 half-days (€280). Monthly '
    'memberships, half-time or full-time. Day passes on request.';

/// The demo space's own card: the owner finds their page in the same
/// directory a stranger searches, and opening it offers to enter.
PublicWorkspace demoOwnCard() => PublicWorkspace('ws-1', kDemoServerOrigin, '', {
  'name': demoSpaceName,
  'address': demoSpaceAddress,
  'host_type': 'company',
  'description': _demoSpaceDescription,
  'plans': _demoSpacePlans,
  'email': 'bonjour@atelier-du-marche.example.test',
  'website': 'https://atelier-du-marche.example.test',
  'latitude': '43.4590',
  'longitude': '3.4230',
  'contacts': [
    {'name': demoCast[0].name, 'owner': true},
    {'name': demoCast[2].name, 'owner': false},
  ],
});

/// The space's own public page, published, and the directory that lists
/// it with its two neighbours.
void seedDemoDirectory(FakeDirectoryRepository directory) {
  directory
    ..ownName = demoSpaceName
    ..local['address'] = demoSpaceAddress
    ..pages['ws-1'] = {
      'published': true,
      'document': <String, dynamic>{
        'description': _demoSpaceDescription,
        'plans': _demoSpacePlans,
        'email': 'bonjour@atelier-du-marche.example.test',
        'website': 'https://atelier-du-marche.example.test',
      },
    }
    ..cards.addAll([demoOwnCard(), demoNeighbourQuai, demoNeighbourHalles]);
}

/// Two visits as a guest, in spaces the directory lists: one the host
/// confirmed, one still waiting for an answer.
FakeGuestParticipationRepository demoGuestVisits(DateTime now) {
  final today = demoDateOf(now);
  DateTime at(int days, int hour) {
    final d = today.add(Duration(days: days));
    return demoAt(d.year, d.month, d.day, hour);
  }

  return FakeGuestParticipationRepository(
    visits: [
      GuestParticipation(
        id: 'demo-visit-quai',
        workspaceId: demoNeighbourQuai.id,
        workspaceName: demoNeighbourQuai.name,
        status: GuestVisitStatus.confirmed,
        startsAt: at(6, 9),
        endsAt: at(6, 17),
        message: 'A day by the harbour, to meet a client in Sète.',
        requestedAt: at(-4, 11),
        decidedAt: at(-3, 9),
      ),
      GuestParticipation(
        id: 'demo-visit-halles',
        workspaceId: demoNeighbourHalles.id,
        workspaceName: demoNeighbourHalles.name,
        status: GuestVisitStatus.requested,
        startsAt: at(13, 14),
        endsAt: at(13, 18),
        message: 'May I try the workshop for an afternoon?',
        requestedAt: at(-1, 16),
      ),
    ],
  );
}

/// The messenger of this server: one message request, from the
/// applicant the space has not admitted yet; the hosts of every listed
/// space (#2405); and a visit request a stranger sent to this space's
/// hosts, which only the owner and the administrator see.
///
/// [actingMember] is the member the session currently looks through, so
/// the inbox answers per person as the server's `my_inbox` does.
FakeMessengerRepository demoMessenger(
  DateTime now, {
  String Function()? actingMember,
}) {
  final yesterday = demoDateOf(now).subtract(const Duration(days: 1));
  final asked = demoAt(yesterday.year, yesterday.month, yesterday.day, 18);
  const visitor = 'Noémie Garnier';
  const visitBody =
      'Hello! I work from Montpellier and will be in Pézenas next week. '
      'Could I try a desk for a day on Thursday before deciding on a carnet?';
  final hosts = {
    DemoPersona.owner.memberId,
    DemoPersona.admin.memberId,
  };
  return FakeMessengerRepository(now: now)
    ..requests.add(
      const MessageRequest(
        conversationId: 'demo-request-dov',
        userId: 'user-4',
        name: 'Dov Meir',
        body:
            'Hello! I applied to join last week. Could I come by on '
            'Thursday to see the desks before you decide?',
      ),
    )
    ..roster['ws-1'] = [
      HostRosterEntry(name: demoCast[0].name, role: 'owner'),
      HostRosterEntry(name: demoCast[2].name, role: 'admin'),
    ]
    ..roster[demoNeighbourQuai.id] = demoQuaiHosts
    ..roster[demoNeighbourHalles.id] = const [
      HostRosterEntry(name: 'Yann Le Berre', role: 'owner'),
    ]
    ..inboxRows.add({
      'context_kind': MessageContextKind.inquiryIn.wire,
      'context_id': 'demo-inquiry-visit',
      'workspace_id': 'ws-1',
      'workspace_name': demoSpaceName,
      'title': visitor,
      'last_body': visitBody,
      'last_at': asked.toUtc().toIso8601String(),
      'unread': 1,
    })
    ..threads[FakeMessengerRepository.threadKey(
      MessageContextKind.inquiryIn,
      'demo-inquiry-visit',
    )] = [
      ContextMessage(
        id: 'demo-inquiry-visit-1',
        kind: MessageKind.inquiryMessage,
        body: visitBody,
        mine: false,
        authorName: visitor,
        createdAt: asked,
      ),
    ]
    ..inboxVisible = actingMember == null
        ? null
        : (row) =>
              row['context_kind'] != MessageContextKind.inquiryIn.wire ||
              hosts.contains(actingMember());
}

/// Two analyses the team saved on the business-analytics page. Neither
/// is the default, so a bare page still opens on the standard view.
InMemoryBiViewRepository demoBiViews() {
  final views = InMemoryBiViewRepository();
  // The in-memory save has no await: the view is stored before it returns.
  for (final (name, definition) in const [
    (
      'Finance against last year',
      BiViewDefinition(
        query: {'cmp': 'year'},
        cards: ['finance.invoiced', 'finance.collected'],
      ),
    ),
    (
      'Quarter by quarter',
      BiViewDefinition(query: {'grain': 'quarter', 'cmp': 'previous'}),
    ),
  ]) {
    unawaited(
      views.save(
        'ws-1',
        scope: BiViewScope.workspace,
        name: name,
        definition: definition,
        expectedRevision: 0,
      ),
    );
  }
  return views;
}
