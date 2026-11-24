// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4178 (F4) -- the door from an accepted quote's line to its engagement: it
// opens the line's engagement, or finds it (one per canonical source line, ever),
// and goes there. Opening it invoices and pays nothing. A refusal is said; a
// lost answer is retried under the same request identity.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/failure/app_failure.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/app_snack.dart';
import '../../domain/service_fulfilment.dart';
import '../../providers/service_fulfilment_providers.dart';
import 'engagement_text.dart';

class FollowLineButton extends ConsumerStatefulWidget {
  const FollowLineButton({
    super.key,
    required this.workspaceId,
    required this.quoteId,
    required this.lineId,
  });

  final String workspaceId;
  final String quoteId;
  final String lineId;

  @override
  ConsumerState<FollowLineButton> createState() => _State();
}

class _State extends ConsumerState<FollowLineButton> {
  bool _busy = false;
  String? _requestId;

  Future<void> _open() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    final outcome = await ref
        .read(serviceFulfilmentCommandProvider)
        .openFromLine(
          widget.workspaceId,
          requestId: _requestId ??= newRequestId(),
          kind: 'quote',
          id: widget.quoteId,
          lineId: widget.lineId,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (outcome) {
      case CommandDone(:final value):
        _requestId = null;
        ref.invalidate(serviceFulfilmentsProvider(widget.workspaceId));
        context.go('/money/engagements/${value.fulfilment.id}');
      case CommandRefused(refusal: Refusal(cause: final FulfilmentRefusal refusal)):
        _requestId = null;
        AppSnack.error(context, engagementRefusalText(l10n, refusal));
      case _:
        AppSnack.error(context, l10n.engagementUnreached);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton(
    key: ValueKey('quote-line-follow-${widget.lineId}'),
    onPressed: _busy ? null : _open,
    child: Text(context.l10n.engagementOpenFromLine),
  );
}
