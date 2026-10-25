// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/presentation/widgets/member_avatar.dart';
import '../../../reservations/domain/reservation.dart';
import '../../application/directory_card.dart';
import 'directory_chips.dart';
import 'member_profile_sheet.dart';

/// One directory row: avatar initial, name (bold when it is me), the
/// self-set status line when present, the reservation + presence chips
/// (#237) flowing in a [Wrap], trailing WhatsApp button when the member
/// shared a number. Tap opens the detail sheet; rows of sharing members
/// additionally swipe right to WhatsApp — no swipe affordance exists at
/// all without a number.
class DirectoryMemberRow extends StatelessWidget {
  const DirectoryMemberRow({
    super.key,
    required this.card,
    required this.onWhatsapp,
    required this.onOpenReservation,
    this.onNotify,
    this.onOpenPage,
  });

  final DirectoryCard card;

  /// #825 — set when the member page is on: the tap goes there.
  final VoidCallback? onOpenPage;
  final void Function(Uri uri) onWhatsapp;
  final void Function(Reservation reservation) onOpenReservation;

  /// Member notes (#456): null hides the affordance.
  final VoidCallback? onNotify;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final whatsappUri = card.whatsappUri;
    final tile = ListTile(
      key: const ValueKey('directory-whatsapp'),
      leading: _avatar(theme),
      title: Row(
        children: [
          Flexible(
            child: Text(
              card.name,
              overflow: TextOverflow.ellipsis,
              style: card.isSelf
                  ? const TextStyle(fontWeight: FontWeight.bold)
                  : null,
            ),
          ),
          ?directoryRoleBadge(context, l10n, card),
        ],
      ),
      subtitle: card.hasSubtitle ? _subtitle(context, theme, l10n) : null,
      trailing: whatsappUri == null
          ? null
          : IconButton(
              key: ValueKey('directory-wa-${card.member.id}'),
              icon: const Icon(Icons.chat_outlined),
              tooltip: l10n.directoryWhatsapp,
              onPressed: () => onWhatsapp(whatsappUri),
            ),
      // #825 — the member page when its flag is on; the sheet otherwise.
      onTap: () => onOpenPage != null
          ? onOpenPage!()
          : showMemberProfileSheet(
              context,
              card: card,
              onWhatsapp: onWhatsapp,
              onOpenReservation: onOpenReservation,
              onNotify: onNotify,
            ),
    );
    final framed = _card(theme, tile);
    if (whatsappUri == null) return framed;
    return _swipeToChat(theme, l10n, whatsappUri, framed);
  }

  Widget _avatar(ThemeData theme) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        MemberAvatar(
          userId: card.member.userId,
          name: card.name,
          hasAvatar: card.hasAvatar,
        ),
        // Presence at a glance: a ringed dot on the avatar — green
        // when online — before any text is read.
        if (card.online)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppStatusColors.successOf(theme.brightness),
                border: Border.all(
                  color: theme.colorScheme.surface,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _subtitle(
      BuildContext context, ThemeData theme, AppLocalizations l10n) {
    final chips = <Widget>[
      ?directoryReservationChip(context, l10n, card),
      ?directoryPresenceChip(context, l10n, card),
    ];
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (card.email.isNotEmpty)
          Text(
            card.email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: muted,
          ),
        if (card.statusText.isNotEmpty)
          Text(
            card.statusText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: muted,
          ),
        if (chips.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: chips,
            ),
          ),
      ],
    );
  }

  /// Presence-forward card: soft elevation for every member, a warm
  /// success-tinted surface for whoever is checked in RIGHT NOW — the
  /// room's live roster pops without reordering the list.
  Widget _card(ThemeData theme, Widget tile) {
    final brightness = theme.brightness;
    final cardColor = card.onSite
        ? Color.alphaBlend(
            AppStatusColors.successOf(brightness).withValues(alpha: 0.10),
            theme.colorScheme.surfaceContainerLow,
          )
        : theme.colorScheme.surfaceContainerLow;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenGutter,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgAll,
        boxShadow: AppElevation.low(brightness),
      ),
      child: Material(
        color: cardColor,
        borderRadius: AppRadius.lgAll,
        clipBehavior: Clip.antiAlias,
        child: tile,
      ),
    );
  }

  /// Swipe right to chat (#232). `confirmDismiss` always resolves false:
  /// the launch is a side effect and the row snaps back — Dismissible
  /// never actually removes it from the list.
  Widget _swipeToChat(ThemeData theme, AppLocalizations l10n,
      Uri whatsappUri, Widget child) {
    final brightness = theme.brightness;
    return Dismissible(
      key: ValueKey('directory-swipe-${card.member.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        onWhatsapp(whatsappUri);
        return false;
      },
      background: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenGutter,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppStatusColors.successOf(brightness),
          borderRadius: AppRadius.lgAll,
        ),
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenGutter,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat, color: AppStatusColors.onSuccessOf(brightness)),
            const SizedBox(width: AppSpacing.sm),
            Text(
              l10n.directoryWhatsapp,
              style: TextStyle(color: AppStatusColors.onSuccessOf(brightness)),
            ),
          ],
        ),
      ),
      child: child,
    );
  }
}

/// Tappable card above the list opening the owner-set WhatsApp group
/// (#231/#232); the caller renders it only when a link is configured.
class DirectoryGroupTile extends StatelessWidget {
  const DirectoryGroupTile({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      key: const ValueKey('directory-group'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenGutter,
        vertical: AppSpacing.sm,
      ),
      child: ListTile(
        key: const ValueKey('directory-open-group'),
        leading: const Icon(Icons.groups_outlined),
        title: Text(l10n.directoryOpenGroup),
        trailing: const Icon(Icons.open_in_new),
        onTap: onOpen,
      ),
    );
  }
}
