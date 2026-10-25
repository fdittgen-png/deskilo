// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/presentation/widgets/member_avatar.dart';
import '../../../reservations/domain/reservation.dart';
import '../../application/directory_card.dart';
import 'directory_chips.dart';
import 'member_contact_card.dart';
import 'member_money_card.dart';

/// The member's public-profile bottom sheet (#232): avatar, name, role
/// (roles are additive flags, spec §2 — owner wins the single label),
/// the automatic reservation + presence chips (#237), the self-set
/// status line (#231) and the WhatsApp contact button when the member
/// shared a number (#223).
/// #695 — PUBLIC so the messaging centre opens the SAME profile the
/// directory does, rather than growing a second one that drifts.
/// [openMemberProfile] is the door for other features.
Future<void> showMemberProfileSheet(
  BuildContext context, {
  required DirectoryCard card,
  required void Function(Uri uri) onWhatsapp,
  required void Function(Reservation reservation) onOpenReservation,
  // Member notes (#456): null hides the affordance (feature off, self).
  VoidCallback? onNotify,
}) {
  return showAppSheet<void>(
    context: context,
    // Scrollable so a full sheet (role + chip + status + button) never
    // overflows small viewports.
    isScrollControlled: true,
    builder: (sheetContext) => _MemberProfileSheet(
      card: card,
      onWhatsapp: onWhatsapp,
      onOpenReservation: onOpenReservation,
      onNotify: onNotify,
    ),
  );
}

class _MemberProfileSheet extends StatelessWidget {
  const _MemberProfileSheet({
    required this.card,
    required this.onWhatsapp,
    required this.onOpenReservation,
    required this.onNotify,
  });

  final DirectoryCard card;
  final void Function(Uri uri) onWhatsapp;
  final void Function(Reservation reservation) onOpenReservation;
  final VoidCallback? onNotify;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final chips = <Widget>[
      ?directoryReservationChip(context, l10n, card,
          keyPrefix: 'directory-sheet-res'),
      ?directoryPresenceChip(context, l10n, card,
          keyPrefix: 'directory-sheet-status'),
    ];
    final statusText = card.statusText;
    final member = card.member;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(theme, l10n),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: chips,
              ),
            ],
            if (statusText.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(statusText, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: AppSpacing.lg),
            ..._reservations(context, theme, l10n),
            // #704 — contact, then money, on the profile of the
            // person they belong to. Each is role-gated INSIDE its own
            // widget: this sheet opens from four places, and a gate
            // repeated four times is one that gets forgotten once.
            MemberContactCard(member: member, isSelf: card.isSelf),
            MemberMoneyCard(memberId: member.id, isSelf: card.isSelf),
            const SizedBox(height: AppSpacing.lg),
            ..._actions(context, l10n),
          ],
        ),
      ),
    );
  }

  String _roleLabel(AppLocalizations l10n) => switch (card.role) {
        DirectoryRole.owner => l10n.memberRoleOwner,
        DirectoryRole.admin => l10n.memberRoleAdmin,
        DirectoryRole.member => l10n.memberRoleMember,
      };

  Widget _header(ThemeData theme, AppLocalizations l10n) {
    return Row(
      children: [
        MemberAvatar(
          userId: card.member.userId,
          name: card.name,
          hasAvatar: card.hasAvatar,
          radius: 24,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: card.isSelf ? FontWeight.bold : null,
                ),
              ),
              Text(
                _roleLabel(l10n),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _reservations(
      BuildContext context, ThemeData theme, AppLocalizations l10n) {
    return [
      Text(
        l10n.directoryReservationsHeading,
        style: theme.textTheme.titleSmall,
      ),
      const SizedBox(height: AppSpacing.xs),
      if (card.memberReservations.isEmpty)
        Text(
          l10n.directoryNoUpcoming,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        )
      else
        for (final reservation in card.memberReservations)
          DirectoryReservationTile(
            key: ValueKey('directory-reservation-tile-${reservation.id}'),
            reservation: reservation,
            seatName: reservation.spaceNameFrom(card.targetNames),
            onTap: () {
              Navigator.of(context).pop();
              onOpenReservation(reservation);
            },
          ),
    ];
  }

  List<Widget> _actions(BuildContext context, AppLocalizations l10n) {
    final notify = onNotify;
    final whatsappUri = card.whatsappUri;
    final id = card.member.id;
    return [
      if (notify != null) ...[
        FilledButton.icon(
          key: ValueKey('directory-sheet-notify-$id'),
          icon: const Icon(Icons.notifications_active_outlined),
          label: Text(l10n.memberNotifyAction),
          onPressed: () {
            Navigator.of(context).pop();
            notify();
          },
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      if (whatsappUri != null) ...[
        FilledButton.icon(
          key: ValueKey('directory-sheet-wa-$id'),
          icon: const Icon(Icons.chat_outlined),
          label: Text(l10n.directoryWhatsapp),
          onPressed: () {
            Navigator.of(context).pop();
            onWhatsapp(whatsappUri);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      TextButton(
        key: const ValueKey('directory-contact-close'),
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.directoryClose),
      ),
    ];
  }
}
