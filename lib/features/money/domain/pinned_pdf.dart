// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3853 — an issued invoice is its stored original, so the bytes of its PDF
// may depend only on what the document says. The PDF writer stamps two
// things from the moment it runs: the dates of the document's information
// and of an attached file (DateTime.now()), and the file identifier (a
// random value). This writes, in their place, the instant the document
// names and an identifier taken from the document's own bytes. Each value
// keeps its length, so every offset of the file stays as written.
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// The dates a PDF writer stamps: `/CreationDate (D:YYYYMMDDHHmmSS` and
/// `/ModDate (D:YYYYMMDDHHmmSS`, with or without a space before the bracket.
final RegExp _stampedDate = RegExp(r'/(CreationDate|ModDate) ?\(D:(\d{14})');

/// The file identifier: `/ID[<hex><hex>]`.
final RegExp _fileId = RegExp(
  r'/ID ?\[ ?<([0-9a-fA-F]+)> ?<([0-9a-fA-F]+)> ?\]',
);

/// [pdf] with its stamped dates set to [at] (in UTC, to the second) and its
/// file identifier taken from its own content.
Uint8List pinnedPdf(Uint8List pdf, DateTime at) {
  final utc = at.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  final stamp =
      '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}${two(utc.day)}'
      '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}';
  var text = latin1
      .decode(pdf)
      .replaceAllMapped(
        _stampedDate,
        (m) => m
            .group(0)!
            .replaceRange(m.group(0)!.length - 14, m.group(0)!.length, stamp),
      );
  final id = _fileId.firstMatch(text);
  if (id != null) {
    // The identifier is the digest of the file with the identifier blanked,
    // so it names this content and nothing else.
    String blank(String hex) => '0' * hex.length;
    final blanked = text.replaceRange(
      id.start,
      id.end,
      id
          .group(0)!
          .replaceFirst(id.group(1)!, blank(id.group(1)!))
          .replaceFirst(id.group(2)!, blank(id.group(2)!)),
    );
    final digest = sha256.convert(latin1.encode(blanked)).toString();
    String sized(int length) =>
        (digest * (length ~/ digest.length + 1)).substring(0, length);
    text = text.replaceRange(
      id.start,
      id.end,
      id
          .group(0)!
          .replaceFirst(id.group(1)!, sized(id.group(1)!.length))
          .replaceFirst(id.group(2)!, sized(id.group(2)!.length)),
    );
  }
  return latin1.encode(text);
}
