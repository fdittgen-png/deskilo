// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'save_new_member_defaults.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The new-member defaults' write.

@ProviderFor(saveNewMemberDefaults)
final saveNewMemberDefaultsProvider = SaveNewMemberDefaultsProvider._();

/// The new-member defaults' write.

final class SaveNewMemberDefaultsProvider
    extends
        $FunctionalProvider<
          SaveNewMemberDefaults,
          SaveNewMemberDefaults,
          SaveNewMemberDefaults
        >
    with $Provider<SaveNewMemberDefaults> {
  /// The new-member defaults' write.
  SaveNewMemberDefaultsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'saveNewMemberDefaultsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$saveNewMemberDefaultsHash();

  @$internal
  @override
  $ProviderElement<SaveNewMemberDefaults> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SaveNewMemberDefaults create(Ref ref) {
    return saveNewMemberDefaults(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SaveNewMemberDefaults value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SaveNewMemberDefaults>(value),
    );
  }
}

String _$saveNewMemberDefaultsHash() =>
    r'147efb94ace37ae889c50b630f0b389b6d38bfa7';
