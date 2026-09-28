// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'directory_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(directoryActions)
final directoryActionsProvider = DirectoryActionsProvider._();

final class DirectoryActionsProvider
    extends
        $FunctionalProvider<
          DirectoryActions,
          DirectoryActions,
          DirectoryActions
        >
    with $Provider<DirectoryActions> {
  DirectoryActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'directoryActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$directoryActionsHash();

  @$internal
  @override
  $ProviderElement<DirectoryActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DirectoryActions create(Ref ref) {
    return directoryActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DirectoryActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DirectoryActions>(value),
    );
  }
}

String _$directoryActionsHash() => r'9bda07a61740d42618618f2d6da97e8885636121';

@ProviderFor(accountContactActions)
final accountContactActionsProvider = AccountContactActionsFamily._();

final class AccountContactActionsProvider
    extends
        $FunctionalProvider<
          AccountContactActions,
          AccountContactActions,
          AccountContactActions
        >
    with $Provider<AccountContactActions> {
  AccountContactActionsProvider._({
    required AccountContactActionsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountContactActionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountContactActionsHash();

  @override
  String toString() {
    return r'accountContactActionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AccountContactActions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountContactActions create(Ref ref) {
    final argument = this.argument as String;
    return accountContactActions(ref, source: argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountContactActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountContactActions>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountContactActionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountContactActionsHash() =>
    r'82d2eb586880a9cc1649f3c4dd9dc73359fcbdf1';

final class AccountContactActionsFamily extends $Family
    with $FunctionalFamilyOverride<AccountContactActions, String> {
  AccountContactActionsFamily._()
    : super(
        retry: null,
        name: r'accountContactActionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountContactActionsProvider call({String source = ''}) =>
      AccountContactActionsProvider._(argument: source, from: this);

  @override
  String toString() => r'accountContactActionsProvider';
}

@ProviderFor(directoryRepository)
final directoryRepositoryProvider = DirectoryRepositoryProvider._();

final class DirectoryRepositoryProvider
    extends
        $FunctionalProvider<
          DirectoryRepository,
          DirectoryRepository,
          DirectoryRepository
        >
    with $Provider<DirectoryRepository> {
  DirectoryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'directoryRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$directoryRepositoryHash();

  @$internal
  @override
  $ProviderElement<DirectoryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DirectoryRepository create(Ref ref) {
    return directoryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DirectoryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DirectoryRepository>(value),
    );
  }
}

String _$directoryRepositoryHash() =>
    r'4625428f569dcb16149861272e4c9e7caf965e7f';

@ProviderFor(publicDirectory)
final publicDirectoryProvider = PublicDirectoryFamily._();

final class PublicDirectoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<DirectoryPage>,
          DirectoryPage,
          FutureOr<DirectoryPage>
        >
    with $FutureModifier<DirectoryPage>, $FutureProvider<DirectoryPage> {
  PublicDirectoryProvider._({
    required PublicDirectoryFamily super.from,
    required (String, {int sourcePage, int workspacePage}) super.argument,
  }) : super(
         retry: null,
         name: r'publicDirectoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$publicDirectoryHash();

  @override
  String toString() {
    return r'publicDirectoryProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<DirectoryPage> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DirectoryPage> create(Ref ref) {
    final argument =
        this.argument as (String, {int sourcePage, int workspacePage});
    return publicDirectory(
      ref,
      argument.$1,
      sourcePage: argument.sourcePage,
      workspacePage: argument.workspacePage,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PublicDirectoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$publicDirectoryHash() => r'33057e01d8da85b61577ec7d95eda22553a25a9c';

final class PublicDirectoryFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<DirectoryPage>,
          (String, {int sourcePage, int workspacePage})
        > {
  PublicDirectoryFamily._()
    : super(
        retry: null,
        name: r'publicDirectoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PublicDirectoryProvider call(
    String query, {
    int sourcePage = 0,
    int workspacePage = 0,
  }) => PublicDirectoryProvider._(
    argument: (query, sourcePage: sourcePage, workspacePage: workspacePage),
    from: this,
  );

  @override
  String toString() => r'publicDirectoryProvider';
}

@ProviderFor(accountContactRepository)
final accountContactRepositoryProvider = AccountContactRepositoryFamily._();

final class AccountContactRepositoryProvider
    extends
        $FunctionalProvider<
          AccountContactRepository,
          AccountContactRepository,
          AccountContactRepository
        >
    with $Provider<AccountContactRepository> {
  AccountContactRepositoryProvider._({
    required AccountContactRepositoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountContactRepositoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountContactRepositoryHash();

  @override
  String toString() {
    return r'accountContactRepositoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AccountContactRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountContactRepository create(Ref ref) {
    final argument = this.argument as String;
    return accountContactRepository(ref, source: argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountContactRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountContactRepository>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountContactRepositoryProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountContactRepositoryHash() =>
    r'8c4ad3f5ea24fbaadda83d271de27d354ad97ddc';

final class AccountContactRepositoryFamily extends $Family
    with $FunctionalFamilyOverride<AccountContactRepository, String> {
  AccountContactRepositoryFamily._()
    : super(
        retry: null,
        name: r'accountContactRepositoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountContactRepositoryProvider call({String source = ''}) =>
      AccountContactRepositoryProvider._(argument: source, from: this);

  @override
  String toString() => r'accountContactRepositoryProvider';
}

@ProviderFor(contactAvailability)
final contactAvailabilityProvider = ContactAvailabilityFamily._();

final class ContactAvailabilityProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  ContactAvailabilityProvider._({
    required ContactAvailabilityFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'contactAvailabilityProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$contactAvailabilityHash();

  @override
  String toString() {
    return r'contactAvailabilityProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as String;
    return contactAvailability(ref, source: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ContactAvailabilityProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$contactAvailabilityHash() =>
    r'b4c892f08c92389faa818ebe5e1423e7b4740373';

final class ContactAvailabilityFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  ContactAvailabilityFamily._()
    : super(
        retry: null,
        name: r'contactAvailabilityProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ContactAvailabilityProvider call({String source = ''}) =>
      ContactAvailabilityProvider._(argument: source, from: this);

  @override
  String toString() => r'contactAvailabilityProvider';
}

@ProviderFor(adminVisibility)
final adminVisibilityProvider = AdminVisibilityFamily._();

final class AdminVisibilityProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  AdminVisibilityProvider._({
    required AdminVisibilityFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'adminVisibilityProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$adminVisibilityHash();

  @override
  String toString() {
    return r'adminVisibilityProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as String;
    return adminVisibility(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AdminVisibilityProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$adminVisibilityHash() => r'd88e306b7f7b54e05291954ce451df45d659ccd1';

final class AdminVisibilityFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  AdminVisibilityFamily._()
    : super(
        retry: null,
        name: r'adminVisibilityProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AdminVisibilityProvider call(String workspace) =>
      AdminVisibilityProvider._(argument: workspace, from: this);

  @override
  String toString() => r'adminVisibilityProvider';
}

@ProviderFor(employmentStatus)
final employmentStatusProvider = EmploymentStatusFamily._();

final class EmploymentStatusProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  EmploymentStatusProvider._({
    required EmploymentStatusFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'employmentStatusProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$employmentStatusHash();

  @override
  String toString() {
    return r'employmentStatusProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as String;
    return employmentStatus(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is EmploymentStatusProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$employmentStatusHash() => r'c6e654c170998d69c248d9e0071ae7457a0c043f';

final class EmploymentStatusFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  EmploymentStatusFamily._()
    : super(
        retry: null,
        name: r'employmentStatusProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EmploymentStatusProvider call(String member) =>
      EmploymentStatusProvider._(argument: member, from: this);

  @override
  String toString() => r'employmentStatusProvider';
}

@ProviderFor(accountContacts)
final accountContactsProvider = AccountContactsFamily._();

final class AccountContactsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Map<String, dynamic>>>,
          List<Map<String, dynamic>>,
          FutureOr<List<Map<String, dynamic>>>
        >
    with
        $FutureModifier<List<Map<String, dynamic>>>,
        $FutureProvider<List<Map<String, dynamic>>> {
  AccountContactsProvider._({
    required AccountContactsFamily super.from,
    required (String, {String source, String? before}) super.argument,
  }) : super(
         retry: null,
         name: r'accountContactsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountContactsHash();

  @override
  String toString() {
    return r'accountContactsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<Map<String, dynamic>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Map<String, dynamic>>> create(Ref ref) {
    final argument = this.argument as (String, {String source, String? before});
    return accountContacts(
      ref,
      argument.$1,
      source: argument.source,
      before: argument.before,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountContactsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountContactsHash() => r'ada9b3793a4853dddb67c7196adecf99c8ecc189';

final class AccountContactsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<Map<String, dynamic>>>,
          (String, {String source, String? before})
        > {
  AccountContactsFamily._()
    : super(
        retry: null,
        name: r'accountContactsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountContactsProvider call(
    String query, {
    String source = '',
    String? before,
  }) => AccountContactsProvider._(
    argument: (query, source: source, before: before),
    from: this,
  );

  @override
  String toString() => r'accountContactsProvider';
}

@ProviderFor(accountConversations)
final accountConversationsProvider = AccountConversationsFamily._();

final class AccountConversationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Map<String, dynamic>>>,
          List<Map<String, dynamic>>,
          FutureOr<List<Map<String, dynamic>>>
        >
    with
        $FutureModifier<List<Map<String, dynamic>>>,
        $FutureProvider<List<Map<String, dynamic>>> {
  AccountConversationsProvider._({
    required AccountConversationsFamily super.from,
    required ({String source, DateTime? beforeAt, String? beforeId})
    super.argument,
  }) : super(
         retry: null,
         name: r'accountConversationsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountConversationsHash();

  @override
  String toString() {
    return r'accountConversationsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<Map<String, dynamic>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Map<String, dynamic>>> create(Ref ref) {
    final argument =
        this.argument
            as ({String source, DateTime? beforeAt, String? beforeId});
    return accountConversations(
      ref,
      source: argument.source,
      beforeAt: argument.beforeAt,
      beforeId: argument.beforeId,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountConversationsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountConversationsHash() =>
    r'c1dfcc97b1de6a0cc5efee3e52b963f1aaaa46ce';

final class AccountConversationsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<Map<String, dynamic>>>,
          ({String source, DateTime? beforeAt, String? beforeId})
        > {
  AccountConversationsFamily._()
    : super(
        retry: null,
        name: r'accountConversationsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountConversationsProvider call({
    String source = '',
    DateTime? beforeAt,
    String? beforeId,
  }) => AccountConversationsProvider._(
    argument: (source: source, beforeAt: beforeAt, beforeId: beforeId),
    from: this,
  );

  @override
  String toString() => r'accountConversationsProvider';
}

@ProviderFor(accountMessages)
final accountMessagesProvider = AccountMessagesFamily._();

final class AccountMessagesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Map<String, dynamic>>>,
          List<Map<String, dynamic>>,
          FutureOr<List<Map<String, dynamic>>>
        >
    with
        $FutureModifier<List<Map<String, dynamic>>>,
        $FutureProvider<List<Map<String, dynamic>>> {
  AccountMessagesProvider._({
    required AccountMessagesFamily super.from,
    required (String, {String source, DateTime? beforeAt, String? beforeId})
    super.argument,
  }) : super(
         retry: null,
         name: r'accountMessagesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountMessagesHash();

  @override
  String toString() {
    return r'accountMessagesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<Map<String, dynamic>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Map<String, dynamic>>> create(Ref ref) {
    final argument =
        this.argument
            as (String, {String source, DateTime? beforeAt, String? beforeId});
    return accountMessages(
      ref,
      argument.$1,
      source: argument.source,
      beforeAt: argument.beforeAt,
      beforeId: argument.beforeId,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountMessagesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountMessagesHash() => r'2ce7aeef0640da257058d71b56906dd097a29ea7';

final class AccountMessagesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<Map<String, dynamic>>>,
          (String, {String source, DateTime? beforeAt, String? beforeId})
        > {
  AccountMessagesFamily._()
    : super(
        retry: null,
        name: r'accountMessagesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AccountMessagesProvider call(
    String conversation, {
    String source = '',
    DateTime? beforeAt,
    String? beforeId,
  }) => AccountMessagesProvider._(
    argument: (
      conversation,
      source: source,
      beforeAt: beforeAt,
      beforeId: beforeId,
    ),
    from: this,
  );

  @override
  String toString() => r'accountMessagesProvider';
}
