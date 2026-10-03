// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/member_monogram.dart';
import '../../providers/profile_providers.dart';

/// Account identity stays the same in every workspace and in Me.
class PersonalAvatar extends ConsumerWidget {
  const PersonalAvatar({super.key, this.radius = 14});
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;
    final bytes = profile != null && profile.hasAvatar
        ? ref.watch(memberAvatarProvider(profile.id)).value
        : null;
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xffdce2f1),
      foregroundColor: const Color(0xff29334f),
      backgroundImage: bytes == null
          ? null
          : ResizeImage(
              MemoryImage(bytes),
              width: (radius * 2 * MediaQuery.devicePixelRatioOf(context))
                  .round(),
            ),
      child: bytes == null
          ? Text(
              plainInitial(profile?.displayName ?? ''),
              style: TextStyle(
                fontSize: radius * .8,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );
  }
}
