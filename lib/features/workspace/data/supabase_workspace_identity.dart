// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2597 -- the workspace's identity: locale, legal, payment, documents, lexicon, branding and emblem, as one mixin composed into
// `SupabaseWorkspaceRepository` (the part-file bodies and their `_xxxImpl`
// forwarders are gone).
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/payment_instructions.dart';
import '../domain/workspace_branding.dart';
import '../domain/workspace_document.dart';
import '../domain/workspace_identity_repository.dart';
import 'supabase_workspace_repository.dart';
import 'supabase_workspace_rows.dart';

mixin SupabaseWorkspaceIdentity on SupabaseWorkspaceRows
    implements WorkspaceIdentityRepository {
  @override
  Future<void> updateWorkspaceLocale(
    String workspaceId, {
    required String countryCode,
    required String currencyCode,
    required String timezone,
  }) async {
    // Direct row update — workspaces_update RLS restricts it to owners,
    // and the 0001 column checks re-validate the ISO shapes (#153).
    await updateWorkspaceRow(workspaceId, {
      'country_code': countryCode.toUpperCase(),
      'currency_code': currencyCode.toUpperCase(),
      'timezone': timezone,
    });
  }

  @override
  Future<void> setPaymentInstructions(
    String workspaceId,
    PaymentInstructions instructions,
  ) async {
    // Wholesale jsonb replace, like feature_flags (#155): the settings
    // form always writes the full three-field blob.
    await updateWorkspaceRow(workspaceId, {
      'payment_instructions': instructions.toDb(),
    });
  }

  @override
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
  }) async {
    // Owner-only via workspaces_update RLS; the 0069 column checks cap
    // every field. ONE row update, so an identity can never be
    // half-declared — and the statutory mentions ride in it, because a
    // VAT regime saved without them is the same half-declaration one
    // level up (#1532).
    await updateWorkspaceRow(workspaceId, {
      'vat_regime': vatRegime,
      'vat_id': vatId.trim(),
      'legal_id': legalId.trim(),
      'tax_exemption_reason': taxExemptionReason.trim(),
      'street': street.trim(),
      'city': city.trim(),
      'postal_code': postalCode.trim(),
      'vat_account': vatAccount.trim(),
      'invoice_legal': invoiceLegal,
    });
  }

  @override
  Future<void> setSubscriptionVatRate(
    String workspaceId,
    String vatRateId,
  ) async {
    // Owner-only via workspaces_update RLS, like the legal identity.
    await updateWorkspaceRow(workspaceId, {
      'subscription_vat_rate_id': vatRateId.isEmpty ? null : vatRateId,
    });
  }

  @override
  Future<List<WorkspaceDocument>> fetchDocuments(String workspaceId) async {
    final rows = await client
        .from('workspace_documents')
        .select()
        .eq('workspace_id', workspaceId)
        .order('category')
        .order('title');
    return [for (final row in rows) WorkspaceDocument.fromRow(row)];
  }

  @override
  Future<void> addDocument(WorkspaceDocument document) async {
    await client.from('workspace_documents').insert({
      'workspace_id': document.workspaceId,
      'title': document.title.trim(),
      'category': document.category,
      'provider': document.provider,
      'url': document.url.trim(),
      'min_role': document.minRole,
    });
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    await client.from('workspace_documents').delete().eq('id', documentId);
  }

  @override
  Future<void> setWorkspaceLanguage(String workspaceId, String locale) async {
    // Owner-only via workspaces_update RLS; 0096 caps at 5 chars.
    await updateWorkspaceRow(workspaceId, {'default_locale': locale.trim()});
  }

  @override
  Future<void> setWorkspaceAddress(String workspaceId, String address) async {
    // Owner-only via workspaces_update RLS; 0060 caps at 400 chars.
    await updateWorkspaceRow(workspaceId, {'address': address.trim()});
  }

  @override
  Future<void> setWhatsappGroup(String workspaceId, String link) async {
    // Direct row update like setPaymentInstructions — workspaces_update
    // RLS restricts it to owners, and the 0029 column check re-validates
    // the chat.whatsapp.com prefix.
    await updateWorkspaceRow(workspaceId, {'whatsapp_group': link.trim()});
  }

  @override
  Future<Map<String, dynamic>> fetchLexicon(String workspaceId) async {
    final row = await client
        .from('workspaces')
        .select('lexicon')
        .eq('id', workspaceId)
        .single();
    return row['lexicon'] as Map<String, dynamic>? ?? const {};
  }

  @override
  Future<void> setLexiconTerm(
    String workspaceId,
    String locale,
    String key,
    String? text,
  ) async {
    // Keyed, so the merge happens in the database: a second editor
    // cannot revert the first, and the other locales survive (#1089).
    await client.rpc<dynamic>(
      'set_workspace_lexicon_term',
      params: {
        'p_workspace_id': workspaceId,
        'p_locale': locale,
        'p_key': key,
        'p_text': text,
      },
    );
  }

  @override
  Future<void> setWorkspaceEmblem(String workspaceId, Uint8List png) async {
    await client.storage
        .from('floor-plans')
        .uploadBinary(
          SupabaseWorkspaceRepository.emblemPath(workspaceId),
          png,
          fileOptions: const FileOptions(
            contentType: 'image/png',
            upsert: true,
          ),
        );
  }

  @override
  Future<Uint8List?> fetchWorkspaceEmblem(String workspaceId) async {
    try {
      return await client.storage
          .from('floor-plans')
          .download(SupabaseWorkspaceRepository.emblemPath(workspaceId));
    } on StorageException {
      // No object, or not readable by this member: the app renders as it
      // always did. Not a fault worth surfacing (#1289).
      return null;
    }
  }

  @override
  Future<void> clearWorkspaceEmblem(String workspaceId) async {
    await client.storage.from('floor-plans').remove([
      SupabaseWorkspaceRepository.emblemPath(workspaceId),
    ]);
  }

  @override
  Future<Map<String, dynamic>> setWorkspaceBranding(
    String workspaceId,
    Map<String, dynamic> delta,
  ) async {
    final dynamic out;
    try {
      out = await client.rpc<dynamic>(
        'set_workspace_branding',
        params: {'p_workspace_id': workspaceId, 'p_branding': delta},
      );
    } on PostgrestException catch (e, st) {
      // 0378 — the letters-and-colour pair is unique across workspaces.
      if (e.code == '23505') {
        Error.throwWithStackTrace(const WorkspaceSymbolTaken(), st);
      }
      rethrow;
    }
    return Map<String, dynamic>.from(out as Map? ?? const <String, dynamic>{});
  }

  @override
  Future<void> setDeskOpacity(String workspaceId, int opacity) async {
    await updateWorkspaceRow(workspaceId, {'desk_opacity': opacity});
  }
}
