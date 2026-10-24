// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2558 C2 — the account and personal home a privacy write is sent for. A
// reply that arrives after either changed belongs to an older epoch: it is
// ignored, never applied to the account now shown.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_settings.dart';
import '../../auth/providers/auth_providers.dart';

final visibilityEpochProvider = Provider<String>((ref) {
  final user = ref.watch(authStateProvider).value ?? '';
  final home = ref.watch(activeBackendProvider).value?.host ?? '';
  return '$user@$home';
});
