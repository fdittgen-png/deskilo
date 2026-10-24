// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'me_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #1823 — the account layer's calls on this server.
/// #2561 C1 — the own-profile reads and writes go to the PERSONAL client (P),
/// never to the process-wide client or to a workspace host.

@ProviderFor(meRepository)
final meRepositoryProvider = MeRepositoryProvider._();

/// #1823 — the account layer's calls on this server.
/// #2561 C1 — the own-profile reads and writes go to the PERSONAL client (P),
/// never to the process-wide client or to a workspace host.

final class MeRepositoryProvider
    extends $FunctionalProvider<MeRepository, MeRepository, MeRepository>
    with $Provider<MeRepository> {
  /// #1823 — the account layer's calls on this server.
  /// #2561 C1 — the own-profile reads and writes go to the PERSONAL client (P),
  /// never to the process-wide client or to a workspace host.
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

String _$meRepositoryHash() => r'11082a2caa0013b3781489e7139fc7c3b0e4f3f3';

/// #2563 C1 — the account's calls inside a workspace (leaving it), on the
/// verified host of that workspace, never on the personal client.

@ProviderFor(workspaceAccessRepository)
final workspaceAccessRepositoryProvider = WorkspaceAccessRepositoryProvider._();

/// #2563 C1 — the account's calls inside a workspace (leaving it), on the
/// verified host of that workspace, never on the personal client.

final class WorkspaceAccessRepositoryProvider
    extends
        $FunctionalProvider<
          WorkspaceAccessRepository,
          WorkspaceAccessRepository,
          WorkspaceAccessRepository
        >
    with $Provider<WorkspaceAccessRepository> {
  /// #2563 C1 — the account's calls inside a workspace (leaving it), on the
  /// verified host of that workspace, never on the personal client.
  WorkspaceAccessRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceAccessRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceAccessRepositoryHash();

  @$internal
  @override
  $ProviderElement<WorkspaceAccessRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkspaceAccessRepository create(Ref ref) {
    return workspaceAccessRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkspaceAccessRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkspaceAccessRepository>(value),
    );
  }
}

String _$workspaceAccessRepositoryHash() =>
    r'085d4bb9cb69c3526f553b2f5d2768f3dbe99478';

/// The account layer's calls on the linked servers, each with that server's
/// own session. The readers below ask it nothing while no server is linked.

@ProviderFor(linkedMeRepository)
final linkedMeRepositoryProvider = LinkedMeRepositoryProvider._();

/// The account layer's calls on the linked servers, each with that server's
/// own session. The readers below ask it nothing while no server is linked.

final class LinkedMeRepositoryProvider
    extends
        $FunctionalProvider<
          LinkedMeRepository,
          LinkedMeRepository,
          LinkedMeRepository
        >
    with $Provider<LinkedMeRepository> {
  /// The account layer's calls on the linked servers, each with that server's
  /// own session. The readers below ask it nothing while no server is linked.
  LinkedMeRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'linkedMeRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$linkedMeRepositoryHash();

  @$internal
  @override
  $ProviderElement<LinkedMeRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LinkedMeRepository create(Ref ref) {
    return linkedMeRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LinkedMeRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LinkedMeRepository>(value),
    );
  }
}

String _$linkedMeRepositoryHash() =>
    r'1494cb6edbcdba4a9bd6d17927295731cae8175c';

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

String _$meActionsHash() => r'8bff45ddd403d2eab12654329fe47cc36896182f';

/// Who sees what of me, as the personal home holds it. #2558 — read on the
/// personal client with no workspace involved; a failure is an error the
/// editor names, never the defaults shown as if they were saved.

@ProviderFor(myVisibility)
final myVisibilityProvider = MyVisibilityProvider._();

/// Who sees what of me, as the personal home holds it. #2558 — read on the
/// personal client with no workspace involved; a failure is an error the
/// editor names, never the defaults shown as if they were saved.

final class MyVisibilityProvider
    extends
        $FunctionalProvider<
          AsyncValue<MyVisibility>,
          MyVisibility,
          FutureOr<MyVisibility>
        >
    with $FutureModifier<MyVisibility>, $FutureProvider<MyVisibility> {
  /// Who sees what of me, as the personal home holds it. #2558 — read on the
  /// personal client with no workspace involved; a failure is an error the
  /// editor names, never the defaults shown as if they were saved.
  MyVisibilityProvider._()
    : super(
        from: null,
        argument: null,
        retry: meReadRetry,
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

String _$myVisibilityHash() => r'66aac5d1ddba65f526a9a4bcf9fccbe0e19efebc';

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

/// #2211 — who sees what of me on the linked server [source]; the
/// defaults while no server is linked.

@ProviderFor(linkedVisibility)
final linkedVisibilityProvider = LinkedVisibilityFamily._();

/// #2211 — who sees what of me on the linked server [source]; the
/// defaults while no server is linked.

final class LinkedVisibilityProvider
    extends
        $FunctionalProvider<
          AsyncValue<MyVisibility>,
          MyVisibility,
          FutureOr<MyVisibility>
        >
    with $FutureModifier<MyVisibility>, $FutureProvider<MyVisibility> {
  /// #2211 — who sees what of me on the linked server [source]; the
  /// defaults while no server is linked.
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

String _$linkedVisibilityHash() => r'00357cd2f03b6f364db1f53cdab4236bc52d3acb';

/// #2211 — who sees what of me on the linked server [source]; the
/// defaults while no server is linked.

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

  /// #2211 — who sees what of me on the linked server [source]; the
  /// defaults while no server is linked.

  LinkedVisibilityProvider call(String source) =>
      LinkedVisibilityProvider._(argument: source, from: this);

  @override
  String toString() => r'linkedVisibilityProvider';
}

/// My spaces on every linked server, all servers asked at once. A server
/// that does not answer is reported as such — the list is then incomplete,
/// never silently short — and does not hold up the others.

@ProviderFor(linkedServerSpaces)
final linkedServerSpacesProvider = LinkedServerSpacesProvider._();

/// My spaces on every linked server, all servers asked at once. A server
/// that does not answer is reported as such — the list is then incomplete,
/// never silently short — and does not hold up the others.

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
  /// My spaces on every linked server, all servers asked at once. A server
  /// that does not answer is reported as such — the list is then incomplete,
  /// never silently short — and does not hold up the others.
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
    r'4ec38ca91b77629106c484bc9ab10624e4d24ed9';

/// #2563 C1 — the workspaces my account names by qualified reference, read
/// on my personal home with no workspace selected; none while signed out.
/// A refusal or a malformed answer is final: no silent retries.

@ProviderFor(personalWorkspaceRefs)
final personalWorkspaceRefsProvider = PersonalWorkspaceRefsProvider._();

/// #2563 C1 — the workspaces my account names by qualified reference, read
/// on my personal home with no workspace selected; none while signed out.
/// A refusal or a malformed answer is final: no silent retries.

final class PersonalWorkspaceRefsProvider
    extends
        $FunctionalProvider<
          AsyncValue<PersonalWorkspaceRefs>,
          PersonalWorkspaceRefs,
          FutureOr<PersonalWorkspaceRefs>
        >
    with
        $FutureModifier<PersonalWorkspaceRefs>,
        $FutureProvider<PersonalWorkspaceRefs> {
  /// #2563 C1 — the workspaces my account names by qualified reference, read
  /// on my personal home with no workspace selected; none while signed out.
  /// A refusal or a malformed answer is final: no silent retries.
  PersonalWorkspaceRefsProvider._()
    : super(
        from: null,
        argument: null,
        retry: personalRefsRetry,
        name: r'personalWorkspaceRefsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalWorkspaceRefsHash();

  @$internal
  @override
  $FutureProviderElement<PersonalWorkspaceRefs> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PersonalWorkspaceRefs> create(Ref ref) {
    return personalWorkspaceRefs(ref);
  }
}

String _$personalWorkspaceRefsHash() =>
    r'69d0d76da6cc0132448ac6e3a8eb92ace24203d2';

/// #2557 C2 — the personal part of my data, read on my personal home while
/// My data's personal view shows it; dropped when it closes, so each visit
/// reads what the home holds now. Signed out there is nothing to read.

@ProviderFor(personalExport)
final personalExportProvider = PersonalExportProvider._();

/// #2557 C2 — the personal part of my data, read on my personal home while
/// My data's personal view shows it; dropped when it closes, so each visit
/// reads what the home holds now. Signed out there is nothing to read.

final class PersonalExportProvider
    extends
        $FunctionalProvider<
          AsyncValue<PersonalExport>,
          PersonalExport,
          FutureOr<PersonalExport>
        >
    with $FutureModifier<PersonalExport>, $FutureProvider<PersonalExport> {
  /// #2557 C2 — the personal part of my data, read on my personal home while
  /// My data's personal view shows it; dropped when it closes, so each visit
  /// reads what the home holds now. Signed out there is nothing to read.
  PersonalExportProvider._()
    : super(
        from: null,
        argument: null,
        retry: personalRefsRetry,
        name: r'personalExportProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalExportHash();

  @$internal
  @override
  $FutureProviderElement<PersonalExport> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PersonalExport> create(Ref ref) {
    return personalExport(ref);
  }
}

String _$personalExportHash() => r'5e379fb0090555f0a509acc53ce6c676301d30ec';
