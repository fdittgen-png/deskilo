// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'capture_protection.dart';

part 'capture_providers.g.dart';

/// #1824 — the ONE capture protection of this app window; every open
/// thread holds it through [CaptureProtection.enable].
@Riverpod(keepAlive: true)
CaptureProtection captureProtection(Ref ref) => CaptureProtection();

/// The reader's own name — the faint watermark a web thread carries, so
/// a screenshot shared onwards says whose screen it was taken from.
/// Empty until the composition root wires it (the profile feature does,
/// see `captureReaderNameFromProfile`).
final captureReaderNameProvider = Provider<String>((ref) => '');
