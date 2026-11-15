// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organisation_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(organisationRepository)
final organisationRepositoryProvider = OrganisationRepositoryProvider._();

final class OrganisationRepositoryProvider
    extends
        $FunctionalProvider<
          OrganisationRepository,
          OrganisationRepository,
          OrganisationRepository
        >
    with $Provider<OrganisationRepository> {
  OrganisationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'organisationRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$organisationRepositoryHash();

  @$internal
  @override
  $ProviderElement<OrganisationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OrganisationRepository create(Ref ref) {
    return organisationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OrganisationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OrganisationRepository>(value),
    );
  }
}

String _$organisationRepositoryHash() =>
    r'f73fd384c35f074a1d6497eb7d9334dcd5646624';

/// Every organisation the reader is a member of a house of.

@ProviderFor(myOrganisations)
final myOrganisationsProvider = MyOrganisationsProvider._();

/// Every organisation the reader is a member of a house of.

final class MyOrganisationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Organisation>>,
          List<Organisation>,
          FutureOr<List<Organisation>>
        >
    with
        $FutureModifier<List<Organisation>>,
        $FutureProvider<List<Organisation>> {
  /// Every organisation the reader is a member of a house of.
  MyOrganisationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myOrganisationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myOrganisationsHash();

  @$internal
  @override
  $FutureProviderElement<List<Organisation>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Organisation>> create(Ref ref) {
    return myOrganisations(ref);
  }
}

String _$myOrganisationsHash() => r'df66c119979f93643268b34614a2aa45ba22ef6f';
