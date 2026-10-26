// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

/// One door of the Money tab's workspace tools (#486 UX): a row with its
/// icon, title and subtitle, or nothing while [on] is false, so a caller
/// lists it with `?` and the tab shows only what the person may open.
Widget? managementTile({
  required bool on,
  required String key,
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) =>
    on
        ? ListTile(
            key: ValueKey(key),
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon),
            title: Text(title),
            subtitle: Text(subtitle),
            // Not chevron_right: the period bar owns that icon here.
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: onTap,
          )
        : null;
