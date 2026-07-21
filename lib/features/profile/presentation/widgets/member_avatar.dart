// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// Display name; its first letter is the fallback glyph.
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
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final bg = backgroundColor ?? theme.colorScheme.primaryContainer;
    final fg = foregroundColor ?? theme.colorScheme.onPrimaryContainer;

    final bytes = hasAvatar ? ref.watch(memberAvatarProvider(userId)).value : null;
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      foregroundColor: fg,
      backgroundImage: bytes == null ? null : MemoryImage(bytes),
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
