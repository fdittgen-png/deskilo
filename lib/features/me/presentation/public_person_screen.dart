// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2211 — /p/:id, for anyone, signed in or not: a person's public profile,
// exactly the three fields they published. An unpublished, withdrawn or
// unknown profile reads the same neutral sentence.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/public_profile_providers.dart';

class PublicPersonScreen extends ConsumerWidget {
  const PublicPersonScreen({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final person = ref.watch(publicPersonProvider(userId));
    final theme = Theme.of(context);
    final gone = EmptyState(
      key: const ValueKey('public-person-unavailable'),
      icon: Icons.person_off_outlined,
      title: l10n?.publicPersonUnavailable ?? 'This profile is not public.',
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n?.publicProfileTitle ?? 'Public profile')),
      body: switch (person) {
        AsyncData(value: final p?) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              key: const ValueKey('public-person'),
              padding: AppSpacing.gutterAll,
              children: [
                CircleAvatar(
                  radius: 40,
                  child: Text(
                    p.name.isEmpty
                        ? '?'
                        : p.name.characters.first.toUpperCase(),
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  p.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.strong,
                ),
                if (p.profession.isNotEmpty)
                  Text(
                    p.profession,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (p.bio.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(p.bio, style: theme.textTheme.bodyLarge),
                ],
              ],
            ),
          ),
        ),
        AsyncData() || AsyncError() => gone,
        _ => const LoadingView(),
      },
    );
  }
}
