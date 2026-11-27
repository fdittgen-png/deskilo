// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4367 -- adding a till of the business, or renaming and switching one off. Whoever manages the sites does it.
// Where the business keeps goods the till is also given the place it sells from: a sale at this till takes goods from
// that place and from every place below it. The till is saved whole, so what the sheet could not read or does not show
// (its site, a place the list no longer offers) is saved as it was read.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/dropdown_field.dart';
import '../../../../core/ui/form_choice_controls.dart';
import '../../../../core/ui/form_kit.dart';
import '../../application/till_drawer_commands.dart';
import '../../domain/till_drawer.dart';
import '../../domain/till_drawer_rules.dart';
import 'drawer_inputs.dart';
import 'drawer_text.dart';

/// The dropdown's value for "the business's selling place": a till that names no place of its own.
const String _businessPlace = '';

/// Opens the sheet for a new till (null [till]) or an existing one; true when it was saved. With [offerSellingPlace] the
/// places a till may be given are read first; when they cannot be read the sheet says so, offers to ask again and saves
/// the till with the place it has.
Future<bool> showTillEditSheet(BuildContext context, TillDrawerCommands commands, {DrawerTill? till, bool offerSellingPlace = false}) async {
  final l10n = context.l10n;
  final fields = FormControllers({'name': till?.name ?? ''});
  final intent = SameIntent();
  var active = till?.active ?? true;
  var sellingPlaceId = till?.sellingPlaceId;
  TillSellingPlaces? places;
  Object? placesError;

  Future<void> readPlaces() async {
    try {
      places = await commands.sellingPlaces();
      placesError = null;
    } on Object catch (e, st) {
      TraceLogger.instance.warn('money', 'the places a till may sell from were not read', error: e, stackTrace: st);
      placesError = e;
    }
  }

  if (offerSellingPlace) await readPlaces();
  if (!context.mounted) return false;
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: till == null ? l10n.tillDrawerTillNewTitle : l10n.tillDrawerEditTill,
      submitLabel: l10n.tillDrawerTillSave,
      submitKey: const ValueKey('drawer-till-save'),
      onDispose: fields.dispose,
      validate: () => drawerFieldErrors(l10n, checkTillName(fields.text('name'))),
      onSubmit: () async {
        try {
          await commands.saveTill(
            requestId: intent.idFor('${fields.text('name')}|$active|${sellingPlaceId ?? ''}'),
            till: DrawerTillEdit(tillId: till?.id, name: fields.text('name'), siteId: till?.siteId, active: active, sellingPlaceId: sellingPlaceId),
          );
          return null;
        } on Object catch (e, st) {
      TraceLogger.instance.warn('money', 'the till drawer refused', error: e, stackTrace: st);
          return drawerProblemText(l10n, e);
        }
      },
      builder: (context, refresh) => [
        AppTextField(
          key: const ValueKey('drawer-till-name'),
          controller: fields['name'],
          fieldKey: 'name',
          label: l10n.tillDrawerTillName,
          maxLength: kTillNameMaxLength,
          autofocus: true,
        ),
        if (placesError case final error?) ...[
          const FormGap(),
          ReadFailureBanner(
            error: error,
            retryKey: const ValueKey('drawer-till-places-retry'),
            onRetry: () => unawaited(readPlaces().whenComplete(refresh)),
          ),
        ] else if (places case final offered?) ...[
          const FormGap(),
          AppDropdownField<String>(
            key: const ValueKey('drawer-till-selling-place'),
            label: l10n.tillDrawerSellingPlace,
            value: sellingPlaceId ?? _businessPlace,
            items: [
              (_businessPlace, l10n.tillDrawerSellingPlaceBusiness(offered.defaultCode)),
              for (final p in offered.places) (p.id, p.label),
              // the place the till has, when the list no longer offers it: shown and saved as it was read
              if (sellingPlaceId case final stored? when !offered.places.any((p) => p.id == stored)) (stored, l10n.tillDrawerSellingPlaceStored),
            ],
            onChanged: (v) {
              sellingPlaceId = v == null || v == _businessPlace ? null : v;
              refresh();
            },
          ),
          const FormGap.small(),
          Text(l10n.tillDrawerSellingPlaceNote, style: Theme.of(context).textTheme.bodySmall),
        ],
        if (till != null)
          AppSwitchRow(
            key: const ValueKey('drawer-till-active'),
            title: l10n.tillDrawerTillActive,
            value: active,
            onChanged: (v) {
              active = v;
              refresh();
            },
          ),
      ],
    ),
  );
}
