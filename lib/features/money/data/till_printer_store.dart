// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4368 (CS6) -- where a device keeps its till printer. The same seam as the other device preferences: a store a test
// replaces, so no widget test touches a platform channel.
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/till_printer_settings.dart';

abstract interface class TillPrinterStore {
  Future<TillPrinterSettings> read();
  Future<void> write(TillPrinterSettings settings);
}

class PrefsTillPrinterStore implements TillPrinterStore {
  const PrefsTillPrinterStore();

  static const _key = 'till_printer';

  @override
  Future<TillPrinterSettings> read() async => TillPrinterSettings.fromJson((await SharedPreferences.getInstance()).getString(_key));

  @override
  Future<void> write(TillPrinterSettings settings) async {
    await (await SharedPreferences.getInstance()).setString(_key, settings.toJson());
  }
}
