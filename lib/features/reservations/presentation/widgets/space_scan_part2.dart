// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'space_scan.dart';


/// The scan-to-book entry (field request): scan a desk/office/level QR
/// card → the space sheet shows exactly the actions this member is
/// permitted to take (reserve / check in now). Whole-office and
/// whole-level bookings require the whole-space feature, the owner's
/// bookable flag AND the member's personal grant — the server re-checks
/// everything.
Future<void> scanSpace(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null) return;

  // #585 — the tap path joins the camera and the typed field when this
  // device can read NFC and the chair-tag feature is on (#604).
  final nfcReader = ref.read(nfcUidReaderProvider);
  final seatTagsOn = ref
      .read(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.nfcSeatTags);
  final nfcReady = seatTagsOn && await nfcReader.isAvailable();
  if (!context.mounted) return;

  final code = await showAppSheet<SpaceCode>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SpaceScanSheet(
      workspaceId: workspace.id,
      scanBuilder:
          qrScanSupported ? ref.read(qrScanWidgetBuilderProvider) : null,
      explainNoCamera: kIsWeb,
      l10n: l10n,
      nfc: nfcReady ? nfcReader : null,
      seatIdForUid: (uid) => ref
          .read(floorPlanRepositoryProvider)
          .seatIdForNfcUid(workspace.id, uid),
    ),
  );
  if (code == null || !context.mounted) return;

  // Resolve the code against the floor plan — the shared walk message
  // references use too (#523); a stale card reports instead of
  // crashing.
  final resolved = await resolveSpaceById(ref, code.kind, code.id);
  if (!context.mounted) return;
  if (resolved == null) {
    AppSnack.error(
      context,
      l10n.spaceScanUnknown,
    );
    return;
  }
  final level = resolved.level;
  final office = resolved.office;
  final desk = resolved.desk;
  final seat = resolved.seat;
  final plan = resolved.plan;

  // #622 — a scanned WORKSTATION acts like tapping it on the kiosk:
  // straight into the shared one-sheet (action + derived period), the
  // signed-in member confirming instead of a badge.
  if (code.kind == SpaceKind.seat && seat != null) {
    // #814 — parity with the kiosk: a closed day refuses up front, not
    // at the end of a full sheet (the guide promised "a scan behaves
    // like the kiosk"; this is where it did not).
    final gate = bookingGateOf(ref);
    if (gate != null && !gate.dayOpen(gate.now)) {
      AppSnack.info(
        context,
        l10n.kioskClosedToday,
        replace: true,
      );
      return;
    }
    await showSpaceActSheet(
      context,
      seat: seat,
      plan: plan,
      title: desk == null ? seat.name : '${seat.name} · ${desk.name}',
    );
    return;
  }

  await showSpaceSheet(
    context,
    kind: code.kind,
    level: level,
    office: office,
    desk: desk,
    seat: seat,
    plan: plan,
    // #687 — an admin who SCANS a room's card gets the same
    // assignment picker as one who double-taps it on the plan.
    members: spaceAssignmentCandidates(ref),
  );
}

/// Opens the whole-space sheet for an ALREADY-RESOLVED target — the
/// scan flow above, the plan canvases' double-tap (field request:
/// double-tapping a table or a room/level on the plan reserves it, or
/// checks in when it is already reserved) AND, since #638, the level
/// rail's layers icon. That last one used to open a SECOND sheet with
/// the assignment dropdown but no period picker and no series; the two
/// converged here rather than each keeping half the capability.
Future<void> showSpaceSheet(
  BuildContext context, {
  required SpaceKind kind,
  Level? level,
  Office? office,
  Desk? desk,
  Seat? seat,
  FloorPlan? plan,
  ({DateTime start, DateTime end})? initialWindow,
  List<({String id, String name})> members = const [],
}) =>
    showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SpaceSheet(
        kind: kind,
        level: level,
        office: office,
        desk: desk,
        seat: seat,
        plan: plan,
        initialWindow: initialWindow,
        members: members,
      ),
    );

/// The scanner: camera (injectable seam) plus a typed field — wedge
/// scanners and tests type the payload. Foreign QR contents show an
/// inline error and keep the sheet open.
class _SpaceSheet extends ConsumerStatefulWidget {
  const _SpaceSheet({
    required this.kind,
    this.level,
    this.office,
    this.desk,
    this.seat,
    this.plan,
    this.initialWindow,
    this.members = const [],
  });

  final SpaceKind kind;
  final Level? level;
  final Office? office;
  final Desk? desk;
  final Seat? seat;
  final FloorPlan? plan;

  /// The window the opener was browsing (hub date strip / plan
  /// scrubber): seeds the reserve picker so "reserve for the day I am
  /// looking at" works — a scan defaults to today's walk-up window.
  final ({DateTime start, DateTime end})? initialWindow;

  /// Members this actor may book the WHOLE SPACE for (#638): empty for
  /// everyone but an owner/delegated admin, and the presence of the
  /// list is itself the assignment right — the caller holds the roster
  /// and the gate (`bookForOthers` / `adminLevelAssign`), the sheet only
  /// offers the choice. Only `admin_create_reservation_for` scales
  /// exist server-side (seat and level), so the selector rides the LEVEL
  /// kind; a desk/office keeps booking for the actor.
  final List<({String id, String name})> members;

  @override
  ConsumerState<_SpaceSheet> createState() => _SpaceSheetState();
}
