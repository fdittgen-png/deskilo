// SPDX-License-Identifier: 0BSD
import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../storage/prefs_stores.dart';
import '../../features/profile/providers/profile_providers.dart';
import '../trace/trace_logger.dart';

part 'locale_controller.g.dart';

/// Persists the in-app language override (#147). Same seam shape as
/// `DevModeStore` so widget tests never touch platform channels.
abstract class LocaleStore {
  /// The stored language code ('de', 'en', …) or null for "system default".
  Future<String?> read();

  /// Persists [languageCode]; null removes the override.
  Future<void> write(String? languageCode);
}

class PrefsLocaleStore extends PrefsStringStore implements LocaleStore {
  const PrefsLocaleStore() : super('locale_override');
}

@Riverpod(keepAlive: true)
LocaleStore localeStore(Ref ref) => const PrefsLocaleStore();

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

  Future<void> set(Locale? locale) async {
    state = AsyncData(locale);
    await ref.read(localeStoreProvider).write(locale?.languageCode);
    // #496 — the pick also becomes the member's DOCUMENT language,
    // server-side, so reports for them print in it. Best effort:
    // offline or signed out must not break the local switch.
    try {
      await ref
          .read(profileRepositoryProvider)
          .setPreferredLocale(locale?.languageCode ?? '');
      ref.invalidate(myProfileProvider);
    } catch (e, st) {
      TraceLogger.instance.warn(
          'profile', 'preferred locale save failed',
          error: e, stackTrace: st);
    }
  }
}
