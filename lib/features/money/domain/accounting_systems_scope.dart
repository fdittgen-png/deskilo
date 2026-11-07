// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What the accounting systems sheet needs of the space and the rights that
// read or manage the connections (split out of accounting_connection.dart).

/// The right that connects, maps and revokes (the server's
/// `accounting_connector_actor`).
const String _accountingConnectPermission = 'manageBilling';

/// The rights that read the connections and the transfers (the server's
/// `accounting_reader`, beside the owner).
const Set<String> accountingTransferReaders = {
  'viewFinances',
  'exportData',
  _accountingConnectPermission,
};

/// What the accounting systems need of the space: its country (which
/// targets it is offered), its issuers by id, the rights the reader holds
/// (by name) and its members' names.
class AccountingSystemsScope {
  const AccountingSystemsScope({
    required this.countryCode,
    required this.issuers,
    required this.permissions,
    required this.memberNames,
    this.owner = false,
  });

  final String countryCode;
  final Map<String, String> issuers;
  final Set<String> permissions;
  final Map<String, String> memberNames;

  /// The reader owns the space: only the owner retires or reopens (#3336).
  final bool owner;

  bool get manage => permissions.contains(_accountingConnectPermission);
}
