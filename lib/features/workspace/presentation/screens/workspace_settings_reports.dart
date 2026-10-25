// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../app/theme.dart';
import '../../../../core/files/file_names.dart';
import '../../../../core/files/file_saver.dart';
import '../../../../core/i18n/country_names.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/locale/report_language.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../money/domain/report_data_letters.dart';
import '../../../money/presentation/invoice_documents.dart';
import '../../../money/presentation/report_facts_of.dart';
import '../../../money/presentation/report_layout_actions.dart';
import '../../../money/presentation/report_strings_l10n.dart';
import '../../../money/providers/money_providers.dart';
import '../../../plan/presentation/plan_png.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../application/workspace_backup_commands.dart';
import '../../domain/booking_granularity.dart';
import '../../domain/launch_review.dart';
import '../../domain/member.dart';
import '../../domain/overage_policy.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_config_report.dart';
import '../../domain/workspace_data_report_builder.dart';
import '../../domain/workspace_data_report_pdf.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_permission.dart';
import '../../providers/data_report_sources.dart';
import '../../providers/local_setup_providers.dart';
import '../../providers/workspace_providers.dart';
import '../config_feature_groups.dart';
import '../config_pdf_lines.dart';
import '../excel_export.dart';
import '../launch_report.dart';
import '../member_labels.dart';
import '../workspace_configuration_report_strings.dart';
import '../workspace_data_report_strings.dart';
import 'workspace_settings_host.dart';

/// #2494 — the settings screen's printed documents: the workspace report
/// (#494), the configuration PDF and the data report (#2862). The one
/// library of the screen that reads money and the plan's printed images,
/// so the configuration section of the XML backup (#916) reads its money
/// side here too.
class WorkspaceSettingsReports {
  const WorkspaceSettingsReports(this.host);

  final WorkspaceSettingsHost host;

  BuildContext get context => host.context;
  WidgetRef get ref => host.ref;

  /// Role label for a member — owner outranks admin outranks member.
  String _granularityLabel(
    AppLocalizations l10n,
    BookingGranularity granularity,
  ) =>
      switch (granularity) {
        BookingGranularity.flexible =>
          l10n.availabilityGranularityFlexible,
        BookingGranularity.halfDay =>
          l10n.availabilityGranularityHalfDay,
        BookingGranularity.fullDay =>
          l10n.availabilityGranularityFullDay,
        BookingGranularity.hours =>
          l10n.availabilityGranularityHours,
        // Minute granularities carry their step in the label itself.
        BookingGranularity.minutes5 ||
        BookingGranularity.minutes15 ||
        BookingGranularity.minutes30 ||
        BookingGranularity.minutes60 =>
          '${granularity.stepMinutes} min',
      };

  /// #494 — the engine-based workspace report, saved to the device.
  Future<void> exportWorkspaceReport() async {
    final context = this.context;
    final l10n = context.l10n;
    await host.runTool('workspace report export failed', () async {
        await warmLetterDocProviders(ref, 'workspace');
        if (!context.mounted) return;
        // #496 — the workspace report prints in the workspace's own
        // language chain (no member involved).
        final String language;
        try {
          language = resolveMemberReportLanguage(ref);
        } on AmbiguousReportLanguage {
          AppSnack.error(
            context,
            l10n.reportLanguageAmbiguous,
          );
          return;
        }
        final docL10n = l10nForLanguage(language);
        final data = workspaceReportData(
            reportStringsFor(context, l10n: docL10n, localeName: language),
            workspaceFactsOf(ref, docL10n));
        final report = renderLetterDoc(context, ref,
            docId: 'workspace', data: data, language: language);
        final pdf = await letterDocPdf(context, ref,
            report: report,
            title: docL10n.reportDocWorkspace,
            layoutXml: letterLayoutXml(ref,
                docId: 'workspace', language: language),
            data: data);
        if (!context.mounted) return;
        final path = await ref.read(fileSaverProvider)(
          bytes: pdf.bytes,
          fileName: pdf.fileName,
        );
        if (!context.mounted) return;
        announceSaved(context, l10n, path);
    });
  }

  /// #2862 — the configuration PDF's hours, VAT rates in force and sites;
  /// the rates and sites only when their features are on; #2876 — the
  /// readiness report when the setup guide is.
  Future<({String hours, List<String> vatRates, List<String> sites,
      List<LaunchReportLine> readiness})>
      _configPdfExtras(Set<WorkspaceFeature> features, String? locale,
          String workspaceId) async {
    final l10n = context.l10n;
    final hours = await ref.read(workHoursProvider.future);
    final rates = features.contains(WorkspaceFeature.vatManagement)
        ? await ref.read(vatRatesProvider.future) : null;
    final sites = features.contains(WorkspaceFeature.multiSite)
        ? await ref.read(sitesProvider.future) : null;
    final setup = features.contains(WorkspaceFeature.setupGuide)
        ? await ref.read(workspaceSetupStatusProvider(workspaceId).future)
        : null;
    return (
      hours: configWorkingHours(hours),
      vatRates: configVatRates(locale, [
        ...?rates?.where((r) => r.active)
            .map((r) => (label: r.label, percent: r.percent)),
      ]),
      sites: configSites(sites ?? []),
      readiness: setup == null
          ? const <LaunchReportLine>[]
          : launchReportLines(l10n, LaunchReview.from(setup)),
    );
  }

  /// Renders a complete, human-readable PDF snapshot of the workspace —
  /// settings, every member with their role and status, enabled features,
  /// availability and the whole floor plan. Unlike the XML export (a
  /// machine backup, no members), this is the owner's shareable
  /// configuration record.
  Future<void> exportConfigPdf(Workspace workspace) async {
    final context = this.context;
    final l10n = context.l10n;
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    await host.runTool('workspace config PDF export failed', () async {
          // #2898 — each level's plan drawn as the data report draws it.
          final printed = await levelReportPlans(ref,
              colors: DeskiloTheme.light().colorScheme);
          final plans = printed.levels;
          final members = await ref.read(workspaceMembersProvider.future);
          final names = await ref.read(memberNamesProvider.future);
          final granularity = await ref.read(bookingGranularityProvider.future);
          final features = await ref.read(enabledFeaturesProvider.future);
          final openWeekdays = await ref.read(openWeekdaysProvider.future);
          final closures = await ref.read(closureDaysProvider.future);
          final extras =
              await _configPdfExtras(features, locale, workspace.id);
          // Formatted once: the l10n branch and its fallback must carry
          // the same stamp.
          final generatedOn =
              DateFormat.yMMMd(locale).format(ref.read(clockProvider).now());

          final configMembers = _configMembers(l10n, members, names);

          final strings = workspaceConfigurationStrings(l10n);

          final data = workspaceConfigurationReportData(WorkspaceConfigDocument(strings: strings,
            workspaceName: workspace.name,
            generatedOnLabel: l10n.workspaceConfigPdfGeneratedOn(generatedOn),
            countryLabel: localizedCountryName(l10n, workspace.countryCode),
            currencyCode: workspace.currencyCode,
            timezone: workspace.timezone,
            granularityLabel: _granularityLabel(l10n, granularity),
            members: configMembers,
            featureGroups: configFeatureGroups(l10n, features),
            openDaysLabel: configOpenDays(locale, openWeekdays),
            closureLabels: configClosures(locale, closures),
            workingHoursLabel: extras.hours,
            vatRates: extras.vatRates,
            sites: extras.sites,
            readinessTitle: l10n.setupLaunchReportTitle,
            readiness: extras.readiness,
            levels: plans,
            planImages: printed.pngs.keys.toSet(),
            levelPrices: {
              for (final entry in plans)
                if (entry.level.bookableAsWhole)
                  entry.level.id: entry.level.priceCents == 0
                      ? ''
                      : moneyFormat(workspace.currencyCode, locale: locale).formatMinor(entry.level.priceCents),
            },
            hasCustomInvitationTemplate:
                workspace.invitationTemplate.trim().isNotEmpty));
          await warmLetterDocProviders(ref, 'workspace_configuration');
          if (!context.mounted || ref.read(currentWorkspaceProvider).value?.id != workspace.id) return;
          final report = renderLetterDoc(context, ref,
              docId: 'workspace_configuration', data: data);
          final pdf = await letterPdfOf(ref, (report: report,
              title: strings.title, data: data, images: configPlanImages(printed.pngs),
              layoutXml: letterLayoutXml(ref, docId: 'workspace_configuration', l10n: l10n)),
              pageLabel: l10n.invoicePdfPage, watermark: developmentMark(context, ref));
          if (!context.mounted) return;
          final path = await ref.read(fileSaverProvider)(
            bytes: pdf.bytes,
            // Slugged (security audit): a raw name may carry path
            // separators — the one export site that skipped the slug.
            fileName: '${safeFileSlug(workspace.name)}-configuration.pdf',
          );
          if (!context.mounted) return;
          announceSaved(context, l10n, path);
    });
  }
  /// The members of the configuration PDF, sorted by name like the
  /// directory, each with role, status and allowances.
  List<ConfigPdfMember> _configMembers(AppLocalizations l10n,
      List<Member> members, Map<String, String> names) {
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
          l10n.overagePolicyBlocked,
        OveragePolicy.payg =>
          l10n.overagePolicyPayg,
        OveragePolicy.package =>
          l10n.overagePolicyPackage,
      },
      if (member.maxActiveReservations != null)
        'max ${member.maxActiveReservations}',
      if (member.canReserveLevel)
        l10n.levelPermissionAllowed,
    ];
    return parts.join(' · ');
  }

  final configMembers = <ConfigPdfMember>[
    for (final member in sortedMembers)
      (
        name: names[member.id] ?? '',
        role: memberRoleLabel(l10n, member),
        status: memberStatusLabel(l10n, member.status),
        details: memberDetails(member),
      ),
  ];
    return configMembers;
  }

  /// #2862 — the same rows as the workbook, as a readable report, under
  /// the export it reads and the same permission.
  List<Widget> dataReportTiles(AppLocalizations l10n, Workspace workspace) => [
        if (ref
                .watch(enabledFeaturesSyncProvider)
                .contains(WorkspaceFeature.dataReport) &&
            ref
                .watch(myPermissionsProvider)
                .contains(WorkspacePermission.exportData))
          ListTile(
            key: const Key('workspaceSettingsDataReport'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: Text(l10n.featureDataReportTitle),
            subtitle: Text(l10n.dataReportSubtitle),
            enabled: !host.busy,
            onTap: () => _exportDataReport(workspace),
          ),
      ];

  /// The workspace data report: the workbook's rows as a readable PDF,
  /// with the plan of each level drawn as the app draws it.
  Future<void> _exportDataReport(Workspace workspace) async {
    final context = this.context;
    final l10n = context.l10n;
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    final watermark = developmentMark(context, ref);
    await host.whileBusy(() => runGuarded(
      context,
      domain: 'workspace',
      message: 'workspace data report failed',
      errorText: l10n.dataReportFailed,
      action: () async {
        final details = await readDataReportDetails(ref, workspace);
        final buying = await readDataReportPurchasing(ref, workspace.id);
        final report = buildWorkspaceDataReport(details,
            purchases: buying.purchases, suppliers: buying.suppliers);
        final colors = DeskiloTheme.light().colorScheme;
        // #2898 — each level's photo under its plan, read as the editor
        // reads it; one that fails prints the plan without it.
        final images = await reportPlanPngs(details.plansByLevel,
            colors: colors,
            photoLevels: {
              for (final level in details.levels)
                if (level.hasBackground) level.id,
            },
            background: (id) => ref.read(levelBackgroundProvider(id).future));
        final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
        final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
        final pdf = await buildWorkspaceDataReportPdf(
          WorkspaceDataReportPdfRequest(
            report: report,
            strings: workspaceDataReportStrings(l10n,
                currency: workspace.currencyCode, locale: locale),
            generatedAt: WorkspaceTime.wall(ref.read(clockProvider).now()),
            baseFont: pw.Font.ttf(regular),
            boldFont: pw.Font.ttf(bold),
            planImages: images,
            watermark: watermark,
          ),
        );
        if (!context.mounted) return;
        final path = await ref.read(fileSaverProvider)(
          bytes: pdf,
          fileName: '${safeFileSlug(workspace.name)}-data-report.pdf',
        );
        if (!context.mounted) return;
        announceSaved(context, l10n, path);
      },
    ));
  }

}

/// #916 — what the XML backup carries beside the plan when the
/// configuration transfer is on: the configuration section and the
/// plan's references by name.
typedef XmlConfiguration = ({
  Map<String, Object?>? configuration,
  Map<String, String> siteNames,
  Map<String, String> vatRateLabels,
});

/// Reads [XmlConfiguration] for [workspaceId]; empty with the feature off.
Future<XmlConfiguration> readXmlConfiguration(
    WidgetRef ref, String workspaceId) async {
  if (!ref
      .read(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.configurationTransfer)) {
    return (
      configuration: null,
      siteNames: const <String, String>{},
      vatRateLabels: const <String, String>{},
    );
  }
  final configuration = await exportWorkspaceConfiguration(ref, workspaceId);
  final sites = await ref.read(sitesProvider.future);
  final rates = await ref.read(vatRatesProvider.future);
  return (
    configuration: configuration,
    siteNames: {for (final site in sites) site.id: site.name},
    vatRateLabels: {for (final rate in rates) rate.id: rate.label},
  );
}

/// What an imported configuration section may have rewritten, read again.
void refreshConfigurationReads(WidgetRef ref) {
  ref
    ..invalidate(sitesProvider)
    ..invalidate(vatRatesProvider);
}
