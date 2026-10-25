// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2552 XPRIV-01 — whether private values (an amount on a compact card, a
// message preview) stay masked until the person reveals one.
//
// The choice is kept twice: on this device, so it holds before sign-in and
// while the personal home cannot answer, and on the personal account (the
// `private_values` personal default), which is canonical once it answers.
// No choice yet means masked; an explicit choice is never overwritten by
// that default. This hides nothing on the server: it is how this screen
// reads in a place where others can see it.
//
// Core cannot read the personal account or the installation's flags, so
// [privateValuesPolicyProvider] is overridden where both are known
// (lib/app/private_values_wiring.dart). Without that wiring — a test, a
// recovery screen — every private value stays masked.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/prefs_stores.dart';

part 'private_values.g.dart';

/// The two values a choice can take, on the device and on the account.
abstract final class PrivateValuesChoice {
  static const masked = 'masked';
  static const shown = 'shown';
  static const all = {masked, shown};
}

/// What stands in place of a masked value.
const String privateValueMask = '••••';

/// The device's copy of the choice. Same seam shape as the theme store, so
/// widget tests keep an in-memory fake.
abstract class PrivateValuesStore {
  Future<String?> read();
  Future<void> write(String? value);
}

class _PrefsPrivateValuesStore extends PrefsStringStore
    implements PrivateValuesStore {
  const _PrefsPrivateValuesStore() : super('private_values');
}

@Riverpod(keepAlive: true)
PrivateValuesStore privateValuesStore(Ref ref) =>
    const _PrefsPrivateValuesStore();

/// The choice stored on this device; null when none was made here.
@Riverpod(keepAlive: true)
class PrivateValuesDevice extends _$PrivateValuesDevice {
  @override
  Future<String?> build() async {
    final stored = await ref.watch(privateValuesStoreProvider).read();
    return PrivateValuesChoice.all.contains(stored) ? stored : null;
  }

  Future<void> set(String value) async {
    if (!PrivateValuesChoice.all.contains(value)) {
      throw ArgumentError.value(value, 'value');
    }
    await ref.read(privateValuesStoreProvider).write(value);
    state = AsyncData(value);
  }
}

/// What the app knows beyond core: whether the preference is offered at
/// all (the `personalShell` platform flag), and the account's choice.
class PrivateValuesPolicy {
  const PrivateValuesPolicy({this.enabled = false, this.account});

  /// Off: masked, always, with a reveal per value (the #2557 C5 cards).
  final bool enabled;

  /// The personal account's choice; null when it never made one.
  final String? account;
}

@riverpod
PrivateValuesPolicy privateValuesPolicy(Ref ref) => const PrivateValuesPolicy();

/// True while a private value starts masked.
@riverpod
bool privateValuesMasked(Ref ref) {
  final policy = ref.watch(privateValuesPolicyProvider);
  if (!policy.enabled) return true;
  final account = PrivateValuesChoice.all.contains(policy.account)
      ? policy.account
      : null;
  final chosen = account ?? ref.watch(privateValuesDeviceProvider).value;
  return chosen != PrivateValuesChoice.shown;
}
