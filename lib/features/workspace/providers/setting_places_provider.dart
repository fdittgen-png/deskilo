// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4495 -- the places of [workspaceId] a setting may name (in use, holding stock), each with its full path. The composition root (lib/app)
// wires the stock's places behind it (the workspace feature never imports the stock); with nothing wired none is offered.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/setting_place.dart';

final settingPlacesProvider = FutureProvider.autoDispose.family<List<SettingPlace>, String>((ref, workspaceId) async => const <SettingPlace>[]);
