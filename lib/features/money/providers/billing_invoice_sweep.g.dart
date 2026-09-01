// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'billing_invoice_sweep.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #816 — the client-side clock for the billing cycle (#802): the first
/// issuer who opens Finances in a session runs `sweep_billing_invoices`
/// for the workspace, exactly as the reminder sweep runs (#726). The
/// sweep is idempotent (one invoice per member and month), so it costs
/// nothing when the cron already ran — and a workspace without pg_cron
/// still gets its subscription and usage invoices.

@ProviderFor(billingInvoiceSweep)
final billingInvoiceSweepProvider = BillingInvoiceSweepFamily._();

/// #816 — the client-side clock for the billing cycle (#802): the first
/// issuer who opens Finances in a session runs `sweep_billing_invoices`
/// for the workspace, exactly as the reminder sweep runs (#726). The
/// sweep is idempotent (one invoice per member and month), so it costs
/// nothing when the cron already ran — and a workspace without pg_cron
/// still gets its subscription and usage invoices.

final class BillingInvoiceSweepProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// #816 — the client-side clock for the billing cycle (#802): the first
  /// issuer who opens Finances in a session runs `sweep_billing_invoices`
  /// for the workspace, exactly as the reminder sweep runs (#726). The
  /// sweep is idempotent (one invoice per member and month), so it costs
  /// nothing when the cron already ran — and a workspace without pg_cron
  /// still gets its subscription and usage invoices.
  BillingInvoiceSweepProvider._({
    required BillingInvoiceSweepFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'billingInvoiceSweepProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$billingInvoiceSweepHash();

  @override
  String toString() {
    return r'billingInvoiceSweepProvider'
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
    return billingInvoiceSweep(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BillingInvoiceSweepProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$billingInvoiceSweepHash() =>
    r'5284919a983b40873d8078e5705c2c7cae456134';

/// #816 — the client-side clock for the billing cycle (#802): the first
/// issuer who opens Finances in a session runs `sweep_billing_invoices`
/// for the workspace, exactly as the reminder sweep runs (#726). The
/// sweep is idempotent (one invoice per member and month), so it costs
/// nothing when the cron already ran — and a workspace without pg_cron
/// still gets its subscription and usage invoices.

final class BillingInvoiceSweepFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int>, String> {
  BillingInvoiceSweepFamily._()
    : super(
        retry: null,
        name: r'billingInvoiceSweepProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// #816 — the client-side clock for the billing cycle (#802): the first
  /// issuer who opens Finances in a session runs `sweep_billing_invoices`
  /// for the workspace, exactly as the reminder sweep runs (#726). The
  /// sweep is idempotent (one invoice per member and month), so it costs
  /// nothing when the cron already ran — and a workspace without pg_cron
  /// still gets its subscription and usage invoices.

  BillingInvoiceSweepProvider call(String workspaceId) =>
      BillingInvoiceSweepProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'billingInvoiceSweepProvider';
}
