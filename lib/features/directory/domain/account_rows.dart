// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4409 — the account messenger's rows as the screens read them: a person
// the account can find, and one of its conversations. The server's row is
// read here, by name, and nowhere in a widget.

/// One person of `accountContacts`.
extension type const AccountPersonRow(Map<String, dynamic> _row) {
  String get id => '${_row['id']}';
  String get name => '${_row['name'] ?? ''}';
}

/// One conversation of `accountConversations`.
extension type const AccountConversationRow(Map<String, dynamic> _row) {
  String get id => '${_row['id']}';
  String get name => '${_row['name'] ?? ''}';

  /// The other person, when the server names them.
  String? get recipient => _row['recipient'] as String?;
  int get unread => (_row['unread'] as num?)?.toInt() ?? 0;

  /// The keyset cursor of the next page.
  DateTime get updatedAt => DateTime.parse(_row['updated_at'] as String);
}
