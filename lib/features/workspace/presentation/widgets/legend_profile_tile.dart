// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1281 — how many states the plan tells apart, chosen by the space.
//
// The field report asked for four words where the app draws six states.
// Two requests hide in that sentence, and answering only the first is a
// bug: a legend with four entries over a canvas painting five colours
// leaves a member looking at a colour nothing explains.
//
// So one choice drives both, and what `simple` gives up is written in
// its own subtitle rather than discovered later — the issue put that
// question to the responsable, and this is what makes it a question
// each space answers for itself instead of one answered for everybody.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/trace/trace_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/booking_policies.dart';
import '../../providers/workspace_providers.dart';

class LegendProfileTile extends ConsumerWidget {
  const LegendProfileTile({super.key, required this.policies});

  final BookingPolicies policies;

  static const groupKey = Key('legend-profile');
  static const fullKey = Key('legend-profile-full');
  static const simpleKey = Key('legend-profile-simple');

  Future<void> _set(WidgetRef ref, LegendProfile? profile) async {
    if (profile == null) return;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .setLegendProfile(workspace.id, profile);
    } catch (e, st) {
      TraceLogger.instance.error('workspace', 'set legend profile failed',
          error: e, stackTrace: st);
    }
    ref.invalidate(currentWorkspaceProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title:
              Text(l10n?.legendProfileTitle ?? 'What the plan tells apart'),
        ),
        RadioGroup<LegendProfile>(
          key: groupKey,
          groupValue: policies.legendProfile,
          onChanged: (profile) => _set(ref, profile),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<LegendProfile>(
                key: fullKey,
                value: LegendProfile.full,
                title: Text(l10n?.legendProfileFull ?? 'Every state'),
                subtitle: Text(l10n?.legendProfileFullDesc ??
                    'Free · Reserved · Checked in · Mine · Blocked — you '
                        'can see who has arrived.'),
              ),
              RadioListTile<LegendProfile>(
                key: simpleKey,
                value: LegendProfile.simple,
                title: Text(l10n?.legendProfileSimple ?? 'Fewer states'),
                subtitle: Text(l10n?.legendProfileSimpleDesc ??
                    'Free · Reserved · Mine · Unavailable. A booked seat '
                        'and one somebody has checked into look the same.'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
