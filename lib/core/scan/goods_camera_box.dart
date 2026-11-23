// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4360 (G11) -- the camera area of the goods scanner: the injectable reader on the lens the device prefers (the
// back camera of a handheld unless the person chose the front one), and the one line to say when the camera could
// not start (a refused permission) -- never a silent black box.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/context_l10n.dart';
import '../theme/app_radius.dart';
import 'front_camera.dart';
import 'goods_scan_widget.dart';

class GoodsCameraBox extends ConsumerStatefulWidget {
  const GoodsCameraBox({required this.onCode, super.key});

  final ValueChanged<String> onCode;

  @override
  ConsumerState<GoodsCameraBox> createState() => _GoodsCameraBoxState();
}

class _GoodsCameraBoxState extends ConsumerState<GoodsCameraBox> {
  bool _denied = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lens = ref.watch(frontCameraScanProvider);
    // the lens is read once before the camera mounts: a camera that is rebuilt on a half-opened controller never decodes
    if (!lens.hasValue && !lens.hasError) {
      return const SizedBox(key: ValueKey('goods-scan-camera'), height: 240, child: Center(child: CircularProgressIndicator()));
    }
    if (_denied) {
      return Padding(
        key: const ValueKey('goods-scan-denied'),
        padding: const EdgeInsets.all(16),
        child: Text(l10n.stockCameraDenied),
      );
    }
    final builder = ref.watch(goodsScanWidgetBuilderProvider);
    return ClipRRect(
      borderRadius: AppRadius.mdAll,
      child: SizedBox(
        key: const ValueKey('goods-scan-camera'),
        height: 240,
        child: KeyedSubtree(
          key: ValueKey('goods-camera-${lens.value}'),
          child: builder(
            onCode: widget.onCode,
            front: lens.value ?? false,
            onError: (_) {
              if (mounted) setState(() => _denied = true);
            },
          ),
        ),
      ),
    );
  }
}
