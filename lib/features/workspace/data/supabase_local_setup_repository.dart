// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/local_setup.dart';
import '../domain/setup_status.dart';
import '../domain/setup_step_draft.dart';
import '../domain/workspace_readiness.dart';

/// #1656 — template_local_needs and workspace_local_readiness (0280).
class SupabaseLocalSetupRepository implements LocalSetupRepository {
  const SupabaseLocalSetupRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<LocalSlot>> templateNeeds(String templateId) async =>
      LocalSlot.listFromJson(
        await _client.rpc<Object?>(
          'template_local_needs',
          params: {'p_template_id': templateId},
        ),
      );

  @override
  Future<List<LocalSlot>> readiness(String workspaceId) async =>
      LocalSlot.listFromJson(
        await _client.rpc<Object?>(
          'workspace_local_readiness',
          params: {'p_workspace_id': workspaceId},
        ),
      );

  @override
  Future<SetupStatus> setupStatus(String workspaceId) async =>
      SetupStatus.fromJson(
        await _client.rpc<Object?>(
          'workspace_setup_status',
          params: {'p_workspace_id': workspaceId},
        ),
      );

  @override
  Future<List<ReadinessSection>> sections(String workspaceId) async =>
      ReadinessSection.listFromJson(
        await _client.rpc<Object?>(
          'workspace_readiness',
          params: {'p_workspace_id': workspaceId},
        ),
      );

  @override
  Future<void> acknowledgeSection(String workspaceId, String section) =>
      _client.rpc<Object?>(
        'acknowledge_readiness_section',
        params: {'p_workspace_id': workspaceId, 'p_section': section},
      );

  @override
  Future<void> clearAcknowledgement(String workspaceId, String section) =>
      _client.rpc<Object?>(
        'clear_readiness_acknowledgement',
        params: {'p_workspace_id': workspaceId, 'p_section': section},
      );

  @override
  Future<void> acknowledgeStep(String workspaceId, String step) =>
      _client.rpc<Object?>(
        'acknowledge_setup_step',
        params: {'p_workspace_id': workspaceId, 'p_step': step},
      );

  @override
  Future<void> clearStepAcknowledgement(String workspaceId, String step) =>
      _client.rpc<Object?>(
        'clear_setup_step_acknowledgement',
        params: {'p_workspace_id': workspaceId, 'p_step': step},
      );

  @override
  Future<SetupStepDraft?> stepDraft(String workspaceId, String step) async =>
      SetupStepDraft.fromJson(
        await _client.rpc<Object?>(
          'get_setup_step_draft',
          params: {'p_workspace_id': workspaceId, 'p_step': step},
        ),
      );

  @override
  Future<SetupDraftWrite> saveStepDraft(
    String workspaceId,
    String step, {
    required Map<String, Object?> payload,
    required int? expectedVersion,
    required String requestId,
  }) async => SetupDraftWrite.fromJson(
    await _drafts('save_setup_step_draft', {
      'p_workspace_id': workspaceId,
      'p_step': step,
      'p_payload': payload,
      'p_expected_version': expectedVersion,
      'p_request_id': requestId,
    }),
  );

  @override
  Future<bool> discardStepDraft(
    String workspaceId,
    String step, {
    required int? expectedVersion,
  }) async =>
      await _drafts('discard_setup_step_draft', {
        'p_workspace_id': workspaceId,
        'p_step': step,
        'p_expected_version': expectedVersion,
      }) ==
      true;

  /// A draft write; the server's "changed by someone else" as its type.
  Future<Object?> _drafts(String fn, Map<String, Object?> params) async {
    try {
      return await _client.rpc<Object?>(fn, params: params);
    } on PostgrestException catch (e, st) {
      // trace-exempt: rethrown typed; the step page shows the conflict.
      if (!SetupDraftConflict.isConflict(e.code, e.message)) rethrow;
      Error.throwWithStackTrace(SetupDraftConflict(e.message), st);
    }
  }
}
