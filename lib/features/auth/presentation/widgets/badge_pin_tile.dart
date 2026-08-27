// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/auth_providers.dart';

/// The shortest PIN the app will store. Four is the familiar length and
/// the server rate-limits to 5 tries per 15 minutes per badge, which is
/// what actually makes a short PIN survivable — a PIN alone is not a
/// password, it is the second half of a credential whose first half is a
/// physical card.
const int kBadgePinMinLength = 4;

/// Settings → "Sign-in PIN" (#662): the member's own half of badge
/// sign-in.
///
/// Its own file rather than another block in settings_screen.dart, which
/// sits exactly at its length budget — and because the whole row is one
/// self-contained piece of state (does a PIN exist?) that nothing else
/// on that screen reads.
///
/// Only ever the SIGNED-IN member's PIN. There is no admin path here and
/// none on the server either: an owner who could set a member's PIN
/// could sign in as them, and every check-in that followed would carry
/// the member's name.
class BadgePinTile extends ConsumerStatefulWidget {
  const BadgePinTile({super.key});

  @override
  ConsumerState<BadgePinTile> createState() => _BadgePinTileState();
}

class _BadgePinTileState extends ConsumerState<BadgePinTile> {
  late Future<bool> _hasPin = ref.read(authRepositoryProvider).hasBadgePin();

  void _refresh() => setState(() {
        _hasPin = ref.read(authRepositoryProvider).hasBadgePin();
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<bool>(
      future: _hasPin,
      builder: (context, snapshot) {
        // While it loads, say nothing about whether a PIN exists rather
        // than guessing — "No PIN yet" that flips to "PIN set" a moment
        // later reads as if the tap did something.
        final has = snapshot.data;
        return ListTile(
          key: const ValueKey('settings-badge-pin'),
          leading: const Icon(Icons.pin_outlined),
          title: Text(l10n?.badgePinSectionTitle ?? 'My badge'),
          subtitle: Text(
            has == null
                ? ''
                : has
                    ? (l10n?.badgePinSet ?? 'PIN set')
                    : (l10n?.badgePinNotSet ?? 'No PIN yet'),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: has == null ? null : () => _open(context, l10n, has: has),
        );
      },
    );
  }

  Future<void> _open(
    BuildContext context,
    AppLocalizations? l10n, {
    required bool has,
  }) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BadgePinSheet(hasPin: has),
    );
    if (changed == true) _refresh();
  }
}

class _BadgePinSheet extends ConsumerStatefulWidget {
  const _BadgePinSheet({required this.hasPin});

  final bool hasPin;

  @override
  ConsumerState<_BadgePinSheet> createState() => _BadgePinSheetState();
}

class _BadgePinSheetState extends ConsumerState<_BadgePinSheet> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save(AppLocalizations? l10n) async {
    // Both checks are client-side ONLY because they are about typing,
    // not about security: the server enforces the length too, and a PIN
    // that reached it from anywhere else would still be refused.
    if (_pin.text.length < kBadgePinMinLength) {
      setState(() => _error = l10n?.badgePinTooShort(kBadgePinMinLength) ??
          'Use at least $kBadgePinMinLength digits.');
      return;
    }
    if (_pin.text != _confirm.text) {
      setState(() =>
          _error = l10n?.badgePinMismatch ?? 'The two entries do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await ref.read(authRepositoryProvider).setBadgePin(_pin.text);
    if (!mounted) return;
    AppSnack.success(context, l10n?.badgePinSaved ?? 'PIN saved.');
    Navigator.of(context).pop(true);
  }

  Future<void> _clear(AppLocalizations? l10n) async {
    setState(() => _busy = true);
    await ref.read(authRepositoryProvider).clearBadgePin();
    if (!mounted) return;
    AppSnack.success(
      context,
      l10n?.badgePinCleared ??
          'PIN removed. Your badges no longer sign you in.',
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.hasPin
                ? (l10n?.badgePinChangeAction ?? 'Change PIN')
                : (l10n?.badgePinSetAction ?? 'Set a PIN'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.badgePinExplain ??
                'Your PIN lets you sign in by scanning your badge instead '
                    'of typing your e-mail. Only you can set it, and '
                    'nobody — not even an owner — can read it back.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          _field(
            key: const ValueKey('badge-pin-new'),
            controller: _pin,
            label: l10n?.badgePinNewLabel ?? 'New PIN',
          ),
          const SizedBox(height: 12),
          _field(
            key: const ValueKey('badge-pin-confirm'),
            controller: _confirm,
            label: l10n?.badgePinConfirmLabel ?? 'Repeat it',
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              key: const ValueKey('badge-pin-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            key: const ValueKey('badge-pin-save'),
            onPressed: _busy ? null : () => _save(l10n),
            child: Text(MaterialLocalizations.of(context).saveButtonLabel),
          ),
          if (widget.hasPin)
            TextButton(
              key: const ValueKey('badge-pin-clear'),
              onPressed: _busy ? null : () => _clear(l10n),
              child: Text(l10n?.badgePinClearAction ?? 'Remove PIN'),
            ),
        ],
      ),
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
  }) =>
      TextField(
        key: key,
        controller: controller,
        obscureText: true,
        enabled: !_busy,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      );
}
