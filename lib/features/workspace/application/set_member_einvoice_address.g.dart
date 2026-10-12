// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_member_einvoice_address.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #2358 — the command that states a customer's e-invoicing address.

@ProviderFor(memberEInvoiceAddresses)
final memberEInvoiceAddressesProvider = MemberEInvoiceAddressesProvider._();

/// #2358 — the command that states a customer's e-invoicing address.

final class MemberEInvoiceAddressesProvider
    extends
        $FunctionalProvider<
          MemberEInvoiceAddresses,
          MemberEInvoiceAddresses,
          MemberEInvoiceAddresses
        >
    with $Provider<MemberEInvoiceAddresses> {
  /// #2358 — the command that states a customer's e-invoicing address.
  MemberEInvoiceAddressesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memberEInvoiceAddressesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memberEInvoiceAddressesHash();

  @$internal
  @override
  $ProviderElement<MemberEInvoiceAddresses> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MemberEInvoiceAddresses create(Ref ref) {
    return memberEInvoiceAddresses(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MemberEInvoiceAddresses value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MemberEInvoiceAddresses>(value),
    );
  }
}

String _$memberEInvoiceAddressesHash() =>
    r'54de83b9061dd51086527dcccd826df28c6979c6';
