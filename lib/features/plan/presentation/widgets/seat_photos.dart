// SPDX-License-Identifier: 0BSD
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/trace/trace_logger.dart';
import '../../../profile/providers/profile_providers.dart';

/// Resolves occupant profile photos for the plan canvas (#618): takes
/// seat id → occupant auth-user id (only occupants whose profile
/// carries a photo) and hands the builder the decoded images, seat by
/// seat, as their downloads land. Decodes ONCE per user at marker size
/// — the canvas repaints per frame and must never re-decode.
class SeatPhotoLoader extends ConsumerStatefulWidget {
  const SeatPhotoLoader({
    required this.seatUserIds,
    required this.builder,
    super.key,
  });

  /// Seat id → occupant user id, pre-filtered to photo-carrying
  /// profiles; empty disables the whole machinery.
  final Map<String, String> seatUserIds;

  final Widget Function(BuildContext, Map<String, ui.Image>) builder;

  @override
  ConsumerState<SeatPhotoLoader> createState() => _SeatPhotoLoaderState();
}

class _SeatPhotoLoaderState extends ConsumerState<SeatPhotoLoader> {
  /// Decoded marker bitmaps per USER id (occupants move seats; the
  /// decode follows the person, not the chair).
  final _decoded = <String, ui.Image>{};
  final _decoding = <String>{};
  final _failed = <String>{};

  /// Decode at 3× the largest marker radius — crisp on the wall
  /// tablet, still tiny (a marker tops out at 16 px radius).
  static const _targetWidth = 96;

  Future<void> _decode(String userId, Uint8List bytes) async {
    _decoding.add(userId);
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: _targetWidth,
      );
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _decoded[userId] = frame.image);
    } catch (e, st) {
      // A corrupt photo falls back to the initial marker — the canvas
      // must never fail on someone's upload; remembered so the build
      // never retries a hopeless decode in a loop.
      _failed.add(userId);
      debugPrint('avatar decode failed: $e\n$st');
      TraceLogger.instance.warn('plan', 'avatar decode failed', error: e);
    } finally {
      _decoding.remove(userId);
    }
  }

  @override
  void dispose() {
    for (final image in _decoded.values) {
      image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final userId in {...widget.seatUserIds.values}) {
      if (_decoded.containsKey(userId) ||
          _decoding.contains(userId) ||
          _failed.contains(userId)) {
        continue;
      }
      final bytes = ref.watch(memberAvatarProvider(userId)).value;
      if (bytes != null) _decode(userId, bytes);
    }
    return widget.builder(context, {
      for (final entry in widget.seatUserIds.entries)
        entry.key: ?_decoded[entry.value],
    });
  }
}
