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
import 'dart:async';

import '../../../features/directory/domain/messenger.dart';
import '../../../features/directory/domain/public_workspace.dart';
import '../../../features/visits/domain/guest_participation.dart';
import '../../../features/workspace/domain/bi_saved_view.dart';
import '../data/guest_participation_repository.dart';
import '../data/messenger_repository.dart';
import '../data/public_directory_repository.dart';
import '../demo_clock.dart';
import 'demo_people_seed.dart';

/// The two neighbouring spaces the directory lists beside this one.
const demoNeighbourQuai = PublicWorkspace('demo-quai', '', '', {
  'name': 'Le Quai Numérique',
  'address': '9 quai des Pêcheurs\n34200 Sète',
  'host_type': 'company',
  'description': 'Twelve desks on the harbour, a meeting room and a terrace.',
  'email': 'hello@quai-numerique.example.test',
  'latitude': '43.4028',
  'longitude': '3.6966',
});

const demoNeighbourHalles = PublicWorkspace('demo-halles', '', '', {
  'name': 'La Fabrique des Halles',
  'address': '2 rue des Halles\n34500 Béziers',
  'host_type': 'association',
  'description': 'A members’ association: a workshop, desks and a kitchen.',
  'email': 'contact@fabrique-halles.example.test',
  'latitude': '43.3442',
  'longitude': '3.2158',
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
        'description':
            'Eight desks and a meeting room above the market '
            'square. Day passes, carnets and monthly memberships.',
        'email': 'bonjour@atelier-du-marche.example.test',
        'website': 'https://atelier-du-marche.example.test',
      },
    }
    ..cards.addAll(const [
      PublicWorkspace('ws-1', '', '', {
        'name': demoSpaceName,
        'address': demoSpaceAddress,
        'host_type': 'company',
        'description':
            'Eight desks and a meeting room above the market '
            'square. Day passes, carnets and monthly memberships.',
        'email': 'bonjour@atelier-du-marche.example.test',
        'website': 'https://atelier-du-marche.example.test',
        'latitude': '43.4590',
        'longitude': '3.4230',
      }),
      demoNeighbourQuai,
      demoNeighbourHalles,
    ]);
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
/// applicant the space has not admitted yet.
FakeMessengerRepository demoMessenger(DateTime now) =>
    FakeMessengerRepository(now: now)
      ..requests.add(
        const MessageRequest(
          conversationId: 'demo-request-dov',
          userId: 'user-4',
          name: 'Dov Meir',
          body:
              'Hello! I applied to join last week. Could I come by on '
              'Thursday to see the desks before you decide?',
        ),
      );

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
