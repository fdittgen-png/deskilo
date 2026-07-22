// SPDX-License-Identifier: 0BSD
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/country/country_catalog.dart';
import '../../../../core/format/cents.dart';
import '../../../../core/files/file_picker.dart';
import '../../../../core/files/file_saver.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/level.dart';
import '../../../events/providers/event_providers.dart';
import '../../../plan/providers/accessory_providers.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../domain/booking_granularity.dart';
import '../../domain/member.dart';
import '../../domain/overage_policy.dart';
import '../../domain/payment_instructions.dart';
import '../../domain/invitation_message.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_config_pdf.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_import.dart';
import '../../domain/workspace_xml.dart';
import '../../providers/workspace_import_providers.dart';
import '../../providers/workspace_providers.dart';
import '../country_names.dart';
import '../feature_names.dart';

/// Owner-only workspace settings (#153): country, currency and time zone
/// become editable after creation. Picking a country re-defaults the
/// currency and time zone from [CountryCatalog] — exactly the onboarding
/// behaviour — but a manual currency override typed AFTER the country
/// pick is persisted verbatim (spec §3: owner-overridable).
class WorkspaceSettingsScreen extends ConsumerStatefulWidget {
  const WorkspaceSettingsScreen({super.key});

  @override
  ConsumerState<WorkspaceSettingsScreen> createState() =>
      _WorkspaceSettingsScreenState();
}

class _WorkspaceSettingsScreenState
    extends ConsumerState<WorkspaceSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currency = TextEditingController();
  final _timezone = TextEditingController();
  // #155/#192 — payment instructions members see on an unpaid statement.
  final _iban = TextEditingController();
  final _paypalMe = TextEditingController();
  final _reference = TextEditingController();
  final _wero = TextEditingController();
  final _lydia = TextEditingController();
  final _wise = TextEditingController();
  // #231 — the community's WhatsApp group invite link (directory, #232).
  final _whatsappGroup = TextEditingController();
  final _invitationTemplate = TextEditingController();
  // 0040 — desk fill opacity percentage (20..100); rides the Save button.
  int _deskOpacity = 100;
  String? _countryCode;
  bool _busy = false;

  /// Seed the form ONCE from the loaded workspace; later rebuilds must
  /// not clobber the owner's in-progress edits.
  bool _seeded = false;

  @override
  void dispose() {
    _currency.dispose();
    _timezone.dispose();
    _iban.dispose();
    _paypalMe.dispose();
    _reference.dispose();
    _wero.dispose();
    _lydia.dispose();
    _wise.dispose();
    _whatsappGroup.dispose();
    _invitationTemplate.dispose();
    super.dispose();
  }

  void _onCountryPicked(String? code) {
    if (code == null) return;
    final country = CountryCatalog.byCode(code);
    setState(() {
      _countryCode = code;
      // Re-default both from the catalog (spec §3); the owner can still
      // override the currency before saving.
      _currency.text = country.currencyCode;
      _timezone.text = country.defaultTimezone;
    });
  }

  Future<void> _save(String workspaceId) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final code = _countryCode;
    if (code == null) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'update workspace locale failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
          final repository = ref.read(workspaceRepositoryProvider);
          await repository.updateWorkspaceLocale(
            workspaceId,
            countryCode: code,
            currencyCode: _currency.text.trim().toUpperCase(),
            timezone: _timezone.text.trim(),
          );
          // #155 — the how-to-pay blob rides the same Save.
          await repository.setPaymentInstructions(
            workspaceId,
            PaymentInstructions(
              iban: _iban.text,
              paypalMe: _paypalMe.text,
              reference: _reference.text,
              wero: _wero.text,
              lydia: _lydia.text,
              wise: _wise.text,
            ),
          );
          // #231 — the WhatsApp group link rides the same Save through its
          // own setter (setPaymentInstructions shape); '' clears it.
          await repository.setWhatsappGroup(
            workspaceId,
            _whatsappGroup.text.trim(),
          );
          // 0049 — the invitation message template rides the same Save;
          // '' falls back to the localized built-in message.
          await repository.setInvitationTemplate(
            workspaceId,
            _invitationTemplate.text.trim(),
          );
          // 0040 — desk transparency rides the same Save.
          await repository.setDeskOpacity(workspaceId, _deskOpacity);
          // Every money surface watches the workspace chain — invalidating it
          // re-renders all amounts in the new currency immediately.
          ref.invalidate(myWorkspacesProvider);
          if (!mounted) return;
          AppSnack.success(
            context,
            l10n?.workspaceSettingsSaved ?? 'Workspace saved.',
          );
      },
    )) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Serializes the workspace settings + every level's floor plan + the
  /// accessory catalog and seat assignments (v2, #180) to the versioned
  /// XML format (#164) and hands it to the system share sheet as a `.xml`
  /// file — same seam the bill PDF export uses (#133).
  Future<void> _exportXml(Workspace workspace) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'workspace XML export failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
          final levels = await ref.read(levelsProvider.future);
          final plans = <({Level level, FloorPlan plan})>[];
          for (final level in levels) {
            plans.add((
              level: level,
              plan: await ref.read(floorPlanProvider(level.id).future),
            ));
          }
          // Inactive entries included — a backup must be complete (#180).
          final accessories =
              await ref.read(accessoriesProvider(includeInactive: true).future);
          final seatAccessories = await ref.read(seatAccessoriesProvider.future);
          final xml = buildWorkspaceXml(
            workspace: workspace,
            levels: plans,
            accessories: accessories,
            seatAccessories: seatAccessories,
          );
          final path = await ref.read(fileSaverProvider)(
            bytes: utf8.encode(xml),
            fileName: workspaceXmlFileName(workspace.name),
          );
          if (!mounted) return;
          _announceSaved(l10n, path);
      },
    )) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Confirms a local export saved (or reports failure) — never a share.
  void _announceSaved(AppLocalizations? l10n, String? path) {
    if (path == null) {
      AppSnack.error(context, l10n?.commonSaveFailed ?? 'Could not save.');
      return;
    }
    AppSnack.success(context, l10n?.commonSavedTo(path) ?? 'Saved to $path');
  }

  /// Role label for a member — owner outranks admin outranks member.
  String _roleLabel(AppLocalizations? l10n, Member member) => member.isOwner
      ? (l10n?.memberRoleOwner ?? 'Owner')
      : member.isAdmin
          ? (l10n?.memberRoleAdmin ?? 'Admin')
          : (l10n?.memberRoleMember ?? 'Member');

  String _statusLabel(AppLocalizations? l10n, MemberStatus status) =>
      switch (status) {
        MemberStatus.active => l10n?.memberStatusActive ?? 'Active',
        MemberStatus.paused => l10n?.memberStatusPaused ?? 'Paused',
        MemberStatus.pending => l10n?.memberStatusPending ?? 'Pending',
        MemberStatus.exited => l10n?.memberStatusExited ?? 'Exited',
      };

  String _granularityLabel(
    AppLocalizations? l10n,
    BookingGranularity granularity,
  ) =>
      switch (granularity) {
        BookingGranularity.flexible =>
          l10n?.availabilityGranularityFlexible ?? 'Flexible',
        BookingGranularity.halfDay =>
          l10n?.availabilityGranularityHalfDay ?? 'Half day',
        BookingGranularity.fullDay =>
          l10n?.availabilityGranularityFullDay ?? 'Full day',
        // Minute granularities carry their step in the label itself.
        BookingGranularity.minutes5 ||
        BookingGranularity.minutes15 ||
        BookingGranularity.minutes30 ||
        BookingGranularity.minutes60 =>
          '${granularity.stepMinutes} min',
      };

  /// Renders a complete, human-readable PDF snapshot of the workspace —
  /// settings, every member with their role and status, enabled features,
  /// availability and the whole floor plan — and hands it to the system
  /// share sheet. Unlike the XML export (a machine backup, no members),
  /// this is the owner's shareable configuration record.
  Future<void> _exportConfigPdf(Workspace workspace) async {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    setState(() => _busy = true);
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'workspace config PDF export failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
          final levelsList = await ref.read(levelsProvider.future);
          final plans = <ConfigPdfLevel>[];
          for (final level in levelsList) {
            plans.add((
              level: level,
              plan: await ref.read(floorPlanProvider(level.id).future),
            ));
          }
          final members = await ref.read(workspaceMembersProvider.future);
          final names = await ref.read(memberNamesProvider.future);
          final granularity = await ref.read(bookingGranularityProvider.future);
          final features = await ref.read(enabledFeaturesProvider.future);
          final openWeekdays = await ref.read(openWeekdaysProvider.future);
          final closures = await ref.read(closureDaysProvider.future);

          // ISO weekday (1=Mon..7=Sun) → localized name via a known Monday.
          final weekdayFormat = DateFormat.EEEE(locale);
          String weekdayName(int isoWeekday) =>
              weekdayFormat.format(DateTime(2026, 6, 1 + (isoWeekday - 1)));
          final openDaysLabel = (openWeekdays.toList()..sort())
              .map(weekdayName)
              .join(', ');

          final dateFormat = DateFormat.yMMMd(locale);
          final closureLabels = [
            for (final closure in closures)
              closure.reason.trim().isEmpty
                  ? dateFormat.format(closure.day.toLocal())
                  : '${dateFormat.format(closure.day.toLocal())} — '
                      '${closure.reason}',
          ];

          // Members sorted by name, like the directory.
          final sortedMembers = [...members]..sort(
              (a, b) => (names[a.id] ?? '')
                  .toLowerCase()
                  .compareTo((names[b.id] ?? '').toLowerCase()),
            );
          String memberDetails(Member member) {
            final parts = <String>[
              switch (member.overagePolicy) {
                OveragePolicy.blocked =>
                  l10n?.overagePolicyBlocked ?? 'Blocked at quota',
                OveragePolicy.payg =>
                  l10n?.overagePolicyPayg ?? 'Pay as you go',
                OveragePolicy.package =>
                  l10n?.overagePolicyPackage ?? 'Day packages',
              },
              if (member.maxActiveReservations != null)
                'max ${member.maxActiveReservations}',
              if (member.canReserveLevel)
                l10n?.levelPermissionAllowed ??
                    'May reserve a whole level',
            ];
            return parts.join(' · ');
          }

          final configMembers = <ConfigPdfMember>[
            for (final member in sortedMembers)
              (
                name: names[member.id] ?? '',
                role: _roleLabel(l10n, member),
                status: _statusLabel(l10n, member.status),
                details: memberDetails(member),
              ),
          ];

          final strings = WorkspaceConfigPdfStrings(
            title: l10n?.workspaceConfigPdfTitle ?? 'Workspace configuration',
            overview: l10n?.workspaceConfigOverview ?? 'Overview',
            country: l10n?.workspaceCountryLabel ?? 'Country',
            currency: l10n?.workspaceCurrencyLabel ?? 'Currency',
            timezone: l10n?.workspaceTimezoneLabel ?? 'Time zone',
            granularity: l10n?.workspaceConfigGranularity ?? 'Booking granularity',
            members: l10n?.workspaceConfigMembersSection ?? 'Members',
            colName: l10n?.workspaceConfigColName ?? 'Name',
            colRole: l10n?.workspaceConfigColRole ?? 'Role',
            colStatus: l10n?.workspaceConfigColStatus ?? 'Status',
            features: l10n?.workspaceConfigFeatures ?? 'Enabled features',
            none: l10n?.workspaceConfigNone ?? 'None',
            availability: l10n?.workspaceConfigAvailability ?? 'Availability',
            openDays: l10n?.workspaceConfigOpenDays ?? 'Open days',
            closures: l10n?.workspaceConfigClosures ?? 'Closures',
            floorPlan: l10n?.workspaceConfigFloorPlan ?? 'Floor plan',
            bookableWhole:
                l10n?.workspaceConfigBookableWhole ?? 'bookable as a whole',
            seatsLabel: l10n?.workspaceConfigSeats ?? 'Seats',
            emptyLevel: l10n?.workspaceConfigEmptyLevel ?? 'No rooms',
            levelBookable: (price) => price.isEmpty
                ? (l10n?.levelBookableToggle ?? 'Bookable as a whole')
                : '${l10n?.levelBookableToggle ?? 'Bookable as a whole'}'
                    ' — $price / '
                    '${l10n?.levelPriceLabel ?? 'Price per half-day'}',
            invitations:
                l10n?.workspaceConfigInvitations ?? 'Invitations',
            invitationCustomTemplate:
                l10n?.workspaceConfigInvitationCustom ??
                    'Custom invitation message configured',
            invitationDefault: l10n?.workspaceConfigInvitationDefault ??
                'Built-in invitation message (all languages)',
            invitationSingleUse:
                l10n?.workspaceConfigInvitationSingleUse ??
                    'Personal invitation codes are single-use and '
                        'expire after 14 days; new members need '
                        'admin approval',
          );

          final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
          final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
          final bytes = await buildWorkspaceConfigPdf(
            strings: strings,
            workspaceName: workspace.name,
            generatedOnLabel: l10n?.workspaceConfigPdfGeneratedOn(
                  dateFormat.format(DateTime.now()),
                ) ??
                'Generated on ${dateFormat.format(DateTime.now())}',
            countryLabel: localizedCountryName(l10n, workspace.countryCode),
            currencyCode: workspace.currencyCode,
            timezone: workspace.timezone,
            granularityLabel: _granularityLabel(l10n, granularity),
            members: configMembers,
            featureLabels: [
              // Registry order for a stable list.
              for (final feature in WorkspaceFeature.values)
                if (features.contains(feature)) featureName(l10n, feature),
            ],
            openDaysLabel: openDaysLabel,
            closureLabels: closureLabels,
            levels: plans,
            levelPrices: {
              for (final entry in plans)
                if (entry.level.bookableAsWhole)
                  entry.level.id: entry.level.priceCents == 0
                      ? ''
                      : '${centsToMajor(entry.level.priceCents)} '
                          '${workspace.currencyCode}',
            },
            hasCustomInvitationTemplate:
                workspace.invitationTemplate.trim().isNotEmpty,
            baseFont: pw.Font.ttf(regular),
            boldFont: pw.Font.ttf(bold),
          );

          final path = await ref.read(fileSaverProvider)(
            bytes: bytes,
            fileName: '${workspace.name}-configuration.pdf',
          );
          if (!mounted) return;
          _announceSaved(l10n, path);
      },
    )) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Irreversible workspace reset (0039): a destructive dialog that unlocks
  /// its confirm button only once the owner types the exact confirmation
  /// phrase ("I agree"), then wipes all transactions + the floor plan while
  /// keeping settings and members.
  Future<void> _resetWorkspace(Workspace workspace) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ResetConfirmDialog(
        phrase: l10n?.workspaceResetConfirmPhrase ?? 'I agree',
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'workspace reset failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
          await ref.read(workspaceRepositoryProvider).resetWorkspace(workspace.id);
          // Refresh every surface that read the now-deleted data.
          ref
            ..invalidate(levelsProvider)
            ..invalidate(floorPlanProvider)
            ..invalidate(targetNamesProvider)
            ..invalidate(accessoriesProvider)
            ..invalidate(seatAccessoriesProvider)
            ..invalidate(myWorkspacesProvider);
          invalidateBookingData(ref);
          if (!mounted) return;
          AppSnack.success(
            context,
            l10n?.workspaceResetDone ?? 'Workspace reset.',
          );
      },
    )) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (mounted) setState(() => _busy = false);
  }

  /// User-facing message for a typed parse failure (#164/#165). The
  /// technical [WorkspaceXmlException.detail] goes to the trace log only.
  String _xmlErrorMessage(AppLocalizations? l10n, WorkspaceXmlError error) =>
      switch (error) {
        WorkspaceXmlError.malformed =>
          l10n?.workspaceXmlErrorMalformed ?? 'The file is not readable XML.',
        WorkspaceXmlError.wrongRoot => l10n?.workspaceXmlErrorWrongRoot ??
            'This is not a DesKilo workspace file.',
        WorkspaceXmlError.unsupportedVersion =>
          l10n?.workspaceXmlErrorUnsupportedVersion ??
              'The file was exported by a newer version of DesKilo and '
                  'cannot be imported.',
        WorkspaceXmlError.missingElement =>
          l10n?.workspaceXmlErrorMissingElement ??
              'The file is incomplete — a required section is missing.',
        WorkspaceXmlError.missingAttribute =>
          l10n?.workspaceXmlErrorMissingAttribute ??
              'The file is incomplete — a required value is missing.',
        WorkspaceXmlError.invalidValue =>
          l10n?.workspaceXmlErrorInvalidValue ??
              'The file contains an invalid value and cannot be imported.',
      };

  /// Owner-only XML import (#165): pick file → parse (typed errors) →
  /// client-side placement validation → preview + destructive confirm →
  /// transactional replace via the import RPC, settings via the existing
  /// owner writers.
  Future<void> _importXml(Workspace workspace) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final pick = ref.read(filePickerProvider);
      final file = await pick(XTypeGroup(
        // Acronym identical in every locale (IBAN precedent, #155); the
        // key exists so the parity gate covers the whole set.
        label: l10n?.workspaceXmlFileTypeLabel ?? 'XML',
        extensions: const ['xml'],
        mimeTypes: const ['application/xml', 'text/xml'],
      ));
      if (file == null) return; // cancelled
      // Explicit UTF-8 decode: the export declares UTF-8 (#164), and
      // XFile.readAsString is not UTF-8-safe for data-backed files.
      final content = utf8.decode(await file.readAsBytes());
      if (!mounted) return;

      final WorkspaceXmlData data;
      try {
        data = parseWorkspaceXml(content);
      } on WorkspaceXmlException catch (e, st) {
        TraceLogger.instance.error(
            'workspace', 'workspace XML import rejected: ${e.detail}',
            error: e, stackTrace: st);
        if (!mounted) return;
        AppSnack.error(context, _xmlErrorMessage(l10n, e.error));
        return;
      }

      // The editor's placement rules (spec §10) gate the preview: a file
      // whose plan the editor could never have drawn is rejected here.
      final invalid = validateWorkspaceXmlPlan(data);
      if (invalid != null) {
        TraceLogger.instance.error(
            'workspace',
            'workspace XML import plan invalid '
            '(${invalid.problem.name}): ${invalid.detail}');
        if (!mounted) return;
        AppSnack.error(
          context,
          l10n?.workspaceXmlErrorInvalidPlan ??
              'The floor plan in the file is invalid: rooms, desks or seats '
                  'overlap or extend outside their parent.',
        );
        return;
      }

      final counts = workspaceXmlPlanCounts(data);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          return AlertDialog(
            title: Text(l10n?.workspaceXmlImportPreviewTitle ??
                'Replace floor plan?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.workspaceXmlImportPreviewCounts(counts.levels,
                          counts.offices, counts.desks, counts.seats) ??
                      'Levels: ${counts.levels} · '
                          'Offices: ${counts.offices} · '
                          'Desks: ${counts.desks} · '
                          'Seats: ${counts.seats}',
                ),
                // #180 — own additive line: the four-count key keeps its
                // placeholders untouched across all locales.
                Text(
                  l10n?.workspaceXmlImportPreviewAccessories(
                          counts.accessories) ??
                      'Accessories: ${counts.accessories}',
                ),
                const SizedBox(height: 12),
                Text(
                  l10n?.workspaceXmlImportPreviewWarning ??
                      'The current floor plan will be deleted and replaced, '
                          'and the workspace settings will be overwritten. '
                          'This cannot be undone.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ],
            ),
            actions: [
              TextButton(
                key: const Key('workspaceXmlImportCancel'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n?.commonCancel ?? 'Cancel'),
              ),
              FilledButton(
                key: const Key('workspaceXmlImportConfirm'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                    l10n?.workspaceXmlImportConfirm ?? 'Replace and import'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
      if (!mounted) return;

      // Floor plan first — the RPC is the step that can refuse (owner
      // check, reservations); nothing else is touched when it does.
      await ref
          .read(workspaceImportRepositoryProvider)
          .importFloorPlan(workspace.id, data);
      // Settings ride the EXISTING owner writers (#153/#155/#146). The
      // workspace NAME has no update path yet and is deliberately skipped.
      final repository = ref.read(workspaceRepositoryProvider);
      await repository.updateWorkspaceLocale(
        workspace.id,
        countryCode: data.settings.countryCode,
        currencyCode: data.settings.currencyCode,
        timezone: data.settings.timezone,
      );
      await repository.setPaymentInstructions(
        workspace.id,
        PaymentInstructions.fromDb(data.settings.paymentInstructions),
      );
      await repository.setFeatureFlags(workspace.id, data.settings.featureFlags);

      ref.invalidate(myWorkspacesProvider);
      ref.invalidate(levelsProvider);
      ref.invalidate(floorPlanProvider);
      ref.invalidate(targetNamesProvider);
      // #180 — the import may have upserted the catalog and re-created
      // every seat assignment.
      ref.invalidate(accessoriesProvider);
      ref.invalidate(seatAccessoriesProvider);
      if (!mounted) return;
      // Re-seed the form so the imported settings show immediately.
      setState(() => _seeded = false);
      AppSnack.success(
        context,
        l10n?.workspaceXmlImportSuccess ?? 'Workspace imported.',
      );
    } on PostgrestException catch (e, st) {
      debugPrint('workspace XML import failed: $e\n$st');
      TraceLogger.instance.error('workspace', 'workspace XML import failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      AppSnack.error(
        context,
        e.message.contains(kWorkspaceHasReservationsError)
            ? (l10n?.workspaceXmlImportReservationsError ??
                'This workspace already has reservations, so its floor plan '
                    'cannot be replaced. Imports are only possible before '
                    'the first booking.')
            : (l10n?.workspaceGenericError ??
                'Something went wrong. Please try again.'),
      );
    } catch (e, st) {
      debugPrint('workspace XML import failed: $e\n$st');
      TraceLogger.instance.error('workspace', 'workspace XML import failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    if (workspace != null && !_seeded) {
      _seeded = true;
      _countryCode = workspace.countryCode;
      _currency.text = workspace.currencyCode;
      _timezone.text = workspace.timezone;
      final instructions =
          PaymentInstructions.fromDb(workspace.paymentInstructions);
      _iban.text = instructions.iban;
      _paypalMe.text = instructions.paypalMe;
      _reference.text = instructions.reference;
      _wero.text = instructions.wero;
      _lydia.text = instructions.lydia;
      _wise.text = instructions.wise;
      _whatsappGroup.text = workspace.whatsappGroup;
      _invitationTemplate.text = workspace.invitationTemplate;
      _deskOpacity = workspace.deskOpacity;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.workspaceSettingsTitle ?? 'Workspace'),
      ),
      body: workspace == null
          ? const LoadingView()
          : Form(
              key: _formKey,
              child: ListView(
                padding: AppSpacing.gutterAll,
                children: [
                  Text(
                    workspace.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const Key('workspaceSettingsCountry'),
                    initialValue: _countryCode,
                    decoration: InputDecoration(
                      labelText: l10n?.workspaceCountryLabel ?? 'Country',
                    ),
                    items: [
                      for (final country in CountryCatalog.countries)
                        DropdownMenuItem(
                          value: country.code,
                          child:
                              Text(localizedCountryName(l10n, country.code)),
                        ),
                    ],
                    onChanged: _busy ? null : _onCountryPicked,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('workspaceSettingsCurrency'),
                    controller: _currency,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: l10n?.workspaceCurrencyLabel ?? 'Currency',
                      helperText: l10n?.workspaceSettingsCurrencyHelper ??
                          'Defaults from the country — override if your '
                              'community bills in another currency.',
                    ),
                    // Same 3-letter shape check (and shared "Required"
                    // copy) as the onboarding form; the 0001 column check
                    // re-validates server-side.
                    validator: (value) =>
                        RegExp(r'^[A-Za-z]{3}$').hasMatch(value?.trim() ?? '')
                            ? null
                            : (l10n?.authFieldRequired ?? 'Required'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('workspaceSettingsTimezone'),
                    controller: _timezone,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: l10n?.workspaceTimezoneLabel ?? 'Time zone',
                    ),
                    validator: (value) =>
                        (value?.trim().isNotEmpty ?? false)
                            ? null
                            : (l10n?.authFieldRequired ?? 'Required'),
                  ),
                  const SizedBox(height: 24),
                  // #155 — payment instructions members see on an unpaid
                  // statement. All optional; empty = no card renders.
                  Text(
                    l10n?.paymentInstructionsTitle ?? 'Payment instructions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n?.paymentInstructionsHelper ??
                        'Shown to members on an unpaid statement. Leave '
                            'empty to show nothing.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('workspaceSettingsIban'),
                    controller: _iban,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      // The acronym is identical in every locale; the key
                      // exists so the parity gate covers the whole set.
                      labelText:
                          l10n?.paymentInstructionsIbanTitle ?? 'IBAN',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('workspaceSettingsPaypalMe'),
                    controller: _paypalMe,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: l10n?.paymentInstructionsPaypalLabel ??
                          'PayPal.me link or handle',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // #192 — Wero / Lydia / Wise ride the same blob; the
                  // labels carry the expected value shape (phone number,
                  // username, Wisetag/link).
                  TextFormField(
                    key: const Key('workspaceSettingsWero'),
                    controller: _wero,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: l10n?.paymentInstructionsWeroLabel ??
                          'Wero phone number',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('workspaceSettingsLydia'),
                    controller: _lydia,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: l10n?.paymentInstructionsLydiaLabel ??
                          'Lydia phone number or username',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('workspaceSettingsWise'),
                    controller: _wise,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: l10n?.paymentInstructionsWiseLabel ??
                          'Wisetag or Wise payment link',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('workspaceSettingsReference'),
                    controller: _reference,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: l10n?.paymentInstructionsReferenceLabel ??
                          'Payment reference hint',
                    ),
                  ),
                  const SizedBox(height: 24),
                  // #231 — the community's WhatsApp group. Own small
                  // section (mirrors the payment-instructions block);
                  // the link is shown to members in the directory (#232).
                  Text(
                    l10n?.workspaceWhatsappGroupTitle ?? 'WhatsApp group',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n?.workspaceWhatsappGroupHelper ??
                        'Shown to members so they can join the '
                            'community\'s WhatsApp group. Paste the '
                            'group\'s invite link '
                            '(https://chat.whatsapp.com/…). Leave empty '
                            'to show nothing.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('workspaceSettingsWhatsappGroup'),
                    controller: _whatsappGroup,
                    enabled: !_busy,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: l10n?.workspaceWhatsappGroupLabel ??
                          'WhatsApp group link',
                    ),
                    // Same prefix check as the 0029 column constraint
                    // (WhatsappGroupRules cross-pins both); empty is
                    // valid and clears the link.
                    validator: (value) =>
                        WhatsappGroupRules.isValid(value?.trim() ?? '')
                            ? null
                            : (l10n?.workspaceWhatsappGroupInvalid ??
                                'Must be a chat.whatsapp.com invite link'),
                  ),
                  const SizedBox(height: 24),
                  // 0049 — the invitation message template. Tags are
                  // listed as selectable chips; empty uses the localized
                  // built-in message (invite sheet on the ID & QR screen).
                  Text(
                    l10n?.invitationTemplateTitle ?? 'Invitation message',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n?.invitationTemplateHelp ??
                        'Sent when you invite someone via WhatsApp, SMS, '
                            'or share. Leave empty to use the built-in '
                            'message in the chosen language. '
                            'Available tags:',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in InvitationTags.all)
                        ActionChip(
                          key: ValueKey('invitation-tag-$tag'),
                          label: Text(tag),
                          onPressed: _busy
                              ? null
                              : () {
                                  final t = _invitationTemplate;
                                  final sel = t.selection.isValid
                                      ? t.selection.start
                                      : t.text.length;
                                  t.text = t.text.substring(0, sel) +
                                      tag +
                                      t.text.substring(sel);
                                  t.selection = TextSelection.collapsed(
                                    offset: sel + tag.length,
                                  );
                                },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('workspaceSettingsInvitationTemplate'),
                    controller: _invitationTemplate,
                    enabled: !_busy,
                    minLines: 3,
                    maxLines: 8,
                    maxLength: invitationTemplateMaxLength,
                    decoration: InputDecoration(
                      labelText: l10n?.invitationTemplateTitle ??
                          'Invitation message',
                      hintText: l10n?.invitationTemplateHint ??
                          'Custom invitation message using the tags above…',
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 0040 — desk transparency. Rides the same Save button.
                  Text(
                    l10n?.workspaceDeskTransparencyTitle ?? 'Desk transparency',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n?.workspaceDeskTransparencyHelper ??
                        'Lower the desk opacity so a level\'s background photo '
                            'shows through the tables.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Slider(
                    key: const Key('workspaceSettingsDeskOpacity'),
                    min: 20,
                    max: 100,
                    divisions: 16,
                    value: _deskOpacity.toDouble(),
                    label: l10n?.workspaceDeskOpacityValue(_deskOpacity) ??
                        'Opacity: $_deskOpacity%',
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _deskOpacity = v.round()),
                  ),
                  Text(
                    l10n?.workspaceDeskOpacityValue(_deskOpacity) ??
                        'Opacity: $_deskOpacity%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('workspaceSettingsSave'),
                    onPressed: _busy ? null : () => _save(workspace.id),
                    child: Text(l10n?.commonSave ?? 'Save'),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  // #164 — versioned XML snapshot of settings + floor
                  // plan; the whole screen is owner-only already.
                  ListTile(
                    key: const Key('workspaceSettingsExportXml'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.upload_file_outlined),
                    title: Text(
                      l10n?.workspaceXmlExport ?? 'Export workspace (XML)',
                    ),
                    subtitle: Text(
                      l10n?.workspaceXmlExportSubtitle ??
                          'Settings and floor plan as a shareable file. '
                              'No members, bookings or money data.',
                    ),
                    enabled: !_busy,
                    onTap: () => _exportXml(workspace),
                  ),
                  // Human-readable PDF snapshot — settings + every member +
                  // the whole floor plan. Owner-only like the rest.
                  ListTile(
                    key: const Key('workspaceSettingsExportPdf'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.picture_as_pdf_outlined),
                    title: Text(
                      l10n?.workspaceConfigPdfExport ??
                          'Export configuration (PDF)',
                    ),
                    subtitle: Text(
                      l10n?.workspaceConfigPdfExportSubtitle ??
                          'Complete snapshot: settings, all members and the '
                              'floor plan.',
                    ),
                    enabled: !_busy,
                    onTap: () => _exportConfigPdf(workspace),
                  ),
                  // #165 — restore from an exported file. Replaces the
                  // floor plan (guarded by preview + destructive confirm);
                  // the whole screen is owner-only already.
                  ListTile(
                    key: const Key('workspaceSettingsImportXml'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.file_open_outlined),
                    title: Text(
                      l10n?.workspaceXmlImport ?? 'Import workspace (XML)',
                    ),
                    subtitle: Text(
                      l10n?.workspaceXmlImportSubtitle ??
                          'Restore settings and floor plan from an exported '
                              'file. Replaces the current floor plan.',
                    ),
                    enabled: !_busy,
                    onTap: () => _importXml(workspace),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  // Irreversible reset (0039). Its own error-tinted section so
                  // it reads as clearly separate from the backup tools above.
                  Text(
                    l10n?.workspaceDangerZone ?? 'Danger zone',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                  ListTile(
                    key: const Key('workspaceSettingsReset'),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.delete_forever_outlined,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      l10n?.workspaceResetTitle ?? 'Reset workspace',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    subtitle: Text(
                      l10n?.workspaceResetSubtitle ??
                          'Delete all bookings, money and the floor plan. '
                              'Keeps settings and members.',
                    ),
                    enabled: !_busy,
                    onTap: () => _resetWorkspace(workspace),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Destructive reset confirmation (0039): the confirm button unlocks only
/// once the owner types [phrase] exactly (case-insensitive). Owns its text
/// controller so it never outlives the dialog's dismissal.
class _ResetConfirmDialog extends StatefulWidget {
  const _ResetConfirmDialog({required this.phrase});

  final String phrase;

  @override
  State<_ResetConfirmDialog> createState() => _ResetConfirmDialogState();
}

class _ResetConfirmDialogState extends State<_ResetConfirmDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final matches = _controller.text.trim().toLowerCase() ==
        widget.phrase.toLowerCase();
    return AlertDialog(
      title:
          Text(l10n?.workspaceResetDialogTitle ?? 'Reset this workspace?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.workspaceResetWarning ??
                'This permanently deletes every reservation, all money and '
                    'ledger entries, the activity feed, and the entire floor '
                    'plan. Settings and members are kept. This cannot be '
                    'undone.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.error),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            key: const Key('workspaceResetConfirmField'),
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n?.workspaceResetConfirmLabel(widget.phrase) ??
                  'Type "${widget.phrase}" to confirm',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          key: const Key('workspaceResetConfirm'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed:
              matches ? () => Navigator.of(context).pop(true) : null,
          child: Text(l10n?.workspaceResetConfirmButton ?? 'Reset workspace'),
        ),
      ],
    );
  }
}
