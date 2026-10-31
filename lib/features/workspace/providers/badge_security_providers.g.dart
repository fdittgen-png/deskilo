// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'badge_security_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Only badge administrators inspect PIN review status on the active host.

@ProviderFor(badgePinReview)
final badgePinReviewProvider = BadgePinReviewFamily._();

/// Only badge administrators inspect PIN review status on the active host.

final class BadgePinReviewProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Only badge administrators inspect PIN review status on the active host.
  BadgePinReviewProvider._({
    required BadgePinReviewFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'badgePinReviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$badgePinReviewHash();

  @override
  String toString() {
    return r'badgePinReviewProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as (String, String);
    return badgePinReview(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is BadgePinReviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$badgePinReviewHash() => r'61b08c3e5fa2d1d683c29f8b5d4b7b842fb05d9c';

/// Only badge administrators inspect PIN review status on the active host.

final class BadgePinReviewFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, (String, String)> {
  BadgePinReviewFamily._()
    : super(
        retry: null,
        name: r'badgePinReviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Only badge administrators inspect PIN review status on the active host.

  BadgePinReviewProvider call(String workspaceId, String memberId) =>
      BadgePinReviewProvider._(argument: (workspaceId, memberId), from: this);

  @override
  String toString() => r'badgePinReviewProvider';
}
