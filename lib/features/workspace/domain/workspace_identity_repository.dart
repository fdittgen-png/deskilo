// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:typed_data';

import 'payment_instructions.dart';
import 'workspace.dart';
import 'workspace_document.dart';

/// How the workspace presents itself: language, address, legal identity, payment instructions, branding, lexicon, documents.
///
/// A part of [WorkspaceRepository] (#2597): that interface is the sum of
/// these, so no caller changes.
abstract class WorkspaceIdentityRepository {
  /// Owner-only (workspaces_update RLS): change the workspace locale —
  /// country, currency and time zone (#153). Currency defaults from the
  /// country in the UI but any ISO 4217 override is persisted verbatim.
  Future<void> updateWorkspaceLocale(
    String workspaceId, {
    required String countryCode,
    required String currencyCode,
    required String timezone,
  });

  /// Owner-only (workspaces_update RLS): replace the workspace's payment
  /// instructions wholesale (#155). Shown to members on unpaid
  /// statements.
  Future<void> setPaymentInstructions(
    String workspaceId,
    PaymentInstructions instructions,
  );

  /// Owner-only (workspaces_update RLS): set the community's WhatsApp
  /// group invite link (#231) — trimmed, '' clears it. Must satisfy
  /// [WhatsappGroupRules.isValid]; the 0029 column check re-validates
  /// the chat.whatsapp.com prefix server-side.
  Future<void> setWhatsappGroup(String workspaceId, String link);

  /// The workspace's postal address (0060), printed on invoices.
  Future<void> setWorkspaceAddress(String workspaceId, String address);

  /// Owner-only (RLS workspaces_update): the LEGAL IDENTITY an EN 16931
  /// e-invoice requires (0069) — VAT regime plus the identifier that
  /// regime demands, the exemption reason and the structured address —
  /// **and the statutory mentions that go on the invoice with it**
  /// (`invoice_legal`, 0094).
  ///
  /// One row update, because they are one statement about the seller.
  /// As two calls from the same Save, a failure on the second left the
  /// VAT regime changed and the mentions not — every invoice after it
  /// carrying a legal block that contradicted itself (#1532).
  Future<void> setLegalIdentity(
    String workspaceId, {
    required String vatRegime,
    required String vatId,
    required String legalId,
    required String taxExemptionReason,
    required String street,
    required String city,
    required String postalCode,
    required String vatAccount,
    required Map<String, Object?> invoiceLegal,
  });

  /// Owner-only: the subscription tariff's VAT rate (#542) — '' resets
  /// to the workspace default.
  Future<void> setSubscriptionVatRate(String workspaceId, String vatRateId);

  /// The document library (#500, 0099) — RLS already trims rows to
  /// what the caller's role may see.
  Future<List<WorkspaceDocument>> fetchDocuments(String workspaceId);

  /// Admin/owner: add a library document.
  Future<void> addDocument(WorkspaceDocument document);

  /// Admin/owner: delete a library document.
  Future<void> deleteDocument(String documentId);

  /// Owner-only (workspaces_update RLS): set the workspace's language
  /// (0096, e.g. 'fr'); '' clears it.
  Future<void> setWorkspaceLanguage(String workspaceId, String locale);

  /// #1277 — the workspace's own words for allow-listed product terms
  /// (`workspaces.lexicon`), shaped `{locale: {key: text}}`. Empty for a
  /// workspace that has renamed nothing, which is almost all of them.
  Future<Map<String, dynamic>> fetchLexicon(String workspaceId);

  /// Writes ONE term, preserving every other word and every other
  /// locale. `text` null removes the override rather than storing the
  /// product default — storing it would freeze that word against every
  /// future rewording. The server refuses a key outside
  /// `lexicon_allowed_keys()` (0223).
  Future<void> setLexiconTerm(
    String workspaceId,
    String locale,
    String key,
    String? text,
  );

  /// #1289 — writes a branding DELTA through `set_workspace_branding`:
  /// a key set to null is removed, a value replaces it, every other key
  /// survives (the server merges). The server refuses a key outside the
  /// three it defines and a colour that is not `#RRGGBB`; the contrast
  /// refusal is the client's, before this is called. Returns the map as
  /// stored.
  Future<Map<String, dynamic>> setWorkspaceBranding(
    String workspaceId,
    Map<String, dynamic> delta,
  );

  /// #1289 — the workspace's emblem, stored at `<workspace>/brand/emblem.png`
  /// in the `floor-plans` bucket: its storage policies already scope the
  /// first folder to the workspace (members read, owners write — 0036),
  /// so the emblem needs no bucket and no policy of its own.
  ///
  /// [png] is what `emblemPngOf` produced: bounded, re-drawn, metadata
  /// gone. Uploading replaces whatever was there.
  Future<void> setWorkspaceEmblem(String workspaceId, Uint8List png);

  /// The emblem's bytes, or null when the space has none — absent is the
  /// normal case and never an error.
  Future<Uint8List?> fetchWorkspaceEmblem(String workspaceId);

  /// Removes the emblem. A space with no emblem renders exactly as one
  /// that never had one.
  Future<void> clearWorkspaceEmblem(String workspaceId);

  /// Owner-only: set the desk fill opacity percentage (0040), clamped
  /// 20..100 server-side. Lower = more translucent desks.
  Future<void> setDeskOpacity(String workspaceId, int opacity);
}
