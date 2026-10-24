// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/personal_home_probe.dart';
import 'instance_network.dart';

/// #2561 L3 -- how the wizard reads a personal home before recording it;
/// tests put a fake in its place.
final personalHomeProbeProvider = Provider<PersonalHomeProbe>(
  (ref) => probePersonalHome,
);
