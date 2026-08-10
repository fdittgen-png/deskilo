// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/profile.dart';
import '../../providers/profile_providers.dart';

/// Editor for the opt-in WhatsApp number on my profile (#223). The raw
/// input is normalized to `+` + digits by [normalizeWhatsapp] on save;
/// an emptied field clears the number (opt-out). Follows the settings
/// dialog pattern (_LanguageDialog/_ThemeDialog) with an explicit Save.
class WhatsappDialog extends ConsumerStatefulWidget {
  const WhatsappDialog({super.key});

  @override
  ConsumerState<WhatsappDialog> createState() => WhatsappDialogState();
}

class WhatsappDialogState extends ConsumerState<WhatsappDialog> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(myProfileProvider).value?.whatsapp ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateWhatsapp(normalizeWhatsapp(_controller.text));
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnack.success(
        context,
        l10n?.whatsappSaved ?? 'WhatsApp number saved',
      );
    } catch (e, st) {
      debugPrint('WhatsApp save failed: $e\n$st');
      TraceLogger.instance.error('profile', 'WhatsApp save failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnack.error(
        context,
        l10n?.whatsappSaveFailed ?? 'Could not save the WhatsApp number',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n?.whatsappTitle ?? 'WhatsApp'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          labelText: l10n?.whatsappFieldLabel ?? 'WhatsApp number',
          hintText: l10n?.whatsappHint ?? '+33612345678',
          helperText: l10n?.whatsappHelper ??
              'Optional. Visible to members of your workspaces. '
                  'Leave empty to stop sharing it.',
          helperMaxLines: 3,
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n?.commonSave ?? 'Save'),
        ),
      ],
    );
  }
}
