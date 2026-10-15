// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — which features the active workspace has switched on, as core
// areas (help, privacy) need to know it: by their keys, not by the
// workspace feature's enum. The workspace feature supplies the set and the
// composition root puts it in its scope's overrides; until then the set is
// unknown (null) and every question is answered with the feature's
// registry default, which the caller states.
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The keys (`WorkspaceFeature.dbKey`) of the enabled features; null until
/// wired by the composition root.
final enabledFeatureKeysProvider = Provider<Set<String>?>((ref) => null);

/// Whether [key] is on: the wired set's answer, or [byDefault] while the
/// set is unknown.
bool featureOn(Set<String>? keys, String key, {required bool byDefault}) =>
    keys?.contains(key) ?? byDefault;

/// The keys core asks about by name. A test pins each to its feature.
const String formHelpHintsKey = 'formHelpHints';
const String recordingPrivacyKey = 'recordingPrivacy';
