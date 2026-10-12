// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../l10n/app_localizations.dart';

export 'mcp_operation_text.g.dart';

/// #1809 — what each optional field discloses, in the person's language.
String mcpOptionalFieldLabel(AppLocalizations l10n, String field) =>
    switch (field) {
      'name' => l10n.mcpFieldName,
      _ => field,
    };

/// #1809 — a fictional value for a field in the disclosure preview.
String mcpOptionalFieldSample(AppLocalizations l10n, String field) =>
    switch (field) {
      'name' => l10n.mcpFieldNameSample,
      _ => '…',
    };
