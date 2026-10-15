// SPDX-License-Identifier: AGPL-3.0-or-later

/// #2587 — per invoice, how many reminders were sent and when the last one
/// went, from EVERY reminder row (the caller pages to the end; a list cut at
/// the server's cap gives a false count and a false latest date).
Map<String, ({int count, DateTime last})> foldInvoiceReminders(
  List<Map<String, Object?>> rows,
) {
  final result = <String, ({int count, DateTime last})>{};
  for (final row in rows) {
    final id = row['invoice_id'] as String;
    final at = DateTime.parse(row['sent_at'] as String).toLocal();
    final prev = result[id];
    result[id] = (
      count: (prev?.count ?? 0) + 1,
      last: prev == null || at.isAfter(prev.last) ? at : prev.last,
    );
  }
  return result;
}
