// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/phone/phone_entry.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/phone_field.dart';
import '../../providers/profile_providers.dart';

/// Editor for the opt-in WhatsApp number on my profile (#223). #3650 — the
/// number is typed in the form kit's phone field, read in its country (the
/// stored number's own, else the owner's identity country, never a guess),
/// and saved only once validated: what was typed and the international
/// form, side by side. A number saved before numbers were checked is shown
/// with a word asking to confirm or correct it. An emptied field clears the
/// number (opt-out). Follows the settings dialog pattern with an explicit
/// Save.
class WhatsappDialog extends ConsumerStatefulWidget {
  const WhatsappDialog({super.key});

  @override
  ConsumerState<WhatsappDialog> createState() => WhatsappDialogState();
}

class WhatsappDialogState extends ConsumerState<WhatsappDialog> {
  late final TextEditingController _number;
  late final TextEditingController _country;
  bool _saving = false;
  bool _needsCorrection = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final mine = ref.read(myProfileProvider).value;
    final entry = mine?.whatsappEntry ?? PhoneEntry.empty;
    _needsCorrection = mine?.whatsappNeedsCorrection ?? false;
    _number = TextEditingController(text: entry.typed);
    _country = TextEditingController(
      text: entry.country ?? mine?.identity.countryCode ?? '',
    );
  }

  @override
  void dispose() {
    _number.dispose();
    _country.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final entry = phoneEntryOf(_number, _country);
    final problem = phoneProblemText(l10n, entry);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateWhatsapp(entry);
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnack.success(
        context,
        l10n.whatsappSaved,
      );
    } on Object catch (e, st) {
      TraceLogger.instance.error('profile', 'WhatsApp save failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnack.error(
        context,
        l10n.whatsappSaveFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.whatsappTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_needsCorrection)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                l10n.phoneNeedsCorrection,
                key: const ValueKey('whatsapp-needs-correction'),
              ),
            ),
          PhoneField(
            number: _number,
            country: _country,
            label: l10n.whatsappFieldLabel,
            fieldKey: 'whatsapp',
            helper: l10n.whatsappHelper,
            error: _error,
            autofocus: true,
            onChanged: () {
              if (_error != null) setState(() => _error = null);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('whatsapp-dialog-cancel'),
          onPressed:
              _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('whatsapp-dialog-save'),
          onPressed: _saving ? null : _save,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
