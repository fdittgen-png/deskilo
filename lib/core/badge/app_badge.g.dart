// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_badge.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appBadge)
final appBadgeProvider = AppBadgeProvider._();

final class AppBadgeProvider
    extends $FunctionalProvider<AppBadge, AppBadge, AppBadge>
    with $Provider<AppBadge> {
  AppBadgeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appBadgeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appBadgeHash();

  @$internal
  @override
  $ProviderElement<AppBadge> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppBadge create(Ref ref) {
    return appBadge(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppBadge value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppBadge>(value),
    );
  }
}

String _$appBadgeHash() => r'd626f646b24fe0395b594a75b41512436cdd5520';
