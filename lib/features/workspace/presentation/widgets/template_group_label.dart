// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../../l10n/app_localizations.dart';
import '../../domain/template_preview.dart';

/// #1280 — the words for a template group, shared by the apply preview and
/// the publish flow so the same group never has two names.
String templateGroupLabel(AppLocalizations? l10n, TemplateGroup group) =>
    switch (group) {
      TemplateGroup.space => l10n?.libraryGroupSpace ?? 'Space & plan',
      TemplateGroup.hoursBooking =>
        l10n?.libraryGroupHoursBooking ?? 'Hours & booking',
      TemplateGroup.pricingCredits =>
        l10n?.libraryGroupPricingCredits ?? 'Prices & credits',
      TemplateGroup.calendarNavigation =>
        l10n?.libraryGroupCalendarNavigation ?? 'Calendar & closures',
      TemplateGroup.wording => l10n?.libraryGroupWording ?? 'Wording',
      TemplateGroup.rolesAccess =>
        l10n?.libraryGroupRolesAccess ?? 'Roles & access',
      TemplateGroup.forms => l10n?.libraryGroupForms ?? 'Forms',
      TemplateGroup.appearance => l10n?.libraryGroupAppearance ?? 'Appearance',
      TemplateGroup.documentsOperations =>
        l10n?.libraryGroupDocumentsOperations ?? 'Documents & operations',
      TemplateGroup.unknown =>
        l10n?.libraryGroupUnknown ?? 'Other — this version cannot apply it',
    };
