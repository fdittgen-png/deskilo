// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_schedule_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #767 — my recurring expense schedules (or the workspace's, for the
/// finance/expense permissions — RLS decides what comes back).

@ProviderFor(expenseSchedules)
final expenseSchedulesProvider = ExpenseSchedulesFamily._();

/// #767 — my recurring expense schedules (or the workspace's, for the
/// finance/expense permissions — RLS decides what comes back).

final class ExpenseSchedulesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ExpenseSchedule>>,
          List<ExpenseSchedule>,
          FutureOr<List<ExpenseSchedule>>
        >
    with
        $FutureModifier<List<ExpenseSchedule>>,
        $FutureProvider<List<ExpenseSchedule>> {
  /// #767 — my recurring expense schedules (or the workspace's, for the
  /// finance/expense permissions — RLS decides what comes back).
  ExpenseSchedulesProvider._({
    required ExpenseSchedulesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'expenseSchedulesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$expenseSchedulesHash();

  @override
  String toString() {
    return r'expenseSchedulesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ExpenseSchedule>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ExpenseSchedule>> create(Ref ref) {
    final argument = this.argument as String;
    return expenseSchedules(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ExpenseSchedulesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$expenseSchedulesHash() => r'eb4d09258956b5b72c588065b0c7feeb28eb2a42';

/// #767 — my recurring expense schedules (or the workspace's, for the
/// finance/expense permissions — RLS decides what comes back).

final class ExpenseSchedulesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ExpenseSchedule>>, String> {
  ExpenseSchedulesFamily._()
    : super(
        retry: null,
        name: r'expenseSchedulesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// #767 — my recurring expense schedules (or the workspace's, for the
  /// finance/expense permissions — RLS decides what comes back).

  ExpenseSchedulesProvider call(String workspaceId) =>
      ExpenseSchedulesProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'expenseSchedulesProvider';
}

/// The member's materialised occurrences — the awaiting and rejected
/// ones are what the Payments face presents for confirmation.

@ProviderFor(expenseOccurrences)
final expenseOccurrencesProvider = ExpenseOccurrencesFamily._();

/// The member's materialised occurrences — the awaiting and rejected
/// ones are what the Payments face presents for confirmation.

final class ExpenseOccurrencesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ExpenseOccurrence>>,
          List<ExpenseOccurrence>,
          FutureOr<List<ExpenseOccurrence>>
        >
    with
        $FutureModifier<List<ExpenseOccurrence>>,
        $FutureProvider<List<ExpenseOccurrence>> {
  /// The member's materialised occurrences — the awaiting and rejected
  /// ones are what the Payments face presents for confirmation.
  ExpenseOccurrencesProvider._({
    required ExpenseOccurrencesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'expenseOccurrencesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$expenseOccurrencesHash();

  @override
  String toString() {
    return r'expenseOccurrencesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ExpenseOccurrence>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ExpenseOccurrence>> create(Ref ref) {
    final argument = this.argument as String;
    return expenseOccurrences(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ExpenseOccurrencesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$expenseOccurrencesHash() =>
    r'2fb6cb8cc6bf45ee30c749465b0401558b8b3a18';

/// The member's materialised occurrences — the awaiting and rejected
/// ones are what the Payments face presents for confirmation.

final class ExpenseOccurrencesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ExpenseOccurrence>>, String> {
  ExpenseOccurrencesFamily._()
    : super(
        retry: null,
        name: r'expenseOccurrencesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The member's materialised occurrences — the awaiting and rejected
  /// ones are what the Payments face presents for confirmation.

  ExpenseOccurrencesProvider call(String workspaceId) =>
      ExpenseOccurrencesProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'expenseOccurrencesProvider';
}

/// #767 — the client-side clock for scheduled expenses: the first member
/// who opens Finances in a session materialises what is due (the
/// morning cron is the other clock). Idempotent — the sweep only fills
/// gaps up to today.

@ProviderFor(expenseScheduleSweep)
final expenseScheduleSweepProvider = ExpenseScheduleSweepFamily._();

/// #767 — the client-side clock for scheduled expenses: the first member
/// who opens Finances in a session materialises what is due (the
/// morning cron is the other clock). Idempotent — the sweep only fills
/// gaps up to today.

final class ExpenseScheduleSweepProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// #767 — the client-side clock for scheduled expenses: the first member
  /// who opens Finances in a session materialises what is due (the
  /// morning cron is the other clock). Idempotent — the sweep only fills
  /// gaps up to today.
  ExpenseScheduleSweepProvider._({
    required ExpenseScheduleSweepFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'expenseScheduleSweepProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$expenseScheduleSweepHash();

  @override
  String toString() {
    return r'expenseScheduleSweepProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    final argument = this.argument as String;
    return expenseScheduleSweep(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ExpenseScheduleSweepProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$expenseScheduleSweepHash() =>
    r'4c20e32546136a95281b1fb303a34b42cb146162';

/// #767 — the client-side clock for scheduled expenses: the first member
/// who opens Finances in a session materialises what is due (the
/// morning cron is the other clock). Idempotent — the sweep only fills
/// gaps up to today.

final class ExpenseScheduleSweepFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int>, String> {
  ExpenseScheduleSweepFamily._()
    : super(
        retry: null,
        name: r'expenseScheduleSweepProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// #767 — the client-side clock for scheduled expenses: the first member
  /// who opens Finances in a session materialises what is due (the
  /// morning cron is the other clock). Idempotent — the sweep only fills
  /// gaps up to today.

  ExpenseScheduleSweepProvider call(String workspaceId) =>
      ExpenseScheduleSweepProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'expenseScheduleSweepProvider';
}
