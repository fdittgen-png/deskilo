// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4407 -- the shape of the selected business, from the one place that names its three sources (`BusinessShape`).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/business_shape.dart';
import 'business_kind_providers.dart';
import 'workspace_providers.dart';

/// What the selected business is. Watched, never awaited (the settings are a long chain): until the kinds and the profile
/// are read it is the shape of its features alone, so nothing is hidden on a guess.
final businessShapeProvider = Provider<BusinessShape>(
  (ref) => BusinessShape.of(
    features: ref.watch(enabledFeaturesSyncProvider),
    kindKeepsPlacesOff: ref.watch(keepsPlacesOffProvider),
    kinds: ref.watch(businessProfileProvider).value?.kinds ?? const [],
  ),
);
