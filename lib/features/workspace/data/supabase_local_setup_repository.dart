// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/json_reader.dart';
import '../domain/local_setup.dart';
import '../domain/setup_journey.dart';
import '../domain/setup_levels.dart';
import '../domain/setup_status.dart';
import '../domain/setup_step_draft.dart';
import '../domain/setup_step_timing.dart';
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

  @override
  Future<SetupJourney?> setupJourney(String workspaceId) async =>
      SetupJourney.fromJson(
        await _client.rpc<Object?>(
          'get_setup_journey',
          params: {'p_workspace_id': workspaceId},
        ),
      );

  @override
  Future<int> saveSetupJourney(
    String workspaceId, {
    required SetupAnswers answers,
    required SetupLevelVector levels,
    required int? expectedVersion,
    required String requestId,
  }) async {
    try {
      final saved = await _client.rpc<Object?>(
        'save_setup_journey',
        params: {
          'p_workspace_id': workspaceId,
          'p_answers': answers.toJson(),
          'p_levels': {
            for (final MapEntry(:key, :value) in levels.entries)
              key.name: value,
          },
          'p_expected_version': expectedVersion,
          'p_request_id': requestId,
        },
      );
      return JsonReader.of(saved, context: 'save_setup_journey')
          .integer('version');
    } on PostgrestException catch (e, st) {
      // trace-exempt: rethrown typed; the levels screen shows the conflict.
      if (!SetupJourneyConflict.isConflict(e.code, e.message)) rethrow;
      Error.throwWithStackTrace(SetupJourneyConflict(e.message), st);
    }
  }

  @override
  Future<void> recordStepTiming(SetupStepObservation observation) =>
      _client.rpc<Object?>(
        'record_setup_step_timing',
        params: {
          'p_workspace_id': observation.workspaceId,
          'p_step': observation.step,
          'p_opened_at': observation.openedAt.toUtc().toIso8601String(),
          'p_seconds': observation.duration.inSeconds,
        },
      );

  @override
  Future<Map<String, SetupEstimate>> stepTimingRanges() async =>
      setupTimingRangesFromJson(
        await _client.rpc<Object?>('setup_step_timing_ranges'),
      );

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
