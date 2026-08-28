// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../members/providers/directory_providers.dart';
import '../../../profile/presentation/widgets/member_avatar.dart';
import '../../providers/workspace_providers.dart';

/// A GROUP's photo (#687), or its initial when it has none.
///
/// Deliberately the same shape and fallback as a member's avatar: a list
/// that mixed circular photos with some other treatment for groups would
/// make the two read as different kinds of thing, when the whole point
/// of the list is that they are both just conversations.
///
/// The photo itself lands in a later stage; the widget exists now so the
/// row does not have to change shape when it arrives.
class ConversationAvatar extends ConsumerWidget {
  const ConversationAvatar({
    super.key,
    required this.conversationId,
    required this.title,
    this.avatarPath,
    this.radius = 20,
  });

  final String conversationId;
  final String title;
  final String? avatarPath;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final initial = title.trim().isEmpty ? '#' : title.trim()[0].toUpperCase();
    return CircleAvatar(
      key: ValueKey('conversation-avatar-$conversationId'),
      radius: radius,
      backgroundColor: theme.colorScheme.secondaryContainer,
      foregroundColor: theme.colorScheme.onSecondaryContainer,
      child: Text(initial),
    );
  }
}

/// A member's avatar addressed by MEMBER id.
///
/// [MemberAvatar] keys on the auth USER id, because that is the avatar
/// bucket's folder. Conversations carry member ids. Bridging them once
/// here beats every caller doing the same two-map lookup — and getting
/// `hasAvatar` wrong there means a download attempt for every member
/// without a photo.
class MemberAvatarByMember extends ConsumerWidget {
  const MemberAvatarByMember({
    super.key,
    required this.memberId,
    required this.name,
    this.radius = 20,
  });

  final String memberId;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(workspaceMembersProvider).value ?? const [];
    final userId =
        members.where((m) => m.id == memberId).map((m) => m.userId).firstOrNull;
    if (userId == null) {
      // The roster has not loaded, or the member left the workspace. An
      // initial is right in both cases: it is what a photo-less member
      // renders as anyway, so nothing flickers when the roster arrives.
      return CircleAvatar(
        radius: radius,
        child: Text(name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase()),
      );
    }
    final profiles = ref.watch(memberProfilesProvider).value ?? const {};
    return MemberAvatar(
      userId: userId,
      name: name,
      hasAvatar: profiles[userId]?.hasAvatar ?? false,
      radius: radius,
    );
  }
}
