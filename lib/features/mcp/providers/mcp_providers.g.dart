// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(actionConfirmationRepository)
final actionConfirmationRepositoryProvider =
    ActionConfirmationRepositoryProvider._();

final class ActionConfirmationRepositoryProvider
    extends
        $FunctionalProvider<
          ActionConfirmationRepository,
          ActionConfirmationRepository,
          ActionConfirmationRepository
        >
    with $Provider<ActionConfirmationRepository> {
  ActionConfirmationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'actionConfirmationRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$actionConfirmationRepositoryHash();

  @$internal
  @override
  $ProviderElement<ActionConfirmationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ActionConfirmationRepository create(Ref ref) {
    return actionConfirmationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActionConfirmationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActionConfirmationRepository>(value),
    );
  }
}

String _$actionConfirmationRepositoryHash() =>
    r'a8a9d46d88e5ca5c391da2845f4a314d14a8a98d';

/// One confirmation, as the server answers it now.

@ProviderFor(actionConfirmation)
final actionConfirmationProvider = ActionConfirmationFamily._();

/// One confirmation, as the server answers it now.

final class ActionConfirmationProvider
    extends
        $FunctionalProvider<
          AsyncValue<ActionConfirmation>,
          ActionConfirmation,
          FutureOr<ActionConfirmation>
        >
    with
        $FutureModifier<ActionConfirmation>,
        $FutureProvider<ActionConfirmation> {
  /// One confirmation, as the server answers it now.
  ActionConfirmationProvider._({
    required ActionConfirmationFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'actionConfirmationProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$actionConfirmationHash();

  @override
  String toString() {
    return r'actionConfirmationProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ActionConfirmation> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ActionConfirmation> create(Ref ref) {
    final argument = this.argument as String;
    return actionConfirmation(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ActionConfirmationProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$actionConfirmationHash() =>
    r'1446a08934cd8f33ef8aba6dcd0bf78271df3c01';

/// One confirmation, as the server answers it now.

final class ActionConfirmationFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ActionConfirmation>, String> {
  ActionConfirmationFamily._()
    : super(
        retry: null,
        name: r'actionConfirmationProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One confirmation, as the server answers it now.

  ActionConfirmationProvider call(String id) =>
      ActionConfirmationProvider._(argument: id, from: this);

  @override
  String toString() => r'actionConfirmationProvider';
}
