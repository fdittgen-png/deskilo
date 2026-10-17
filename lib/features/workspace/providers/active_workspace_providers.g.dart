// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_workspace_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The persisted active-profile choice (#89). At START-UP the user's
/// DEFAULT profile wins (#322; server-first since #458, so a fresh install
/// lands on it); in-session switches last until the next start. The
/// device's memory is per account (#1823). Null: no space chosen yet.

@ProviderFor(ActiveWorkspaceId)
final activeWorkspaceIdProvider = ActiveWorkspaceIdProvider._();

/// The persisted active-profile choice (#89). At START-UP the user's
/// DEFAULT profile wins (#322; server-first since #458, so a fresh install
/// lands on it); in-session switches last until the next start. The
/// device's memory is per account (#1823). Null: no space chosen yet.
final class ActiveWorkspaceIdProvider
    extends $AsyncNotifierProvider<ActiveWorkspaceId, String?> {
  /// The persisted active-profile choice (#89). At START-UP the user's
  /// DEFAULT profile wins (#322; server-first since #458, so a fresh install
  /// lands on it); in-session switches last until the next start. The
  /// device's memory is per account (#1823). Null: no space chosen yet.
  ActiveWorkspaceIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeWorkspaceIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeWorkspaceIdHash();

  @$internal
  @override
  ActiveWorkspaceId create() => ActiveWorkspaceId();
}

String _$activeWorkspaceIdHash() => r'8ffee45466d6fbbf8838413846e825bb821db230';

/// The persisted active-profile choice (#89). At START-UP the user's
/// DEFAULT profile wins (#322; server-first since #458, so a fresh install
/// lands on it); in-session switches last until the next start. The
/// device's memory is per account (#1823). Null: no space chosen yet.

abstract class _$ActiveWorkspaceId extends $AsyncNotifier<String?> {
  FutureOr<String?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, String?>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
