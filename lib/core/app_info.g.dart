// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_info.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The installed app version as "x.y.z+build" (#560) — shown in the
/// About section. '' when the platform channel is unavailable (tests,
/// exotic embeddings): the tile then simply shows no subtitle.

@ProviderFor(appVersion)
final appVersionProvider = AppVersionProvider._();

/// The installed app version as "x.y.z+build" (#560) — shown in the
/// About section. '' when the platform channel is unavailable (tests,
/// exotic embeddings): the tile then simply shows no subtitle.

final class AppVersionProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// The installed app version as "x.y.z+build" (#560) — shown in the
  /// About section. '' when the platform channel is unavailable (tests,
  /// exotic embeddings): the tile then simply shows no subtitle.
  AppVersionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appVersionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appVersionHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return appVersion(ref);
  }
}

String _$appVersionHash() => r'451751069a7c9f99a7552b953f612bb0b9b19cd9';
