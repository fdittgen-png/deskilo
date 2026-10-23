// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_member_kiosk.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The kiosk account's write.

@ProviderFor(setMemberKiosk)
final setMemberKioskProvider = SetMemberKioskProvider._();

/// The kiosk account's write.

final class SetMemberKioskProvider
    extends $FunctionalProvider<SetMemberKiosk, SetMemberKiosk, SetMemberKiosk>
    with $Provider<SetMemberKiosk> {
  /// The kiosk account's write.
  SetMemberKioskProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'setMemberKioskProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$setMemberKioskHash();

  @$internal
  @override
  $ProviderElement<SetMemberKiosk> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SetMemberKiosk create(Ref ref) {
    return setMemberKiosk(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SetMemberKiosk value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SetMemberKiosk>(value),
    );
  }
}

String _$setMemberKioskHash() => r'ad764c1c4b92a1f871ed7ae7765bfdd8a3b5f0e1';
