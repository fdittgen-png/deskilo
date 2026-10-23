// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1656 group 5 — what a space must set up locally for the features a
// template switches on (0280): its legal identity, how members pay, a
// payment provider, an e-invoice platform, a site. Never carried by a
// template, never guessed; only named, with where it is filled in.

import 'setup_status.dart';
import 'setup_step_draft.dart';
import 'workspace_readiness.dart';

enum LocalSlotKind {
  legalIdentity,
  paymentDetails,
  paymentProvider,
  einvoicePlatform,
  site,
  namedValidators,
  unknown,
}

class LocalSlot {
  const LocalSlot({
    required this.kind,
    required this.required,
    required this.route,
    this.filled,
    this.eventType,
  });

  /// #1657 — for [LocalSlotKind.namedValidators]: which policy.
  final String? eventType;

  final LocalSlotKind kind;

  /// Recommended rather than needed when false.
  final bool required;

  /// Where it is filled in.
  final String route;

  /// Null when describing a template (nothing to check yet).
  final bool? filled;

  static List<LocalSlot> listFromJson(Object? json) => [
    for (final s in json is List ? json : const [])
      if (s is Map)
        LocalSlot(
          kind: switch (s['slot']) {
            'legal_identity' => LocalSlotKind.legalIdentity,
            'payment_details' => LocalSlotKind.paymentDetails,
            'payment_provider' => LocalSlotKind.paymentProvider,
            'einvoice_platform' => LocalSlotKind.einvoicePlatform,
            'site' => LocalSlotKind.site,
            'named_validators' => LocalSlotKind.namedValidators,
            _ => LocalSlotKind.unknown,
          },
          required: s['required'] != false,
          route: s['route'] is String && '${s['route']}'.startsWith('/')
              ? s['route'] as String
              : '/settings',
          filled: s['filled'] is bool ? s['filled'] as bool : null,
          eventType: s['event_type'] is String ? s['event_type'] as String : null,
        ),
  ];
}

abstract interface class LocalSetupRepository {
  /// What [templateId] will need locally.
  Future<List<LocalSlot>> templateNeeds(String templateId);

  /// What [workspaceId] still lacks for the features it has on.
  Future<List<LocalSlot>> readiness(String workspaceId);

  /// #1636 — each setup section of [workspaceId] and its state.
  Future<List<ReadinessSection>> sections(String workspaceId);

  /// 0307 — sets the optional section [section] (the server's name) aside
  /// for later, at its current state. The server refuses a required or a
  /// ready one.
  Future<void> acknowledgeSection(String workspaceId, String section);

  /// 0307 — takes [section] back: it is next again when it is open.
  Future<void> clearAcknowledgement(String workspaceId, String section);

  /// #2869 — every setup step of [workspaceId] and the four milestones
  /// (`workspace_setup_status`, 0539).
  Future<SetupStatus> setupStatus(String workspaceId);

  /// 0545 — marks the guide's step [step] done when the server cannot
  /// verify it, else sets the optional step aside for later. The server
  /// refuses a required step it verifies and one with nothing left to do.
  Future<void> acknowledgeStep(String workspaceId, String step);

  /// 0545 — takes [step] back: it is open again.
  Future<void> clearStepAcknowledgement(String workspaceId, String step);

  /// #2869 — the draft [step] of [workspaceId] holds, or null.
  Future<SetupStepDraft?> stepDraft(String workspaceId, String step);

  /// #2869 — stores [payload] as [step]'s draft against [expectedVersion]
  /// (null: there was no draft). Throws [SetupDraftConflict] when the draft
  /// moved since; the same [requestId] answers its first write again.
  Future<SetupDraftWrite> saveStepDraft(
    String workspaceId,
    String step, {
    required Map<String, Object?> payload,
    required int? expectedVersion,
    required String requestId,
  });

  /// #2869 — discards [step]'s draft at [expectedVersion]; false when there
  /// was none. Throws [SetupDraftConflict] when it moved since.
  Future<bool> discardStepDraft(
    String workspaceId,
    String step, {
    required int? expectedVersion,
  });
}
