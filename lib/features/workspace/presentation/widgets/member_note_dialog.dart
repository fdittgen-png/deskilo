// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/time/clock.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../reservations/domain/reservation.dart';
import '../../../reservations/domain/space_code.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../domain/member_note.dart';
import '../../domain/member_note_refs.dart';
import '../../providers/workspace_providers.dart';

/// Compose-and-send dialog for a member note (#456). [toMemberId] null =
/// broadcast to all admins incl. the owner (the server re-checks the
/// sender's admin rights). [recipientName] labels the dialog.
///
/// #523 — the composer can attach REFERENCES: a reservation/check-in,
/// or a space (seat, table, room, level) to discuss a future booking.
/// They land as `[res:…]`/`[space:…]` tokens in the text and render as
/// tappable links for the reader.
Future<void> showMemberNoteDialog(
  BuildContext context,
  WidgetRef ref, {
  required String? toMemberId,
  required String recipientName,
}) async {
  final l10n = AppLocalizations.of(context);
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null) return;
  final body = await showDialog<String>(
    context: context,
    builder: (context) => _NoteDialog(recipientName: recipientName),
  );
  if (body == null || body.trim().isEmpty || !context.mounted) return;
  try {
    await ref.read(workspaceRepositoryProvider).sendMemberNote(
          workspace.id,
          toMemberId: toMemberId,
          body: body.trim(),
        );
  } catch (e, st) {
    TraceLogger.instance
        .error('workspace', 'send member note failed', error: e, stackTrace: st);
    if (!context.mounted) return;
    AppSnack.error(
      context,
      l10n?.workspaceGenericError ?? 'Something went wrong. Please try again.',
    );
    return;
  }
  if (!context.mounted) return;
  AppSnack.info(
    context,
    l10n?.memberNoteSent ?? 'Notification sent.',
    replace: true,
  );
}

class _NoteDialog extends ConsumerStatefulWidget {
  const _NoteDialog({required this.recipientName});

  final String recipientName;

  @override
  ConsumerState<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends ConsumerState<_NoteDialog> {
  final _body = TextEditingController();

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  /// Inserts [token] at the caret (or the end), padded with spaces so
  /// the link never glues to a word.
  void _insert(String token) {
    final text = _body.text;
    final selection = _body.selection;
    final at = selection.isValid ? selection.start : text.length;
    final before = text.substring(0, at);
    final after = text.substring(selection.isValid ? selection.end : at);
    final glued = StringBuffer(before);
    if (before.isNotEmpty && !before.endsWith(' ')) glued.write(' ');
    glued.write(token);
    if (!after.startsWith(' ')) glued.write(' ');
    final caret = glued.length;
    glued.write(after);
    _body.text = glued.toString();
    _body.selection = TextSelection.collapsed(offset: caret);
    setState(() {});
  }

  /// The label a reservation reference carries: who · space · when —
  /// the name matters because ANY participant's booking or check-in can
  /// be the subject of the conversation, not just my own.
  String _reservationLabel(
    Reservation reservation,
    Map<String, String> spaceNames,
    Map<String, String> memberNames,
    String? localeName,
  ) {
    final target = reservation.seatId ??
        reservation.deskId ??
        reservation.officeId ??
        reservation.levelId;
    final who = memberNames[reservation.memberId] ?? '';
    final space = spaceNames[target] ?? '';
    final when = DateFormat.MMMd(localeName)
        .add_Hm()
        .format(reservation.startsAt.toLocal());
    return [who, space, when].where((p) => p.isNotEmpty).join(' · ');
  }

  Future<void> _pickReservation() async {
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.maybeLocaleOf(context)?.toString();
    final workspace = ref.read(currentWorkspaceProvider).value;
    final me = ref.read(myMemberProvider).value;
    if (workspace == null) return;
    // EVERY participant's linkable booking: still-running or upcoming
    // reservations AND live check-ins of the whole workspace (the
    // conversation is often about someone else's seat) — mine first.
    final now = ref.read(clockProvider).now();
    final window =
        await ref.read(reservationRepositoryProvider).fetchWindow(
              workspace.id,
              from: now,
              to: now.add(const Duration(days: 7)),
            );
    final spaceNames = await ref.read(targetNamesProvider.future);
    final memberNames = await ref.read(memberNamesProvider.future);
    if (!mounted) return;
    final reservations = window
        .where((r) =>
            (r.status == ReservationStatus.reserved ||
                r.status == ReservationStatus.checkedIn) &&
            r.endsAt.isAfter(now))
        .toList()
      ..sort((a, b) {
        final aMine = a.memberId == me?.id ? 0 : 1;
        final bMine = b.memberId == me?.id ? 0 : 1;
        if (aMine != bMine) return aMine - bMine;
        return a.startsAt.compareTo(b.startsAt);
      });
    if (reservations.isEmpty) {
      AppSnack.info(
        context,
        l10n?.noteRefNoReservations ?? 'No upcoming reservations to link.',
      );
      return;
    }
    final picked = await showModalBottomSheet<Reservation>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final reservation in reservations)
              ListTile(
                key: ValueKey('note-ref-res-${reservation.id}'),
                leading: Icon(
                  reservation.status == ReservationStatus.checkedIn
                      ? Icons.login_outlined
                      : Icons.event_available_outlined,
                ),
                title: Text(_reservationLabel(
                    reservation, spaceNames, memberNames, localeName)),
                onTap: () => Navigator.of(sheetContext).pop(reservation),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    _insert(reservationToken(
        picked.id,
        _reservationLabel(picked, spaceNames, memberNames, localeName)));
  }

  Future<void> _pickSpace() async {
    final l10n = AppLocalizations.of(context);
    final levels = await ref.read(levelsProvider.future);
    if (!mounted || levels.isEmpty) return;
    // Step 1: the level. Step 2: the level itself, or one of its rooms,
    // tables and seats — every kind a future booking can be about.
    final level = levels.length == 1
        ? levels.single
        : await showModalBottomSheet<dynamic>(
            context: context,
            builder: (sheetContext) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final candidate in levels)
                    ListTile(
                      key: ValueKey('note-ref-level-${candidate.id}'),
                      leading: const Icon(Icons.layers_outlined),
                      title: Text(candidate.name),
                      onTap: () =>
                          Navigator.of(sheetContext).pop(candidate),
                    ),
                ],
              ),
            ),
          );
    if (level == null || !mounted) return;
    final plan = await ref.read(floorPlanProvider(level.id).future);
    if (!mounted) return;
    final picked =
        await showModalBottomSheet<({SpaceKind kind, String id, String label})>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              key: ValueKey('note-ref-space-level-${level.id}'),
              leading: const Icon(Icons.layers_outlined),
              title: Text(
                  '${level.name} — ${l10n?.noteRefWholeLevel ?? 'whole level'}'),
              onTap: () => Navigator.of(sheetContext).pop(
                  (kind: SpaceKind.level, id: level.id, label: level.name)),
            ),
            for (final office in plan.offices)
              ListTile(
                key: ValueKey('note-ref-space-office-${office.id}'),
                leading: const Icon(Icons.meeting_room_outlined),
                title: Text(office.name),
                onTap: () => Navigator.of(sheetContext).pop((
                  kind: SpaceKind.office,
                  id: office.id,
                  label: office.name
                )),
              ),
            for (final desk in plan.desks)
              ListTile(
                key: ValueKey('note-ref-space-desk-${desk.id}'),
                leading: const Icon(Icons.table_restaurant_outlined),
                title: Text(desk.name),
                onTap: () => Navigator.of(sheetContext).pop(
                    (kind: SpaceKind.desk, id: desk.id, label: desk.name)),
              ),
            for (final seat in plan.seats)
              ListTile(
                key: ValueKey('note-ref-space-seat-${seat.id}'),
                leading: const Icon(Icons.chair_outlined),
                title: Text(seat.name),
                onTap: () => Navigator.of(sheetContext).pop(
                    (kind: SpaceKind.seat, id: seat.id, label: seat.name)),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    _insert(spaceToken(picked.kind, picked.id, picked.label));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        l10n?.memberNoteTitle(widget.recipientName) ??
            'Notify ${widget.recipientName}',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('member-note-body'),
            controller: _body,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            maxLength: MemberNoteRules.maxLength,
            decoration: InputDecoration(
              labelText: l10n?.memberNoteHint ?? 'Your message',
              border: const OutlineInputBorder(),
            ),
          ),
          // #523 — attach references: they read as links on the other
          // side and open the reservation / the space's booking sheet.
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                key: const ValueKey('member-note-ref-reservation'),
                avatar: const Icon(Icons.event_available_outlined, size: 18),
                label: Text(
                    l10n?.noteRefReservation ?? 'Link a reservation'),
                onPressed: _pickReservation,
              ),
              ActionChip(
                key: const ValueKey('member-note-ref-space'),
                avatar: const Icon(Icons.chair_outlined, size: 18),
                label: Text(l10n?.noteRefSpace ?? 'Link a space'),
                onPressed: _pickSpace,
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          key: const ValueKey('member-note-send'),
          onPressed: () => Navigator.of(context).pop(_body.text),
          child: Text(l10n?.memberNoteSend ?? 'Send'),
        ),
      ],
    );
  }
}
