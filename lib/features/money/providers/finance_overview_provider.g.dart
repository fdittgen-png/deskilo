// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finance_overview_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Me › Finances: my invoices and reminders across every workspace (0380),
/// each read where its documents live. The personal home answers for the
/// installation the app is signed in to; when the selected workspace lives
/// on a connected installation, that host answers for its own documents on
/// the selected workspace's client, and a host that does not answer leaves
/// the others on screen and is named as unavailable rather than hiding
/// them or posing as empty.

@ProviderFor(financeOverview)
final financeOverviewProvider = FinanceOverviewProvider._();

/// Me › Finances: my invoices and reminders across every workspace (0380),
/// each read where its documents live. The personal home answers for the
/// installation the app is signed in to; when the selected workspace lives
/// on a connected installation, that host answers for its own documents on
/// the selected workspace's client, and a host that does not answer leaves
/// the others on screen and is named as unavailable rather than hiding
/// them or posing as empty.

final class FinanceOverviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<FinanceOverview>,
          FinanceOverview,
          FutureOr<FinanceOverview>
        >
    with $FutureModifier<FinanceOverview>, $FutureProvider<FinanceOverview> {
  /// Me › Finances: my invoices and reminders across every workspace (0380),
  /// each read where its documents live. The personal home answers for the
  /// installation the app is signed in to; when the selected workspace lives
  /// on a connected installation, that host answers for its own documents on
  /// the selected workspace's client, and a host that does not answer leaves
  /// the others on screen and is named as unavailable rather than hiding
  /// them or posing as empty.
  FinanceOverviewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'financeOverviewProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$financeOverviewHash();

  @$internal
  @override
  $FutureProviderElement<FinanceOverview> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<FinanceOverview> create(Ref ref) {
    return financeOverview(ref);
  }
}

String _$financeOverviewHash() => r'507a90cca3fb85f2913c8b6314f5486ed6727c92';

/// A one-shot request to open one invoice in its own space's Money screen
/// (Me › Finances → the workspace, in the right environment). The screen
/// consumes it only when the request's space is the current one. Kept
/// alive: the request outlives the screen that made it.

@ProviderFor(InvoiceFocus)
final invoiceFocusProvider = InvoiceFocusProvider._();

/// A one-shot request to open one invoice in its own space's Money screen
/// (Me › Finances → the workspace, in the right environment). The screen
/// consumes it only when the request's space is the current one. Kept
/// alive: the request outlives the screen that made it.
final class InvoiceFocusProvider
    extends
        $NotifierProvider<
          InvoiceFocus,
          ({String invoiceId, String workspaceId})?
        > {
  /// A one-shot request to open one invoice in its own space's Money screen
  /// (Me › Finances → the workspace, in the right environment). The screen
  /// consumes it only when the request's space is the current one. Kept
  /// alive: the request outlives the screen that made it.
  InvoiceFocusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'invoiceFocusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$invoiceFocusHash();

  @$internal
  @override
  InvoiceFocus create() => InvoiceFocus();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(({String invoiceId, String workspaceId})? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<({String invoiceId, String workspaceId})?>(value),
    );
  }
}

String _$invoiceFocusHash() => r'2883828614aa1734e0eb68ea066d71e94d46cd71';

/// A one-shot request to open one invoice in its own space's Money screen
/// (Me › Finances → the workspace, in the right environment). The screen
/// consumes it only when the request's space is the current one. Kept
/// alive: the request outlives the screen that made it.

abstract class _$InvoiceFocus
    extends $Notifier<({String invoiceId, String workspaceId})?> {
  ({String invoiceId, String workspaceId})? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              ({String invoiceId, String workspaceId})?,
              ({String invoiceId, String workspaceId})?
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                ({String invoiceId, String workspaceId})?,
                ({String invoiceId, String workspaceId})?
              >,
              ({String invoiceId, String workspaceId})?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
