// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/member_monogram.dart';
import '../../providers/profile_providers.dart';

/// A member's avatar (0038): their uploaded photo when they set one, the
/// name's initial otherwise. Shared by the directory row and detail sheet
/// so photos appear everywhere the initial used to. The photo download is
/// gated on [hasAvatar] — a member with no photo never triggers a fetch.
class MemberAvatar extends ConsumerWidget {
  const MemberAvatar({
    required this.userId,
    required this.name,
    required this.hasAvatar,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
    super.key,
  });

  /// auth.users id — the avatar bucket folder and provider key.
  final String userId;

  /// Display name. #793 — the fallback glyph is the member's monogram
  /// when the workspace's member list can supply a unique one, and the
  /// plain first letter otherwise.
  final String name;

  /// Whether the member's profile carries a photo (`Profile.hasAvatar`).
  /// False skips the download entirely.
  final bool hasAvatar;

  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // #793 — one member, one monogram. The map is keyed by user id and
    // is empty while the feature is off or the member list is still
    // loading, so an unknown face keeps the historical single letter.
    final initial =
        ref.watch(memberMonogramsProvider)[userId] ?? plainInitial(name);
    final bg = backgroundColor ?? theme.colorScheme.primaryContainer;
    final fg = foregroundColor ?? theme.colorScheme.onPrimaryContainer;

    final bytes = hasAvatar ? ref.watch(memberAvatarProvider(userId)).value : null;
    // Decode at DISPLAY size (#401): a camera-sized photo fed straight to
    // MemoryImage decodes at full resolution — tens of MB of bitmap to
    // paint a small circle, once per member row. ResizeImage makes the
    // engine decode to the circle's physical pixels instead.
    final targetWidth =
        (radius * 2 * MediaQuery.devicePixelRatioOf(context)).round();
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      foregroundColor: fg,
      backgroundImage: bytes == null
          ? null
          : ResizeImage(MemoryImage(bytes), width: targetWidth),
      // The initial stays as the fallback child; a loaded photo covers it.
      child: bytes == null
          ? Text(
              initial,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: radius * 0.8,
              ),
            )
          : null,
    );
  }
}
