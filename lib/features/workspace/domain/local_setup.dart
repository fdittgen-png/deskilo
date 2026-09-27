// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1656 group 5 — what a space must set up locally for the features a
// template switches on (0280): its legal identity, how members pay, a
// payment provider, an e-invoice platform, a site. Never carried by a
// template, never guessed; only named, with where it is filled in.

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
}
