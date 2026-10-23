// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2861 — the workspace's own facts as a reader takes them in: one line per
// field (Overview) instead of one wide row, and every feature by process
// with whether it is on (Features) instead of one cell of stored keys. The
// stable keys stay in the cells; the workbook's localisation pass turns the
// field, process and feature keys into the reader's words.
import '../../../core/files/xlsx.dart';
import 'workspace.dart';
import 'workspace_process.dart';

/// The Overview and Features sheets of [workspace] with [enabledFeatures]
/// (their stored keys) on.
List<XlsxSheet> workspaceOverviewSheets(
  Workspace workspace,
  Set<String> enabledFeatures,
) => [
  XlsxSheet(
    name: 'Overview',
    rows: [
      ['field', 'value'],
      for (final (field, value) in [
        ('name', workspace.name),
        ('country', workspace.countryCode),
        ('currency', workspace.currencyCode),
        ('timezone', workspace.timezone),
        ('workspace_code', workspace.inviteCode),
        ('vat_regime', workspace.vatRegime),
        ('vat_id', workspace.vatId),
        ('legal_id', workspace.legalId),
        ('street', workspace.street),
        ('postal_code', workspace.postalCode),
        ('city', workspace.city),
        ('id', workspace.id),
      ])
        [field, value],
    ],
  ),
  XlsxSheet(
    name: 'Features',
    rows: [
      ['process', 'feature', 'on'],
      for (final process in workspaceProcesses)
        for (final sub in process.subprocesses)
          for (final feature in sub.capabilities)
            [
              process.key,
              feature.dbKey,
              enabledFeatures.contains(feature.dbKey),
            ],
    ],
  ),
];
