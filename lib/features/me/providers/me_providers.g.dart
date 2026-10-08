// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'me_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #1823 — the account layer's calls, this server's and the linked ones'.

@ProviderFor(meRepository)
final meRepositoryProvider = MeRepositoryProvider._();

/// #1823 — the account layer's calls, this server's and the linked ones'.

final class MeRepositoryProvider
    extends $FunctionalProvider<MeRepository, MeRepository, MeRepository>
    with $Provider<MeRepository> {
  /// #1823 — the account layer's calls, this server's and the linked ones'.
  MeRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'meRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$meRepositoryHash();

  @$internal
  @override
  $ProviderElement<MeRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MeRepository create(Ref ref) {
    return meRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MeRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MeRepository>(value),
    );
  }
}

String _$meRepositoryHash() => r'4b004994d652d462af3b8d8c0c465078e6b54cb6';

@ProviderFor(meActions)
final meActionsProvider = MeActionsProvider._();

final class MeActionsProvider
    extends $FunctionalProvider<MeActions, MeActions, MeActions>
    with $Provider<MeActions> {
  MeActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'meActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$meActionsHash();

  @$internal
  @override
  $ProviderElement<MeActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MeActions create(Ref ref) {
    return meActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MeActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MeActions>(value),
    );
  }
}

String _$meActionsHash() => r'f3c840a50074fd3a5776af5f373d40075d6f9a14';

/// Who sees what of me, as the server holds it.

@ProviderFor(myVisibility)
final myVisibilityProvider = MyVisibilityProvider._();

/// Who sees what of me, as the server holds it.

final class MyVisibilityProvider
    extends
        $FunctionalProvider<
          AsyncValue<MyVisibility>,
          MyVisibility,
          FutureOr<MyVisibility>
        >
    with $FutureModifier<MyVisibility>, $FutureProvider<MyVisibility> {
  /// Who sees what of me, as the server holds it.
  MyVisibilityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myVisibilityProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myVisibilityHash();

  @$internal
  @override
  $FutureProviderElement<MyVisibility> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MyVisibility> create(Ref ref) {
    return myVisibility(ref);
  }
}

String _$myVisibilityHash() => r'40b833db1e3a7393206add0fb996ff27a8868f21';

/// "How others see me": what [audience] would read.

@ProviderFor(visibilityPreview)
final visibilityPreviewProvider = VisibilityPreviewFamily._();

/// "How others see me": what [audience] would read.

final class VisibilityPreviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<AccountView>,
          AccountView,
          FutureOr<AccountView>
        >
    with $FutureModifier<AccountView>, $FutureProvider<AccountView> {
  /// "How others see me": what [audience] would read.
  VisibilityPreviewProvider._({
    required VisibilityPreviewFamily super.from,
    required PreviewAudience super.argument,
  }) : super(
         retry: null,
         name: r'visibilityPreviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$visibilityPreviewHash();

  @override
  String toString() {
    return r'visibilityPreviewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<AccountView> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AccountView> create(Ref ref) {
    final argument = this.argument as PreviewAudience;
    return visibilityPreview(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is VisibilityPreviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$visibilityPreviewHash() => r'43b2a8c5eab8eb427fc12207ca67d73686d30c1e';

/// "How others see me": what [audience] would read.

final class VisibilityPreviewFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<AccountView>, PreviewAudience> {
  VisibilityPreviewFamily._()
    : super(
        retry: null,
        name: r'visibilityPreviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// "How others see me": what [audience] would read.

  VisibilityPreviewProvider call(PreviewAudience audience) =>
      VisibilityPreviewProvider._(argument: audience, from: this);

  @override
  String toString() => r'visibilityPreviewProvider';
}

/// #2211 — who sees what of me on the linked server [source].

@ProviderFor(linkedVisibility)
final linkedVisibilityProvider = LinkedVisibilityFamily._();

/// #2211 — who sees what of me on the linked server [source].

final class LinkedVisibilityProvider
    extends
        $FunctionalProvider<
          AsyncValue<MyVisibility>,
          MyVisibility,
          FutureOr<MyVisibility>
        >
    with $FutureModifier<MyVisibility>, $FutureProvider<MyVisibility> {
  /// #2211 — who sees what of me on the linked server [source].
  LinkedVisibilityProvider._({
    required LinkedVisibilityFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'linkedVisibilityProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$linkedVisibilityHash();

  @override
  String toString() {
    return r'linkedVisibilityProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<MyVisibility> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MyVisibility> create(Ref ref) {
    final argument = this.argument as String;
    return linkedVisibility(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LinkedVisibilityProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$linkedVisibilityHash() => r'630733fcf5962e0702559f0018bf46f398faeee4';

/// #2211 — who sees what of me on the linked server [source].

final class LinkedVisibilityFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<MyVisibility>, String> {
  LinkedVisibilityFamily._()
    : super(
        retry: null,
        name: r'linkedVisibilityProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// #2211 — who sees what of me on the linked server [source].

  LinkedVisibilityProvider call(String source) =>
      LinkedVisibilityProvider._(argument: source, from: this);

  @override
  String toString() => r'linkedVisibilityProvider';
}

/// My spaces on every linked server. A server that does not answer is
/// reported as such — the list is then incomplete, never silently short.

@ProviderFor(linkedServerSpaces)
final linkedServerSpacesProvider = LinkedServerSpacesProvider._();

/// My spaces on every linked server. A server that does not answer is
/// reported as such — the list is then incomplete, never silently short.

final class LinkedServerSpacesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LinkedServerSpaces>>,
          List<LinkedServerSpaces>,
          FutureOr<List<LinkedServerSpaces>>
        >
    with
        $FutureModifier<List<LinkedServerSpaces>>,
        $FutureProvider<List<LinkedServerSpaces>> {
  /// My spaces on every linked server. A server that does not answer is
  /// reported as such — the list is then incomplete, never silently short.
  LinkedServerSpacesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'linkedServerSpacesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$linkedServerSpacesHash();

  @$internal
  @override
  $FutureProviderElement<List<LinkedServerSpaces>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<LinkedServerSpaces>> create(Ref ref) {
    return linkedServerSpaces(ref);
  }
}

String _$linkedServerSpacesHash() =>
    r'fa01fabcb63e48a7dc48870256e015f97510eeb7';
