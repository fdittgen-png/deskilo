// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 — the open business as the invoicing screens read it, a part of
// the money providers (their imports, their scope).
part of 'money_providers.dart';

/// #3587 — the open business as the invoicing screens need it: its id, its
/// currency, its country, and its calendar day of an instant (the
/// workspace's own context; the plain calendar day while it is not ready).
typedef InvoicingBusiness = ({
  String id,
  String currency,
  String country,
  DateTime Function(DateTime instant) dayOf,
});

/// #3587 — the [InvoicingBusiness] in scope.
final invoicingBusinessProvider = Provider.autoDispose<InvoicingBusiness>((
  ref,
) {
  final workspace = ref.watch(currentWorkspaceProvider).value;
  return (
    id: workspace?.id ?? '',
    currency: workspace?.currencyCode ?? '',
    country: workspace?.countryCode ?? '',
    dayOf:
        ref.watch(readyWorkspaceContextProvider)?.calendar.dateOf ??
        (DateTime d) => DateTime(d.year, d.month, d.day),
  );
});
