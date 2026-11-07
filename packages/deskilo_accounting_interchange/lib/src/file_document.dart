// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3376 -- one document a file carried, as the file delivery records it: what a
// writer returns beside its text, so the delivery can log each document's own
// digest.

/// One document a file carried, as the file delivery records it.
class FileDocument {
  const FileDocument({
    required this.kind,
    required this.id,
    required this.number,
    required this.date,
    required this.sha256,
  });

  final String kind;
  final String id;
  final String number;
  final DateTime date;
  final String sha256;
}
