// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/status_colors.dart';
import '../../../../core/theme/app_typography.dart';
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
      backgroundColor: AppIdentityColors.background,
      foregroundColor: AppIdentityColors.foreground,
      backgroundImage: bytes == null
          ? null
          : ResizeImage(
              MemoryImage(bytes),
              width: (radius * 2 * MediaQuery.devicePixelRatioOf(context))
                  .round(),
            ),
      // The initial is decoration: wherever the avatar is a control, the
      // control names itself ("Back to Me"), so a screen reader must not
      // announce a bare letter, and the text-contrast audit must not read
      // the letter against the whole 48 dp button it sits in (#2136).
      child: bytes == null
          ? ExcludeSemantics(
              child: Text(
                plainInitial(profile?.displayName ?? ''),
                style: Theme.of(context).textTheme.labelLarge?.emphasised
                    .copyWith(color: AppIdentityColors.foreground),
              ),
            )
          : null,
    );
  }
}
