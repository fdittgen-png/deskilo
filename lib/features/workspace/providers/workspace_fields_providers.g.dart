// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace_fields_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #1288 — the questions a workspace asks, and the answers to them.

@ProviderFor(workspaceFieldsRepository)
final workspaceFieldsRepositoryProvider = WorkspaceFieldsRepositoryProvider._();

/// #1288 — the questions a workspace asks, and the answers to them.

final class WorkspaceFieldsRepositoryProvider
    extends
        $FunctionalProvider<
          WorkspaceFieldsRepository,
          WorkspaceFieldsRepository,
          WorkspaceFieldsRepository
        >
    with $Provider<WorkspaceFieldsRepository> {
  /// #1288 — the questions a workspace asks, and the answers to them.
  WorkspaceFieldsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceFieldsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceFieldsRepositoryHash();

  @$internal
  @override
  $ProviderElement<WorkspaceFieldsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkspaceFieldsRepository create(Ref ref) {
    return workspaceFieldsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkspaceFieldsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkspaceFieldsRepository>(value),
    );
  }
}

String _$workspaceFieldsRepositoryHash() =>
    r'0edb887cb0e1c4b21129c28cd322c9bab42d76eb';

/// The active workspace's questions, or none while the feature is off.
///
/// The flag is read here rather than in each form, so a workspace that
/// never turned it on makes no request at all — the identity form is
/// byte-identical to what it was, which is what #1288 asks for.

@ProviderFor(workspaceFields)
final workspaceFieldsProvider = WorkspaceFieldsProvider._();

/// The active workspace's questions, or none while the feature is off.
///
/// The flag is read here rather than in each form, so a workspace that
/// never turned it on makes no request at all — the identity form is
/// byte-identical to what it was, which is what #1288 asks for.

final class WorkspaceFieldsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<WorkspaceField>>,
          List<WorkspaceField>,
          FutureOr<List<WorkspaceField>>
        >
    with
        $FutureModifier<List<WorkspaceField>>,
        $FutureProvider<List<WorkspaceField>> {
  /// The active workspace's questions, or none while the feature is off.
  ///
  /// The flag is read here rather than in each form, so a workspace that
  /// never turned it on makes no request at all — the identity form is
  /// byte-identical to what it was, which is what #1288 asks for.
  WorkspaceFieldsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceFieldsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceFieldsHash();

  @$internal
  @override
  $FutureProviderElement<List<WorkspaceField>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<WorkspaceField>> create(Ref ref) {
    return workspaceFields(ref);
  }
}

String _$workspaceFieldsHash() => r'18c2fbcc9920d0a8b23670c6fc7421eeeba86dac';

/// One member's answers, keyed by field key.

@ProviderFor(memberFieldAnswers)
final memberFieldAnswersProvider = MemberFieldAnswersFamily._();

/// One member's answers, keyed by field key.

final class MemberFieldAnswersProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, Object?>>,
          Map<String, Object?>,
          FutureOr<Map<String, Object?>>
        >
    with
        $FutureModifier<Map<String, Object?>>,
        $FutureProvider<Map<String, Object?>> {
  /// One member's answers, keyed by field key.
  MemberFieldAnswersProvider._({
    required MemberFieldAnswersFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'memberFieldAnswersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$memberFieldAnswersHash();

  @override
  String toString() {
    return r'memberFieldAnswersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Map<String, Object?>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, Object?>> create(Ref ref) {
    final argument = this.argument as String;
    return memberFieldAnswers(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MemberFieldAnswersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$memberFieldAnswersHash() =>
    r'304bf9931545514ffdc9ab28c19a75f82894ce97';

/// One member's answers, keyed by field key.

final class MemberFieldAnswersFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Map<String, Object?>>, String> {
  MemberFieldAnswersFamily._()
    : super(
        retry: null,
        name: r'memberFieldAnswersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One member's answers, keyed by field key.

  MemberFieldAnswersProvider call(String memberId) =>
      MemberFieldAnswersProvider._(argument: memberId, from: this);

  @override
  String toString() => r'memberFieldAnswersProvider';
}
