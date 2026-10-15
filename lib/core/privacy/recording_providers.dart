// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1514 — is the app currently showing invented people?
//
// One provider, read by the six data providers that carry people, by the
// indicator that says so on every screen, and by the identity forms that
// refuse to save while it is on. A workspace-level switch and not a
// per-device one, deliberately: whether this space's data may be filmed
// is the space's decision, not the decision of whoever happens to hold
// the phone.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/enabled_feature_keys.dart';

part 'recording_providers.g.dart';

/// True while the workspace is showing invented people in place of its
/// own (#1514).
@Riverpod(keepAlive: true)
bool recordingPrivacy(Ref ref) => featureOn(
  ref.watch(enabledFeatureKeysProvider),
  recordingPrivacyKey,
  byDefault: false,
);
