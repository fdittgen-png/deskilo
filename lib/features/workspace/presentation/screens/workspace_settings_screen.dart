// SPDX-License-Identifier: 0BSD
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/country/country_catalog.dart';
import '../../../../core/i18n/workspace_locale_fields.dart';
import '../../../../core/format/cents.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/help/help_hint.dart';
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
import '../../../../core/files/file_names.dart';
import '../../../events/providers/event_providers.dart';
import '../../../plan/providers/accessory_providers.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../domain/booking_granularity.dart';
import '../../domain/space_code_entries.dart';
import '../widgets/space_codes_options_dialog.dart';
import '../../domain/member.dart';
import '../../domain/overage_policy.dart';
import '../../domain/payment_instructions.dart';
import '../../domain/invitation_message.dart';
import '../../domain/space_codes_pdf.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_config_pdf.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_import.dart';
import '../../domain/workspace_xml.dart';
import '../../providers/workspace_import_providers.dart';
import '../../../money/presentation/widgets/billing_rules_dialog.dart';
import '../../../money/presentation/widgets/dunning_rules_dialog.dart';
import '../../../money/presentation/widgets/invoice_template_sheet.dart';
import '../../providers/workspace_providers.dart';
import '../excel_export.dart';
import '../country_names.dart';
import '../feature_names.dart';
import '../../../../core/time/clock.dart';
import '../../../money/presentation/invoice_actions.dart';
import '../../../money/presentation/batch_cover.dart';
import '../../../../core/locale/report_language.dart';

/// Owner-only workspace settings: identity (country/currency/time zone,
/// #153 — a country pick re-defaults both from [CountryCatalog], a
/// manual currency typed afterwards wins), payment instructions, the
/// WhatsApp group link, desk transparency, invitation template, the
/// backup tools (XML export/import, configuration PDF, space-QR PDF)
/// and the guarded workspace reset (0039).
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
  // #231 — the community's WhatsApp group invite link (directory, #232).
  final _whatsappGroup = TextEditingController();
  final _workspaceAddress = TextEditingController();
  final _invitationTemplate = TextEditingController();
  // 0040 — desk fill opacity percentage (20..100); rides the Save button.
  int _deskOpacity = 100;
  String? _countryCode;
  // #486 — the workspace's own language ('' = sender's app language)
  // and the per-language invitation drafts the chips page through.
  String _defaultLocale = '';
  String _templateLang = 'en';
  final Map<String, String> _templateDrafts = {};
  bool _busy = false;

  static const Map<String, String> _languages = {
    'en': 'English',
    'fr': 'Français',
    'de': 'Deutsch',
    'es': 'Español',
    'it': 'Italiano',
  };

  /// Stash the visible template into its language's draft, then show
  /// [lang]'s draft.
  void _switchTemplateLang(String lang) {
    setState(() {
      _templateDrafts[_templateLang] = _invitationTemplate.text;
      _templateLang = lang;
      _invitationTemplate.text = _templateDrafts[lang] ?? '';
    });
  }

  /// Seed the form ONCE from the loaded workspace; later rebuilds must
  /// not clobber the owner's in-progress edits.
  bool _seeded = false;

  @override
  void dispose() {
    _currency.dispose();
    _timezone.dispose();
    _whatsappGroup.dispose();
    _workspaceAddress.dispose();
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
          // #231 — the WhatsApp group link rides the same Save through its
          // own setter (setPaymentInstructions shape); '' clears it.
          await repository.setWhatsappGroup(
            workspaceId,
            _whatsappGroup.text.trim(),
          );
          // 0060 — the invoice-letterhead address rides the same Save.
          await repository.setWorkspaceAddress(
            workspaceId,
            _workspaceAddress.text.trim(),
          );
          // #486 — per-language invitation templates: the visible text
          // is stashed first, empty drafts mean "built-in message for
          // that language". The legacy single template (0049) is cleared
          // — its content was seeded into every language's draft.
          _templateDrafts[_templateLang] = _invitationTemplate.text;
          await repository.setInvitationTemplates(
            workspaceId,
            Map.of(_templateDrafts),
          );
          await repository.setInvitationTemplate(workspaceId, '');
          // #486 — the workspace's own language.
          await repository.setWorkspaceLanguage(
            workspaceId,
            _defaultLocale,
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
        BookingGranularity.hours =>
          l10n?.availabilityGranularityHours ?? 'Real hours',
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
  /// #494 — the engine-based workspace report, saved to the device.
  Future<void> _exportWorkspaceReport() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    await runGuarded(
      context,
      domain: 'workspace',
      message: 'workspace report export failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        await warmLetterDocProviders(ref, 'workspace');
        if (!mounted) return;
        // #496 — the workspace report prints in the workspace's own
        // language chain (no member involved).
        final String language;
        try {
          language = resolveMemberReportLanguage(ref);
        } on AmbiguousReportLanguage {
          AppSnack.error(
            context,
            l10n?.reportLanguageAmbiguous ??
                'This country has several languages — set the '
                    'workspace language in Workspace settings first.',
          );
          return;
        }
        final docL10n = l10nForLanguage(language);
        final data = workspaceReportData(context, ref,
            l10nOverride: docL10n, localeName: language);
        final report = renderLetterDoc(context, ref,
            docId: 'workspace', data: data, language: language);
        final pdf = await letterDocPdf(context, ref,
            report: report, title: docL10n.reportDocWorkspace);
        if (!mounted) return;
        final path = await ref.read(fileSaverProvider)(
          bytes: pdf.bytes,
          fileName: pdf.fileName,
        );
        if (!mounted) return;
        _announceSaved(l10n, path);
      },
    );
    if (mounted) setState(() => _busy = false);
  }

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
          // Formatted once: the l10n branch and its fallback must carry
          // the same stamp.
          final generatedOn =
              dateFormat.format(ref.read(clockProvider).now());
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
            generatedOnLabel: l10n?.workspaceConfigPdfGeneratedOn(generatedOn) ??
                'Generated on $generatedOn',
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
            // Slugged (security audit): a raw name may carry path
            // separators — the one export site that skipped the slug.
            fileName: '${safeFileSlug(workspace.name)}-configuration.pdf',
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

  /// Prints the space QR sheet (field request): one card per desk,
  /// office, level and chair, in an A4 grid — saved to Downloads.
  /// #584 — the owner first picks the card size (S/M/L) and which
  /// information rides each card (printed AND embedded in the QR).
  Future<void> _exportSpaceCodes(Workspace workspace) async {
    final l10n = AppLocalizations.of(context);
    final options = await showDialog<SpaceCodesOptions>(
      context: context,
      builder: (_) => const SpaceCodesOptionsDialog(),
    );
    if (options == null || !mounted) return;
    setState(() => _busy = true);
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'space codes export failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        // #671 — the surrounding wording comes from report management;
        // the cards stay with the renderer. Read FIRST: it needs the
        // context, and everything below this line is an async gap.
        final cover = batchCover(context, ref, docId: 'space_codes', data: {
          'workspace': workspace.name,
          'issued': DateFormat.yMMMMd().format(ref.read(clockProvider).now()),
        });
        final levels = await ref.read(levelsProvider.future);
        final entries = buildSpaceCodeEntries(
          workspaceId: workspace.id,
          workspaceName: workspace.name,
          plans: [
            for (final level in levels)
              (level, await ref.read(floorPlanProvider(level.id).future)),
          ],
          info: options.info,
          kindLabels: (
            level: l10n?.spaceKindLevel ?? 'Level',
            office: l10n?.spaceKindOffice ?? 'Office',
            desk: l10n?.spaceKindDesk ?? 'Desk',
            seat: l10n?.spaceKindSeat ?? 'Seat',
          ),
        );
        if (entries.isEmpty) {
          if (!mounted) return;
          AppSnack.info(
            context,
            l10n?.planNoLevels ?? 'The workspace has no floor plan yet.',
          );
          return;
        }
        final regular =
            await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
        final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
        final bytes = await buildSpaceCodesPdf(
          workspaceName: workspace.name,
          entries: entries,
          baseFont: pw.Font.ttf(regular),
          boldFont: pw.Font.ttf(bold),
          size: options.size,
          qrSize: options.qrSize,
          coverHeader: cover.header,
          coverBody: cover.body,
          coverFooter: cover.footer,
        );
        final path = await ref.read(fileSaverProvider)(
          bytes: bytes,
          fileName: '${safeFileSlug(workspace.name)}-space-codes.pdf',
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

  /// #763 — a control with no free suffix slot gets the ? at its side.
  Widget _withDot(Widget field, String topic) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Expanded(child: field), HelpDot(topic)],
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final helpTopic = l10n?.helpHintWorkspaceTopic ?? 'Workspace settings';
    if (workspace != null && !_seeded) {
      _seeded = true;
      _countryCode = workspace.countryCode;
      _currency.text = workspace.currencyCode;
      _timezone.text = workspace.timezone;
      // #486 — one draft per language; a workspace still on the legacy
      // single template (0049) sees it in every language until it saves.
      final legacy = workspace.invitationTemplate.trim();
      final hasPerLocale = workspace.invitationTemplates.values
          .any((t) => (t as String? ?? '').trim().isNotEmpty);
      for (final lang in _languages.keys) {
        _templateDrafts[lang] = hasPerLocale
            ? ((workspace.invitationTemplates[lang] as String?) ?? '')
            : legacy;
      }
      _defaultLocale = workspace.defaultLocale;
      _templateLang = _languages.containsKey(_defaultLocale)
          ? _defaultLocale
          : 'en';
      _whatsappGroup.text = workspace.whatsappGroup;
      _workspaceAddress.text = workspace.address;
      _invitationTemplate.text = _templateDrafts[_templateLang] ?? '';
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
                  // #606 — contextual how-to; gated inside the widget.
                  const HelpHint(HelpHintId.workspaceSettings),
                  Text(
                    workspace.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _withDot(
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
                            child: Text(
                                localizedCountryName(l10n, country.code)),
                          ),
                      ],
                      onChanged: _busy ? null : _onCountryPicked,
                    ),
                    helpTopic,
                  ),
                  const SizedBox(height: 12),
                  // #711 — currency picker and time-zone search, in
                  // core/i18n so the onboarding form can reuse them.
                  _withDot(
                    WorkspaceLocaleFields(
                      currency: _currency,
                      timezone: _timezone,
                      enabled: !_busy,
                      onTimezonePicked: (zone) =>
                          setState(() => _timezone.text = zone),
                    ),
                    helpTopic,
                  ),
                  const SizedBox(height: 12),
                  // #486 — the workspace's own language: invitations
                  // default to it.
                  _withDot(
                    DropdownButtonFormField<String>(
                      key: const Key('workspaceSettingsLanguage'),
                      initialValue: _defaultLocale,
                      decoration: InputDecoration(
                        labelText: l10n?.workspaceLanguageLabel ??
                            'Workspace language',
                        helperMaxLines: 3,
                        helperText: l10n?.workspaceLanguageHelper ??
                            'Invitations are written in this language by '
                                'default.',
                      ),
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text(l10n?.workspaceLanguageUnset ??
                              "Sender's app language"),
                        ),
                        for (final entry in _languages.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => setState(
                              () => _defaultLocale = value ?? ''),
                    ),
                    helpTopic,
                  ),
                  const SizedBox(height: 12),
                  // 0060 — the postal address printed as the invoice
                  // letterhead. Lives with the other identity basics.
                  TextFormField(
                    key: const Key('workspaceSettingsAddress'),
                    controller: _workspaceAddress,
                    enabled: !_busy,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: l10n?.workspaceAddressLabel ??
                          'Workspace address',
                      suffixIcon: HelpDot(helpTopic),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // #486 — payments & billing are SCREENS, not form
                  // fields: the two tiles say where money settings live.
                  Text(
                    l10n?.workspacePaymentsBillingTitle ??
                        'Payments & billing',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ListTile(
                    key: const Key('workspaceSettingsPaymentMethods'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                        Icons.account_balance_wallet_outlined),
                    title: Text(l10n?.paymentInstructionsTitle ??
                        'Payment instructions'),
                    subtitle: Text(l10n?.paymentMethodsSubtitle ??
                        'IBAN, PayPal, Wero, Lydia, Wise and the '
                            'payment reference'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/payment-methods'),
                  ),
                  // 0069 — the legal identity the e-invoice needs lives
                  // on its own screen: the regime decides which fields
                  // even apply.
                  ListTile(
                    key: const Key('workspaceSettingsLegalIdentity'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.badge_outlined),
                    title: Text(l10n?.legalIdentityTitle ??
                        'Legal identity & e-invoicing'),
                    subtitle: Text(l10n?.legalIdentitySubtitle ??
                        'VAT regime and registration numbers'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/legal-identity'),
                  ),
                  const SizedBox(height: 24),
                  // #231 — the community's WhatsApp group; the link is
                  // shown to members in the directory (#232).
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
                      suffixIcon: HelpDot(helpTopic),
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
                  Row(children: [
                    Text(
                      l10n?.invitationTemplateTitle ?? 'Invitation message',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    HelpDot(helpTopic),
                  ]),
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
                  // #486 — one template per language: the chips page
                  // through the drafts, empty = built-in message.
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final entry in _languages.entries)
                        ChoiceChip(
                          key: ValueKey(
                              'workspace-invitation-lang-${entry.key}'),
                          label: Text(entry.value),
                          selected: _templateLang == entry.key,
                          onSelected: _busy
                              ? null
                              : (_) => _switchTemplateLang(entry.key),
                        ),
                    ],
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
                      suffixIcon: HelpDot(helpTopic),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 0040 — desk transparency. Rides the same Save button.
                  Row(children: [
                    Text(
                      l10n?.workspaceDeskTransparencyTitle ??
                          'Desk transparency',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    HelpDot(helpTopic),
                  ]),
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
                  // #474 — the banded report editor (invoice + every
                  // reminder level) and the dunning policy live in the
                  // app parameters too, not only behind the Invoices
                  // header. The whole screen is owner-only already.
                  if (ref
                      .watch(enabledFeaturesSyncProvider)
                      .contains(WorkspaceFeature.invoicePdfTemplate))
                  ListTile(
                    key: const Key('workspaceSettingsReportEditor'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.edit_note_outlined),
                    title: HelpDotTitle(
                      l10n?.invoiceTemplateTitle ?? 'Invoice PDF template',
                      helpTopic,
                    ),
                    subtitle: Text(
                      l10n?.invoiceTemplateHint ??
                          'Three report bands rendered on the PDF.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => showInvoiceTemplateSheet(context, ref),
                  ),
                  if (ref
                      .watch(enabledFeaturesSyncProvider)
                      .contains(WorkspaceFeature.invoicing))
                  ListTile(
                    key: const Key('workspaceSettingsDunning'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.rule_outlined),
                    title: HelpDotTitle(
                      l10n?.dunningSettingsTitle ?? 'Reminder rules',
                      helpTopic,
                    ),
                    subtitle: Text(
                      l10n?.dunningLevels ?? 'Number of reminder levels',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => showDunningRulesDialog(context, ref),
                  ),
                  // #802 — WHEN the two automatic invoice runs happen.
                  // Beside the reminder rules on purpose: issuing and
                  // chasing are the same conversation with a member.
                  if (ref.watch(enabledFeaturesSyncProvider).any((f) =>
                      f == WorkspaceFeature.subscriptionInvoices ||
                      f == WorkspaceFeature.usageInvoices))
                    ListTile(
                      key: const Key('workspaceSettingsBillingRules'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_repeat_outlined),
                      title: HelpDotTitle(
                        l10n?.billingRulesTitle ?? 'Invoice schedule',
                        l10n?.billingRulesTitle ?? 'Invoice schedule',
                      ),
                      subtitle: Text(
                        l10n?.billingRulesSubtitle ??
                            'When subscription and end-of-month invoices go out',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => showBillingRulesDialog(context, ref),
                    ),
                  // #164 — versioned XML snapshot of settings + floor
                  // plan; the whole screen is owner-only already.
                  ListTile(
                    key: const Key('workspaceSettingsExportXml'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.upload_file_outlined),
                    title: HelpDotTitle(
                      l10n?.workspaceXmlExport ?? 'Export workspace (XML)',
                      helpTopic,
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
                    title: HelpDotTitle(
                      l10n?.workspaceConfigPdfExport ??
                          'Export configuration (PDF)',
                      helpTopic,
                    ),
                    subtitle: Text(
                      l10n?.workspaceConfigPdfExportSubtitle ??
                          'Complete snapshot: settings, all members and the '
                              'floor plan.',
                    ),
                    enabled: !_busy,
                    onTap: () => _exportConfigPdf(workspace),
                  ),
                  // #494 — the workspace report through the REPORT
                  // engine: templated, translated, image-capable.
                  ListTile(
                    key: const Key('workspaceSettingsWorkspaceReport'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.summarize_outlined),
                    title: HelpDotTitle(
                      l10n?.reportDocWorkspace ?? 'Workspace report',
                      helpTopic,
                    ),
                    subtitle: Text(l10n?.reportDocWorkspaceSubtitle ??
                        'Everything about the space — through the '
                            'report editor\'s workspace template'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _exportWorkspaceReport,
                  ),
                  // Space QR codes (field request): one printable card
                  // per desk, office and level — members scan them to
                  // reserve or check in on the spot.
                  if (ref
                      .watch(enabledFeaturesSyncProvider)
                      .contains(WorkspaceFeature.spaceQrCodes))
                  ListTile(
                    key: const Key('workspaceSettingsSpaceCodes'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.qr_code_2_outlined),
                    title: HelpDotTitle(
                      l10n?.spaceCodesTitle ?? 'Space QR codes (PDF)',
                      helpTopic,
                    ),
                    subtitle: Text(
                      l10n?.spaceCodesDesc ??
                          'One printable QR card per desk, office and '
                              'level — members scan to reserve or check '
                              'in.',
                    ),
                    enabled: !_busy,
                    onTap: () => _exportSpaceCodes(workspace),
                  ),
                  // #395 — the full data workbook. The tile is the ONLY
                  // surface, so the flag gate lives here (no route to
                  // guard); headers inside the file are stable English
                  // like the XML schema, the UI around it is localized.
                  if (ref
                      .watch(enabledFeaturesSyncProvider)
                      .contains(WorkspaceFeature.dataExport))
                  ListTile(
                    key: const Key('workspaceSettingsExportExcel'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.table_view_outlined),
                    title: HelpDotTitle(
                      l10n?.workspaceExcelExport ?? 'Export data (Excel)',
                      helpTopic,
                    ),
                    subtitle: Text(
                      l10n?.workspaceExcelExportSubtitle ??
                          'Every dataset in one workbook: bookings, '
                              'payments, invoices, members and the floor '
                              'plan — a tab each.',
                    ),
                    enabled: !_busy,
                    onTap: () async {
                      setState(() => _busy = true);
                      await exportWorkspaceExcel(context, ref, workspace);
                      if (mounted) setState(() => _busy = false);
                    },
                  ),
                  // #165 — restore from an exported file. Replaces the
                  // floor plan (guarded by preview + destructive confirm);
                  // the whole screen is owner-only already.
                  ListTile(
                    key: const Key('workspaceSettingsImportXml'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.file_open_outlined),
                    title: HelpDotTitle(
                      l10n?.workspaceXmlImport ?? 'Import workspace (XML)',
                      helpTopic,
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
