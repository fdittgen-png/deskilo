// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../domain/workspace_event.dart';

/// Where the row of [event] leads, or null when it leads nowhere: #4136 —
/// the notice that a payment could not be checked opens the account of the
/// member who pays it (named in its payload, never its subject).
@visibleForTesting
String? eventDestination(WorkspaceEvent event) =>
    switch ((event.type, event.payload['member_id'])) {
      (EventType.paymentAttemptUnreadable, final String member)
          when member.isNotEmpty =>
        '/invoices/customer/${Uri.encodeComponent(member)}',
      _ => null,
    };

/// What tapping the row of [event] does: opens [eventDestination], if any.
VoidCallback? eventTap(BuildContext context, WorkspaceEvent event) =>
    switch (eventDestination(event)) {
      final to? => () => context.push(to),
      null => null,
    };
