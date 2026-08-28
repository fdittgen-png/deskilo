// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_spacing.dart';
import 'time_zones.dart';

/// A searchable sheet over the IANA zones (#711). Returns the picked
/// name, or null when dismissed.
///
/// Search, not a dropdown: four hundred entries in a dropdown is a
/// scroll nobody finishes. Each row shows the zone's current UTC offset
/// beside its name, because "Europe/Paris" means nothing to someone
/// who only knows they are an hour behind London.
Future<String?> showTimeZonePicker(
  BuildContext context, {
  required String current,
  required DateTime now,
}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TimeZoneSheet(current: current, now: now),
    );

class _TimeZoneSheet extends StatefulWidget {
  const _TimeZoneSheet({required this.current, required this.now});

  final String current;
  final DateTime now;

  @override
  State<_TimeZoneSheet> createState() => _TimeZoneSheetState();
}

class _TimeZoneSheetState extends State<_TimeZoneSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final matches = TimeZones.search(_query);
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.8,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: TextField(
              key: const ValueKey('timezone-search'),
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: l10n?.workspaceTimezoneLabel ?? 'Time zone',
                hintText: 'Europe/Paris',
              ),
              onChanged: (q) => setState(() => _query = q),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final name = matches[index];
                return ListTile(
                  key: ValueKey('timezone-$name'),
                  title: Text(name),
                  trailing: Text(TimeZones.offsetLabel(name, widget.now)),
                  selected: name == widget.current,
                  onTap: () => Navigator.of(context).pop(name),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
