// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3550 — the kinds of business, and the workspace's own.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/business_kind_commands.dart';
import '../data/supabase_business_kind_repository.dart';
import '../domain/business_kind.dart';
import '../domain/business_profile.dart';
import '../domain/setup_status.dart';
import '../domain/setup_steps_for_kind.dart';
import '../domain/switched_off_by_kind.dart';
import '../domain/workspace_feature.dart';
import 'local_setup_providers.dart';
import 'settings_providers.dart';
import 'workspace_providers.dart';

part 'business_kind_providers.g.dart';

@Riverpod(keepAlive: true)
BusinessKindRepository businessKindRepository(Ref ref) =>
    SupabaseBusinessKindRepository(ref.watch(selectedWorkspaceClientProvider));

/// The kinds of business, in their order.
@riverpod
Future<List<BusinessKind>> businessKinds(Ref ref) =>
    ref.watch(businessKindRepositoryProvider).kinds();

/// What the selected workspace says it is (coworking until it says otherwise).
@riverpod
Future<BusinessProfile> businessProfile(Ref ref) async =>
    BusinessProfile.fromSettings(
      await ref.watch(currentSettingsProvider.future),
    );

/// What the kind chooser does.
@riverpod
BusinessKindCommands businessKindCommands(Ref ref) => BusinessKindCommands(
  ref.watch(businessKindRepositoryProvider),
  ref.watch(workspaceRepositoryProvider),
  ref.watch(settingsRepositoryProvider),
);

/// #4223 — whether the selected workspace's primary kind keeps places off.
/// Watched, never awaited (the settings are a long chain): until the kinds and
/// the profile are both read, and when one cannot be, it is false, so
/// nothing is hidden on a guess.
@riverpod
bool keepsPlacesOff(Ref ref) {
  final kinds = ref.watch(businessKindsProvider);
  final profile = ref.watch(businessProfileProvider);
  return switch ((kinds, profile)) {
    (AsyncData(value: final k), AsyncData(value: final p)) =>
      switchedOffByKind(WorkspaceFeature.placeBooking, p, k),
    _ => false,
  };
}

/// #4223, #4232 — the setup status a business is shown: a business whose kind
/// keeps places off has no place step in it, so no list, "Next" or resume line
/// can name one. Every reader of the guide's status reads this one.
@riverpod
AsyncValue<SetupStatus> visibleSetupStatus(Ref ref, String workspaceId) {
  final noPlaces = ref.watch(keepsPlacesOffProvider);
  return ref
      .watch(workspaceSetupStatusProvider(workspaceId))
      .whenData((s) => noPlaces ? s.withoutSteps(setupStepsNeedingPlaces) : s);
}
