// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/public_network/public_network_codec.dart';
import '../../../core/public_network/public_network_operations.dart';
import '../domain/public_workspace.dart';

/// #1847 — the MANAGEMENT interface: the owner's own public page, through
/// the signed-in native session. Never reachable anonymously; the RPCs
/// re-check ownership. The save input is refused when it carries a key
/// the contract does not list, and its answer is read with the PUBLIC
/// projection, so the preview shows exactly what a visitor will see.
class SupabasePublicationRepository implements PublicationRepository {
  SupabasePublicationRepository(this.client);
  final SupabaseClient client;

  static const _read = PublicNetworkOperations.publicationPageRead;
  static const _save = PublicNetworkOperations.publicationPageSave;

  @override
  Future<Map<String, dynamic>> ownPage(String workspace) async =>
      decodePublicRecord(
        _read.output!,
        await client.rpc<Object?>(
          _read.rpc!,
          params: {'p_workspace': workspace},
        ),
      );

  @override
  Future<Map<String, dynamic>> savePage(
    String workspace,
    Map<String, String> document,
    bool published,
  ) async {
    final input = encodePublicInput(_save.input['p_document']!, document);
    return decodePublicRecord(
      _save.output!,
      await client.rpc<Object?>(
        _save.rpc!,
        params: {
          'p_workspace': workspace,
          'p_document': input,
          'p_published': published,
        },
      ),
    );
  }
}
