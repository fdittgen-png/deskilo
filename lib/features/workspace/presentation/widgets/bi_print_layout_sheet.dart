// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The print layout of a report, edited: paper, orientation, margins, a
// typed header and footer line, page breaks and the sources list, with a
// sheet that shows the result as it is chosen. The layout belongs to the
// report's draft; the report editor saves it with the rest. What every
// copy prints whatever the layout says (the provenance, the qualification)
// is stated here, not offered as a switch.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/bi_report_definition.dart';
import 'bi_print_preview.dart' show BiPrintSheet;

/// Edits [current]; the chosen layout, or null when the person backed out.
Future<BiPrintStyle?> showBiPrintLayoutSheet(
  BuildContext context,
  BiPrintStyle current,
) async {
  final l10n = context.l10n;
  final fields = FormControllers({
    'header': current.header,
    'footer': current.footer,
  });
  var style = current;
  BiPrintStyle? chosen;
  final applied = await showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.biPrintLayoutTitle,
      submitLabel: l10n.biPrintLayoutApply,
      submitKey: const ValueKey('bi-print-apply'),
      onDispose: fields.dispose,
      validate: () => {
        for (final key in const ['header', 'footer'])
          if (!BiPrintStyle.validLine(fields.text(key)))
            key: l10n.biPrintLineInvalid,
      },
      onSubmit: () async {
        chosen = style
            .withValue('header', fields.text('header'))
            .withValue('footer', fields.text('footer'));
        return null;
      },
      builder: (context, refresh) {
        void set(BiPrintStyle next) {
          style = next;
          refresh();
        }

        return [
          _Choice(
            key: const ValueKey('bi-print-paper'),
            keyPrefix: 'bi-print-paper',
            label: l10n.biPrintPaper,
            value: style.paper,
            options: {
              'A4': l10n.biPrintPaperA4,
              'Letter': l10n.biPrintPaperLetter,
            },
            onChanged: (v) => set(style.withValue('paper', v)),
          ),
          const FormGap(),
          _Choice(
            key: const ValueKey('bi-print-orientation'),
            keyPrefix: 'bi-print-orientation',
            label: l10n.biPrintOrientation,
            value: style.orientation,
            options: {
              'portrait': l10n.biPrintPortrait,
              'landscape': l10n.biPrintLandscape,
            },
            onChanged: (v) => set(style.withValue('orientation', v)),
          ),
          const FormGap(),
          _Choice(
            key: const ValueKey('bi-print-margin'),
            keyPrefix: 'bi-print-margin',
            label: l10n.biPrintMargins,
            value: style.margin,
            options: {
              'narrow': l10n.biPrintMarginNarrow,
              'normal': l10n.biPrintMarginNormal,
              'wide': l10n.biPrintMarginWide,
            },
            onChanged: (v) => set(style.withValue('margin', v)),
          ),
          const FormGap(),
          AppTextField(
            key: const ValueKey('bi-print-header'),
            controller: fields['header'],
            fieldKey: 'header',
            label: l10n.biPrintHeader,
            helper: l10n.biPrintLineHelper,
            maxLength: BiPrintStyle.maxLine,
            onChanged: (_) => refresh(),
          ),
          const FormGap(),
          AppTextField(
            key: const ValueKey('bi-print-footer'),
            controller: fields['footer'],
            fieldKey: 'footer',
            label: l10n.biPrintFooter,
            helper: l10n.biPrintLineHelper,
            maxLength: BiPrintStyle.maxLine,
            onChanged: (_) => refresh(),
          ),
          SwitchListTile(
            key: const ValueKey('bi-print-page-breaks'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.biPrintPageBreaks),
            value: style.pageBreaks,
            onChanged: (v) => set(style.withValue('pageBreaks', v)),
          ),
          SwitchListTile(
            key: const ValueKey('bi-print-sources'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.biPrintShowSources),
            value: style.showSources,
            onChanged: (v) => set(style.withValue('showSources', v)),
          ),
          Text(
            l10n.biPrintProvenanceNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const FormGap(),
          _Sketch(
            style: style,
            header: fields.text('header'),
            footer: fields.text('footer'),
          ),
        ];
      },
    ),
  );
  return applied ? chosen : null;
}

/// One choice among a few, all visible.
class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.keyPrefix,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String keyPrefix;
  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      const FormGap.small(),
      SegmentedButton<String>(
        segments: [
          for (final o in options.entries)
            ButtonSegment(
              value: o.key,
              label: Text(o.value, key: ValueKey('$keyPrefix-${o.key}')),
            ),
        ],
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.single),
      ),
    ],
  );
}

/// The chosen sheet, in miniature: its proportions, margins and lines.
class _Sketch extends StatelessWidget {
  const _Sketch({
    required this.style,
    required this.header,
    required this.footer,
  });

  final BiPrintStyle style;
  final String header;
  final String footer;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return FractionallySizedBox(
      key: const ValueKey('bi-print-sketch'),
      widthFactor: style.landscape ? 0.9 : 0.6,
      child: BiPrintSheet(
        style: style,
        children: [
          Text(header, style: small),
          const Divider(),
          Container(
            height: 40,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          const Divider(),
          Text(footer, style: small),
        ],
      ),
    );
  }
}
