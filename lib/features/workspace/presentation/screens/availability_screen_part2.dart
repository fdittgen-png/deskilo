// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'availability_screen.dart';


/// One working-day bound: localized clock text, tap opens a time picker.
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.availabilityAddClosure),
      content: TextField(
        controller: _reason,
        autofocus: true,
        maxLength: 120,
        decoration: InputDecoration(
          labelText: l10n.availabilityClosureReason,
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('availability-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('availability-save'),
          onPressed: () => Navigator.of(context).pop(_reason.text),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
