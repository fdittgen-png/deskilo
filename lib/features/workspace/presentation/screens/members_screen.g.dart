// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'members_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// All memberships of the active workspace (owner management, spec §2/§7.2).

@ProviderFor(workspaceMembers)
final workspaceMembersProvider = WorkspaceMembersProvider._();

/// All memberships of the active workspace (owner management, spec §2/§7.2).

final class WorkspaceMembersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Member>>,
          List<Member>,
          FutureOr<List<Member>>
        >
    with $FutureModifier<List<Member>>, $FutureProvider<List<Member>> {
  /// All memberships of the active workspace (owner management, spec §2/§7.2).
  WorkspaceMembersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceMembersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceMembersHash();

  @$internal
  @override
  $FutureProviderElement<List<Member>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Member>> create(Ref ref) {
    return workspaceMembers(ref);
  }
}

String _$workspaceMembersHash() => r'22591de7638efc1d8b8ae3991143235e160da403';
