// SPDX-License-Identifier: AGPL-3.0-or-later
import 'number_sequence.dart';

/// #2591 — the number series of a workspace's documents and the
/// fingerprint check of an issued invoice. The server takes the numbers;
/// the client only reads, previews and sets the format.
abstract interface class DocumentNumbering {
  /// #925 — every number series of the workspace (table
  /// `number_sequences`, 0164), one per journal, seeded lazily.
  Future<List<NumberSequence>> fetchNumberSequences(String workspaceId);

  /// #925 — what the next number of [journal] would be, without taking
  /// it (RPC `preview_document_number`).
  Future<String> previewDocumentNumber(String workspaceId, String journal);

  /// #956 — 'verified' | 'altered' | 'unverifiable' (RPC
  /// `verify_invoice_signature`): the fingerprint recomputed from the
  /// stored columns.
  Future<String> verifyInvoiceSignature(String invoiceId);

  /// #925 — the owner sets a series' format; the counter may only be
  /// raised (RPC `set_number_sequence`).
  Future<void> setNumberSequence(
    String workspaceId,
    NumberSequence sequence, {
    int? raiseNextValueTo,
  });
}
