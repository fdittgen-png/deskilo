// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1636 — creating a workspace is an intent, frozen when it is sent.
//
// The wizard used to create a development/production PAIR unless the
// owner unticked it, re-derived an edited currency when the country
// changed, and after ANY failure offered "Create without a template" —
// which, after a response that was merely lost, sent a second request
// for a second pair. Here:
//
//   * the shape is chosen, and one TEST workspace is the default;
//   * what was sent is kept, with its request id, on the device, so a
//     lost reply or a restart retries the SAME creation;
//   * after an uncertain failure the payload may not change until the
//     retry has found out what happened;
//   * only a refusal the server actually gave about the template offers
//     the template remedy.
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/prefs_stores.dart';
import '../../../core/time/clock.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/workspace.dart';

part 'creation_intent.g.dart';

/// What a creation makes: how many workspaces, and whether one is real.
enum CreationShape {
  /// One development workspace. Watermarked, no real billing. Default.
  test,

  /// One production workspace. Its invoices are owed.
  real,

  /// A development and a production workspace with the same name.
  pair;

  WorkspaceEnvironment get environment => this == CreationShape.real
      ? WorkspaceEnvironment.production
      : WorkspaceEnvironment.development;

  bool get withTwin => this == CreationShape.pair;

  /// How many workspaces the server makes for this shape.
  int get workspaceCount => this == CreationShape.pair ? 2 : 1;

  /// Whether any workspace this creates can issue real invoices.
  bool get realBilling => this != CreationShape.test;
}

/// The payload a creation sends, and the id it is known by.
class CreationIntent {
  const CreationIntent({
    required this.requestId,
    required this.name,
    required this.countryCode,
    required this.currencyCode,
    required this.timezone,
    required this.shape,
    required this.templateId,
  });

  final String requestId;
  final String name;
  final String countryCode;
  final String currencyCode;
  final String timezone;
  final CreationShape shape;
  final String? templateId;

  /// Same material payload — the fields the server would create from.
  /// The request id is not material: it is what the payload is known by.
  bool sameMaterial(CreationIntent other) =>
      name.trim() == other.name.trim() &&
      countryCode == other.countryCode &&
      currencyCode.trim().toUpperCase() ==
          other.currencyCode.trim().toUpperCase() &&
      timezone.trim() == other.timezone.trim() &&
      shape == other.shape &&
      templateId == other.templateId;

  Map<String, Object?> toJson() => {
        'requestId': requestId,
        'name': name,
        'countryCode': countryCode,
        'currencyCode': currencyCode,
        'timezone': timezone,
        'shape': shape.name,
        'templateId': templateId,
      };

  static CreationIntent? fromJson(Object? json) {
    if (json is! Map) return null;
    final shape = CreationShape.values
        .where((s) => s.name == json['shape'])
        .firstOrNull;
    final requestId = json['requestId'];
    final name = json['name'];
    final country = json['countryCode'];
    final currency = json['currencyCode'];
    final timezone = json['timezone'];
    final template = json['templateId'];
    if (shape == null ||
        requestId is! String ||
        name is! String ||
        country is! String ||
        currency is! String ||
        timezone is! String ||
        (template != null && template is! String)) {
      return null;
    }
    return CreationIntent(
      requestId: requestId,
      name: name,
      countryCode: country,
      currencyCode: currency,
      timezone: timezone,
      shape: shape,
      templateId: template as String?,
    );
  }
}

/// A sent creation whose outcome the device does not know yet, and the
/// account that sent it. Nothing secret: no password, no token, no key.
class CreationDraft {
  const CreationDraft({
    required this.userId,
    required this.savedAt,
    required this.intent,
  });

  final String userId;
  final DateTime savedAt;
  final CreationIntent intent;

  /// Older than this, the draft is dropped rather than resumed: a server
  /// that did create the workspace shows it in the list by then.
  static const Duration lifetime = Duration(days: 7);

  static const int _version = 1;

  String encode() => jsonEncode({
        'v': _version,
        'userId': userId,
        'savedAt': savedAt.toUtc().toIso8601String(),
        'intent': intent.toJson(),
      });

  /// The draft in [raw] if it is [userId]'s and still fresh at [now].
  /// Another account's draft, an expired one or a malformed one is null:
  /// never resumed, never shown.
  static CreationDraft? decodeFor(String? raw,
      {required String? userId, required DateTime now}) {
    if (raw == null || userId == null) return null;
    Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (json is! Map || json['v'] != _version || json['userId'] != userId) {
      return null;
    }
    final savedAt = DateTime.tryParse('${json['savedAt']}');
    final intent = CreationIntent.fromJson(json['intent']);
    if (savedAt == null || intent == null) return null;
    if (now.toUtc().difference(savedAt.toUtc()) > lifetime) return null;
    return CreationDraft(userId: userId, savedAt: savedAt, intent: intent);
  }
}

/// Whether [error] is the server refusing the TEMPLATE — the only failure
/// after which creating without it is a safe remedy. `create_workspace_
/// once` applies the template in the creation's transaction, so these
/// refusals roll the whole creation back: nothing was made.
bool isTemplateRefusal(Object error) {
  final message = '$error'.toLowerCase();
  return message.contains('unknown template') ||
      message.contains('not supported:') ||
      message.contains('applies a template');
}

/// The device's copy of the one pending creation.
abstract class CreationDraftStore {
  Future<String?> read();
  Future<void> write(String? draft);
}

class PrefsCreationDraftStore extends PrefsStringStore
    implements CreationDraftStore {
  const PrefsCreationDraftStore() : super('workspace_creation_draft');
}

class InMemoryCreationDraftStore implements CreationDraftStore {
  InMemoryCreationDraftStore([this.value]);
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? draft) async => value = draft;
}

@Riverpod(keepAlive: true)
CreationDraftStore creationDraftStore(Ref ref) =>
    const PrefsCreationDraftStore();

/// #1636 — the pending creation, for the account signed in now. The
/// wizard asks this; it never reads the store or the account itself.
class CreationDrafts {
  const CreationDrafts(this._store, this._userId, this._clock);

  final CreationDraftStore _store;
  final String? Function() _userId;
  final Clock _clock;

  /// The draft this account left, while fresh; null otherwise.
  Future<CreationDraft?> pending() async => CreationDraft.decodeFor(
        await _store.read(),
        userId: _userId(),
        now: _clock.now(),
      );

  /// Records [intent] as sent. Without an account there is nobody to
  /// resume it for, so nothing is kept.
  Future<void> sent(CreationIntent intent) async {
    final userId = _userId();
    if (userId == null) return;
    await _store.write(CreationDraft(
      userId: userId,
      savedAt: _clock.now(),
      intent: intent,
    ).encode());
  }

  /// The creation was confirmed: nothing is pending any more.
  Future<void> confirmed() => _store.write(null);
}

@riverpod
CreationDrafts creationDrafts(Ref ref) {
  final auth = ref.watch(authRepositoryProvider);
  return CreationDrafts(
    ref.watch(creationDraftStoreProvider),
    () => auth.currentUserId,
    ref.watch(clockProvider),
  );
}
