// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/i18n/format_controller.dart';
import 'route_classes.dart';

/// The format of the route on top follows its layer: the person's on their
/// own pages, the business's in a space ([isPersonalLayer]). The router
/// announces a route while it builds, so a change found mid-build is set
/// once that frame is done.
void followFormatSurface(GoRouter router, Ref ref) {
  final surface = isPersonalLayer(router.state.uri.path)
      ? FormatSurface.personal
      : FormatSurface.business;
  void apply() {
    if (!ref.mounted) return;
    ref.read(formatSurfaceOfRouteProvider.notifier).set(surface);
  }

  final scheduler = SchedulerBinding.instance;
  if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
    scheduler.addPostFrameCallback((_) => apply());
  } else {
    apply();
  }
}
