// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/prefs_stores.dart';

part 'locale_controller.g.dart';

/// Persists the in-app language override (#147). Same seam shape as
/// `DevModeStore` so widget tests never touch platform channels.
abstract class LocaleStore {
  /// The stored language code ('de', 'en', …) or null for "system default".
  Future<String?> read();

  /// Persists [languageCode]; null removes the override.
  Future<void> write(String? languageCode);
}

class _PrefsLocaleStore extends PrefsStringStore implements LocaleStore {
  const _PrefsLocaleStore() : super('locale_override');
}

@Riverpod(keepAlive: true)
LocaleStore localeStore(Ref ref) => const _PrefsLocaleStore();

/// The user's language override; null means "follow the system locale".
/// Feeding this into `MaterialApp.locale` applies a change instantly,
/// no restart needed.
@Riverpod(keepAlive: true)
class LocaleController extends _$LocaleController {
  @override
  Future<Locale?> build() async {
    final code = await ref.watch(localeStoreProvider).read();
    return code == null ? null : Locale(code);
  }

  /// Applies [locale] and keeps it on this device. The account's own copy
  /// of the language is saved by the profile feature (preference scopes);
  /// this controller knows nothing of it.
  Future<void> set(Locale? locale) async {
    state = AsyncData(locale);
    await ref.read(localeStoreProvider).write(locale?.languageCode);
  }
}
