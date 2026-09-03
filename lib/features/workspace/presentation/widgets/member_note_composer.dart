// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import 'ref_picker_sheet.dart';
import 'note_record_open.dart';
import '../../domain/workspace_feature.dart';
import '../../../events/presentation/event_labels.dart';
import '../../../events/providers/event_providers.dart';
import '../../../money/domain/ledger_entry.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../money/providers/money_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../reservations/domain/reservation.dart';
import '../../../reservations/domain/space_code.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../domain/member_note.dart';
import '../../domain/member_note_refs.dart';
import '../../providers/workspace_providers.dart';

/// The ONE message composer (#523/refactor): text field, the two
/// reference chips (any participant's reservation/check-in, any
/// space) and the send button. The conversation thread and the
/// broadcast dialog embed the same widget, so composing works — and
/// evolves — identically everywhere.
class MemberNoteComposer extends ConsumerStatefulWidget {
  const MemberNoteComposer({
    super.key,
    required this.onSend,
    this.autofocus = true,
    this.seedBody,
    this.quoted,
    this.onCancelQuote,
    this.onChanged,
    this.compact = false,
  });

  /// #821 — every keystroke, for the draft store.
  final ValueChanged<String>? onChanged;

  /// #821 — the two reference chips folded into ONE attach menu beside
  /// the field, a counter as the limit nears, a spinner while sending.
  final bool compact;

  /// Called with the trimmed body; returns true when it went out (the
  /// field then clears).
  final Future<bool> Function(String body) onSend;
  final bool autofocus;

  /// #622 — pre-seeded body (e.g. a `[res:…]` reference to the booking
  /// the conversation is about); the caret lands after it so the
  /// member just types around the reference.
  final String? seedBody;

  /// #798 — the message being replied to, shown above the field.
  ///
  /// Composer STATE rather than text in the field: the token is built at
  /// send time, so a quote cannot be half-deleted by a stray backspace
  /// into something that no longer parses.
  final ({String id, String preview})? quoted;
  final VoidCallback? onCancelQuote;

  @override
  ConsumerState<MemberNoteComposer> createState() =>
      _MemberNoteComposerState();
}

class _MemberNoteComposerState extends ConsumerState<MemberNoteComposer> {
  final _body = TextEditingController();
  bool _sending = false;

  /// How close to the limit the counter appears (#821).
  static const int _counterFrom = 100;

  @override
  void initState() {
    super.initState();
    final seed = widget.seedBody;
    if (seed != null && seed.trim().isNotEmpty) {
      _body.text = seed;
      _body.selection = TextSelection.collapsed(offset: seed.length);
    }
  }

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
    // #842 — the same filterable sheet every reference uses. A busy
    // workspace has dozens of live bookings in a week; a flat list of
    // them is a list you scroll past, not one you choose from.
    final pickedId = await showRefPicker(
      context,
      title: l10n?.noteRefReservation ?? 'Reservation',
      keyPrefix: 'note-ref-res',
      candidates: [
        for (final reservation in reservations)
          refCandidate(
            id: reservation.id,
            label: _reservationLabel(
                reservation, spaceNames, memberNames, localeName),
            icon: reservation.status == ReservationStatus.checkedIn
                ? Icons.login_outlined
                : Icons.event_available_outlined,
          ),
      ],
    );
    if (pickedId == null || !mounted) return;
    final picked =
        reservations.where((r) => r.id == pickedId).firstOrNull;
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
    final levelId = levels.length == 1
        ? levels.single.id
        : await showRefPicker(
            context,
            title: l10n?.noteRefSpace ?? 'Space',
            keyPrefix: 'note-ref-level',
            candidates: [
              for (final candidate in levels)
                refCandidate(
                  id: candidate.id,
                  label: candidate.name,
                  icon: Icons.layers_outlined,
                ),
            ],
          );
    if (levelId == null || !mounted) return;
    final level = levels.where((l) => l.id == levelId).firstOrNull;
    if (level == null || !mounted) return;
    final plan = await ref.read(floorPlanProvider(level.id).future);
    if (!mounted) return;
    // Every bookable thing on the level, in one searchable list: a
    // level with sixty seats was sixty rows to scroll before #842.
    final spaces = <({SpaceKind kind, String id, String label})>[
      (kind: SpaceKind.level, id: level.id, label: level.name),
      for (final office in plan.offices)
        (kind: SpaceKind.office, id: office.id, label: office.name),
      for (final desk in plan.desks)
        (kind: SpaceKind.desk, id: desk.id, label: desk.name),
      for (final seat in plan.seats)
        (kind: SpaceKind.seat, id: seat.id, label: seat.name),
    ];
    final pickedKey = await showRefPicker(
      context,
      title: l10n?.noteRefSpace ?? 'Space',
      keyPrefix: 'note-ref-space',
      candidates: [
        for (final space in spaces)
          refCandidate(
            // The key stays `note-ref-space-<kind>-<id>`: one sheet now,
            // same address as the four lists it replaced.
            id: '${space.kind.name}-${space.id}',
            label: space.kind == SpaceKind.level
                ? '${level.name} — '
                    '${l10n?.noteRefWholeLevel ?? 'whole level'}'
                : space.label,
            icon: switch (space.kind) {
              SpaceKind.level => Icons.layers_outlined,
              SpaceKind.office => Icons.meeting_room_outlined,
              SpaceKind.desk => Icons.table_restaurant_outlined,
              SpaceKind.seat => Icons.chair_outlined,
            },
          ),
      ],
    );
    if (pickedKey == null || !mounted) return;
    final picked = spaces
        .where((s) => '${s.kind.name}-${s.id}' == pickedKey)
        .firstOrNull;
    if (picked == null || !mounted) return;
    _insert(spaceToken(picked.kind, picked.id, picked.label));
  }

  /// #842 — an alert, the validation trail behind one, an invoice or a
  /// month's payments. Every list goes through the same filterable
  /// sheet, because every one of them is long in a real workspace.
  Future<void> _pickRecord(NoteRecordKind kind) async {
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.maybeLocaleOf(context)?.toString();
    final candidates = <RefCandidate>[];
    final labels = <String, String>{};

    switch (kind) {
      case NoteRecordKind.alert:
      case NoteRecordKind.validation:
        final events = await ref.read(eventsProvider.future);
        if (!mounted) return;
        final names = ref.read(memberNamesProvider).value ?? const {};
        final decisions =
            ref.read(eventDecisionsProvider).value ?? const {};
        for (final event in events) {
          // A validation reference is about a decision: an event nobody
          // was ever asked about has no trail to point at.
          if (kind == NoteRecordKind.validation &&
              !event.isPending &&
              (decisions[event.id] ?? const []).isEmpty) {
            continue;
          }
          final when = DateFormat.MMMd(localeName)
              .add_Hm()
              .format(event.createdAt.toLocal());
          final who = names[event.subjectMemberId] ?? '';
          final label = [eventTypeLabel(l10n, event.type), who, when]
              .where((p) => p.isNotEmpty)
              .join(' · ');
          labels[event.id] = label;
          candidates.add(refCandidate(
            id: event.id,
            label: label,
            icon: noteRecordIcon(kind),
            extraKeywords: event.status.name,
          ));
        }
      case NoteRecordKind.invoice:
      case NoteRecordKind.refund:
        final invoices = await ref.read(invoicesProvider.future);
        if (!mounted) return;
        final names = ref.read(memberNamesProvider).value ?? const {};
        for (final invoice in invoices) {
          final label = <String>[
            invoice.number,
            names[invoice.memberId] ?? invoice.memberName,
            invoice.period ?? '',
          ].where((p) => p.isNotEmpty).join(' · ');
          labels[invoice.id] = label;
          candidates.add(refCandidate(
            id: invoice.id,
            label: label,
            detail: invoice.title.isEmpty ? null : invoice.title,
            icon: noteRecordIcon(kind),
          ));
        }
      case NoteRecordKind.payment:
        final ledger = await ref.read(myLedgerProvider.future);
        if (!mounted) return;
        final money = moneyFormat(
            ref.read(currentWorkspaceProvider).value?.currencyCode ?? 'EUR');
        final seen = <String>{};
        for (final entry in ledger) {
          if (entry.kind != LedgerKind.credit ||
              entry.category != LedgerCategory.payment) {
            continue;
          }
          // The reference names the MONTH: that is the page a payment
          // opens on, and two payments in one month share it.
          if (!seen.add(entry.period)) continue;
          final label = '${l10n?.noteRefPayment ?? 'Payment'} · '
              '${entry.period} · ${money.formatMinor(entry.amountCents)}';
          labels[entry.period] = label;
          candidates.add(refCandidate(
            id: entry.period,
            label: label,
            detail:
                entry.description.isEmpty ? null : entry.description,
            icon: noteRecordIcon(kind),
          ));
        }
    }

    if (!mounted) return;
    if (candidates.isEmpty) {
      AppSnack.info(
          context, l10n?.noteRefNone ?? 'Nothing to reference yet.');
      return;
    }
    final picked = await showRefPicker(
      context,
      title: switch (kind) {
        NoteRecordKind.alert => l10n?.noteRefPickAlert ?? 'Which alert?',
        NoteRecordKind.validation =>
          l10n?.noteRefPickValidation ?? 'Which validation?',
        NoteRecordKind.payment =>
          l10n?.noteRefPickPayment ?? 'Which payment?',
        _ => l10n?.noteRefPickInvoice ?? 'Which invoice?',
      },
      keyPrefix: 'note-ref-${kind.name}',
      candidates: candidates,
    );
    if (picked == null || !mounted) return;
    _insert(recordToken(kind, picked, labels[picked] ?? picked));
  }

  /// #842 — the reference kinds this workspace offers. A refund opens
  /// as the credit note it is, so it needs no entry of its own.
  List<NoteRecordKind> get _recordKinds =>
      ref.read(enabledFeaturesSyncProvider)
              .contains(WorkspaceFeature.richMessageRefs)
          ? const [
              NoteRecordKind.alert,
              NoteRecordKind.validation,
              NoteRecordKind.invoice,
              NoteRecordKind.payment,
            ]
          : const [];

  String _recordLabel(AppLocalizations? l10n, NoteRecordKind kind) =>
      switch (kind) {
        NoteRecordKind.alert => l10n?.noteRefAlert ?? 'Alert',
        NoteRecordKind.validation => l10n?.noteRefValidation ?? 'Validation',
        NoteRecordKind.invoice => l10n?.noteRefInvoice ?? 'Invoice',
        NoteRecordKind.payment => l10n?.noteRefPayment ?? 'Payment',
        NoteRecordKind.refund => l10n?.noteRefRefund ?? 'Refund',
      };

  Future<void> _send() async {
    final typed = _body.text.trim();
    if (typed.isEmpty || _sending) return;
    final quoted = widget.quoted;
    // The quote leads the body: the bubble splits it back off and
    // renders it as the block above the reply.
    final body = quoted == null
        ? typed
        : '${quoteToken(quoted.id, quoted.preview)}\n$typed';
    setState(() => _sending = true);
    final sent = await widget.onSend(body);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (sent) _body.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quoted = widget.quoted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (quoted != null)
          Container(
            key: const ValueKey('composer-quote'),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.fromLTRB(8, 4, 0, 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: AppRadius.smAll,
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
              ),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  quoted.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ),
              IconButton(
                key: const ValueKey('composer-quote-cancel'),
                icon: const Icon(Icons.close, size: 18),
                tooltip: l10n?.commonCancel ?? 'Cancel',
                onPressed: widget.onCancelQuote,
              ),
            ]),
          ),
        TextField(
          key: const ValueKey('member-note-body'),
          controller: _body,
          autofocus: widget.autofocus,
          minLines: 1,
          maxLines: 5,
          maxLength: MemberNoteRules.maxLength,
          onChanged: (text) {
            widget.onChanged?.call(text);
            if (widget.compact) setState(() {});
          },
          decoration: InputDecoration(
            labelText: l10n?.memberNoteHint ?? 'Your message',
            border: const OutlineInputBorder(),
            // #821 — silent until the limit is near, then it says how
            // much room is left instead of just stopping the keys.
            counterText: widget.compact &&
                    MemberNoteRules.maxLength - _body.text.length <=
                        _counterFrom
                ? (l10n?.composerCharsLeft(
                        MemberNoteRules.maxLength - _body.text.length) ??
                    '${MemberNoteRules.maxLength - _body.text.length} characters left')
                : '',
          ),
          onSubmitted: (_) => _send(),
        ),
        if (widget.compact)
          Row(children: [
            PopupMenuButton<String>(
              key: const ValueKey('composer-attach'),
              tooltip: l10n?.composerAttach ?? 'Attach a reference',
              icon: const Icon(Icons.add_circle_outline),
              onSelected: (value) => switch (value) {
                'reservation' => _pickReservation(),
                'space' => _pickSpace(),
                // #842 — the four new kinds share one picker.
                _ => _pickRecord(NoteRecordKind.values.byName(value)),
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  key: const ValueKey('member-note-ref-reservation'),
                  value: 'reservation',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_available_outlined),
                    title: Text(
                        l10n?.noteRefReservation ?? 'Link a reservation'),
                  ),
                ),
                PopupMenuItem(
                  key: const ValueKey('member-note-ref-space'),
                  value: 'space',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.chair_outlined),
                    title: Text(l10n?.noteRefSpace ?? 'Link a space'),
                  ),
                ),
                for (final kind in _recordKinds)
                  PopupMenuItem(
                    key: ValueKey('member-note-ref-${kind.name}'),
                    value: kind.name,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(noteRecordIcon(kind)),
                      title: Text(_recordLabel(l10n, kind)),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            _sending
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton.filled(
                    key: const ValueKey('member-note-send'),
                    icon: const Icon(Icons.send),
                    tooltip: l10n?.memberNoteSend ?? 'Send',
                    onPressed: _send,
                  ),
          ])
        else
        // #523 — attach references: they read as links on the other
        // side and open the reservation / the space's booking sheet.
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    key: const ValueKey('member-note-ref-reservation'),
                    avatar:
                        const Icon(Icons.event_available_outlined, size: 18),
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
                  for (final kind in _recordKinds)
                    ActionChip(
                      key: ValueKey('member-note-ref-${kind.name}'),
                      avatar: Icon(noteRecordIcon(kind), size: 18),
                      label: Text(_recordLabel(l10n, kind)),
                      onPressed: () => _pickRecord(kind),
                    ),
                ],
              ),
            ),
            IconButton.filled(
              key: const ValueKey('member-note-send'),
              icon: const Icon(Icons.send),
              tooltip: l10n?.memberNoteSend ?? 'Send',
              onPressed: _sending ? null : _send,
            ),
          ],
        ),
      ],
    );
  }
}
