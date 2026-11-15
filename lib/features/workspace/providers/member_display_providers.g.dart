// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_display_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// member id → display name for the active workspace.

@ProviderFor(memberNames)
final memberNamesProvider = MemberNamesProvider._();

/// member id → display name for the active workspace.

final class MemberNamesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, String>>,
          Map<String, String>,
          FutureOr<Map<String, String>>
        >
    with
        $FutureModifier<Map<String, String>>,
        $FutureProvider<Map<String, String>> {
  /// member id → display name for the active workspace.
  MemberNamesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memberNamesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memberNamesHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, String>> create(Ref ref) {
    return memberNames(ref);
  }
}

String _$memberNamesHash() => r'004c24caf27181af8978ae9eade5c76d7b3a50e3';

/// user id → profile for the active workspace's members (#224): the
/// directory derives statuses from `last_seen_at` and shows the WhatsApp
/// button for shared numbers. #1833: each profile is the projection the
/// caller may read in this space — the community fields for a space
/// mate, the printed identity only with `viewPersonalData` or
/// `issueInvoices` (invoices, letters, the Excel export).

@ProviderFor(memberProfiles)
final memberProfilesProvider = MemberProfilesProvider._();

/// user id → profile for the active workspace's members (#224): the
/// directory derives statuses from `last_seen_at` and shows the WhatsApp
/// button for shared numbers. #1833: each profile is the projection the
/// caller may read in this space — the community fields for a space
/// mate, the printed identity only with `viewPersonalData` or
/// `issueInvoices` (invoices, letters, the Excel export).

final class MemberProfilesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, Profile>>,
          Map<String, Profile>,
          FutureOr<Map<String, Profile>>
        >
    with
        $FutureModifier<Map<String, Profile>>,
        $FutureProvider<Map<String, Profile>> {
  /// user id → profile for the active workspace's members (#224): the
  /// directory derives statuses from `last_seen_at` and shows the WhatsApp
  /// button for shared numbers. #1833: each profile is the projection the
  /// caller may read in this space — the community fields for a space
  /// mate, the printed identity only with `viewPersonalData` or
  /// `issueInvoices` (invoices, letters, the Excel export).
  MemberProfilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memberProfilesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memberProfilesHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, Profile>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, Profile>> create(Ref ref) {
    return memberProfiles(ref);
  }
}

String _$memberProfilesHash() => r'bff9c67a33f13dd721e0a674d6f72102c42d1edc';

/// #3853 — the name of the member whose account is [userId] in the active
/// workspace, as the names above print it; empty when no member has it.

@ProviderFor(accountMemberName)
final accountMemberNameProvider = AccountMemberNameFamily._();

/// #3853 — the name of the member whose account is [userId] in the active
/// workspace, as the names above print it; empty when no member has it.

final class AccountMemberNameProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// #3853 — the name of the member whose account is [userId] in the active
  /// workspace, as the names above print it; empty when no member has it.
  AccountMemberNameProvider._({
    required AccountMemberNameFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountMemberNameProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountMemberNameHash();

  @override
  String toString() {
    return r'accountMemberNameProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    final argument = this.argument as String;
    return accountMemberName(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AccountMemberNameProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountMemberNameHash() => r'fc213b87f9235c808b712137785fe0cc8166f3a1';

/// #3853 — the name of the member whose account is [userId] in the active
/// workspace, as the names above print it; empty when no member has it.

final class AccountMemberNameFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String>, String> {
  AccountMemberNameFamily._()
    : super(
        retry: null,
        name: r'accountMemberNameProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// #3853 — the name of the member whose account is [userId] in the active
  /// workspace, as the names above print it; empty when no member has it.

  AccountMemberNameProvider call(String userId) =>
      AccountMemberNameProvider._(argument: userId, from: this);

  @override
  String toString() => r'accountMemberNameProvider';
}

/// #3853 — whether the person may issue invoices in the active workspace.

@ProviderFor(mayIssueInvoices)
final mayIssueInvoicesProvider = MayIssueInvoicesProvider._();

/// #3853 — whether the person may issue invoices in the active workspace.

final class MayIssueInvoicesProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// #3853 — whether the person may issue invoices in the active workspace.
  MayIssueInvoicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mayIssueInvoicesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mayIssueInvoicesHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return mayIssueInvoices(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$mayIssueInvoicesHash() => r'af1ece735c22d46bfb2bd0d0e9e6dd4753070407';
