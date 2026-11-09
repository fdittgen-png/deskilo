// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2597 -- the in-memory half of WorkspaceIdentity: moved verbatim out of the part
// files; the state it reads is `FakeWorkspaceState`.
import 'dart:async';
import 'dart:typed_data' show Uint8List;

import 'package:deskilo/features/workspace/domain/payment_instructions.dart';
import 'package:deskilo/features/workspace/domain/workspace_branding.dart';
import 'package:deskilo/features/workspace/domain/workspace_document.dart';
import 'package:deskilo/features/workspace/domain/workspace_identity_repository.dart';

import 'fake_workspace_state.dart';

mixin FakeWorkspaceIdentity on FakeWorkspaceState
    implements WorkspaceIdentityRepository {
  @override
  Future<void> updateWorkspaceLocale(
    String workspaceId, {
    required String countryCode,
    required String currencyCode,
    required String timezone,
  }) async {
    lastLocaleUpdate = [workspaceId, countryCode, currencyCode, timezone];
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i != -1) {
      workspaces[i] = workspaces[i].copyWith(
        countryCode: countryCode,
        currencyCode: currencyCode,
        timezone: timezone,
      );
    }
  }

  @override
  Future<void> setPaymentInstructions(
    String workspaceId,
    PaymentInstructions instructions,
  ) async {
    lastPaymentInstructions = instructions;
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i != -1) {
      workspaces[i] = workspaces[i].copyWith(
        paymentInstructions: instructions.toDb(),
      );
    }
  }

  @override
  Future<void> setWhatsappGroup(String workspaceId, String link) async {
    lastWhatsappGroup = link;
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i != -1) {
      workspaces[i] = workspaces[i].copyWith(whatsappGroup: link);
    }
  }

  @override
  Future<void> setWorkspaceAddress(String workspaceId, String address) async {
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i >= 0) workspaces[i] = workspaces[i].copyWith(address: address.trim());
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
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i < 0) return;
    // One copyWith, like the server's one row update: the identity and
    // the mentions that go on the invoice with it move together or not
    // at all (#1532).
    workspaces[i] = workspaces[i].copyWith(
      vatRegime: vatRegime,
      vatId: vatId.trim(),
      legalId: legalId.trim(),
      taxExemptionReason: taxExemptionReason.trim(),
      street: street.trim(),
      city: city.trim(),
      postalCode: postalCode.trim(),
      vatAccount: vatAccount.trim(),
      invoiceLegal: Map<String, dynamic>.from(invoiceLegal),
    );
  }

  @override
  Future<void> setSubscriptionVatRate(
    String workspaceId,
    String vatRateId,
  ) async {
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i < 0) return;
    workspaces[i] = workspaces[i].copyWith(subscriptionVatRateId: vatRateId);
  }

  @override
  Future<List<WorkspaceDocument>> fetchDocuments(String workspaceId) async {
    // Mirror the RLS role gate so tests see honest visibility.
    bool visible(WorkspaceDocument d) => switch (d.minRole) {
      'owner' => myMember.isOwner,
      'admin' => myMember.isAdmin || myMember.isOwner,
      _ => true,
    };
    return documents
        .where((d) => d.workspaceId == workspaceId && visible(d))
        .toList();
  }

  @override
  Future<void> addDocument(WorkspaceDocument document) async {
    documents.add(
      WorkspaceDocument(
        id: 'doc-${documents.length + 1}',
        workspaceId: document.workspaceId,
        title: document.title.trim(),
        category: document.category,
        provider: document.provider,
        url: document.url.trim(),
        minRole: document.minRole,
      ),
    );
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    documents.removeWhere((d) => d.id == documentId);
  }

  @override
  Future<void> setWorkspaceLanguage(String workspaceId, String locale) async {
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i < 0) return;
    workspaces[i] = workspaces[i].copyWith(defaultLocale: locale.trim());
  }

  @override
  Future<void> setWorkspaceEmblem(String workspaceId, Uint8List png) async {
    emblems[workspaceId] = png;
  }

  @override
  Future<Uint8List?> fetchWorkspaceEmblem(String workspaceId) async =>
      emblems[workspaceId];
  @override
  Future<void> clearWorkspaceEmblem(String workspaceId) async {
    emblems.remove(workspaceId);
  }

  @override
  Future<Map<String, dynamic>> setWorkspaceBranding(
    String workspaceId,
    Map<String, dynamic> delta,
  ) async {
    // The server merges into the row, so the fake starts from what the
    // workspace carries — not from an empty map, which would make a
    // reset of one key look like a reset of all of them.
    final stored = workspaces.where((w) => w.id == workspaceId).firstOrNull;
    final current = Map<String, dynamic>.from(
      brandings[workspaceId] ?? stored?.branding ?? const {},
    );
    for (final e in delta.entries) {
      if (e.value == null) {
        current.remove(e.key);
      } else {
        current[e.key] = e.value;
      }
    }
    final mine = WorkspaceSymbol.of(current);
    if (mine != null &&
        symbolClashes(mine, [
          for (final w in workspaces)
            if (w.id != workspaceId) brandings[w.id] ?? w.branding,
        ])) {
      throw const WorkspaceSymbolTaken();
    }
    brandings[workspaceId] = current;
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i >= 0) workspaces[i] = workspaces[i].copyWith(branding: current);
    return current;
  }

  @override
  Future<Map<String, dynamic>> fetchLexicon(String workspaceId) async => {
    for (final e in (lexicons[workspaceId] ?? {}).entries) e.key: e.value,
  };
  @override
  Future<void> setLexiconTerm(
    String workspaceId,
    String locale,
    String key,
    String? text,
  ) async {
    final byLocale = lexicons.putIfAbsent(workspaceId, () => {});
    final terms = byLocale.putIfAbsent(locale, () => {});
    if (text == null) {
      terms.remove(key);
    } else {
      terms[key] = text;
    }
  }

  @override
  Future<void> setDeskOpacity(String workspaceId, int opacity) async {
    lastDeskOpacity = opacity;
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i >= 0) workspaces[i] = workspaces[i].copyWith(deskOpacity: opacity);
  }
}
