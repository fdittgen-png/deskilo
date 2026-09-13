// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/nfc/nfc_uid_reader.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/accessory.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/seat.dart';
import '../../../plan/providers/accessory_providers.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../plan/domain/floor_plan_rules.dart';
import 'placement_problem.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;

/// One seat's properties (#1216, extracted from the level canvas).
///
/// It is the longest sheet in the editor — name, sitting direction,
/// chair, the workspace accessory catalogue, the chair's NFC tag and
/// the maintenance block — and it has nothing to do with drawing on a
/// grid, which is what the screen it used to live in is about.
/// Chip label: accessory name, plus its per-half-day supplement (in the
/// workspace currency) when one is set.
String _accessoryLabel(Accessory accessory, MoneyFormat currency) {
  if (accessory.supplementCents <= 0) return accessory.name;
  final supplement = currency.formatMinor(accessory.supplementCents);
  return '${accessory.name} (+$supplement)';
}

Future<void> showSeatPropertiesSheet(
  BuildContext context,
  WidgetRef ref, {
  required String levelId,
  required FloorPlan plan,
  required Seat seat,
}) async {
  final l10n = AppLocalizations.of(context);
  final workspace = ref.read(currentWorkspaceProvider).value;
  // #168: the seat's equipment comes from the workspace accessory
  // catalog (active entries, catalog order), not a hard-coded list.
  final catalog = await ref.read(accessoriesProvider().future);
  final assignments = await ref.read(seatAccessoriesProvider.future);
  if (!context.mounted) return;
  final initialAccessories = assignments[seat.id] ?? const <String>{};
  final selectedAccessories = {...initialAccessories};
  final currency =
      moneyFormat(workspace?.currencyCode);

  final name = TextEditingController(text: seat.name);
  final chair = TextEditingController(text: seat.chair);
  // #585 — the chair's NFC/RFID tag. The field takes a typed/pasted
  // uid on any platform; the Read button fills it from a live tap
  // where the device can (Android with NFC on).
  final nfcUid = TextEditingController(text: seat.nfcUid ?? '');
  final nfcReader = ref.read(nfcUidReaderProvider);
  // #604: the whole chair-tag block rides the nfcSeatTags flag.
  final seatTagsOn = ref
      .read(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.nfcSeatTags);
  final nfcReady = seatTagsOn && await nfcReader.isAvailable();
  if (!context.mounted) return;
  var orientation = seat.orientation;
  var blocked = seat.isBlockedAt(ref.read(clockProvider).now());

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: StatefulBuilder(
        builder: (context, setSheetState) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n?.editorSeatProperties ?? 'Seat',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: InputDecoration(
                  labelText: l10n?.editorSeatNameLabel ?? 'Seat name',
                ),
              ),
              const SizedBox(height: 12),
              Text(l10n?.editorOrientationLabel ?? 'Sitting direction'),
              // #1216 — four bare arrows say nothing about what "up"
              // means. It is the direction on the PLAN, the same one
              // the canvas is drawn in, which is the one fact the
              // reader needs to pick the right arrow first time.
              Text(
                l10n?.editorOrientationHint ??
                    'Which way the chair faces on the plan.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 4),
              SegmentedButton<SeatOrientation>(
                segments: const [
                  ButtonSegment(
                    value: SeatOrientation.n,
                    icon: Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment(
                    value: SeatOrientation.e,
                    icon: Icon(Icons.arrow_forward),
                  ),
                  ButtonSegment(
                    value: SeatOrientation.s,
                    icon: Icon(Icons.arrow_downward),
                  ),
                  ButtonSegment(
                    value: SeatOrientation.w,
                    icon: Icon(Icons.arrow_back),
                  ),
                ],
                selected: {orientation},
                onSelectionChanged: (selection) =>
                    setSheetState(() => orientation = selection.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: chair,
                decoration: InputDecoration(
                  labelText: l10n?.editorChairLabel ?? 'Chair type',
                ),
              ),
              const SizedBox(height: 12),
              Text(l10n?.editorAccessoriesLabel ?? 'Accessories'),
              const SizedBox(height: 4),
              // #1216 — a link, not an instruction. Telling somebody
              // where to go and making them walk there themselves is
              // two taps and a memory of the sentence; this is one
              // tap, and the sheet closes behind it.
              if (catalog.isEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: const ValueKey('seat-add-accessories'),
                    onPressed: () {
                      Navigator.of(context).pop(false);
                      context.push('/accessories');
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      l10n?.editorNoAccessoriesAction ??
                          'No accessories yet — set them up',
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  children: [
                    for (final accessory in catalog)
                      FilterChip(
                        label: Text(_accessoryLabel(accessory, currency)),
                        selected:
                            selectedAccessories.contains(accessory.id),
                        onSelected: (selected) => setSheetState(() {
                          selected
                              ? selectedAccessories.add(accessory.id)
                              : selectedAccessories.remove(accessory.id);
                        }),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              // #585 — a physical tag on the chair resolves to this
              // seat like its printed QR card (#604: flag-gated).
              if (seatTagsOn)
              TextField(
                key: const ValueKey('editor-seat-nfc'),
                controller: nfcUid,
                decoration: InputDecoration(
                  labelText:
                      l10n?.editorSeatNfcLabel ?? 'NFC/RFID tag',
                  helperText: l10n?.editorSeatNfcHelp ??
                      'Tag uid in hex — leave empty for no tag.',
                  suffixIcon: nfcReady
                      ? IconButton(
                          key: const ValueKey('editor-seat-nfc-read'),
                          tooltip: l10n?.editorSeatNfcRead ??
                              'Read a tag now',
                          icon: const Icon(Icons.nfc),
                          onPressed: () async {
                            final ok = await nfcReader.startRead(
                              onUid: (uid) {
                                nfcUid.text = uid;
                                nfcReader.stop();
                              },
                            );
                            if (!ok && context.mounted) {
                              AppSnack.error(
                                context,
                                l10n?.editorSeatNfcReadFailed ??
                                    'Could not start the tag reader.',
                              );
                            }
                          },
                        )
                      : null,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n?.editorBlockedLabel ?? 'Blocked (maintenance)',
                ),
                value: blocked,
                onChanged: (v) => setSheetState(() => blocked = v),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n?.commonSave ?? 'Save'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (saved != true) return;

  // #168: `seat.amenities` is intentionally NOT written anymore — the
  // seat_accessories joins are the write path for seat equipment.
  // #585 — mirror the server normalization: lowercase hex, no
  // separators; empty clears the tag.
  final tag = nfcUid.text.toLowerCase().replaceAll(
        RegExp('[^0-9a-f]'), '');
  final updated = seat.copyWith(
    name: name.text.trim().isEmpty ? seat.name : name.text.trim(),
    chair: chair.text.trim(),
    orientation: orientation,
    blockedFrom: blocked ? (seat.blockedFrom ?? ref.read(clockProvider).now()) : null,
    blockedTo: blocked ? seat.blockedTo : null,
    nfcUid: tag.isEmpty ? null : tag,
  );
  final problem = validateSeatInPlan(plan, updated);
  if (problem != null) {
    if (context.mounted) showPlacementProblem(context, problem);
    return;
  }
  try {
    await ref.read(floorPlanRepositoryProvider).updateSeat(updated);
  } on PostgrestException catch (e, st) {
    // The partial unique index (0114): one tag, one chair.
    if (e.message.contains('seats_nfc_uid_unique')) {
      TraceLogger.instance.error('editor', 'nfc tag already linked',
          error: e, stackTrace: st);
      if (context.mounted) {
        AppSnack.error(
          context,
          l10n?.editorSeatNfcDuplicate ??
              'This tag is already linked to another chair.',
        );
      }
      return;
    }
    rethrow;
  }
  final accessoriesChanged =
      selectedAccessories.length != initialAccessories.length ||
          !selectedAccessories.containsAll(initialAccessories);
  if (accessoriesChanged) {
    await ref
        .read(accessoryRepositoryProvider)
        .setSeatAccessories(seat.id, selectedAccessories);
    ref.invalidate(seatAccessoriesProvider);
  }
  ref.invalidate(floorPlanProvider(levelId));
}
