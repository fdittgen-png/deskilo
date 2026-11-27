// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4452 (E01A) -- the profile the terminal renders: the till's quick keys projected into bounded pages for the 480x320 screen.
// A till without a saved layout is projected from its generated default (the keys under their categories, the #4366 behaviour);
// the published layout of #4448 joins it as E01B and must produce the same shape. The projection is deterministic, carries no
// script and no widget of its own, and says in words (a reason code) what the terminal cannot do instead of turning it into an
// ordinary item sale. Its digest is the SHA-256 of its canonical form without the digest itself.
import 'dart:convert';

import 'package:deskilo/features/money/domain/counter_till.dart';

import 'embedded_till_canonical.dart';
import 'embedded_till_contract.dart';

/// Why a key is shown but cannot be rung up on the terminal.
enum TerminalKeyReason {
  /// The item asks the cashier to confirm the customer's age: the terminal has no such flow.
  ageConfirmation('age_confirmation'),

  /// The item adds a deposit item to the sale: the terminal has no deposit flow.
  deposit('deposit');

  const TerminalKeyReason(this.wire);

  final String wire;
}

/// One key of a profile page. [fixedQuantity] is the exact quantity a tap rings up; null asks the quantity on the keypad.
class ProfileKey {
  const ProfileKey({required this.itemId, required this.label, required this.unit, this.colour, this.fixedQuantity, this.reason, this.shortened = false});

  final String itemId;
  final String label;
  final String unit;
  final String? colour;
  final String? fixedQuantity;
  final TerminalKeyReason? reason;

  /// The label was cut to the terminal's width at a character boundary.
  final bool shortened;

  bool get available => reason == null;

  Map<String, Object?> toJson() => {
    'kind': 'item',
    'item_id': itemId,
    'label': label,
    'unit': unit,
    'state': available ? 'available' : 'unavailable',
    'colour': ?colour,
    'fixed_quantity': ?fixedQuantity,
    'reason': ?reason?.wire,
    if (shortened) 'shortened': true,
  };
}

/// One page of keys; [title] is the category's name, null for the keys that have none.
class ProfilePage {
  const ProfilePage({required this.id, required this.keys, this.title});

  final String id;
  final String? title;
  final List<ProfileKey> keys;

  Map<String, Object?> toJson() => {'id': id, 'title': ?title, 'keys': [for (final k in keys) k.toJson()]};
}

/// The profile of one till for the terminal.
class EmbeddedTillProfile {
  const EmbeddedTillProfile({required this.currency, required this.exponent, required this.layoutVersion, required this.pages});

  final String currency;
  final int exponent;

  /// The version of the layout this was projected from; the generated default is `default-1`.
  final String layoutVersion;
  final List<ProfilePage> pages;

  /// The document without its digest: what the digest is of.
  Map<String, Object?> body() => {
    'protocol': {'major': terminalProtocolMajor, 'minor': terminalProtocolMinor},
    'currency': {'code': currency, 'exponent': exponent},
    'layout': {'source': 'generated_default', 'version': layoutVersion},
    'capabilities_required': [for (final c in _required()) c.wire],
    'pages': [for (final p in pages) p.toJson()],
  };

  /// The lower-case hex SHA-256 of the canonical form of [body]: the immutable version of this profile.
  String get digest => sha256Hex(canonicalBytes(body()));

  /// The document as the terminal receives it.
  Map<String, Object?> toJson() => {...body(), 'profile_version': digest};

  /// The capabilities a terminal needs to render this profile: the connected checkout, and the keypad only if a key asks it.
  List<TerminalCapability> _required() => [
    TerminalCapability.basket,
    TerminalCapability.cash,
    TerminalCapability.categoryPages,
    TerminalCapability.nextCustomer,
    TerminalCapability.quantityKeypad,
  ]..sort((a, b) => a.wire.compareTo(b.wire));
}

/// A projection and what did not fit: [omitted] keys beyond the ceilings are named here, never dropped silently.
class ProfileProjection {
  const ProfileProjection({required this.profile, required this.omitted});

  final EmbeddedTillProfile profile;

  /// How many keys the ceilings (keys per page, pages) left out; above zero the owner is told to reduce the profile.
  final int omitted;

  bool get complete => omitted == 0;
}

final RegExp _colourShape = RegExp(r'^#[0-9a-fA-F]{6}$');

/// The generated default of [keys]: the keys of each category (the categories in the order of their names, then the keys with
/// none), in the order given, [TerminalBounds.keysPerPage] to a page, at most [TerminalBounds.profilePages] pages.
ProfileProjection projectDefaultProfile(List<TillKey> keys, {required String currency, required int exponent}) {
  final groups = <String?, List<TillKey>>{};
  for (final k in keys) {
    final c = k.category?.trim();
    groups.putIfAbsent(c == null || c.isEmpty ? null : c, () => []).add(k);
  }
  final names = [for (final n in groups.keys) ?n]..sort();
  final pages = <ProfilePage>[];
  var omitted = 0;
  for (final name in [null, ...names]) {
    final group = groups[name];
    if (group == null) continue;
    for (var at = 0; at < group.length; at += TerminalBounds.keysPerPage) {
      final chunk = group.skip(at).take(TerminalBounds.keysPerPage).toList();
      if (pages.length >= TerminalBounds.profilePages) {
        omitted += chunk.length;
      } else {
        pages.add(ProfilePage(id: 'p${pages.length + 1}', title: name, keys: [for (final k in chunk) _keyOf(k)]));
      }
    }
  }
  return ProfileProjection(
    profile: EmbeddedTillProfile(currency: currency, exponent: exponent, layoutVersion: 'default-1', pages: pages),
    omitted: omitted,
  );
}

ProfileKey _keyOf(TillKey k) {
  final label = _fit(k.name.trim(), TerminalBounds.labelBytes);
  return ProfileKey(
    itemId: k.id,
    label: label,
    unit: k.unit,
    colour: k.colour != null && _colourShape.hasMatch(k.colour!) ? k.colour!.toLowerCase() : null,
    fixedQuantity: k.weighed ? null : '1',
    reason: k.minAge != null ? TerminalKeyReason.ageConfirmation : (k.depositItemId != null ? TerminalKeyReason.deposit : null),
    shortened: label != k.name.trim(),
  );
}

/// [text] cut to at most [bytes] UTF-8 bytes at a character boundary.
String _fit(String text, int bytes) {
  if (utf8.encode(text).length <= bytes) return text;
  final out = StringBuffer();
  var used = 0;
  for (final r in text.runes) {
    final n = utf8.encode(String.fromCharCode(r)).length;
    if (used + n > bytes) break;
    out.writeCharCode(r);
    used += n;
  }
  return out.toString();
}
