// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1289 — the two ways a chosen file may not become an emblem.
//
// Pure Dart, apart from the re-encode that produces them: the decision
// layer must be able to name a refusal without importing the engine.
enum EmblemRefusal {
  /// The bytes are not an image this platform can decode.
  notAnImage,

  /// Re-encoded and still too heavy — a photograph where a mark belongs.
  tooHeavy,
}

class EmblemException implements Exception {
  const EmblemException(this.refusal);
  final EmblemRefusal refusal;

  @override
  String toString() => 'EmblemException(${refusal.name})';
}
