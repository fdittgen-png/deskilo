// SPDX-License-Identifier: 0BSD
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/money/domain/invoice.dart';
import '../../features/profile/domain/personal_info.dart';
import '../../features/profile/domain/profile.dart';
import '../storage/prefs_stores.dart';

part 'demo_mode.g.dart';

/// Demo mode (#970): while it is on, everything on screen that
/// identifies a person — names, e-mail addresses, phone numbers, postal
/// addresses, registrations — is BLURRED in place, like a redacted
/// screenshot: the real pixels, softened until unreadable, the layout
/// untouched, nothing hidden and nothing invented. A recording of the
/// app then carries no personal data and still looks like the app.
///
/// How: the providers that hand names, profiles, identities and
/// invoices to the screens register the personal strings they carry
/// in [demoSensitive]; [DemoBlurLayer] (demo_blur.dart), mounted above
/// the navigator, finds every rendered paragraph or text field whose
/// text carries one of them and blurs exactly those rectangles. The
/// plan's painted occupant labels blur through their painter. Per
/// device, like the theme.
abstract class DemoModeStore {
  Future<String?> read();
  Future<void> write(String? value);
}

class PrefsDemoModeStore extends PrefsStringStore implements DemoModeStore {
  const PrefsDemoModeStore() : super('demo_mode');
}

@Riverpod(keepAlive: true)
DemoModeStore demoModeStore(Ref ref) => const PrefsDemoModeStore();

@Riverpod(keepAlive: true)
class DemoModeController extends _$DemoModeController {
  static const _on = 'on';

  @override
  Future<bool> build() async =>
      await ref.watch(demoModeStoreProvider).read() == _on;

  Future<void> set(bool on) async {
    state = AsyncData(on);
    await ref.read(demoModeStoreProvider).write(on ? _on : null);
  }
}

/// The strings that identify a person, as the data layer saw them.
/// A paragraph is blurred when its text carries one of them: whole
/// short strings as words, longer ones anywhere.
class DemoSensitiveRegistry extends ChangeNotifier {
  final Set<String> _values = {};

  Set<String> get values => Set.unmodifiable(_values);

  static const int _minLength = 3;

  /// Registers [strings]; blanks and very short ones are ignored.
  void addAll(Iterable<String> strings) {
    var changed = false;
    for (final s in strings) {
      final v = s.trim();
      if (v.length < _minLength) continue;
      if (_values.add(v)) changed = true;
    }
    if (changed) notifyListeners();
  }

  void clear() {
    if (_values.isEmpty) return;
    _values.clear();
    notifyListeners();
  }

  /// Whether [text] carries a registered string.
  bool matches(String text) {
    if (text.trim().isEmpty || _values.isEmpty) return false;
    final lower = text.toLowerCase();
    for (final v in _values) {
      final needle = v.toLowerCase();
      if (needle.length >= 6) {
        if (lower.contains(needle)) return true;
      } else if (RegExp('(^|[^\\p{L}\\p{N}])${RegExp.escape(needle)}([^\\p{L}\\p{N}]|\$)',
              unicode: true)
          .hasMatch(lower)) {
        return true;
      }
    }
    return false;
  }
}

/// One registry for the process: every provider adds to it, the layer
/// reads it. Tests clear it.
final DemoSensitiveRegistry demoSensitive = DemoSensitiveRegistry();

/// The personal strings of one identity, every way a screen prints them.
Iterable<String> sensitiveOfPersonalInfo(PersonalInfo info) sync* {
  if (info.isEmpty) return;
  yield info.firstName;
  yield info.lastName;
  yield '${info.firstName} ${info.lastName}';
  yield info.fullName;
  yield info.personName;
  yield info.company;
  yield info.street;
  yield '${info.postalCode} ${info.city}';
  yield '${info.postalCode} ${info.city.toUpperCase()}';
  yield info.phone;
  yield info.email;
  yield info.vatId;
  yield info.legalId;
  yield* info.postalBlock().split('\n');
}

Iterable<String> sensitiveOfProfile(Profile profile) sync* {
  yield profile.displayName;
  yield profile.whatsapp;
  yield* profile.address.split('\n');
  yield profile.vatId;
  yield* sensitiveOfPersonalInfo(profile.identity);
}

Iterable<String> sensitiveOfInvoice(Invoice invoice) sync* {
  yield invoice.memberName;
  yield invoice.clientName;
  yield* invoice.memberAddress.split('\n');
  yield invoice.issuerName;
  yield invoice.voidedByName;
  final buyer = invoice.buyerParty;
  if (buyer != null) {
    yield buyer.name;
    yield buyer.person;
    yield buyer.company;
    yield buyer.street;
    yield '${buyer.postalCode} ${buyer.city}';
    yield '${buyer.postalCode} ${buyer.city.toUpperCase()}';
    yield buyer.email;
    yield buyer.phone;
    yield buyer.vatId;
    yield buyer.legalId;
  }
}

/// Registers the personal strings of [names] (a member id → name map).
void registerSensitiveNames(Map<String, String> names) =>
    demoSensitive.addAll(names.values);
