// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/member_note_refs.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/presentation/widgets/conversation_sheet.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/reservation.dart';

/// #622 — "message the reserver": when ANOTHER member's reservation
/// blocks a check-in or booking (scan sheet, Plan tab), the surface
/// offers opening THE conversation thread with that member, the
/// composer pre-seeded with the blocking reservation's `[res:…]`
/// reference. One helper, every surface — the kiosk deliberately only
/// NAMES the holder (a wall device cannot write as the member).
///
/// Gated on the messaging feature's own flag ([canMessageReserver],
/// memberNotifications) — no flag of its own.
bool canMessageReserver(WidgetRef ref, Reservation blocking) =>
    ref
        .read(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.memberNotifications) &&
    blocking.memberId != ref.read(myMemberProvider).value?.id;

/// The reference label a seeded message carries: who · space · when —
/// the composer's own reservation-label idiom.
String _blockingLabel(
  Reservation blocking, {
  required String name,
  required String spaceName,
  String? localeName,
}) {
  final when = DateFormat.MMMd(
    localeName,
  ).add_Hm().format(blocking.startsAt.toLocal());
  return [name, spaceName, when].where((p) => p.isNotEmpty).join(' · ');
}

/// Opens the conversation with [blocking]'s holder, the composer
/// seeded with the reservation reference.
Future<void> messageReserver(
  BuildContext context,
  WidgetRef ref, {
  required Reservation blocking,
  required String name,
  required String spaceName,
}) {
  final localeName = Localizations.maybeLocaleOf(context)?.toString();
  final token = reservationToken(
    blocking.id,
    _blockingLabel(
      blocking,
      name: name,
      spaceName: spaceName,
      localeName: localeName,
    ),
  );
  return showConversationSheet(
    context,
    ref,
    otherMemberId: blocking.memberId,
    otherName: name,
    seedBody: '$token ',
  );
}

/// The shared "Message …" affordance (button form) — scan/space
/// sheets embed it under their blocked-space info.
class MessageReserverButton extends ConsumerWidget {
  const MessageReserverButton({
    super.key,
    required this.blocking,
    required this.name,
    required this.spaceName,
    this.widgetKey,
  });

  final Reservation blocking;
  final String name;
  final String spaceName;
  final Key? widgetKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return OutlinedButton.icon(
      key: widgetKey,
      icon: const Icon(Icons.chat_outlined),
      label: Text(l10n?.spaceMessageReserver(name) ?? 'Message $name'),
      onPressed: () => messageReserver(
        context,
        ref,
        blocking: blocking,
        name: name,
        spaceName: spaceName,
      ),
    );
  }
}

/// Regular-member sheet on a seat/space held by someone else (Plan tab,
/// #622): who holds it and until when — plus the message affordance.
/// The caller gates on [canMessageReserver]; without it the old
/// info-snack stays.
Future<void> showBlockedSpaceSheet(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String infoLine,
  required Reservation blocking,
  required String name,
  required String spaceName,
}) async {
  final l10n = AppLocalizations.of(context);
  final message = await showModalBottomSheet<bool>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(title.isEmpty ? infoLine : title),
            subtitle: title.isEmpty ? null : Text(infoLine),
          ),
          ListTile(
            key: const ValueKey('blocked-message-reserver'),
            leading: const Icon(Icons.chat_outlined),
            title: Text(l10n?.spaceMessageReserver(name) ?? 'Message $name'),
            onTap: () => Navigator.of(sheetContext).pop(true),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (message != true || !context.mounted) return;
  await messageReserver(
    context,
    ref,
    blocking: blocking,
    name: name,
    spaceName: spaceName,
  );
}
