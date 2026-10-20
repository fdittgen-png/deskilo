// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../profile/presentation/widgets/member_avatar.dart';

/// The self-dismissing receipt: who, what, where, until when — big
/// enough to verify the badge resolved to the right person, gone in a
/// few seconds so the next member finds a clean wall. Tap anywhere to
/// dismiss sooner.
class KioskSuccessCard extends StatefulWidget {
  const KioskSuccessCard({
    super.key,
    required this.actionLabel,
    required this.memberName,
    required this.avatarUserId,
    required this.hasAvatar,
    required this.targetName,
    required this.rangeText,
  });

  final String actionLabel;
  final String memberName;

  /// The subject's auth user id for their profile photo (#616) — null
  /// hides the avatar entirely (feature off or unknown user).
  final String? avatarUserId;
  final bool hasAvatar;
  final String targetName;
  final String? rangeText;

  @override
  State<KioskSuccessCard> createState() => KioskSuccessCardState();
}

class KioskSuccessCardState extends State<KioskSuccessCard> {
  Timer? _dismiss;

  @override
  void initState() {
    super.initState();
    _dismiss = Timer(const Duration(seconds: 4), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _dismiss?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rangeText = widget.rangeText;
    return AlertDialog(scrollable: true,
      key: const ValueKey('kiosk-success-card'),
      icon: Icon(
        Icons.check_circle_outline,
        size: 44,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(widget.actionLabel),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // #616 — the badge's face: the member's photo when they set
          // one, their initial otherwise.
          if (widget.avatarUserId case final userId?
              when userId.isNotEmpty) ...[
            MemberAvatar(
              key: const ValueKey('kiosk-summary-avatar'),
              userId: userId,
              name: widget.memberName,
              hasAvatar: widget.hasAvatar,
              radius: 32,
            ),
            const SizedBox(height: 8),
          ],
          Text(
            widget.memberName,
            key: const ValueKey('kiosk-summary-name'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(widget.targetName),
          if (rangeText != null) ...[
            const SizedBox(height: 4),
            Text(
              rangeText,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
