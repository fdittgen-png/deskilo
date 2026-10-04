// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

/// Reports the height it is given; draws nothing. A grid reads it to let its
/// rows use the room the screen has (Day view seat rows).
class HeightProbe extends StatelessWidget {
  const HeightProbe({super.key, required this.onHeight});

  final ValueChanged<double> onHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        if (h.isFinite) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(h));
        }
        return const SizedBox.shrink();
      },
    );
  }
}
