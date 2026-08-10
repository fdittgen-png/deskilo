// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/space_code.dart';
import '../widgets/reference_open.dart';

/// Deep-link targets `/res/:id` and `/space/:kind/:id` (0106): the
/// reference links inside a WhatsApp-mirrored message land here — the
/// app opens straight onto the reservation's detail sheet or the
/// space's booking sheet, exactly like tapping the link in-app. When
/// the sheet closes (or the target is gone, which the openers report
/// with their usual snacks), the Reserve hub takes over.
class ReferenceLinkScreen extends ConsumerStatefulWidget {
  const ReferenceLinkScreen.reservation({super.key, required this.id})
      : kind = null;

  const ReferenceLinkScreen.space({
    super.key,
    required SpaceKind this.kind,
    required this.id,
  });

  /// null = a reservation link; else the space kind.
  final SpaceKind? kind;
  final String id;

  @override
  ConsumerState<ReferenceLinkScreen> createState() =>
      _ReferenceLinkScreenState();
}

class _ReferenceLinkScreenState extends ConsumerState<ReferenceLinkScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (!mounted) return;
    final kind = widget.kind;
    if (kind == null) {
      await openReservationById(context, ref, widget.id);
    } else {
      await openSpaceById(context, ref, kind: kind, id: widget.id);
    }
    if (!mounted) return;
    context.go('/reserve');
  }

  @override
  // A still, empty host — the sheet opens over it in the same frame; a
  // spinner here would animate under the sheet for its whole life.
  Widget build(BuildContext context) =>
      const Scaffold(body: SizedBox.shrink());
}
