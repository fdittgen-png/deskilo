// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1650 — the current continuation: what the person came to do, kept
// across sign-in, verification, consent, a reload and an app restart,
// and forgotten the moment it is done, expired, or belongs to somebody
// else.
//
// On the device it is one bounded draft: versioned, keyed to the
// installation (the server this device talks to) and to the user when
// one was signed in, with an expiry. A draft from another version,
// another server, another account or another day is dropped unread. It
// carries the intent's own fields and nothing else — the intent type
// refuses credentials at construction, so there is nothing here to leak.
import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/backend/backend_settings.dart';
import '../core/storage/entry_intent_store.dart';
import '../core/time/clock.dart';
import '../core/trace/trace_logger.dart';
import '../features/auth/providers/auth_providers.dart';
import 'entry_intent.dart';

part 'entry_intents.g.dart';

/// The draft's shape. Bumped when a field changes meaning; an older
/// draft is then dropped rather than reinterpreted.
const int kEntryIntentDraftVersion = 1;

/// How long a draft may wait. A confirmation e-mail is good for a day
/// on the default service; a draft that outlives it was not resumed.
const Duration kEntryIntentLifetime = Duration(hours: 24);

/// The installation key when the device talks to the default service.
const String kDefaultInstallation = 'default';

/// What is written: the intent, and the keys that say who may resume it.
class EntryIntentDraft {
  const EntryIntentDraft({
    required this.intent,
    required this.installation,
    required this.userId,
    required this.expiresAt,
  });

  final EntryIntent intent;
  final String installation;
  final String? userId;
  final DateTime expiresAt;

  String encode() => jsonEncode({
        'v': kEntryIntentDraftVersion,
        'id': intent.id,
        'purpose': intent.purpose.name,
        if (intent.target != null) 'target': intent.target,
        if (intent.hint != null) 'hint': intent.hint,
        'installation': installation,
        if (userId != null) 'user': userId,
        'expires': expiresAt.toUtc().toIso8601String(),
      });

  /// Null for anything that is not a draft of THIS version — including a
  /// purpose this build does not know, and a location that no longer
  /// validates: the registry may have changed since it was written.
  static EntryIntentDraft? decode(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    final json = decoded;
    if (json is! Map<String, dynamic>) return null;
    if (json['v'] != kEntryIntentDraftVersion) return null;
    final id = json['id'];
    final purpose = EntryPurpose.values
        .where((p) => p.name == json['purpose'])
        .firstOrNull;
    final installation = json['installation'];
    final expires = DateTime.tryParse(json['expires'] as String? ?? '');
    if (id is! String || purpose == null || installation is! String ||
        expires == null) {
      return null;
    }
    final target = json['target'] as String?;
    final hint = json['hint'] as String?;
    final intent = switch (purpose) {
      EntryPurpose.defaultEntry => EntryIntent.defaultEntry(id),
      EntryPurpose.open => switch (
          EntryIntent.validatedLocation(target ?? '')) {
          final String location => EntryIntent.openValidated(id, location),
          null => null,
        },
      EntryPurpose.join => EntryIntent.join(id, workspaceHint: hint),
      EntryPurpose.create => EntryIntent.create(id),
      EntryPurpose.connectInstallation => target == null
          ? null
          : EntryIntent.connectInstallation(id, host: target),
      EntryPurpose.account => switch (AccountSection.values
          .where((s) => s.name == target)
          .firstOrNull) {
          final AccountSection section => EntryIntent.account(id, section),
          null => null,
        },
      EntryPurpose.consentReference => target == null
          ? null
          : EntryIntent.consentReference(id, reference: target),
      EntryPurpose.actionConfirmation => target == null
          ? null
          : EntryIntent.actionConfirmation(id, reference: target),
    };
    if (intent == null) return null;
    return EntryIntentDraft(
      intent: intent,
      installation: installation,
      userId: json['user'] as String?,
      expiresAt: expires,
    );
  }
}

/// The current continuation, or null. Kept alive: the router reads it on
/// every redirect and the value must not vanish between two.
@Riverpod(keepAlive: true)
class EntryIntents extends _$EntryIntents {
  /// The account the current intent was captured under; null when it was
  /// captured signed out, in which case whoever signs in may finish it —
  /// it is a place to go, not an authority.
  String? _owner;
  int _sequence = 0;

  @override
  EntryIntent? build() {
    ref.listen(authStateProvider, (previous, next) {
      final was = previous?.value;
      final now = next.value;
      // Sign-out forgets. A different account than the one that asked
      // forgets too: the second person did not come for the first's
      // errand.
      if ((was != null && now == null) ||
          (now != null && _owner != null && now != _owner)) {
        unawaited(forget());
      }
    });
    unawaited(_restore());
    return null;
  }

  Future<String> _installation() async =>
      (await ref.read(backendSettingsStoreProvider).read())?.url ??
      kDefaultInstallation;

  Future<void> _restore() async {
    final raw = await ref.read(entryIntentStoreProvider).read();
    if (raw == null) return;
    final draft = EntryIntentDraft.decode(raw);
    final now = ref.read(clockProvider).now();
    final installation = await _installation();
    final user = ref.read(authStateProvider).value;
    final valid = draft != null &&
        !draft.expiresAt.isBefore(now) &&
        draft.installation == installation &&
        (draft.userId == null || user == null || draft.userId == user);
    if (!valid) {
      TraceLogger.instance
          .log(TraceLevel.info, 'navigation', 'entry-intent draft dropped');
      await ref.read(entryIntentStoreProvider).write(null);
      return;
    }
    _owner = draft.userId;
    state = draft.intent;
  }

  /// A fresh continuation id. Two captures in the same instant still
  /// differ; two app runs differ by the clock.
  String nextId() =>
      '${ref.read(clockProvider).now().toUtc().millisecondsSinceEpoch}'
      '-${++_sequence}';

  /// Replaces the current continuation with [intent] and writes the
  /// draft. The newest ask wins; a late answer for an older one is told
  /// apart by its id in [consume].
  Future<void> capture(EntryIntent intent) async {
    final user = ref.read(authStateProvider).value;
    _owner = user;
    state = intent;
    final draft = EntryIntentDraft(
      intent: intent,
      installation: await _installation(),
      userId: user,
      expiresAt: ref.read(clockProvider).now().add(kEntryIntentLifetime),
    );
    await ref.read(entryIntentStoreProvider).write(draft.encode());
  }

  /// Done with [id] — and only [id]: a continuation captured since is
  /// somebody's current errand, not this one's leftover.
  Future<void> consume(String id) async {
    if (state?.id != id) return;
    await forget();
  }

  Future<void> forget() async {
    _owner = null;
    state = null;
    await ref.read(entryIntentStoreProvider).write(null);
  }
}
