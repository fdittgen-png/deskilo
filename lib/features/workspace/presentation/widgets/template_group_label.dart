// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../../l10n/app_localizations.dart';
import '../../domain/template_preview.dart';

/// #1280 — the words for a template group, shared by the apply preview and
/// the publish flow so the same group never has two names.
String templateGroupLabel(AppLocalizations l10n, TemplateGroup group) =>
    switch (group) {
      TemplateGroup.space => l10n.libraryGroupSpace,
      TemplateGroup.hoursBooking =>
        l10n.libraryGroupHoursBooking,
      TemplateGroup.pricingCredits =>
        l10n.libraryGroupPricingCredits,
      TemplateGroup.calendarNavigation =>
        l10n.libraryGroupCalendarNavigation,
      TemplateGroup.wording => l10n.libraryGroupWording,
      TemplateGroup.rolesAccess =>
        l10n.libraryGroupRolesAccess,
      TemplateGroup.forms => l10n.libraryGroupForms,
      TemplateGroup.appearance => l10n.libraryGroupAppearance,
      TemplateGroup.documentsOperations =>
        l10n.libraryGroupDocumentsOperations,
      TemplateGroup.unknown =>
        l10n.libraryGroupUnknown,
    };
