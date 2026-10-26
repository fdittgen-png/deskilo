// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bank_statement_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bankStatementRepository)
final bankStatementRepositoryProvider = BankStatementRepositoryProvider._();

final class BankStatementRepositoryProvider
    extends
        $FunctionalProvider<
          BankStatementRepository,
          BankStatementRepository,
          BankStatementRepository
        >
    with $Provider<BankStatementRepository> {
  BankStatementRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bankStatementRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bankStatementRepositoryHash();

  @$internal
  @override
  $ProviderElement<BankStatementRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BankStatementRepository create(Ref ref) {
    return bankStatementRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BankStatementRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BankStatementRepository>(value),
    );
  }
}

String _$bankStatementRepositoryHash() =>
    r'b22e4308782092ab78c3c8baf8b4d0fefccb2357';

@ProviderFor(bankImportCommands)
final bankImportCommandsProvider = BankImportCommandsProvider._();

final class BankImportCommandsProvider
    extends
        $FunctionalProvider<
          BankImportCommands,
          BankImportCommands,
          BankImportCommands
        >
    with $Provider<BankImportCommands> {
  BankImportCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bankImportCommandsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bankImportCommandsHash();

  @$internal
  @override
  $ProviderElement<BankImportCommands> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BankImportCommands create(Ref ref) {
    return bankImportCommands(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BankImportCommands value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BankImportCommands>(value),
    );
  }
}

String _$bankImportCommandsHash() =>
    r'a6d4816ca47a10a87654730fc6b2586179eb333f';

/// The bounds a file is read under and the suggestion window, from the
/// active space's settings.

@ProviderFor(bankImportSettings)
final bankImportSettingsProvider = BankImportSettingsProvider._();

/// The bounds a file is read under and the suggestion window, from the
/// active space's settings.

final class BankImportSettingsProvider
    extends
        $FunctionalProvider<
          BankImportSettings,
          BankImportSettings,
          BankImportSettings
        >
    with $Provider<BankImportSettings> {
  /// The bounds a file is read under and the suggestion window, from the
  /// active space's settings.
  BankImportSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bankImportSettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bankImportSettingsHash();

  @$internal
  @override
  $ProviderElement<BankImportSettings> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BankImportSettings create(Ref ref) {
    return bankImportSettings(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BankImportSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BankImportSettings>(value),
    );
  }
}

String _$bankImportSettingsHash() =>
    r'324e7bb193955deffe3d089e741c64a5827f8ede';

/// The statements of one space, newest period first.

@ProviderFor(bankStatements)
final bankStatementsProvider = BankStatementsFamily._();

/// The statements of one space, newest period first.

final class BankStatementsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<StoredBankStatement>>,
          List<StoredBankStatement>,
          FutureOr<List<StoredBankStatement>>
        >
    with
        $FutureModifier<List<StoredBankStatement>>,
        $FutureProvider<List<StoredBankStatement>> {
  /// The statements of one space, newest period first.
  BankStatementsProvider._({
    required BankStatementsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'bankStatementsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bankStatementsHash();

  @override
  String toString() {
    return r'bankStatementsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<StoredBankStatement>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<StoredBankStatement>> create(Ref ref) {
    final argument = this.argument as String;
    return bankStatements(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BankStatementsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bankStatementsHash() => r'd72f1df25715720b75def29fda90fafd96d30a0b';

/// The statements of one space, newest period first.

final class BankStatementsFamily extends $Family
    with
        $FunctionalFamilyOverride<FutureOr<List<StoredBankStatement>>, String> {
  BankStatementsFamily._()
    : super(
        retry: null,
        name: r'bankStatementsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The statements of one space, newest period first.

  BankStatementsProvider call(String workspaceId) =>
      BankStatementsProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'bankStatementsProvider';
}

/// The movements of one statement, in the file's order.

@ProviderFor(bankStatementLines)
final bankStatementLinesProvider = BankStatementLinesFamily._();

/// The movements of one statement, in the file's order.

final class BankStatementLinesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<StoredBankLine>>,
          List<StoredBankLine>,
          FutureOr<List<StoredBankLine>>
        >
    with
        $FutureModifier<List<StoredBankLine>>,
        $FutureProvider<List<StoredBankLine>> {
  /// The movements of one statement, in the file's order.
  BankStatementLinesProvider._({
    required BankStatementLinesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'bankStatementLinesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bankStatementLinesHash();

  @override
  String toString() {
    return r'bankStatementLinesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<StoredBankLine>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<StoredBankLine>> create(Ref ref) {
    final argument = this.argument as String;
    return bankStatementLines(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BankStatementLinesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bankStatementLinesHash() =>
    r'6987e9246f2294c38ca5e98e8a6611fa293f0c46';

/// The movements of one statement, in the file's order.

final class BankStatementLinesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<StoredBankLine>>, String> {
  BankStatementLinesFamily._()
    : super(
        retry: null,
        name: r'bankStatementLinesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The movements of one statement, in the file's order.

  BankStatementLinesProvider call(String statementId) =>
      BankStatementLinesProvider._(argument: statementId, from: this);

  @override
  String toString() => r'bankStatementLinesProvider';
}

/// The work list of one statement: its movements with what each may
/// settle, matched once per load against the space's open invoices.

@ProviderFor(bankWorkList)
final bankWorkListProvider = BankWorkListFamily._();

/// The work list of one statement: its movements with what each may
/// settle, matched once per load against the space's open invoices.

final class BankWorkListProvider
    extends
        $FunctionalProvider<
          AsyncValue<BankWorkList>,
          BankWorkList,
          FutureOr<BankWorkList>
        >
    with $FutureModifier<BankWorkList>, $FutureProvider<BankWorkList> {
  /// The work list of one statement: its movements with what each may
  /// settle, matched once per load against the space's open invoices.
  BankWorkListProvider._({
    required BankWorkListFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'bankWorkListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bankWorkListHash();

  @override
  String toString() {
    return r'bankWorkListProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<BankWorkList> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BankWorkList> create(Ref ref) {
    final argument = this.argument as String;
    return bankWorkList(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BankWorkListProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bankWorkListHash() => r'f42f5e94d4caf659259ca1e8bd4d5c8b738d5e92';

/// The work list of one statement: its movements with what each may
/// settle, matched once per load against the space's open invoices.

final class BankWorkListFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<BankWorkList>, String> {
  BankWorkListFamily._()
    : super(
        retry: null,
        name: r'bankWorkListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The work list of one statement: its movements with what each may
  /// settle, matched once per load against the space's open invoices.

  BankWorkListProvider call(String statementId) =>
      BankWorkListProvider._(argument: statementId, from: this);

  @override
  String toString() => r'bankWorkListProvider';
}
