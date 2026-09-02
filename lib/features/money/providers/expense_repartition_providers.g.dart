// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_repartition_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #828 — the workspace's distributions, newest first.

@ProviderFor(expenseRepartitions)
final expenseRepartitionsProvider = ExpenseRepartitionsProvider._();

/// #828 — the workspace's distributions, newest first.

final class ExpenseRepartitionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ExpenseRepartition>>,
          List<ExpenseRepartition>,
          FutureOr<List<ExpenseRepartition>>
        >
    with
        $FutureModifier<List<ExpenseRepartition>>,
        $FutureProvider<List<ExpenseRepartition>> {
  /// #828 — the workspace's distributions, newest first.
  ExpenseRepartitionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'expenseRepartitionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$expenseRepartitionsHash();

  @$internal
  @override
  $FutureProviderElement<List<ExpenseRepartition>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ExpenseRepartition>> create(Ref ref) {
    return expenseRepartitions(ref);
  }
}

String _$expenseRepartitionsHash() =>
    r'fd1d610f2bcddf55532db7ca1739f659dfbd3974';
