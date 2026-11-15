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

/// The owners' commands; a change reads the organisations again.

@ProviderFor(organisationCommands)
final organisationCommandsProvider = OrganisationCommandsProvider._();

/// The owners' commands; a change reads the organisations again.

final class OrganisationCommandsProvider
    extends
        $FunctionalProvider<
          OrganisationCommands,
          OrganisationCommands,
          OrganisationCommands
        >
    with $Provider<OrganisationCommands> {
  /// The owners' commands; a change reads the organisations again.
  OrganisationCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'organisationCommandsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$organisationCommandsHash();

  @$internal
  @override
  $ProviderElement<OrganisationCommands> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OrganisationCommands create(Ref ref) {
    return organisationCommands(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OrganisationCommands value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OrganisationCommands>(value),
    );
  }
}

String _$organisationCommandsHash() =>
    r'c31d198cdd02f8baa099fa01c412241b9d51cc7e';

/// #4008 — the houses of the reader's organisations they may ask to join.

@ProviderFor(joinableHouses)
final joinableHousesProvider = JoinableHousesProvider._();

/// #4008 — the houses of the reader's organisations they may ask to join.

final class JoinableHousesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<JoinableHouse>>,
          List<JoinableHouse>,
          FutureOr<List<JoinableHouse>>
        >
    with
        $FutureModifier<List<JoinableHouse>>,
        $FutureProvider<List<JoinableHouse>> {
  /// #4008 — the houses of the reader's organisations they may ask to join.
  JoinableHousesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'joinableHousesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$joinableHousesHash();

  @$internal
  @override
  $FutureProviderElement<List<JoinableHouse>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<JoinableHouse>> create(Ref ref) {
    return joinableHouses(ref);
  }
}

String _$joinableHousesHash() => r'b9f7981aa4f58504c7b67903a90e13c67db78862';

/// #4008 — whether the house [workspaceId] of [organisationId] welcomes the
/// members of the organisation's other houses at once.

@ProviderFor(houseWelcomes)
final houseWelcomesProvider = HouseWelcomesFamily._();

/// #4008 — whether the house [workspaceId] of [organisationId] welcomes the
/// members of the organisation's other houses at once.

final class HouseWelcomesProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// #4008 — whether the house [workspaceId] of [organisationId] welcomes the
  /// members of the organisation's other houses at once.
  HouseWelcomesProvider._({
    required HouseWelcomesFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'houseWelcomesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$houseWelcomesHash();

  @override
  String toString() {
    return r'houseWelcomesProvider'
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
    return houseWelcomes(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is HouseWelcomesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$houseWelcomesHash() => r'2ea28b7b21514c2e1cabda5b2eedfc96257eda76';

/// #4008 — whether the house [workspaceId] of [organisationId] welcomes the
/// members of the organisation's other houses at once.

final class HouseWelcomesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, (String, String)> {
  HouseWelcomesFamily._()
    : super(
        retry: null,
        name: r'houseWelcomesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// #4008 — whether the house [workspaceId] of [organisationId] welcomes the
  /// members of the organisation's other houses at once.

  HouseWelcomesProvider call(String organisationId, String workspaceId) =>
      HouseWelcomesProvider._(
        argument: (organisationId, workspaceId),
        from: this,
      );

  @override
  String toString() => r'houseWelcomesProvider';
}

/// #4005 — the birth record of [workspaceId], if it was made as a house.

@ProviderFor(houseBirth)
final houseBirthProvider = HouseBirthFamily._();

/// #4005 — the birth record of [workspaceId], if it was made as a house.

final class HouseBirthProvider
    extends
        $FunctionalProvider<
          AsyncValue<HouseBirth?>,
          HouseBirth?,
          FutureOr<HouseBirth?>
        >
    with $FutureModifier<HouseBirth?>, $FutureProvider<HouseBirth?> {
  /// #4005 — the birth record of [workspaceId], if it was made as a house.
  HouseBirthProvider._({
    required HouseBirthFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'houseBirthProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$houseBirthHash();

  @override
  String toString() {
    return r'houseBirthProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<HouseBirth?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<HouseBirth?> create(Ref ref) {
    final argument = this.argument as String;
    return houseBirth(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is HouseBirthProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$houseBirthHash() => r'13dc5bba3516912d7f1297ab51b456cab5e64936';

/// #4005 — the birth record of [workspaceId], if it was made as a house.

final class HouseBirthFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<HouseBirth?>, String> {
  HouseBirthFamily._()
    : super(
        retry: null,
        name: r'houseBirthProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// #4005 — the birth record of [workspaceId], if it was made as a house.

  HouseBirthProvider call(String workspaceId) =>
      HouseBirthProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'houseBirthProvider';
}

/// #4005 — the house just made, whose birth record its home shows once.

@ProviderFor(PendingHouseBirth)
final pendingHouseBirthProvider = PendingHouseBirthProvider._();

/// #4005 — the house just made, whose birth record its home shows once.
final class PendingHouseBirthProvider
    extends $NotifierProvider<PendingHouseBirth, String?> {
  /// #4005 — the house just made, whose birth record its home shows once.
  PendingHouseBirthProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingHouseBirthProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingHouseBirthHash();

  @$internal
  @override
  PendingHouseBirth create() => PendingHouseBirth();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$pendingHouseBirthHash() => r'fc16da261a6f3992af773ca6f8e9cebe68a29da1';

/// #4005 — the house just made, whose birth record its home shows once.

abstract class _$PendingHouseBirth extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
