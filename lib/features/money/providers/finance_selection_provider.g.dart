// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finance_selection_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FinanceSelectionController)
final financeSelectionControllerProvider =
    FinanceSelectionControllerProvider._();

final class FinanceSelectionControllerProvider
    extends $NotifierProvider<FinanceSelectionController, FinanceSelection> {
  FinanceSelectionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'financeSelectionControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$financeSelectionControllerHash();

  @$internal
  @override
  FinanceSelectionController create() => FinanceSelectionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FinanceSelection value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FinanceSelection>(value),
    );
  }
}

String _$financeSelectionControllerHash() =>
    r'55c856a5f2b8cd2448a2052d53159f3f4e389909';

abstract class _$FinanceSelectionController
    extends $Notifier<FinanceSelection> {
  FinanceSelection build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<FinanceSelection, FinanceSelection>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FinanceSelection, FinanceSelection>,
              FinanceSelection,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The selection with each invoice as the overview reads it now; one no
/// longer selectable (paid, declared, in a payment) is left out.

@ProviderFor(financeSelection)
final financeSelectionProvider = FinanceSelectionProvider._();

/// The selection with each invoice as the overview reads it now; one no
/// longer selectable (paid, declared, in a payment) is left out.

final class FinanceSelectionProvider
    extends
        $FunctionalProvider<
          FinanceSelection,
          FinanceSelection,
          FinanceSelection
        >
    with $Provider<FinanceSelection> {
  /// The selection with each invoice as the overview reads it now; one no
  /// longer selectable (paid, declared, in a payment) is left out.
  FinanceSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'financeSelectionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$financeSelectionHash();

  @$internal
  @override
  $ProviderElement<FinanceSelection> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FinanceSelection create(Ref ref) {
    return financeSelection(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FinanceSelection value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FinanceSelection>(value),
    );
  }
}

String _$financeSelectionHash() => r'dd0c648088e57d4d82749d5cedd80f1d69f3bc5d';

/// Enters a business as Open does. Nothing by default; the composition root
/// selects the workspace (`financeWorkspaceEntryFromApp`, lib/app), where
/// money and the workspace meet.

@ProviderFor(financeWorkspaceEntry)
final financeWorkspaceEntryProvider = FinanceWorkspaceEntryProvider._();

/// Enters a business as Open does. Nothing by default; the composition root
/// selects the workspace (`financeWorkspaceEntryFromApp`, lib/app), where
/// money and the workspace meet.

final class FinanceWorkspaceEntryProvider
    extends
        $FunctionalProvider<
          FinanceWorkspaceEntry,
          FinanceWorkspaceEntry,
          FinanceWorkspaceEntry
        >
    with $Provider<FinanceWorkspaceEntry> {
  /// Enters a business as Open does. Nothing by default; the composition root
  /// selects the workspace (`financeWorkspaceEntryFromApp`, lib/app), where
  /// money and the workspace meet.
  FinanceWorkspaceEntryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'financeWorkspaceEntryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$financeWorkspaceEntryHash();

  @$internal
  @override
  $ProviderElement<FinanceWorkspaceEntry> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FinanceWorkspaceEntry create(Ref ref) {
    return financeWorkspaceEntry(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FinanceWorkspaceEntry value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FinanceWorkspaceEntry>(value),
    );
  }
}

String _$financeWorkspaceEntryHash() =>
    r'679f53274433aa2f7e0f6f9efb35439aff9665b0';

/// My finances' commands on a selection and a payment being processed.
/// Kept alive: a command outlives the tap that started it. It reads kept-
/// alive providers only; the selection is the page's, and the page takes
/// out of it what a command recorded.

@ProviderFor(financeSelectionCommands)
final financeSelectionCommandsProvider = FinanceSelectionCommandsProvider._();

/// My finances' commands on a selection and a payment being processed.
/// Kept alive: a command outlives the tap that started it. It reads kept-
/// alive providers only; the selection is the page's, and the page takes
/// out of it what a command recorded.

final class FinanceSelectionCommandsProvider
    extends
        $FunctionalProvider<
          FinanceSelectionCommands,
          FinanceSelectionCommands,
          FinanceSelectionCommands
        >
    with $Provider<FinanceSelectionCommands> {
  /// My finances' commands on a selection and a payment being processed.
  /// Kept alive: a command outlives the tap that started it. It reads kept-
  /// alive providers only; the selection is the page's, and the page takes
  /// out of it what a command recorded.
  FinanceSelectionCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'financeSelectionCommandsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$financeSelectionCommandsHash();

  @$internal
  @override
  $ProviderElement<FinanceSelectionCommands> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FinanceSelectionCommands create(Ref ref) {
    return financeSelectionCommands(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FinanceSelectionCommands value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FinanceSelectionCommands>(value),
    );
  }
}

String _$financeSelectionCommandsHash() =>
    r'e30cc7353b24f5e5ccf7b8e83419a3012f980cdd';

/// #3556 — the request ids of my payments, one set per account, shared by
/// My finances and the Money screen: a retry after a lost answer is the
/// same request, so the payment flow gives its checkout back instead of a
/// second payment (0797's replay).

@ProviderFor(paymentRequestIds)
final paymentRequestIdsProvider = PaymentRequestIdsProvider._();

/// #3556 — the request ids of my payments, one set per account, shared by
/// My finances and the Money screen: a retry after a lost answer is the
/// same request, so the payment flow gives its checkout back instead of a
/// second payment (0797's replay).

final class PaymentRequestIdsProvider
    extends
        $FunctionalProvider<
          PaymentRequestIds,
          PaymentRequestIds,
          PaymentRequestIds
        >
    with $Provider<PaymentRequestIds> {
  /// #3556 — the request ids of my payments, one set per account, shared by
  /// My finances and the Money screen: a retry after a lost answer is the
  /// same request, so the payment flow gives its checkout back instead of a
  /// second payment (0797's replay).
  PaymentRequestIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paymentRequestIdsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paymentRequestIdsHash();

  @$internal
  @override
  $ProviderElement<PaymentRequestIds> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PaymentRequestIds create(Ref ref) {
    return paymentRequestIds(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PaymentRequestIds value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PaymentRequestIds>(value),
    );
  }
}

String _$paymentRequestIdsHash() => r'b883e6a2e0512925457c8072618f9cb380fb2162';
