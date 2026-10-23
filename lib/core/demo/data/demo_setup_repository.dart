// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup guide in the demo, read from each space's own fixture the way
// the server's detectors (`workspace_setup_status`, `workspace_readiness`)
// read its tables: a step is ready when the space holds what the step's
// evidence names. The features come from the space's row as it stands, so
// a level changed in the guide changes which steps apply; Later and Mark
// as done are kept per space, in memory, like everything a visitor does.
import '../../../features/events/domain/validation_policy.dart';
import '../../../features/money/domain/dunning.dart';
import '../../../features/money/domain/invoice_pdf_template.dart';
import '../../../features/reservations/domain/reservation.dart';
import '../../../features/workspace/domain/member.dart';
import '../../../features/workspace/domain/setup_status.dart';
import '../../../features/workspace/domain/setup_steps.dart';
import '../../../features/workspace/domain/workspace.dart';
import '../seed/demo_setup_status.dart';
import 'book_profile_repository.dart';
import 'event_repository.dart';
import 'floor_plan_repository.dart';
import 'local_setup_repository.dart';
import 'money_repository.dart';
import 'premises_lease_repository.dart';
import 'public_directory_repository.dart';
import 'reservation_repository.dart';
import 'supplier_repository.dart';
import 'workspace_asset_repository.dart';
import 'workspace_repository.dart';

/// The purchase side, the books and the public page: the repositories only
/// the demo's main space holds rows in.
class DemoSetupBooks {
  const DemoSetupBooks({
    required this.suppliers,
    required this.leases,
    required this.assets,
    required this.books,
    required this.directory,
  });

  final FakeSupplierRepository suppliers;
  final FakePremisesLeaseRepository leases;
  final FakeWorkspaceAssetRepository assets;
  final FakeBookProfileRepository books;
  final FakeDirectoryRepository directory;
}

/// Where one demo space's rows live.
class DemoSetupSources {
  const DemoSetupSources({
    required this.space,
    required this.plan,
    required this.reservations,
    required this.money,
    required this.events,
    this.books,
    this.decided = const {},
  });

  final FakeWorkspaceRepository space;
  final FakeFloorPlanRepository plan;
  final FakeReservationRepository reservations;
  final FakeMoneyRepository money;
  final FakeEventRepository events;

  /// Null for a space that keeps no books of its own.
  final DemoSetupBooks? books;

  /// The evidence no demo can hold — a payment provider's account, an
  /// e-invoicing platform, an export recorded by a server — decided from
  /// what the space is.
  final Set<String> decided;
}

/// Pézenas runs every process, so it has a payment provider's account, an
/// e-invoicing platform and a recent export; the demo holds none of them,
/// and says so here. Leipzig, new, has none either.
const demoMainSpaceDecidedEvidence = {
  'online_payments',
  'einvoicing',
  'recovery',
};

/// The manual steps Pézenas's owner marked done: the server cannot verify
/// them, so only the owner's word makes them ready.
const demoMainSpaceMarkedDone = {'new_members', 'notifications', 'limits'};

/// The setup guide of the demo's spaces, each from its [spaces] sources;
/// [rows] holds the spaces' rows, whose features decide what applies, and
/// [acknowledged] what each space's owner set aside or marked done.
class DemoSetupRepository extends FakeLocalSetupRepository {
  DemoSetupRepository({
    required this.rows,
    required this.spaces,
    Map<String, Set<String>> acknowledged = const {},
  }) : _acknowledged = {
         for (final e in acknowledged.entries) e.key: {...e.value},
       };

  final FakeWorkspaceRepository rows;
  final Map<String, DemoSetupSources> spaces;
  final Map<String, Set<String>> _acknowledged;

  @override
  Future<SetupStatus> setupStatus(String workspaceId) async {
    final row = rows.workspaces.where((w) => w.id == workspaceId).firstOrNull;
    final sources = spaces[workspaceId];
    if (row == null || sources == null) return const SetupStatus();
    return demoSetupStatus(
      row.featureFlags,
      ready: await _demoSetupEvidence(row, sources),
      acknowledged: {...?_acknowledged[workspaceId]},
    );
  }

  /// The server's refusals (0545): a step it verifies and a milestone waits
  /// for cannot be set aside, nor one with nothing left to do.
  @override
  Future<void> acknowledgeStep(String workspaceId, String step) async {
    final s = (await setupStatus(workspaceId)).steps
        .where((x) => x.step == step)
        .firstOrNull;
    if (s == null) throw ArgumentError.value(step, 'step', 'no such step');
    if (s.required && !s.manual) {
      throw StateError('a required step cannot be set aside for later');
    }
    if (!s.open) throw StateError('this step has nothing left to set aside');
    _acknowledged.putIfAbsent(workspaceId, () => {}).add(step);
  }

  @override
  Future<void> clearStepAcknowledgement(
    String workspaceId,
    String step,
  ) async => _acknowledged[workspaceId]?.remove(step);
}

/// The steps whose evidence [row]'s space holds, by step id.
Future<Set<String>> _demoSetupEvidence(
  Workspace row,
  DemoSetupSources sources,
) async {
  final holds = {
    ..._rowEvidence(row, await sources.space.fetchOpenWeekdays(row.id)),
    ..._fixtureEvidence(row.id, sources),
    ...await _booksEvidence(row.id, sources.books),
    for (final key in sources.decided) key: true,
  };
  return {
    for (final s in setupSteps)
      if (holds[s.evidence] ?? false) s.id,
  };
}

/// What the space's own row says.
Map<String, bool> _rowEvidence(Workspace w, List<int> openWeekdays) {
  final basics = w.timezone.isNotEmpty && w.currencyCode.isNotEmpty;
  final memberGrants = w.rolePermissions['member'];
  return {
    'basics': basics,
    'hours': basics && openWeekdays.isNotEmpty,
    'member_rights':
        memberGrants is List && memberGrants.contains('makeReservations'),
    'payment_methods': w.paymentInstructions.values.any(
      (v) => '$v'.trim().isNotEmpty,
    ),
    'look': w.branding.isNotEmpty,
    'legal_identity':
        w.legalId.trim().isNotEmpty &&
        (w.street.trim().isNotEmpty || w.address.trim().isNotEmpty),
  };
}

/// What the space's members, plan, bookings, money and rules hold.
Map<String, bool> _fixtureEvidence(String id, DemoSetupSources s) {
  final members = [
    for (final m in [s.space.myMember, ...s.space.otherMembers])
      if (m.workspaceId == id && m.status == MemberStatus.active) m,
  ];
  final money = s.money;
  return {
    'places': s.plan.seats.any((x) => x.workspaceId == id),
    'invite': members.length > 1,
    'pricing': money.feeBands.any((b) => b.workspaceId == id),
    'services': money.services.any((x) => x.workspaceId == id && x.active),
    'approvals': !s.events.policies.any(
      (p) => p.workspaceId == id && _tooFewValidators(p, members),
    ),
    'kiosk': members.any((m) => m.isKiosk),
    'vat': money.vatRates.isNotEmpty,
    'numbering': money.numberSequences.isNotEmpty,
    // A template or rules the space saved, not the ones a space without
    // any is served.
    'documents': !identical(money.pdfTemplate, InvoicePdfTemplate.empty),
    'reminders': !identical(money.dunningRules, DunningRules.defaults),
    'first_booking': s.reservations.reservations.any(
      (r) =>
          r.workspaceId == id &&
          const {
            ReservationStatus.reserved,
            ReservationStatus.checkedIn,
            ReservationStatus.completed,
          }.contains(r.status),
    ),
  };
}

/// Whether fewer active members may decide under [p] than it needs: the
/// owner, then by scope every member, the listed ones, or the admins it
/// admits (0294).
bool _tooFewValidators(ValidationPolicy p, List<Member> members) =>
    p.requiredCount >
    members.where((m) {
      final listed = p.eligibleAdminIds.contains(m.id);
      return m.isOwner ||
          switch (p.validatorScope) {
            'members' => true,
            'listed' => listed,
            _ =>
              m.isAdmin &&
                  p.adminsMayValidate &&
                  (p.eligibleAdminIds.isEmpty || listed),
          };
    }).length;

/// What the space's purchase side, books and public page hold.
Future<Map<String, bool>> _booksEvidence(String id, DemoSetupBooks? b) async {
  if (b == null) return const {};
  return {
    'purchases': (await b.suppliers.fetchSuppliers(id)).isNotEmpty,
    'lease': (await b.leases.fetchLeases(id)).isNotEmpty,
    'assets': (await b.assets.fetchAssets(id)).isNotEmpty,
    'accounting': (await b.books.fetchBookProfiles(id)).isNotEmpty,
    'public_page': b.directory.pages.containsKey(id),
  };
}
