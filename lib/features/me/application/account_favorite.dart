// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2554 — the heart of My spaces is kept on the account, by the space's
// qualified reference (`set_workspace_favorite_ref_v1`). This device's
// own copy (SpacePrefs) shows the choice at once and stays as the
// fallback: when the personal home refuses the reference or cannot be
// reached, the choice is kept here only and the person is told so. Once
// the home kept it and the list was read again, the device copy is
// dropped, so the account is what the heart shows on every device.
import '../../../core/trace/trace_logger.dart';
import '../domain/account_favorite.dart';
import '../domain/me_repository.dart';

/// Where a favourite ended up.
enum FavoriteKept {
  /// On the account: every device of mine shows it.
  account,

  /// On this device only: the personal home refused the reference.
  deviceRefused,

  /// On this device only: the personal home could not be reached.
  deviceUnreachable,
}

/// Sets or clears the heart of one card of My spaces.
class AccountFavoriteCommand {
  const AccountFavoriteCommand({
    required this.repository,
    required this.keepOnDevice,
    required this.reloadAccount,
  });

  final MeRepository repository;

  /// This device's copy, under the card's own key.
  final Future<void> Function(String key, {required bool on}) keepOnDevice;

  /// Reads my references again, so the heart shows what the home kept.
  final Future<void> Function() reloadAccount;

  /// Marks [mark] (the reference the card leads with) when [on]; clears
  /// every reference of [clear] (the card's sides the account holds)
  /// otherwise. [deviceKey] is the card's key on this device.
  Future<FavoriteKept> set({
    required bool on,
    required String deviceKey,
    required String mark,
    List<String> clear = const [],
  }) async {
    await keepOnDevice(deviceKey, on: on);
    final refs = on ? [mark] : clear;
    if (refs.isEmpty) return FavoriteKept.account;
    try {
      for (final ref in refs) {
        await repository.setAccountFavorite(ref, on: on);
      }
    } on AccountFavoriteRefused catch (e, st) {
      TraceLogger.instance.warn('me', 'favourite kept on this device',
          error: e, stackTrace: st);
      return FavoriteKept.deviceRefused;
    } on Object catch (e, st) {
      TraceLogger.instance.warn('me', 'favourite kept on this device',
          error: e, stackTrace: st);
      return FavoriteKept.deviceUnreachable;
    }
    try {
      await reloadAccount();
    } on Object catch (e, st) {
      // The home kept it; the device copy shows it until the list reads.
      TraceLogger.instance.warn('me', 'references not read again',
          error: e, stackTrace: st);
      return FavoriteKept.account;
    }
    await keepOnDevice(deviceKey, on: false);
    return FavoriteKept.account;
  }
}
