// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'share_launcher.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Injectable seam over `SharePlus.instance.share` so widget tests can
/// capture what the app would hand to the system share sheet (#133).

@ProviderFor(shareLauncher)
final shareLauncherProvider = ShareLauncherProvider._();

/// Injectable seam over `SharePlus.instance.share` so widget tests can
/// capture what the app would hand to the system share sheet (#133).

final class ShareLauncherProvider
    extends $FunctionalProvider<ShareLauncher, ShareLauncher, ShareLauncher>
    with $Provider<ShareLauncher> {
  /// Injectable seam over `SharePlus.instance.share` so widget tests can
  /// capture what the app would hand to the system share sheet (#133).
  ShareLauncherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shareLauncherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shareLauncherHash();

  @$internal
  @override
  $ProviderElement<ShareLauncher> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ShareLauncher create(Ref ref) {
    return shareLauncher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShareLauncher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShareLauncher>(value),
    );
  }
}

String _$shareLauncherHash() => r'a7d47496c21304ec0970851e63d690c5bd702096';
