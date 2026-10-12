// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A section's title (#2388): the local `_heading`/`_header` builders
/// several screens wrote around a `Text` in a `Padding`. The default is
/// the titleMedium heading above its rows; a screen with a quieter
/// heading passes its own [padding] and [style].
class SectionHeading extends StatelessWidget {
  const SectionHeading(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.sm),
    this.style,
  });

  final String text;
  final EdgeInsetsGeometry padding;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Text(text, style: style ?? Theme.of(context).textTheme.titleMedium),
  );
}

/// One "label: value" line of a summary (#2388), the label emphasised.
class LabeledRow extends StatelessWidget {
  const LabeledRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: Theme.of(context).textTheme.bodyMedium?.emphasised,
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );
}
