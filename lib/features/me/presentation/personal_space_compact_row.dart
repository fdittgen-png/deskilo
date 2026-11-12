// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step E -- a space on Home: an initial, the business's name, where the
// person stands in plain words, and where booking is allowed a tonal Book.
// The whole text is one button (the space, or the request's status); the
// server and verification detail live on the Places tab's own card.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/personal_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../application/personal_spaces_view.dart';
import '../domain/personal_workspace_refs.dart';
import 'kit/me_row.dart';
import 'personal_space_card.dart';

class PersonalSpaceCompactRow extends ConsumerWidget {
  const PersonalSpaceCompactRow({super.key, required this.row});

  final PersonalSpaceRow row;

  /// Where the person stands, in plain words.
  static String stand(AppLocalizations l10n, PersonalSpaceEntry entry) {
    final ref = entry.ref;
    if (ref.freshness == RefFreshness.unavailable) return l10n.meRefUnverified;
    return switch (ref.status) {
      RefStatus.pending => l10n.mePlaceRequestSent,
      RefStatus.active => l10n.mePlaceMember,
      _ => l10n.meRefNoRelationship,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final entry = row.main;
    final id = entry.ref.networkId;
    final name = entry.ref.label ?? l10n.meRefUnnamed;
    final local = entry.local;
    final open = entry.action == PersonalSpaceAction.open && local != null;
    final pending = entry.action == PersonalSpaceAction.requestStatus;
    final stand0 = stand(l10n, entry);
    final VoidCallback? onTap = open
        ? () => openMySpace(ref, context, local)
        : pending
        ? () => context.push('/applications')
        : null;
    // A test space is entered, never booked from Home.
    final book = open && !entry.isTest;
    return Padding(
      key: ValueKey('my-space-$id'),
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: MeRow(
        key: ValueKey('my-space-row-$id'),
        leading: Text(
          name.characters.firstOrNull?.toUpperCase() ?? '',
          style: TextStyle(color: PersonalTheme.of(context).primary),
        ),
        title: name,
        subtitle: stand0,
        semanticLabel: l10n.titleAndBody(name, stand0),
        onTap: onTap,
        trailing: book
            ? FilledButton.tonal(
                key: ValueKey('my-space-open-$id'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, PersonalShellMetrics.minTarget),
                ),
                onPressed: () => openMySpace(ref, context, local),
                child: Text(l10n.meNextBook),
              )
            : null,
      ),
    );
  }
}
