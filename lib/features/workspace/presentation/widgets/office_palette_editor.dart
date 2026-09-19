// SPDX-License-Identifier: 0BSD
//
// #1289 — the fills the plan paints its rooms with.
//
// The plan reads the workspace's palette by the office's own stored
// index (`OfficeColors.of(index, from:)`), so a space with three fills
// simply cycles through three and an office keeps its slot when the
// palette changes size. That is why this editor is a LIST and not a set
// of eight slots: the order is the meaning.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/office_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace_branding.dart';

class OfficePaletteEditor extends StatelessWidget {
  const OfficePaletteEditor({
    super.key,
    required this.fills,
    required this.busy,
    required this.onChanged,
    required this.onSave,
    required this.onReset,
  });

  /// The fills as chosen so far, `#RRGGBB` each; empty means the
  /// product's palette.
  final List<String> fills;
  final bool busy;
  final ValueChanged<List<String>> onChanged;
  final VoidCallback onSave;
  final VoidCallback onReset;

  /// At most eight: the plan's own palette is eight, and a ninth fill
  /// would never be reached by an office index.
  static const int most = 8;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final showing = fills.isEmpty
        ? [for (final c in OfficeColors.palette) hexOfColor(c.toARGB32())]
        : fills;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n?.coloursRooms ?? 'Room colours',
            style: theme.textTheme.titleSmall),
        Text(
          fills.isEmpty
              ? (l10n?.coloursRoomsProduct ??
                  'The product palette. Add a colour to use your own.')
              : (l10n?.coloursRoomsOwn(fills.length) ??
                  '${fills.length} of your own colours, in order.'),
          key: const ValueKey('colours-rooms-state'),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (var i = 0; i < showing.length; i++)
              _Fill(
                key: ValueKey('colours-room-$i'),
                hex: showing[i],
                removable: fills.isNotEmpty && !busy,
                onRemove: () => onChanged([...fills]..removeAt(i)),
              ),
            if (fills.length < most)
              _AddFill(
                enabled: !busy,
                onAdd: (hex) => onChanged([...fills, hex]),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            FilledButton.tonal(
              key: const ValueKey('colours-rooms-save'),
              onPressed: busy ? null : onSave,
              child: Text(l10n?.commonSave ?? 'Save'),
            ),
            TextButton(
              key: const ValueKey('colours-rooms-reset'),
              onPressed: busy || fills.isEmpty ? null : onReset,
              child: Text(l10n?.coloursReset ?? 'Product colours'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Fill extends StatelessWidget {
  const _Fill({
    super.key,
    required this.hex,
    required this.removable,
    required this.onRemove,
  });

  final String hex;
  final bool removable;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final argb = parseHexColor(hex) ?? 0xFF9E9E9E;
    return Tooltip(
      message: hex,
      child: InkWell(
        onTap: removable ? onRemove : null,
        borderRadius: AppRadius.mdAll,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Color(argb),
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: removable
              ? const Icon(Icons.close, size: 16, color: Colors.black54)
              : null,
        ),
      ),
    );
  }
}

class _AddFill extends StatefulWidget {
  const _AddFill({required this.enabled, required this.onAdd});

  final bool enabled;
  final ValueChanged<String> onAdd;

  @override
  State<_AddFill> createState() => _AddFillState();
}

class _AddFillState extends State<_AddFill> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typed = parseHexColor(_field.text);
    return SizedBox(
      width: 180,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('colours-room-hex'),
              controller: _field,
              enabled: widget.enabled,
              decoration: InputDecoration(
                isDense: true,
                labelText: l10n?.coloursRoomsAdd ?? 'Add a colour',
                hintText: '#EBDCC9',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          IconButton(
            key: const ValueKey('colours-room-add'),
            tooltip: l10n?.coloursRoomsAdd ?? 'Add a colour',
            onPressed: widget.enabled && typed != null
                ? () {
                    widget.onAdd(hexOfColor(typed));
                    _field.clear();
                    setState(() {});
                  }
                : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
