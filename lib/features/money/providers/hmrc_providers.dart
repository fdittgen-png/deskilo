// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 — the HMRC submission's providers: the port, the space's state, and
// the browser's own values for the fraud-prevention headers.
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../../core/browser/browser_facts.dart';
import '../../../core/links/link_launcher.dart';
import '../../../core/storage/prefs_stores.dart';
import '../../../core/time/clock.dart';
import '../application/connect_hmrc.dart';
import '../application/submit_to_hmrc.dart';
import '../data/supabase_hmrc_repository.dart';
import '../domain/hmrc_submission.dart';
import 'credit_providers.dart';

/// The HMRC port. A test (and the Demo scope) swaps it.
@visibleForTesting
final hmrcRepositoryProvider = Provider<HmrcRepository>(
  (ref) => SupabaseHmrcRepository(ref.watch(moneyClientProvider)),
);

final connectHmrcProvider = Provider<ConnectHmrc>(
  (ref) => ConnectHmrc(
    ref.watch(hmrcRepositoryProvider),
    ref.watch(linkLauncherProvider),
  ),
);

final submitToHmrcProvider = Provider<SubmitToHmrc>(
  (ref) => SubmitToHmrc(ref.watch(hmrcRepositoryProvider)),
);

/// The UK VAT number and live HMRC connection of [workspaceId].
final hmrcStateProvider = FutureProvider.autoDispose.family<HmrcState, String>(
  (ref, workspaceId) => ref.watch(hmrcRepositoryProvider).state(workspaceId),
);

/// The device id HMRC asks for: a random UUID this browser keeps.
abstract interface class _DeviceIdStore {
  Future<String> read();
}

class _PrefsDeviceIdStore implements _DeviceIdStore {
  const _PrefsDeviceIdStore();

  static const _store = PrefsStringStore('hmrc_device_id');

  @override
  Future<String> read() async {
    final held = await _store.read();
    if (held != null && held.length >= 8) return held;
    final fresh = _uuidV4(Random.secure());
    await _store.write(fresh);
    return fresh;
  }
}

String _uuidV4(Random random) {
  final b = List<int>.generate(16, (_) => random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String hex(int from, int to) => [
    for (final i in List.generate(to - from, (i) => from + i))
      b[i].toRadixString(16).padLeft(2, '0'),
  ].join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

final _deviceIdStoreProvider = Provider<_DeviceIdStore>(
  (ref) => const _PrefsDeviceIdStore(),
);

/// The page's facts, or null when this build is not a web page: the
/// submission is offered on the web build only (connection method
/// WEB_APP_VIA_SERVER); other builds say to use the web app.
final _browserFactsProvider = Provider<BrowserFacts?>((ref) => readBrowserFacts());

/// HMRC's client values from the browser, or null off the web.
final hmrcClientValuesProvider = FutureProvider.autoDispose<HmrcClientValues?>((
  ref,
) async {
  final facts = ref.watch(_browserFactsProvider);
  if (facts == null) return null;
  final offset = ref.watch(clockProvider).now().timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  final zone =
      'UTC$sign${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  return HmrcClientValues(
    browserJsUserAgent: facts.userAgent,
    deviceId: await ref.watch(_deviceIdStoreProvider).read(),
    timezone: zone,
    screens:
        'width=${facts.screenWidth}&height=${facts.screenHeight}&scaling-factor=${facts.scalingFactor}&colour-depth=${facts.colourDepth}',
    windowSize: 'width=${facts.windowWidth}&height=${facts.windowHeight}',
    doNotTrack: facts.doNotTrack,
  );
});
