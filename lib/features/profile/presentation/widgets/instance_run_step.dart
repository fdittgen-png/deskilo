// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../core/instance/instance_builder.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

/// One long-running wizard step (#977): what it does, its progress, and
/// the one button that starts, resumes or shows it done.
class InstanceRunStep extends StatelessWidget {
  const InstanceRunStep({
    super.key,
    required this.intro,
    required this.buttonKey,
    required this.done,
    required this.busy,
    required this.progress,
    required this.retry,
    required this.onRun,
    this.startLabel,
    this.startIcon = Icons.play_arrow_outlined,
  });

  final String intro;
  final String buttonKey;
  final bool done;
  final bool busy;
  final InstanceProgress? progress;

  /// A failure stopped the step: the button resumes rather than starts.
  final bool retry;
  final Future<void> Function() onRun;

  /// The button before the step ran; "Start" when null.
  final String? startLabel;
  final IconData startIcon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(intro),
        ),
        if (p != null && !done) ...[
          LinearProgressIndicator(value: p.total == 0 ? null : p.done / p.total),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(l10n?.instanceProgress(p.done, p.total, p.current) ??
                '${p.done} / ${p.total} · ${p.current}'),
          ),
        ],
        FilledButton.icon(
          key: ValueKey(buttonKey),
          onPressed: busy || done ? null : onRun,
          icon: Icon(done ? Icons.check_circle_outline : startIcon),
          label: Text(done
              ? (l10n?.commonDone ?? 'Done')
              : retry
                  ? (l10n?.instanceRetry ?? 'Retry from where it stopped')
                  : (startLabel ?? l10n?.commonStart ?? 'Start')),
        ),
      ],
    );
  }
}
