// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get accessoriesTitle => 'Accessories';

  @override
  String get accessoriesEmpty => 'No accessories yet.';

  @override
  String get accessoriesNew => 'New accessory';

  @override
  String get accessoriesEdit => 'Edit accessory';

  @override
  String get accessoriesName => 'Name';

  @override
  String get accessoriesSupplement => 'Supplement per half-day';

  @override
  String accessoriesPerHalfDay(String amount) {
    return '$amount / half-day';
  }

  @override
  String get accessoriesNoSupplement => 'No supplement';

  @override
  String get accessoriesInactive => 'Inactive';

  @override
  String get accessoriesActive => 'Active';

  @override
  String get authSignInTitle => 'Sign in';

  @override
  String get authSignUpTitle => 'Create account';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authDisplayNameLabel => 'Display name';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authResetTitle => 'Reset password';

  @override
  String get authResetExplainer =>
      'We\'ll email you a one-time code. Use it here to set a new password.';

  @override
  String get authResetSendCode => 'Send code';

  @override
  String get authResetCodeSent => 'Code sent — check your email.';

  @override
  String get authResetCodeLabel => 'Code from the email';

  @override
  String get authResetNewPasswordLabel => 'New password';

  @override
  String get authResetSubmit => 'Set new password';

  @override
  String get authResetDone => 'Password updated — you are signed in.';

  @override
  String get authResetInvalidCode => 'That code is invalid or expired.';

  @override
  String get authSignInButton => 'Sign in';

  @override
  String get authSignUpButton => 'Create account';

  @override
  String get authToggleToSignUp => 'New here? Create an account';

  @override
  String get authToggleToSignIn => 'Already have an account? Sign in';

  @override
  String get authFieldRequired => 'Required';

  @override
  String get authPasswordTooShort => 'At least 8 characters';

  @override
  String get authGenericError =>
      'Authentication failed. Check your credentials and try again.';

  @override
  String get authSignOut => 'Sign out';

  @override
  String get authNetworkError =>
      'Could not reach the server. Check your connection and try again.';

  @override
  String get availabilityTitle => 'Availability';

  @override
  String get availabilityOpenWeekdays => 'Open weekdays';

  @override
  String get availabilityClosureDays => 'Closure days';

  @override
  String get availabilityAddClosure => 'Add closure day';

  @override
  String get availabilityClosureReason => 'Reason (optional)';

  @override
  String get availabilityLastOpenDay => 'At least one weekday must stay open.';

  @override
  String get availabilityNoClosures => 'No closure days.';

  @override
  String get availabilityGranularityTitle => 'Booking granularity';

  @override
  String get availabilityGranularityDescription =>
      'Half days: bookings cover the morning, the afternoon or the whole working day — the windows follow the configured working hours.';

  @override
  String get availabilityGranularityFlexible => 'Free time period';

  @override
  String get availabilityGranularityHalfDay =>
      'Half days (morning & afternoon)';

  @override
  String get availabilityGranularity5 => '5-minute slots';

  @override
  String get availabilityGranularity15 => '15-minute slots';

  @override
  String get availabilityGranularity30 => '30-minute slots';

  @override
  String get availabilityGranularity60 => '1-hour slots';

  @override
  String get availabilityGranularityFullDay => 'Full days only';

  @override
  String planSlotError(int minutes) {
    return 'Bookings must start and end on the $minutes-minute grid.';
  }

  @override
  String get planFullDayError => 'Bookings here cover the full day.';

  @override
  String get availabilityGranularityHours =>
      'Real hours (exact from–to, half/full days as shortcuts)';

  @override
  String get availabilityWorkHoursTitle => 'Working hours';

  @override
  String get availabilityWorkHoursDescription =>
      'The half-day and full-day windows everywhere — reservations, check-in and invoicing — follow these hours.';

  @override
  String get availabilityWorkStart => 'Day starts';

  @override
  String get availabilityHalfBoundary => 'Half-day boundary';

  @override
  String get availabilityWorkEnd => 'Day ends';

  @override
  String get availabilityHalfDayHours => 'Hours billed as a half day';

  @override
  String get availabilityFullDayHours => 'Hours billed as a full day';

  @override
  String availabilityHourOption(int count) {
    return '$count h';
  }

  @override
  String get availabilityWorkHoursInvalid =>
      'The day must run start < half-day boundary < end.';

  @override
  String get availabilityPoliciesTitle => 'Booking policies';

  @override
  String get policyAllowPastTitle => 'Allow past bookings';

  @override
  String get policyAllowPastDesc =>
      'Members may record a booking that already ended (backfill).';

  @override
  String get policyAdminCheckoutTitle => 'Admins may check members out';

  @override
  String get policyAdminCheckoutDesc =>
      'An admin can end a member\'s running check-in.';

  @override
  String get policyOutsideHoursTitle => 'Outside the opening hours';

  @override
  String get policyOutsideHoursDesc =>
      'What may happen outside the working day — one answer, on every granularity. A booking that touches the working hours is an ordinary booking.';

  @override
  String get policyOutsideHoursOff => 'Off';

  @override
  String get policyOutsideHoursOffDesc =>
      'Nothing outside the hours: no booking ahead, no walk-up, and a booking running past the day end is refused too.';

  @override
  String get policyOutsideHoursWalkUp => 'Spontaneous only';

  @override
  String get policyOutsideHoursWalkUpDesc =>
      'Walk-up check-ins stay possible, evening overtime included; booking ahead outside the hours is refused.';

  @override
  String get policyOutsideHoursFree => 'Free';

  @override
  String get policyOutsideHoursFreeDesc =>
      'Allowed, never counted and never charged — pure presence information.';

  @override
  String get policyOutsideHoursCharged => 'Charged';

  @override
  String get policyOutsideHoursChargedDesc =>
      'Allowed and counted like ordinary usage — except on a day the member already holds a regular booking.';

  @override
  String get policySimultaneousTitle => 'Simultaneous reservations per member';

  @override
  String get policySimultaneousDesc =>
      'How many overlapping bookings one member may hold. 1 keeps one place at a time.';

  @override
  String get policyLimitsTitle => 'Booking limits';

  @override
  String get policyLimitsDesc =>
      'How far ahead a booking may be made, and how short or long it may be. These hold on every granularity.';

  @override
  String get policyHorizonTitle => 'Advance booking horizon';

  @override
  String get policyHorizonDesc =>
      'How many days ahead a booking may start. Beyond it the booking is refused.';

  @override
  String get policyMinDurationTitle => 'Minimum duration';

  @override
  String get policyMinDurationDesc =>
      'The shortest booking accepted. It is why arriving at 11:45 for a 12:00 half-day boundary is refused as too short.';

  @override
  String get policyMaxDurationTitle => 'Maximum duration';

  @override
  String get policyMaxDurationDesc =>
      'The longest booking accepted. A booking ends on the day it starts, so a full day is the ceiling.';

  @override
  String get policyDurationConflict =>
      'The minimum cannot exceed the maximum — no booking would be accepted.';

  @override
  String policyDaysValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String policyMinutesValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String policyHoursValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String get myBadgeTitle => 'My badge';

  @override
  String get badgeSignInTitle => 'Sign in with your badge';

  @override
  String get badgeSignInTapPrompt => 'Hold your badge against the phone.';

  @override
  String get badgeSignInNoReader =>
      'No badge reader is available on this device.';

  @override
  String get badgeSignInRetry => 'Try again';

  @override
  String badgeSignInHello(String name) {
    return 'Hello $name';
  }

  @override
  String get badgeSignInPinLabel => 'Your PIN';

  @override
  String get badgeSignInButton => 'Sign in';

  @override
  String get badgeSignInUseEmail => 'Use my e-mail instead';

  @override
  String get badgeSignInRefused =>
      'That did not work. Check the badge and the PIN, or sign in with your e-mail.';

  @override
  String get badgeSignInLocked =>
      'Too many attempts. Wait a few minutes, or sign in with your e-mail.';

  @override
  String get badgeSignInUnavailable =>
      'Badge sign-in is not reachable right now. Sign in with your e-mail instead.';

  @override
  String get badgeSignInEntry => 'Sign in with a badge';

  @override
  String get badgePinSectionTitle => 'My badge';

  @override
  String get badgePinSet => 'PIN set';

  @override
  String get badgePinNotSet => 'No PIN yet';

  @override
  String get badgePinExplain =>
      'Your PIN lets you sign in by scanning your badge instead of typing your e-mail. Only you can set it, and nobody — not even an owner — can read it back.';

  @override
  String get badgePinSetAction => 'Set a PIN';

  @override
  String get badgePinChangeAction => 'Change PIN';

  @override
  String get badgePinClearAction => 'Remove PIN';

  @override
  String get badgePinNewLabel => 'New PIN';

  @override
  String get badgePinConfirmLabel => 'Repeat it';

  @override
  String get badgePinMismatch => 'The two entries do not match.';

  @override
  String badgePinTooShort(int min) {
    return 'Use at least $min digits.';
  }

  @override
  String get badgePinSaved => 'PIN saved.';

  @override
  String get badgePinCleared =>
      'PIN removed. Your badges no longer sign you in.';

  @override
  String get badgeAuthEnabledLabel => 'Signs me in';

  @override
  String get badgeAuthEnabledHint =>
      'Off by default: a badge that checks you in does not log you in until you say so.';

  @override
  String get badgeAuthNeedsPin =>
      'Set a sign-in PIN first — a badge alone must never be enough.';

  @override
  String billSubscription(int pct) {
    return 'Subscription $pct%';
  }

  @override
  String billEntitlement(int used, int included, int openDays) {
    return '$used of $included half-days used ($openDays open days)';
  }

  @override
  String billOverage(int extra) {
    return '$extra extra half-days';
  }

  @override
  String get billServices => 'Consumed services';

  @override
  String get billServicesTotal => 'Services total';

  @override
  String get billOpenPositions => 'Open positions';

  @override
  String get billPendingBadge => 'pending validation';

  @override
  String get billPaymentsCredits => 'Payments & credits';

  @override
  String get billBalance => 'Balance';

  @override
  String get billSettled => 'Settled';

  @override
  String get billOutstanding => 'Outstanding';

  @override
  String get billAccessorySupplements => 'Accessory supplements';

  @override
  String get entitlementTitle => 'This month';

  @override
  String entitlementDaysUsed(String used, String total) {
    return '$used of $total days used';
  }

  @override
  String entitlementDaysLeft(String left) {
    return '$left days left';
  }

  @override
  String get entitlementBlockedFull =>
      'You\'ve used all your days this month. Ask an admin for more or request extra half-days below.';

  @override
  String entitlementPaygRate(String rate) {
    return 'Extra days beyond your plan bill at $rate each.';
  }

  @override
  String get entitlementPackageFull =>
      'You\'ve used all your days this month. Buy a package to keep booking.';

  @override
  String get billPackages => 'Day packages';

  @override
  String get payOnlineButton => 'Pay online';

  @override
  String get payOnlineNotConfigured =>
      'Online payments aren\'t set up yet. Ask the workspace owner.';

  @override
  String get payOnlineChooseTitle => 'Pay online';

  @override
  String get paymentProviderStripe => 'Credit card (Stripe)';

  @override
  String get paymentProviderMollie => 'Mollie — iDEAL, Bancontact…';

  @override
  String get payOnlineDiagTitle => 'Online payments — not configured';

  @override
  String get payOnlineDiagHint =>
      'The server is missing this configuration (docs/design/payments-integration.md):';

  @override
  String billInvoiceCard(String number) {
    return 'Invoice $number';
  }

  @override
  String billCreditNoteCard(String number) {
    return 'Credit note $number';
  }

  @override
  String get billInvoiceTotal => 'Invoice total';

  @override
  String get billInvoicePaid => 'Paid so far';

  @override
  String get billInvoiceRemaining => 'Remaining to pay';

  @override
  String get billCreditNoteDue =>
      'The workspace owes you this amount — nothing to pay on your side.';

  @override
  String get billCreditNoteRefunded =>
      'The workspace refunded you this amount.';

  @override
  String get accountCardTitle => 'Your account';

  @override
  String get accountCredit => 'Credit on account';

  @override
  String get accountRefundDue => 'Refund due from the workspace';

  @override
  String get accountNet => 'Net position';

  @override
  String accountOpenPartial(String period, String paid) {
    return '$period · $paid paid';
  }

  @override
  String get accountImputationHint =>
      'Your credit can settle open invoices — the workspace applies it when matching payments.';

  @override
  String get invoiceExportSafTPt => 'SAF-T (Portugal)';

  @override
  String get invoiceExportDatev => 'DATEV (Buchungsstapel)';

  @override
  String get invoiceExportSage => 'Sage 50 (audit trail)';

  @override
  String get invoiceExportAccountantCsv => 'Accounting CSV';

  @override
  String get invoiceExportAuditTrail => 'Audit trail';

  @override
  String get exportClaimRegulatory => 'The format your tax authority asks for.';

  @override
  String get exportClaimExchange =>
      'For your accountant to import and review — not a filing.';

  @override
  String get exportClaimSubset =>
      'Invoices and payments only; no general ledger. The file says so in its header.';

  @override
  String get exportUncertifiedSoftware =>
      'Built to the published spec, but DesKilo is not certified software in this country — check with your accountant whether that is required of you.';

  @override
  String get datevAccountsTitle => 'DATEV export';

  @override
  String get datevAccountsIntro =>
      'Your accountant gives you the consultant and client numbers. DATEV refuses a file whose numbers do not match — which is what keeps it out of the wrong company’s books.';

  @override
  String get datevConsultantNumber => 'Beraternummer';

  @override
  String get datevClientNumber => 'Mandantennummer';

  @override
  String get sageAccountsTitle => 'Sage export';

  @override
  String get sageAccountsIntro =>
      'The defaults are Sage’s own shipped nominal codes. The tax code decides which VAT return these land on, so check it with your accountant if you are not on the standard rate.';

  @override
  String get sageTaxCode => 'VAT code (T1 / T0 / T9)';

  @override
  String get saftLedgerTitle => 'Include postings?';

  @override
  String get saftLedgerIntro =>
      'With account numbers, the file carries double-entry postings your accountant can import instead of keying in. They cover your sales and the payments against them — not your whole books.';

  @override
  String get saftDocumentsOnly => 'Documents only';

  @override
  String get saftWithPostings => 'With postings';

  @override
  String get billPdfTitle => 'Monthly bill';

  @override
  String get billPdfExport => 'Export bill as PDF';

  @override
  String get reportCoaTitle => 'Chart of accounts — preview';

  @override
  String get reportCoaIntro =>
      'A suggestion, not your accounting. These are the accounts a bookkeeper in your country would usually use for a space like yours.';

  @override
  String get reportCoaAccounts => 'Suggested accounts';

  @override
  String get reportCoaNumber => 'Account';

  @override
  String get reportCoaLabel => 'Name';

  @override
  String get reportCoaDisclaimer =>
      'Preview only. DesKilo does not keep a ledger and does not do your accounting — your accountant\'s chart always wins.';

  @override
  String get reportBadgesTitle => 'Member badges';

  @override
  String get reportBadgesIntro =>
      'Cut along the lines. Each card carries one member\'s badge code — present it at the kiosk to check in.';

  @override
  String get reportBadgesFooter =>
      'A lost badge should be revoked in Members & plans, not just replaced.';

  @override
  String get reportSpaceCodesTitle => 'Space codes';

  @override
  String get reportSpaceCodesIntro =>
      'One card per seat, table, room and floor. Stick each card on its space: scanning it opens the same sheet the kiosk shows.';

  @override
  String get reportSpaceCodesFooter =>
      'A card that no longer matches its space misleads whoever scans it — reprint the sheet after moving or renaming a space.';

  @override
  String get billingTitle => 'Billing';

  @override
  String get billingFeeBands => 'Fee bands';

  @override
  String billingBandFrom(int from) {
    return 'from $from%';
  }

  @override
  String get billingBandTo => 'To %';

  @override
  String get billingBandFee => 'Monthly fee';

  @override
  String get billingBandOverage => 'Overage';

  @override
  String get billingAddBand => 'Add band';

  @override
  String get billingRemoveBand => 'Remove band';

  @override
  String get billingBandsInvalid => 'Bands must increase and end at 100%.';

  @override
  String get billingSaved => 'Saved.';

  @override
  String get billingLevels => 'Subscription levels';

  @override
  String get billingAddLevel => 'Add level';

  @override
  String get billingLevelValue => 'Level (1–100)';

  @override
  String get billingAllowCustom => 'Allow negotiated custom value';

  @override
  String get memberSubscriptionLabel => 'Subscription';

  @override
  String get memberSubscriptionCustom => 'Custom (1–100)';

  @override
  String moneySubscriptionPct(int pct) {
    return 'Subscription $pct%';
  }

  @override
  String percentValue(int value) {
    return '$value%';
  }

  @override
  String get memberOveragePolicyLabel => 'When days run out';

  @override
  String get memberOveragePolicyTooltip => 'Over-consumption';

  @override
  String get overagePolicyBlocked => 'Block further booking';

  @override
  String get overagePolicyPayg => 'Charge overage (pay-as-you-go)';

  @override
  String get overagePolicyPackage => 'Require buying a package';

  @override
  String get billingPackages => 'Day packages';

  @override
  String get billingPackagesHint =>
      'Members on the package plan buy these when their days run out.';

  @override
  String billingPackageSummary(int days, String price) {
    return '$days days · $price';
  }

  @override
  String get billingPackageName => 'Name';

  @override
  String get billingPackageDays => 'Days';

  @override
  String get billingPackagePrice => 'Price';

  @override
  String get billingAddPackage => 'Add package';

  @override
  String get buyPackageButton => 'Buy a package';

  @override
  String get buyPackageTitle => 'Buy a package';

  @override
  String buyPackageDays(int days) {
    return '$days days';
  }

  @override
  String get buyPackageNone => 'No packages are available yet.';

  @override
  String get buyPackageDone => 'Days added — enjoy the extra time.';

  @override
  String get payConfigTitle => 'Online payments';

  @override
  String get payConfigOpen => 'Configure';

  @override
  String get payConfigIntro =>
      'Enter each payment provider you want to offer. Keys are stored securely on the server and never shown again. See docs/design/payments-integration.md.';

  @override
  String get payConfigConfigured => 'Configured';

  @override
  String get payConfigNotConfigured => 'Not configured';

  @override
  String get payConfigSecretSet => 'Set — leave blank to keep';

  @override
  String get payConfigSaved => 'Saved.';

  @override
  String get payConfigRemove => 'Remove';

  @override
  String get payConfigRemoved => 'Removed.';

  @override
  String get payFieldClientId => 'Client ID';

  @override
  String get payFieldSecret => 'Secret';

  @override
  String get payFieldEnv => 'Environment';

  @override
  String get payFieldWebhookId => 'Webhook ID';

  @override
  String get payFieldReturnUrl => 'Return URL';

  @override
  String get payFieldSecretKey => 'Secret key';

  @override
  String get payFieldWebhookSecret => 'Webhook signing secret';

  @override
  String get payFieldApiKey => 'API key';

  @override
  String get paymentProviderWero => 'Wero (via Mollie)';

  @override
  String get billingRulesTitle => 'Invoice schedule';

  @override
  String get billingRulesSubtitle =>
      'When subscription and end-of-month invoices go out';

  @override
  String get billingRulesSaved => 'Invoice schedule saved.';

  @override
  String get billingSubscriptionSection => 'Subscription, in advance';

  @override
  String get billingSubscriptionAuto => 'Issue automatically';

  @override
  String get billingSubscriptionOff =>
      'Switch on “Subscription invoices” in Features to use this.';

  @override
  String get billingAdvanceDays => 'Days before the month starts';

  @override
  String billingSubscriptionWhen(String day, String month) {
    return 'Issued on $day for $month';
  }

  @override
  String get billingUsageSection => 'The month just finished';

  @override
  String get billingUsageAuto => 'Issue automatically';

  @override
  String get billingUsageOff =>
      'Switch on “End-of-month invoices” in Features to use this.';

  @override
  String get billingUsageWhenZero => 'Also when there is nothing to pay';

  @override
  String get billingUsageWhenZeroHint =>
      'Sends a document reading zero, as confirmation that the subscription covered the whole month.';

  @override
  String get invoiceKindSubscription => 'Subscription, in advance';

  @override
  String get invoiceKindUsage => 'The month\'s extras';

  @override
  String get invoiceKindSettlement => 'Regrouped invoices';

  @override
  String get invoiceKindFull => 'Whole month';

  @override
  String get settlementRegroups => 'This invoice regroups';

  @override
  String get settlementVatNote =>
      'VAT stays declared on the invoices above; this document only regroups what is owed.';

  @override
  String get settlementSettledBy =>
      'Regrouped into another invoice — that one is what is owed and chased.';

  @override
  String get settlementAction => 'Regroup into one invoice';

  @override
  String settlementConfirm(int count, String amount) {
    return 'Regroup $count invoices into one of $amount?';
  }

  @override
  String settlementDone(String number) {
    return 'Regrouped into $number.';
  }

  @override
  String get settlementNeedsTwo =>
      'Pick at least two open invoices of the same member.';

  @override
  String get reservationExtendButton => 'Stay longer';

  @override
  String get reservationExtendLaterOnly => 'Pick a time after the current end.';

  @override
  String get reservationEndEarlyButton => 'End earlier';

  @override
  String get reservationEndEarlyAheadOnly =>
      'Pick a time still ahead of now and before the current end.';

  @override
  String get calendarMineTab => 'Mine';

  @override
  String get calendarEveryoneTab => 'Everyone';

  @override
  String get calendarNoReservations => 'No reservations on this day.';

  @override
  String get calendarCancelOccurrence => 'Cancel this occurrence';

  @override
  String get calendarCancelFollowing => 'Cancel this and following';

  @override
  String get calendarPreviousMonth => 'Previous month';

  @override
  String get calendarNextMonth => 'Next month';

  @override
  String get calendarReservationActions => 'Reservation actions';

  @override
  String get calendarShowOnPlan => 'Show on plan';

  @override
  String get calendarListView => 'List view';

  @override
  String get calendarTimelineView => 'Timeline view';

  @override
  String get calendarTimelineEmpty =>
      'No reservations on this level for this day.';

  @override
  String get calendarAllLevels => 'All levels';

  @override
  String get calendarTimelineAllEmpty =>
      'No reservations on any level for this day.';

  @override
  String calendarLevelCollapsed(String level) {
    return '$level, collapsed';
  }

  @override
  String calendarLevelExpanded(String level) {
    return '$level, expanded';
  }

  @override
  String get calendarWhoCanSee => 'Who can see this';

  @override
  String get calendarPrevious => 'Previous';

  @override
  String get calendarNext => 'Next';

  @override
  String get calendarDay => 'Day';

  @override
  String get calendarRange => 'Range';

  @override
  String get calendarMemberMe => 'Me';

  @override
  String get calendarNothingHere => 'Nothing on these dates.';

  @override
  String calendarLockedKinds(String kinds) {
    return 'Not visible to you for this member: $kinds';
  }

  @override
  String calendarEventTitle(String label) {
    return 'Alert: $label';
  }

  @override
  String get calendarKindReservation => 'Bookings';

  @override
  String get calendarKindCheckIn => 'Check-ins';

  @override
  String get calendarKindCheckOut => 'Check-outs';

  @override
  String get calendarKindEvent => 'Alerts';

  @override
  String get calendarKindMessage => 'Messages';

  @override
  String get calendarKindInvoice => 'Invoices';

  @override
  String get calendarKindPayment => 'Payments';

  @override
  String get calendarKindConsumption => 'Consumption';

  @override
  String get calendarKindReminder => 'Reminders';

  @override
  String get accessNobodyElse => 'nobody else';

  @override
  String get accessRuleReservations =>
      'Every member of the workspace — the floor plan shows occupancy to everyone.';

  @override
  String get accessRuleEvents => 'You, the member who acted, and the admins.';

  @override
  String get accessRuleMessages =>
      'Only the people in the conversation — no role can read a conversation it is not part of.';

  @override
  String accessRuleFinances(String people) {
    return 'You, and those with the finance permission: $people.';
  }

  @override
  String get accessRuleReminders => 'Only you.';

  @override
  String get accessLogTitle => 'Who accessed your data';

  @override
  String get accessLogEmpty =>
      'Nobody has looked at your finances or messages.';

  @override
  String accessLogRow(String actor, String category, String subject) {
    return '$actor read $category of $subject';
  }

  @override
  String get calendarEventActionCreated => 'created';

  @override
  String get calendarEventActionModified => 'changed';

  @override
  String get calendarEventActionCancelled => 'cancelled';

  @override
  String get calendarEventActionSubmitted => 'submitted';

  @override
  String get calendarEventActionApproved => 'approved';

  @override
  String get calendarEventActionRejected => 'rejected';

  @override
  String get calendarEventStatusPending => 'awaiting confirmation';

  @override
  String get calendarEventStatusRejected => 'rejected';

  @override
  String get calendarEventStatusExpired => 'expired';

  @override
  String get accessKindNegotiations => 'Price negotiations';

  @override
  String accessRuleNegotiations(String people) {
    return 'You, the owners and the finance admins: $people. Every read by someone else is on the record below.';
  }

  @override
  String get calendarViewAgenda => 'Agenda';

  @override
  String get calendarViewWeek => 'Week';

  @override
  String get calendarViewMonth => 'Month';

  @override
  String get calendarToday => 'Today';

  @override
  String get calendarTomorrow => 'Tomorrow';

  @override
  String get calendarYesterday => 'Yesterday';

  @override
  String get calendarKindDue => 'Payments due';

  @override
  String get calendarKindScheduled => 'Scheduled expenses';

  @override
  String calendarDueTitle(String number) {
    return 'Payment due · $number';
  }

  @override
  String calendarScheduledTitle(String name) {
    return 'Scheduled expense · $name';
  }

  @override
  String get calendarClosedDay => 'Closed';

  @override
  String calendarClosedDayReason(String reason) {
    return 'Closed — $reason';
  }

  @override
  String get calendarGroupBookings => 'Bookings & presence';

  @override
  String get calendarGroupActivity => 'Alerts & messages';

  @override
  String get calendarGroupMoney => 'Money';

  @override
  String calendarAgendaEmpty(int days) {
    return 'Nothing planned in the next $days days.';
  }

  @override
  String calendarAgendaRange(int days) {
    return 'Next $days days';
  }

  @override
  String get calendarWeekEmpty => 'Nothing this week.';

  @override
  String get calendarDayEmpty => 'Nothing on this day.';

  @override
  String calendarItemCount(int count) {
    return '$count items';
  }

  @override
  String get appTitle => 'DesKilo';

  @override
  String get tabPlan => 'Plan';

  @override
  String get tabCalendar => 'Calendar';

  @override
  String get tabEvents => 'Events';

  @override
  String get tabMoney => 'Money';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionAdministration => 'Administration';

  @override
  String get settingsSectionPreferences => 'Preferences';

  @override
  String get settingsSectionAdvanced => 'Advanced';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get shellReserveButton => 'Reserve';

  @override
  String commonSavedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String get commonSaveFailed => 'Could not save the file.';

  @override
  String get commonRetry => 'Try again';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutOpenSource => 'Open source (0BSD)';

  @override
  String get aboutOpenSourceDesc => 'Source code on GitHub';

  @override
  String get aboutPrivacy => 'Privacy policy';

  @override
  String get aboutReportBug => 'Report a bug / suggest a feature';

  @override
  String get aboutSupportTitle => 'Support this project';

  @override
  String get aboutSupportBody =>
      'This app is free, open source and ad-free. If you find it useful, support the developer.';

  @override
  String get consumptionAdd => 'Add consumption';

  @override
  String consumptionAddForMember(String name) {
    return 'Add service for $name';
  }

  @override
  String get consumptionService => 'Service';

  @override
  String get consumptionQuantity => 'Quantity';

  @override
  String get consumptionPeriodLabel => 'Billing period (YYYY-MM)';

  @override
  String get consumptionNoServices => 'No active services to record.';

  @override
  String get consumptionRecorded =>
      'Consumption recorded — waiting for confirmation.';

  @override
  String get eventTypeServiceCharge => 'Service';

  @override
  String eventServiceChargeTitle(String name, int quantity, String amount) {
    return '$name ×$quantity — $amount';
  }

  @override
  String get coOwnerAction => 'Co-ownership';

  @override
  String get coOwnerNone => 'No co-owner role';

  @override
  String get coOwnerActive =>
      'Active co-owner — owner permissions now, automatic succession';

  @override
  String get coOwnerPassive =>
      'Passive co-owner — becomes owner when activated or when the owner leaves';

  @override
  String get coOwnerActivate => 'Promote to owner now';

  @override
  String get memberCoOwnerChip => 'Co-owner';

  @override
  String get memberCoOwnerPassiveChip => 'Co-owner (passive)';

  @override
  String get developerMode => 'Developer mode';

  @override
  String get developerModeWorkspaceHint =>
      'Applies to every member of this workspace.';

  @override
  String get developerTitle => 'Developer';

  @override
  String get developerExport => 'Export trace';

  @override
  String get developerClear => 'Clear trace';

  @override
  String get developerEmpty => 'No trace entries yet.';

  @override
  String get developerFilterAll => 'All';

  @override
  String get developerFilterErrors => 'Errors';

  @override
  String get developerFilterWarnings => 'Warnings+';

  @override
  String get pushStatusRegistered => 'Push notifications are active';

  @override
  String get pushStatusNotConfigured => 'Push notifications are not set up yet';

  @override
  String get pushStatusNotConfiguredHint =>
      'The workspace owner completes the Firebase setup (push-setup guide).';

  @override
  String get notificationsSystemOff =>
      'Android is blocking DesKilo notifications';

  @override
  String get notificationsSystemOffHint =>
      'Allow them under system Settings → Apps → DesKilo → Notifications — the icon badge needs them.';

  @override
  String get developerExportReservations => 'Export reservations';

  @override
  String get developerExportReservationsHint =>
      'Every booking and check-in — past, present and future, every state — as CSV, for analysis and debugging.';

  @override
  String get pushStatusNoTransport => 'This build has no push notifications';

  @override
  String get pushStatusNoTransportHint =>
      'Notifications arrive in the app and as local notifications on this device.';

  @override
  String get directoryTitle => 'Members';

  @override
  String get directoryEmpty => 'No members yet.';

  @override
  String get directoryCheckedIn => 'Checked in';

  @override
  String directoryCheckedInSeat(String seat) {
    return 'Checked in · $seat';
  }

  @override
  String get directoryOnline => 'Online';

  @override
  String get directoryReservedToday => 'Reserved today';

  @override
  String directoryLastSeenMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String directoryLastSeenHours(int hours) {
    return '$hours h';
  }

  @override
  String directoryLastSeenDays(int days) {
    return '$days d';
  }

  @override
  String get directoryWhatsapp => 'Chat on WhatsApp';

  @override
  String get directoryOpenGroup => 'Open WhatsApp group';

  @override
  String get directoryClose => 'Close';

  @override
  String get directoryReservedNow => 'Reserved now';

  @override
  String directoryReservedNowSeat(String seat) {
    return 'Reserved now · $seat';
  }

  @override
  String get directoryReservationsHeading => 'Reservations';

  @override
  String get directoryNoUpcoming => 'No upcoming reservations';

  @override
  String get editorBackgroundImage => 'Background image';

  @override
  String get editorBackgroundSet => 'Set background image';

  @override
  String get editorBackgroundReplace => 'Replace background image';

  @override
  String get editorBackgroundRemove => 'Remove background image';

  @override
  String get editorTitle => 'Workspace editor';

  @override
  String get editorOpenTooltip => 'Edit workspace';

  @override
  String get editorAddLevel => 'Add level';

  @override
  String get editorNoLevels =>
      'No levels yet. Add the first floor of your workspace.';

  @override
  String get editorLevelNameLabel => 'Level name';

  @override
  String get editorRenameLevel => 'Rename';

  @override
  String get editorLevelActions => 'Level actions';

  @override
  String get editorDeleteLevelConfirm =>
      'Delete this level? All offices, desks and seats on it are removed.';

  @override
  String get editorToolSelect => 'Select';

  @override
  String get editorToolOffice => 'Office';

  @override
  String get editorToolDesk => 'Desk';

  @override
  String get editorToolImage => 'Image';

  @override
  String get editorToolErase => 'Erase';

  @override
  String get editorNewOffice => 'New office';

  @override
  String get editorOfficeNameLabel => 'Office name';

  @override
  String get editorOfficeNameDefault => 'Office';

  @override
  String get editorDeskNameDefault => 'Desk';

  @override
  String get editorDeskNameLabel => 'Desk name';

  @override
  String get editorPlacementOverlap => 'Overlaps an existing element.';

  @override
  String get editorPlacementOutside => 'Must be fully inside an office.';

  @override
  String get editorOfficeProperties => 'Office';

  @override
  String get editorDeskProperties => 'Desk';

  @override
  String get editorBookableAsWhole => 'Bookable as a whole';

  @override
  String get editorDeleteElementConfirm =>
      'Delete this element? Anything placed on it is removed too.';

  @override
  String get editorToolSeat => 'Seat';

  @override
  String get editorSeatProperties => 'Seat';

  @override
  String get editorSeatNameLabel => 'Seat name';

  @override
  String get editorSeatNameDefault => 'Seat';

  @override
  String get editorOrientationLabel => 'Sitting direction';

  @override
  String get editorChairLabel => 'Chair type';

  @override
  String get editorAmenitiesLabel => 'Amenities';

  @override
  String get editorBlockedLabel => 'Blocked (maintenance)';

  @override
  String get editorSeatNoDesk => 'Seats can only be placed on a desk.';

  @override
  String get amenityMonitor => 'Monitor';

  @override
  String get amenityStandingDesk => 'Standing desk';

  @override
  String get amenityWindow => 'Window seat';

  @override
  String get amenityDock => 'Docking station';

  @override
  String get amenityErgonomicChair => 'Ergonomic chair';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get editorAccessoriesLabel => 'Accessories';

  @override
  String get editorNoAccessories =>
      'No accessories yet — add them in Settings → Accessories.';

  @override
  String get editorSeatNfcLabel => 'NFC/RFID tag';

  @override
  String get editorSeatNfcHelp => 'Tag uid in hex — leave empty for no tag.';

  @override
  String get editorSeatNfcRead => 'Read a tag now';

  @override
  String get editorSeatNfcReadFailed => 'Could not start the tag reader.';

  @override
  String get editorSeatNfcDuplicate =>
      'This tag is already linked to another chair.';

  @override
  String get editorDeleteElementConfirmAudit =>
      'Delete this element? Anything placed on it is removed too. Bookings that reference it keep a text snapshot for audits; open bookings are cancelled.';

  @override
  String get editorDeleteLevelConfirmAudit =>
      'Delete this level? All offices, desks and seats on it are removed. Bookings that reference them keep a text snapshot for audits; open bookings are cancelled.';

  @override
  String get eventsPendingHeader => 'Waiting for your confirmation';

  @override
  String get eventAccept => 'Accept';

  @override
  String get eventReject => 'Decline';

  @override
  String get eventsEmpty => 'No events yet.';

  @override
  String get eventsFilterAll => 'All';

  @override
  String get eventTypeReservation => 'Reservation';

  @override
  String get eventTypePayment => 'Payment';

  @override
  String get eventTypeExpense => 'Expense';

  @override
  String get eventTypeAdjustment => 'Adjustment';

  @override
  String eventReservationCreated(String actor, String target) {
    return '$actor booked $target';
  }

  @override
  String eventReservationModified(String actor, String target) {
    return '$actor changed the booking of $target';
  }

  @override
  String eventReservationCancelled(String actor, String target) {
    return '$actor cancelled the booking of $target';
  }

  @override
  String eventPaymentSubmitted(String actor, String amount) {
    return '$actor recorded a payment of $amount';
  }

  @override
  String eventExpenseSubmitted(String actor, String amount) {
    return '$actor submitted an expense of $amount';
  }

  @override
  String eventForSubject(String name) {
    return 'for $name';
  }

  @override
  String get pushPendingTitle => 'DesKilo';

  @override
  String get pushPendingBody => 'Someone needs your confirmation.';

  @override
  String get pushCancelledTitle => 'Reservation removed';

  @override
  String get pushCancelledBody => 'A reservation was removed by an admin.';

  @override
  String get eventTypeReservationDelete => 'Booking deletion';

  @override
  String eventReservationDeleteLine(String actor, String date, String state) {
    return '$actor asks to delete the booking of $date ($state)';
  }

  @override
  String get eventReservationDeleteCheckedIn => 'checked in';

  @override
  String get eventReservationDeleteUnused => 'never used';

  @override
  String get eventAutoValidated => 'Auto-validated';

  @override
  String get reservationDeleteRequestButton => 'Request deletion';

  @override
  String get reservationDeleteRequestExplain =>
      'Past or checked-in bookings are not deleted directly. An owner or admin will decide: was the check-in simply forgotten (the booking stays), or was it never used (it is removed)?';

  @override
  String get reservationDeleteReasonLabel => 'Reason (optional)';

  @override
  String get reservationDeleteSubmit => 'Send request';

  @override
  String get reservationDeleteSubmitted =>
      'Deletion requested — an owner or admin will decide.';

  @override
  String get notifCategoryCheckIns => 'Check-ins';

  @override
  String get notifCategoryMoney => 'Money';

  @override
  String get notifCategoryMembers => 'Members';

  @override
  String get notesFilterRead => 'Read';

  @override
  String get notifSortByDate => 'Sort by date';

  @override
  String get notifGroupBy => 'Group by';

  @override
  String get notifGroupByType => 'Type';

  @override
  String get notifGroupByDate => 'Date';

  @override
  String get notifGroupByUser => 'Member';

  @override
  String get notifUngroup => 'Ungroup';

  @override
  String get validationScopeLabel => 'Who validates';

  @override
  String get validationScopeAdmins => 'Admins';

  @override
  String get validationScopeListed => 'Listed persons';

  @override
  String get validationScopeMembers => 'All members';

  @override
  String get validationScopeHint =>
      'The owner always may. Admins: every admin, or the ones you list. Listed: exactly these people, whatever their role. All members: anyone active.';

  @override
  String get validationPickPersons => 'Pick the persons';

  @override
  String get eventTypeExpenseSchedule => 'Scheduled expense';

  @override
  String eventExpenseScheduleLine(Object actor, Object amount, Object title) {
    return '$actor schedules “$title” — $amount recurring';
  }

  @override
  String eventExpenseDeviation(Object reason, Object scheduled) {
    return 'validated $scheduled — $reason';
  }

  @override
  String get featuresTitle => 'Features';

  @override
  String get featureCalendarTab => 'Calendar tab';

  @override
  String get featureCalendarTabDesc =>
      'Monthly overview of bookings and closed days.';

  @override
  String get featureEventsTab => 'Events tab';

  @override
  String get featureEventsTabDesc => 'Activity feed and pending confirmations.';

  @override
  String get featureMoneyTab => 'Money tab';

  @override
  String get featureMoneyTabDesc => 'Monthly bills, payments and expenses.';

  @override
  String get featureServices => 'Services';

  @override
  String get featureServicesDesc => 'Service catalog and consumption tracking.';

  @override
  String get featurePdfExport => 'PDF export';

  @override
  String get featurePdfExportDesc => 'Export the monthly bill as a PDF.';

  @override
  String get featureSeriesBooking => 'Series booking';

  @override
  String get featureSeriesBookingDesc =>
      'Repeat a reservation daily, weekly or on weekdays.';

  @override
  String get featureBookForOthers => 'Book for others';

  @override
  String get featureBookForOthersDesc =>
      'Admins and owners book seats for other members.';

  @override
  String get featurePushNotifications => 'Push notifications';

  @override
  String get featurePushNotificationsDesc =>
      'Deliver pending confirmations to members\' devices.';

  @override
  String get featureAdminSeatBlocking => 'Admins can block seats';

  @override
  String get featureAdminSeatBlockingDesc =>
      'Admins mark seats not reservable for maintenance. The owner always can.';

  @override
  String get featureAccessorySupplements => 'Accessory supplements';

  @override
  String get featureAccessorySupplementsDesc =>
      'Bill priced seat accessories per booked half-day. Applies to bookings from activation on.';

  @override
  String get featureOnlinePayments => 'Online payments';

  @override
  String get featureOnlinePaymentsDesc =>
      'Let members pay their bill online (PayPal). Needs the payment provider configured on the server.';

  @override
  String get featureNfcBadges => 'RFID / NFC badges';

  @override
  String get featureNfcBadgesDesc =>
      'Members check in at a kiosk by tapping an RFID/NFC card. Needs an Android device with NFC.';

  @override
  String get featureLevelBooking => 'Desk, office & level reservations';

  @override
  String get featureLevelBookingDesc =>
      'Reserve a whole desk, office or floor as one booking, priced per half-day. Grant the right per member.';

  @override
  String get featureAdminLevelAssign => 'Admins can assign levels';

  @override
  String get featureAdminLevelAssignDesc =>
      'Admins assign level reservations to members. The owner always can.';

  @override
  String get featureKioskMode => 'Kiosk mode';

  @override
  String get featureKioskModeDesc =>
      'Wall-tablet accounts locked to the live plan; members act through badges.';

  @override
  String get featureMembersDirectory => 'Members directory';

  @override
  String get featureMembersDirectoryDesc =>
      'The community tab: who is here, statuses, presence.';

  @override
  String get featureWhatsappIntegration => 'WhatsApp integration';

  @override
  String get featureWhatsappIntegrationDesc =>
      'Members share their WhatsApp number on their profile; one tap on a member opens a chat with it; the community group link in the directory. No server-side WhatsApp integration.';

  @override
  String get featureSpaceQrCodes => 'Space QR codes';

  @override
  String get featureSpaceQrCodesDesc =>
      'Printable QR cards per seat, desk, office and level — scan to reserve or check in.';

  @override
  String featureRequires(String feature) {
    return 'Requires $feature';
  }

  @override
  String get featureCoOwner => 'Co-owners';

  @override
  String get featureCoOwnerDesc =>
      'Appoint co-owners: owner permissions now (active) or succession-in-waiting (passive).';

  @override
  String get featureAutoCheckInOut => 'Auto check-in/out at day end';

  @override
  String get featureDataExport => 'Data export (Excel)';

  @override
  String get featureAutoCheckInOutDesc =>
      'Reservations never checked in or out complete themselves once their time has passed.';

  @override
  String get featureDataExportDesc =>
      'Download all workspace data as an Excel workbook.';

  @override
  String get featureWorkingHours => 'Working hours';

  @override
  String get featureWorkingHoursDesc =>
      'Configure the working day and offer exact-hours booking; off keeps the 8:00–17:00 defaults.';

  @override
  String get featureInvoicePdfTemplate => 'Invoice PDF template';

  @override
  String get featureInvoicePdfTemplateDesc =>
      'Owner-written intro and footer text on the invoice PDF. Never touches the e-invoice XML.';

  @override
  String get featureMemberNotifications => 'Member notifications';

  @override
  String get featureMemberNotificationsDesc =>
      'Messaging between members: private and group conversations, read receipts, links to a reservation or a space; admins can notify all admins, owner included.';

  @override
  String get featureDunning => 'Payment reminders (Mahnwesen)';

  @override
  String get featureDunningDesc =>
      'Configurable reminder levels and delays, a reminder letter per level, and “Reminder due” flags on late invoices. Sending stays a manual tap unless Automatic payment reminders is on.';

  @override
  String get featureMemberReports => 'Member reports';

  @override
  String get featureMemberReportsDesc =>
      'The financial agreement and the monthly payments report — self-service for members, sendable per member.';

  @override
  String get featureDeletionRequests => 'Booking deletion requests';

  @override
  String get featureDeletionRequestsDesc =>
      'Members may REQUEST deletion of a past or checked-in booking; an owner/admin validates. Off, such bookings cannot be deleted at all.';

  @override
  String get featurePlanObjectDeleteTitle => 'Delete spaces with history';

  @override
  String get featurePlanObjectDeleteDesc =>
      'Owners may delete levels, offices, desks and seats even when past reservations reference them — the bookings keep a text snapshot for audits and reports.';

  @override
  String get featureNotificationGroupingTitle => 'Notification feed grouping';

  @override
  String get featureNotificationGroupingDesc =>
      'Members may fold the notification feed into groups by type, day or member; tapping the group symbol returns to the flat list.';

  @override
  String get featureBookingPoliciesTitle => 'Booking policies';

  @override
  String get featureBookingPoliciesDesc =>
      'Owner-configurable booking behavior: past bookings, minute bookings outside the working hours, and check-out by admins.';

  @override
  String get featureNfcSeatTagsTitle => 'NFC/RFID chair tags';

  @override
  String get featureNfcSeatTagsDesc =>
      'A physical NFC/RFID tag on a chair resolves to its seat like the printed QR card; owners fill the tag field by tapping the chip.';

  @override
  String get featureQrBadgesTitle => 'QR badges';

  @override
  String get featureQrBadgesDesc =>
      'Printable QR badge cards for the kiosk, beside the NFC/RFID cards.';

  @override
  String get featureFormHelpHintsTitle => 'Help hints';

  @override
  String get featureFormHelpHintsDesc =>
      'A dismissible tip carousel on every main screen, and a small ? beside every parameter and entry field — one tap opens the guide at the right section. Restorable from Settings.';

  @override
  String get featureUiAnimationsTitle => 'Interface animations';

  @override
  String get featureUiAnimationsDesc =>
      'Smooth transitions and state animations across the app. Off means every change is instant; the device\'s reduced-motion setting always wins.';

  @override
  String get featureKioskMemberPhotosTitle => 'Member photos at the kiosk';

  @override
  String get featureKioskMemberPhotosDesc =>
      'The kiosk receipt shows the member\'s profile photo — the visual wrong-badge check.';

  @override
  String get featurePlanMemberPhotosTitle => 'Member photos on the plan';

  @override
  String get featurePlanMemberPhotosDesc =>
      'Occupied seats on the Plan tab and Reserve hub show the occupant\'s profile photo instead of the initial.';

  @override
  String get featureBadgeSignInTitle => 'Sign in with a badge';

  @override
  String get featureBadgeSignInDesc =>
      'Members can sign in by scanning their badge and entering their PIN, instead of typing an e-mail on a shared tablet. Each member sets their own PIN and arms their own badge.';

  @override
  String get featureRegionalFormatsTitle => 'Region & formats';

  @override
  String get featureRegionalFormatsDesc =>
      'Members choose how numbers, dates, the clock and the time zone are shown to them. Off: everyone reads in the app language\'s home region, 24-hour, workspace time.';

  @override
  String get featureCalendarHubTitle => 'Calendar hub';

  @override
  String get featureCalendarHubDesc =>
      'The calendar shows everything dated — bookings, check-ins, alerts, messages, invoices, payments, consumption, reminders — for a day or a range, each row opening its source. Off: reservations only.';

  @override
  String get featureDataAccessLogTitle => 'Data access log';

  @override
  String get featureDataAccessLogDesc =>
      'Members see who looked at their finances and when (written by the server, never skippable). Off hides the row; the log is still kept.';

  @override
  String get featureMemberDataExportTitle => 'Export & erasure';

  @override
  String get featureMemberDataExportDesc =>
      'Every member can export their data as one file (GDPR art. 20) and leave the workspace with their personal data cleared (art. 17) from Settings → Privacy & data.';

  @override
  String get featureFinanceFacesTitle => 'Finances in four faces';

  @override
  String get featureFinanceFacesDesc =>
      'The Finances tab reads as four faces — Statement, Payments, Invoices, Documents — under one month chooser, each with its own help. Off: a single column.';

  @override
  String get featurePaymentRemindersTitle => 'Automatic payment reminders';

  @override
  String get featurePaymentRemindersDesc =>
      'Open invoices past the configured term get their reminder levels automatically — an alert in the member\'s feed and a push, once a day. Off: reminders stay a manual action.';

  @override
  String get featureSupplyExpensesTitle => 'Supplies from expenses';

  @override
  String get featureSupplyExpensesDesc =>
      'An expense can be a supply for the space (coffee capsules, vacuum bags…): once validated it restocks or creates a consumable service with a unit price, and consumptions count the stock down.';

  @override
  String get featureValidationScopesTitle => 'Validators by role or person';

  @override
  String get featureValidationScopesDesc =>
      'Each validation rule names who validates: the admins, listed persons of any role, or every member — plus how many. Off: owner and admins as before.';

  @override
  String get featurePriceNegotiationsTitle => 'Price negotiations';

  @override
  String get featurePriceNegotiationsDesc =>
      'The tariff is the default; a member can hold their own conditions — monthly fee, overage rate, discount on supplements, unit prices per service and package, the occupation percentage — proposed by whoever holds Manage commercial agreements and validated by the rules. Seen by the member, the owners and the holders of View commercial agreements; every read is logged.';

  @override
  String get featureScheduledExpensesTitle => 'Scheduled expenses';

  @override
  String get featureUniqueMonogramsTitle => 'Distinct avatar initials';

  @override
  String get featureMessageGesturesTitle => 'Swipe to quote or take back';

  @override
  String get featureSubscriptionInvoicesTitle => 'Subscription invoices';

  @override
  String get featureSubscriptionInvoicesDesc =>
      'The membership fee is invoiced before the month it pays for, on a date you choose. Off: the fee stays on the whole-month invoice.';

  @override
  String get featureUsageInvoicesTitle => 'End-of-month invoices';

  @override
  String get featureUsageInvoicesDesc =>
      'Once a month is over, what it actually cost beyond the subscription — overage, accessories, services — is invoiced separately. Off: those stay on the whole-month invoice.';

  @override
  String get featureInvoiceSettlementTitle => 'Regroup invoices';

  @override
  String get featureInvoiceSettlementDesc =>
      'Several of a member\'s open invoices can be regrouped into one they pay. The originals stay in the archive, traceable position by position, and stop being chased separately.';

  @override
  String featureAlsoEnabled(String features) {
    return 'Also switched on: $features';
  }

  @override
  String featureAlsoEnables(String features) {
    return 'Switching this on also enables $features';
  }

  @override
  String get featureHeldBack =>
      'Waiting on the feature above — switch that on and this one works again.';

  @override
  String get featureMessageGesturesDesc =>
      'Swipe a message right to quote it in your reply; swipe left to take your own message back while nobody has read it yet, after a confirmation. Off: messages are deleted by holding them.';

  @override
  String get featureUniqueMonogramsDesc =>
      'An avatar without a photo shows initials that belong to one member: first and family initial, a further letter when two members would clash, numbers only as a last resort. Off: the first letter alone, repeated across everyone who shares it.';

  @override
  String get featureScheduledExpensesDesc =>
      'Recurring expenses (internet, phone, electricity): any member schedules one with its rule (every X days/weeks/months/years, X times or until a date); the schedule is validated once, and every due date is presented to the member — the validated amount counts immediately, a different amount explains itself and passes the expense validation.';

  @override
  String get featureInvoiceJourneyTitle => 'The journey of an invoice';

  @override
  String get featureInvoiceJourneyDesc =>
      'Every invoice shows where it stands — Issued, Payment, Confirmation, Closed — and whose move it is: the member pays, an admin confirms the declared payment, the issuer matches it, the validators decide. The issuers\' hub adds a stage strip with live counts and a How-it-works explainer.';

  @override
  String get featureBookingGateTitle => 'Booking gate';

  @override
  String get featureBookingGateDesc =>
      'Every booking surface — plan, day, week and month views, the booking sheet, the kiosk, a QR or NFC scan — checks the availability parameters before offering a window and names the reason when it cannot; closed days draw as closed in every view, a legend names the seat states, and admins may check members out where the policy allows.';

  @override
  String get featureCalendarViewsTitle => 'Calendar views';

  @override
  String get featureCalendarViewsDesc =>
      'The Calendar tab as agenda, week and month: per-day markers by kind, closed days drawn as closed, Today / Tomorrow headers, payment due dates and scheduled expenses in the feed. Off: the plain day-or-range selector over the feed.';

  @override
  String get featureMessagesHubTitle => 'Messages, reworked';

  @override
  String get featureMessagesHubDesc =>
      'One inbox bar (All / Unread / Archived and search), pin, mute, archive and mark-unread on a thread, the conversation as a full page with date separators, an attach menu and a kept draft in the composer, a person opened with one tap. Off: the two-bar inbox and the sheet thread.';

  @override
  String get helpTitle => 'Help';

  @override
  String get helpContents => 'Contents';

  @override
  String get helpHintMessages =>
      'Every conversation in one list, newest first. Tap the pencil to write to someone or start a group.';

  @override
  String get helpHintMessagesTopic => 'Messages';

  @override
  String get helpHintMessagesTip2 =>
      'Pick one person for a private chat, or several to make a group — the name field appears once there are two, and a group name is unique here, so nobody has to guess which “Team” they mean.';

  @override
  String get helpHintMessagesTip3 =>
      'Tap a name at the top of a chat to see their profile: today’s booking, whether they are checked in, and how to reach them.';

  @override
  String get helpHintMessagesTip4 =>
      'Search finds people, groups and the words inside messages — a result takes you straight there.';

  @override
  String get helpHintMessagesTip5 =>
      'Link a reservation or a space in a message instead of describing it; the reader taps it and lands on the right one.';

  @override
  String get helpHintLearnMore => 'Learn more';

  @override
  String get helpHintDismiss => 'Dismiss hint';

  @override
  String get helpHintPrevTip => 'Previous tip';

  @override
  String get helpHintNextTip => 'Next tip';

  @override
  String get helpHintRestoreTitle => 'Show help hints again';

  @override
  String get helpHintRestored => 'Help hints will be shown again.';

  @override
  String get helpHintReserve =>
      'Pick a day and time window, then tap a free seat to book it.';

  @override
  String get helpHintReserveTopic => 'Reserve hub';

  @override
  String get helpHintReserveTip2 =>
      'The Week and Month views find a free half-day at a glance — tap a free cell or day to book right there.';

  @override
  String get helpHintReserveTip3 =>
      'Tap the scan button and point the camera at a space\'s QR card — the sheet shows exactly what you may do there.';

  @override
  String get helpHintReserveTip3Topic => 'Scan a space code';

  @override
  String get helpHintReserveTip4 =>
      'The morning, afternoon and full-day chips pick your window before you choose a seat — a booked morning counts as half a day.';

  @override
  String get helpHintReserveTip4Topic => 'How booking behaves';

  @override
  String get helpHintReserveTip5 =>
      'Set your default booking period in Settings — the hub preselects it on every visit.';

  @override
  String get helpHintReserveTip5Topic => 'Settings & profile';

  @override
  String get helpHintPlan =>
      'The live floor plan: tap a free seat to book it, tap your own booking to check in.';

  @override
  String get helpHintPlanTopic => 'floor plan';

  @override
  String get helpHintPlanTip2 =>
      'Standing at a free seat? Tap it — the sheet suggests now until closing, and confirming checks you in on the spot.';

  @override
  String get helpHintPlanTip3 =>
      'Browse another moment with the date chip and the time scroller — the plan shows who sits where at any future time.';

  @override
  String get helpHintPlanTip4 =>
      'Double-tap a desk, a room or the floor itself — or tap the layers icon on the level rail — to reserve the whole space at once.';

  @override
  String get helpHintPlanTip5 =>
      'Tap your own seat for its sheet: check in from 15 minutes before your start, check out when you leave.';

  @override
  String get helpHintPlanTip5Topic => 'How booking behaves';

  @override
  String get helpHintCalendar =>
      'Pick a day or a range: everything dated that you may see, in one list, each row opening its source.';

  @override
  String get helpHintCalendarTopic => 'Calendar';

  @override
  String get helpHintCalendarTip2 =>
      'Switch Day to Range to see a whole week or month at once — the arrows step by the size of your selection.';

  @override
  String get helpHintCalendarTip3 =>
      'Tap a kind chip to see only that: bookings, alerts, messages, invoices, payments, consumption, reminders.';

  @override
  String get helpHintCalendarTip4 =>
      'Every row opens its source — the booking, the conversation, the alert, the invoice, or that month on Finances.';

  @override
  String get helpHintCalendarTip4Topic => 'How booking behaves';

  @override
  String get helpHintEvents =>
      'Everything that happened, in one feed. Decisions waiting for you sit on top; the chips filter the rest.';

  @override
  String get helpHintEventsTopic => 'confirmations';

  @override
  String get helpHintEventsTip2 =>
      'The filter chips remember your choice across visits — and the Unread chip narrows the list to unread messages.';

  @override
  String get helpHintEventsTip3 =>
      'Group the feed by type, day or member from the Group by menu; tap the group symbol to return to the flat list.';

  @override
  String get helpHintEventsTip4 =>
      'Pending decisions sit pinned on top with Accept and reject — and nobody ever validates their own event.';

  @override
  String get helpHintEditor =>
      'Draw rooms and desks, stamp seats onto them — tap a seat twice to edit its properties.';

  @override
  String get helpHintEditorTopic => 'space editor';

  @override
  String get helpHintEditorTip2 =>
      'Pick Office or Table in the toolbar and drag on the grid to draw it; Select moves and resizes what is already there.';

  @override
  String get helpHintEditorTip3 =>
      'The Seat tool stamps seats onto desks; a seat\'s sheet sets its direction, chair type, accessories and a maintenance block.';

  @override
  String get helpHintEditorTip4 =>
      'Give a seat its NFC/RFID tag from the seat sheet — tap the chip on the phone and the field fills itself.';

  @override
  String get helpHintEditorTip5 =>
      'Print a QR card for every seat, desk, office and level — pick the card size and what each card shows before exporting.';

  @override
  String get helpHintEditorTip5Topic => 'Space QR codes';

  @override
  String get helpHintAvailability =>
      'Set the open weekdays and working hours, and add closure days nobody can book.';

  @override
  String get helpHintAvailabilityTopic => 'Availability';

  @override
  String get helpHintAvailabilityTip2 =>
      'The booking granularity decides what a window may look like: half-days, full days, minute grids or free times.';

  @override
  String get helpHintAvailabilityTip3 =>
      'Day start, half-day boundary and day end drive every half-day and full-day slot — booking, check-in and billing follow them.';

  @override
  String get helpHintAvailabilityTip4 =>
      'Three booking policies tighten or relax the rules: past bookings, minute bookings kept within working hours, and admin check-out.';

  @override
  String get helpHintFeatures =>
      'Switch workspace functionality on or off — every member\'s app follows immediately.';

  @override
  String get helpHintFeaturesTopic => 'Features';

  @override
  String get helpHintFeaturesTip2 =>
      'The list is hierarchical — a feature that needs another sits indented under it and greys out while its parent is off.';

  @override
  String get helpHintFeaturesTip3 =>
      'Switching a parent off takes its whole subtree out of the app; the children\'s stored choices return untouched with the parent.';

  @override
  String get helpHintFeaturesTip4 =>
      'A feature\'s settings entry only appears while the feature is on — the Features screen itself always stays reachable.';

  @override
  String get helpHintMembers =>
      'Invite members, set their plan percentage and role, and manage their badges.';

  @override
  String get helpHintMembersTopic => 'Members & plans';

  @override
  String get helpHintMembersTip2 =>
      'Tap a member for their management sheet — subscription, reservation limit, badges, services and more in one place.';

  @override
  String get helpHintMembersTip3 =>
      'Badges live per member: mint a printable QR badge, or register their NFC card by holding it to the device.';

  @override
  String get helpHintMembersTip3Topic => 'NFC badges';

  @override
  String get helpHintMembersTip4 =>
      'Name admin grants admin rights after validation; the role matrix under Role management decides what every role may do.';

  @override
  String get helpHintMembersTip4Topic => 'Role management';

  @override
  String get helpHintMoney =>
      'Your monthly bill: browse months with the arrows; pay, export or share from here.';

  @override
  String get helpHintMoneyTopic => 'Money';

  @override
  String get helpHintMoneyTip2 =>
      'Every document offers the same three actions: quick view on screen, download as PDF, and share to any app.';

  @override
  String get helpHintMoneyTip2Topic => 'Quick view, save, share';

  @override
  String get helpHintMoneyTip3 =>
      'Record a payment with the date the money moved and the month it settles — the other side confirms it.';

  @override
  String get helpHintMoneyTip4 =>
      'Once the month is invoiced, the invoice decides: the month reads settled as soon as its invoice is paid.';

  @override
  String get helpHintMoneyTip4Topic => 'the invoice decides';

  @override
  String get helpHintValidation =>
      'Decide which actions need confirmation, who confirms, and how many approvals it takes.';

  @override
  String get helpHintValidationTopic => 'confirmations';

  @override
  String get helpHintValidationTip2 =>
      'One card per event type, each inheriting from the default rule until you edit it — payments, expenses, role changes and more.';

  @override
  String get helpHintValidationTip3 =>
      'Nobody ever validates their own event, and unanswered requests expire after 7 days — nothing is granted silently.';

  @override
  String get helpHintWorkspace =>
      'Country, currency, language and billing details — documents and taxes follow these settings.';

  @override
  String get helpHintWorkspaceTopic => 'Workspace settings';

  @override
  String get helpHintWorkspaceTip2 =>
      'Print the space QR cards from Exports — choose the card size and the info each card carries, ten per A4 page.';

  @override
  String get helpHintWorkspaceTip2Topic => 'Space QR codes';

  @override
  String get helpHintWorkspaceTip3 =>
      'Export the space as XML to back it up or template a new one; the setup questionnaire prefills a fresh workspace end to end.';

  @override
  String get helpHintWorkspaceTip4 =>
      'Reset the workspace wipes reservations, accounting and the floor plan — settings and members survive, and a typed confirmation guards it.';

  @override
  String get helpHintBadges =>
      'Issue a printable QR badge or register an NFC card; revoke lost badges any time.';

  @override
  String get helpHintBadgesTopic => 'NFC badges';

  @override
  String get helpHintBadgesTip2 =>
      'Register a card by holding it to the device — any readable chip works, and the dialog names the workspace it joins.';

  @override
  String get helpHintBadgesTip3 =>
      'Save a QR badge as PDF to print ten credit-card copies on one A4 page — spares included.';

  @override
  String get helpHintBadgesTip4 =>
      'Revoke a lost badge any time; swipe a revoked badge to the right to delete it for good.';

  @override
  String get helpHintCalendarTip5 =>
      'The shield shows who can see each kind, and who actually looked at your finances.';

  @override
  String get helpHintCalendarTip5Topic => 'Privacy';

  @override
  String get helpHintPrivacy =>
      'See who can read your data and who did, export everything as one file, or leave with your personal data erased.';

  @override
  String get helpHintPrivacyTopic => 'Privacy';

  @override
  String get helpHintPrivacyTip2 =>
      'Messages are readable only by the people in the conversation, whatever their role; money only by you and the finance permission.';

  @override
  String get helpHintPrivacyTip3 =>
      'Every read of your finances by someone else is logged by the server — the log cannot be skipped or edited.';

  @override
  String get helpHintMoneyPayments =>
      'Settle and ask: the balance, how to pay it or pay online, record a payment — and submit an expense, request half-days or add a consumption.';

  @override
  String get helpHintMoneyPaymentsTopic => 'The Payments face';

  @override
  String get helpHintMoneyPaymentsTip2 =>
      'Record a payment with the date the money moved and the month it settles — the other side confirms it.';

  @override
  String get helpHintMoneyPaymentsTip3 =>
      'Pay online settles what is owed right away; the instructions card shows the manual way with the reference to quote.';

  @override
  String get helpHintMoneyPaymentsTip3Topic => 'online payments';

  @override
  String get helpHintMoneyStatement =>
      'The month as it stands: your account, days used and left, subscription, services, packages, open positions, credits and the balance. Browse months with the arrows.';

  @override
  String get helpHintMoneyStatementTopic => 'The Statement face';

  @override
  String get helpHintMoneyStatementTip2 =>
      'A booked morning counts as half a day; days outside the opening hours follow the workspace\'s outside-hours policy.';

  @override
  String get helpHintMoneyStatementTip2Topic => 'How booking behaves';

  @override
  String get helpHintMoneyStatementTip3 =>
      'Out of days? Request extra half-days, buy a package, or keep booking pay-as-you-go — whichever your plan allows.';

  @override
  String get helpHintMoneyInvoices =>
      'Your invoices: what is open and when it is due, every invoice issued to you with its status, one tap to the detail and to paying it.';

  @override
  String get helpHintMoneyInvoicesTopic => 'The Invoices face';

  @override
  String get helpHintMoneyInvoicesTip2 =>
      'Past the workspace\'s payment term an open invoice reads overdue here, and the reminder levels the owner configured arrive by themselves — in your feed and as a push.';

  @override
  String get helpHintMoneyInvoicesTip2Topic => 'Automatic payment reminders';

  @override
  String get helpHintMoneyDocuments =>
      'Your paperwork: your conditions, the payments report, the month\'s statement as PDF, the document library.';

  @override
  String get helpHintMoneyDocumentsTopic => 'The Documents face';

  @override
  String get helpHintMoneyDocumentsTip3 =>
      'My conditions is your standing financial agreement — plan, rate, extras — rendered as a document you can keep.';

  @override
  String get helpHintValidationTipScopes =>
      'Who validates is the rule\'s scope: the admins, listed persons of any role, or every member — and how many. The owner always may; nobody validates their own event.';

  @override
  String get helpHintValidationTipScopesTopic => 'Role management';

  @override
  String get helpHintMoneyPaymentsTipSupply =>
      'Bought capsules or vacuum bags for the space? Submit the expense as a supply: validated, it goes on the shelf as a consumable that others pay for, and you are reimbursed.';

  @override
  String get helpHintMoneyPaymentsTipSupplyTopic => 'Services and Accessories';

  @override
  String get helpHintMoneyStatementTipNegotiation =>
      'Negotiated a deal? The card shows your prices beside the tariff, since when, and who can see them — the owners and finance admins, every read on the record.';

  @override
  String get helpHintMoneyStatementTipNegotiationTopic => 'Price negotiations';

  @override
  String get helpHintMembersTipNegotiation =>
      'A member\'s own prices: open their sheet → Price negotiation, set the fee, overage or discount you agreed, and the rule\'s validators confirm it.';

  @override
  String get helpHintMembersTipNegotiationTopic => 'Price negotiations';

  @override
  String get helpDotTooltip => 'Open the guide';

  @override
  String get helpTopicLegalIdentity => 'Legal identity';

  @override
  String get helpTopicEinvoice => 'e-invoice';

  @override
  String get helpTopicReportEditor => 'report editor';

  @override
  String get helpTopicDocumentLibrary => 'document library';

  @override
  String get helpTopicWorkspaceId => 'Workspace ID';

  @override
  String get helpTopicVat => 'VAT';

  @override
  String get helpTopicSettings => 'Settings & profile';

  @override
  String get helpTopicKiosk => 'Kiosk mode';

  @override
  String get helpTopicBilling => 'Billing';

  @override
  String get helpTopicWorkingHours => 'Working hours';

  @override
  String get helpTopicBookingPolicies => 'Booking policies';

  @override
  String get helpTopicBookingLimits => 'Booking limits';

  @override
  String get helpTopicScheduledExpenses => 'Scheduled expenses';

  @override
  String get helpTopicServer => 'your own server';

  @override
  String get inviteSectionTitle => 'Invite someone';

  @override
  String get inviteViaWhatsapp => 'WhatsApp';

  @override
  String get inviteViaSms => 'SMS';

  @override
  String get inviteViaShare => 'Share…';

  @override
  String get inviteFirstNameLabel => 'First name (optional)';

  @override
  String get inviteLastNameLabel => 'Last name (optional)';

  @override
  String get invitePhoneLabel => 'Phone (optional, with country code)';

  @override
  String get inviteLanguageLabel => 'Message language';

  @override
  String get inviteSendFailed =>
      'Could not open the app for sending. The message was copied instead.';

  @override
  String get inviteCreateFailed =>
      'Could not create the invitation. Check your connection and try again.';

  @override
  String invitationDefaultTemplate(
    String firstName,
    String workspaceName,
    String workspaceId,
    String downloadUrl,
    String inviteLink,
  ) {
    return 'Hi$firstName! You\'re invited to join our coworking space \"$workspaceName\" on DesKilo.\n\n1. Download the app:\n$downloadUrl\n\n2. Open it, create your account (e-mail + password) and sign in.\n\n3. Choose \"Join a workspace\" and enter your personal invitation code:\n$workspaceId\n(invitation link: $inviteLink)\n\nTip: simply copy this whole message and paste it into the app — the code is found automatically. Your code is personal, single-use and valid for 14 days.\n\nSee you soon at $workspaceName!';
  }

  @override
  String get invitationTemplateTitle => 'Invitation message';

  @override
  String get invitationTemplateHelp =>
      'Sent when you invite someone via WhatsApp, SMS, or share. Leave empty to use the built-in message in the chosen language. Available tags:';

  @override
  String get invitationTemplateHint =>
      'Custom invitation message using the tags above…';

  @override
  String get workspaceInvitePasteHint =>
      'Paste the whole invitation message — the ID is found automatically.';

  @override
  String get workspaceInviteCodeInvalid =>
      'No workspace ID found — paste the invitation or type the ID.';

  @override
  String get invoicesTitle => 'Invoices';

  @override
  String get invoicesEmpty => 'No invoices yet.';

  @override
  String get invoiceCreate => 'New invoice';

  @override
  String get invoiceMemberLabel => 'Member';

  @override
  String get invoiceIssue => 'Issue invoice';

  @override
  String get invoiceIssued => 'Invoice issued.';

  @override
  String get invoiceDownload => 'Download PDF';

  @override
  String get invoiceShare => 'Share PDF';

  @override
  String get invoicePdfTitle => 'Invoice';

  @override
  String get invoicePdfIssuedOn => 'Issued on';

  @override
  String get invoicePdfIssuedBy => 'Issued by';

  @override
  String get invoicePdfBilledTo => 'Billed to';

  @override
  String get invoicePdfSignature => 'Digital signature (SHA-256)';

  @override
  String get addressTitle => 'Address';

  @override
  String get addressNone => 'No address';

  @override
  String get addressSaved => 'Address saved';

  @override
  String get workspaceAddressLabel => 'Workspace address';

  @override
  String get featureInvoicing => 'Invoices';

  @override
  String get featureInvoicingDesc =>
      'Immutable, signed invoices in an archive — download or share as PDF.';

  @override
  String get featureAdminInvoicing => 'Admins issue invoices';

  @override
  String get featureAdminInvoicingDesc =>
      'Admins issue invoices too. The owner always can.';

  @override
  String get invoiceVoidedChip => 'Erroneous';

  @override
  String get invoiceVoidAction => 'Mark erroneous';

  @override
  String invoiceVoidConfirm(String number) {
    return 'Mark invoice $number as erroneous? This cannot be undone.';
  }

  @override
  String get invoiceVoided => 'Invoice marked as erroneous.';

  @override
  String get invoiceReplaceAction => 'Issue replacement';

  @override
  String get invoicePdfVoided => 'ERRONEOUS — voided on';

  @override
  String get invoicePdfReplaces => 'Replaces';

  @override
  String get invoiceNothingToInvoice =>
      'Nothing tracked for this month — nothing to invoice.';

  @override
  String get invoiceLineAdjustment => 'Adjustment';

  @override
  String get invoiceFilterAllMembers => 'All members';

  @override
  String get invoiceFilterAllMonths => 'All months';

  @override
  String get invoiceFilterMonthLabel => 'Month';

  @override
  String get invoiceSortTooltip => 'Sort';

  @override
  String get invoiceSortNewest => 'Newest first';

  @override
  String get invoiceSortByMember => 'By member';

  @override
  String get invoiceSortByMonth => 'By month';

  @override
  String get invoiceBalance => 'Balance due';

  @override
  String get invoiceDetailedToggle =>
      'Include the detailed annex (check-ins, services, payments)';

  @override
  String get invoicePdfDescription => 'Description';

  @override
  String get invoicePdfCharges => 'Charges';

  @override
  String get invoicePdfPayments => 'Payments';

  @override
  String get invoicePdfAnnex => 'Annex — details';

  @override
  String get invoicePdfAttendance => 'Check-ins';

  @override
  String get invoicePdfActivity => 'Bookings & payments';

  @override
  String get invoicePdfReserved => 'reserved';

  @override
  String get invoicePdfPage => 'Page';

  @override
  String get invoiceRemindAction => 'Send a reminder';

  @override
  String get invoiceReminded => 'Reminder recorded.';

  @override
  String invoiceRemindedBadge(int count) {
    return 'Reminded ×$count';
  }

  @override
  String invoiceReminderMessage(String number, String amount) {
    return 'Friendly reminder: invoice $number — balance due $amount.';
  }

  @override
  String get invoiceEInvoiceDownload => 'Download e-invoice (XML)';

  @override
  String get invoiceEInvoiceShare => 'Share e-invoice (XML)';

  @override
  String get invoiceTabToInvoice => 'To invoice';

  @override
  String get invoiceTabOpen => 'Open';

  @override
  String get invoiceTabArchive => 'Archive';

  @override
  String get invoiceIssueAll => 'Invoice all';

  @override
  String get invoiceIssueOne => 'Issue';

  @override
  String get invoiceAllCaughtUp => 'All caught up — nothing to invoice.';

  @override
  String get invoiceNoOpen => 'No open invoices.';

  @override
  String invoiceSummaryToInvoice(int count) {
    return '$count to invoice';
  }

  @override
  String invoiceSummaryOpen(int count, String amount) {
    return '$count open · $amount outstanding';
  }

  @override
  String invoiceOpenAge(int days) {
    return '$days days';
  }

  @override
  String invoiceIssuedCount(int count) {
    return '$count invoices issued.';
  }

  @override
  String get eventTypeInvoicePayment => 'Invoice payment';

  @override
  String eventInvoicePaid(String number, String amount) {
    return 'Invoice $number paid — $amount';
  }

  @override
  String get invoiceMatchAction => 'Mark as paid';

  @override
  String get invoiceMatchNoteLabel => 'Note';

  @override
  String get invoiceMatchNoteRequired => 'A note is required.';

  @override
  String invoiceMatchOver(String excess) {
    return 'The member paid $excess more.';
  }

  @override
  String get invoiceMatchCreditNote => 'Create a credit note for the excess';

  @override
  String get invoiceMatchForce => 'Accept anyway (note why)';

  @override
  String invoiceMatchUnder(String missing) {
    return 'The member paid $missing less — accepting requires a note.';
  }

  @override
  String get invoiceMatched => 'Invoice matched.';

  @override
  String get invoiceMatchPendingBadge => 'Awaiting validation';

  @override
  String get invoiceMatchedBadge => 'Paid';

  @override
  String get invoiceAlreadyInvoiced =>
      'This month is already invoiced for this member.';

  @override
  String get invoiceMatchPickPayment => 'Select the registered payment';

  @override
  String get invoiceMatchNoPayments =>
      'No registered payment to match — record or confirm it first.';

  @override
  String get invoiceStatusOpen => 'Open';

  @override
  String invoiceCountShown(int count) {
    return '$count invoices';
  }

  @override
  String get invoiceFilterNoMatch => 'No invoice matches these filters.';

  @override
  String get invoiceFilterClear => 'Clear filters';

  @override
  String get invoiceShowCancelled => 'Show cancelled';

  @override
  String invoiceReplacedBy(String number) {
    return 'Replaced by $number';
  }

  @override
  String invoiceMatchSummary(String amount, String date) {
    return 'Paid $amount on $date';
  }

  @override
  String invoiceRemindedLast(String date) {
    return 'last reminder $date';
  }

  @override
  String invoiceAnnexSummary(int movements, int checkIns) {
    return 'Annex: $movements movements, $checkIns check-ins';
  }

  @override
  String get invoicePickMember =>
      'Pick a member to see what their month tracked.';

  @override
  String get invoiceRunningMonth =>
      'This month is still running — its positions can still change, and a month can only be invoiced once.';

  @override
  String invoiceIssueAllConfirm(int count, String month, String total) {
    return 'Issue $count invoices for $month, $total in total? An issued invoice can no longer be edited — a mistake is corrected with a replacement.';
  }

  @override
  String invoiceIssuedPartial(int issued, int failed) {
    return '$issued issued, $failed failed.';
  }

  @override
  String get invoiceEInvoiceAction => 'E-invoice (XML)';

  @override
  String get invoiceEInvoiceExplain =>
      'The machine-readable EN 16931 invoice — the file tax administrations and business customers ask for.';

  @override
  String invoiceEInvoiceBusinessRoute(String channel, String format) {
    return 'Business customers: send it through $channel as $format.';
  }

  @override
  String invoiceEInvoicePublicRoute(String channel) {
    return 'Public-sector customers: $channel.';
  }

  @override
  String get invoiceEInvoiceTransportPeppol =>
      'An access point delivers it to the customer — no government platform in between.';

  @override
  String get invoiceEInvoiceTransportClearance =>
      'The national platform receives the invoice first and hands it on — sending it straight to the customer is not an option.';

  @override
  String get invoiceEInvoiceTransportAccredited =>
      'An accredited platform carries the invoice and reports it to the tax administration for you.';

  @override
  String get invoiceEInvoiceTransportBilateral =>
      'No channel is imposed: e-mail, a portal or Peppol — whatever you agree with the customer.';

  @override
  String invoiceEInvoiceFormatMismatch(String channel, String format) {
    return '$channel only accepts $format: this EN 16931 file serves Peppol, public buyers and foreign customers — your platform or accountant converts the rest.';
  }

  @override
  String get invoiceEInvoiceReady => 'Ready — this file satisfies EN 16931.';

  @override
  String get invoiceEInvoiceBlockedTitle =>
      'A validator would reject this file:';

  @override
  String get invoiceEInvoiceIncompleteTitle =>
      'Valid, but the strict national profiles also want:';

  @override
  String get invoiceGapVatNotSupported =>
      'The workspace charges VAT but this invoice carries no rate — add your VAT rates, then issue it again.';

  @override
  String get invoiceGapMissingVatId =>
      'The VAT number is missing — an exempt seller must state one.';

  @override
  String get invoiceGapMissingLegalId =>
      'The company registration number is missing (SIREN, HRB, CIF…) — nothing identifies you on the invoice.';

  @override
  String get invoiceGapMissingExemptionReason =>
      'The reason for not charging VAT is missing.';

  @override
  String get invoiceGapMissingSellerCountry =>
      'The workspace country is missing.';

  @override
  String get invoiceGapMissingBuyerCountry =>
      'The customer\'s country is missing.';

  @override
  String get invoiceGapNoChargeLines =>
      'This invoice has no charge line — its month was fully covered by payments, so there is no invoice to send.';

  @override
  String get invoiceGapMissingSellerCity => 'the city of the workspace address';

  @override
  String get invoiceGapMissingSellerPostalCode =>
      'the post code of the workspace address';

  @override
  String get invoiceEInvoiceFixIdentity => 'Complete the legal identity';

  @override
  String get legalIdentityTitle => 'Legal identity & e-invoicing';

  @override
  String get legalIdentitySubtitle =>
      'VAT regime and registration numbers — required by the e-invoice';

  @override
  String get legalIdentityIntro =>
      'What an EN 16931 e-invoice must state about you. Invoices already issued keep the identity they were signed with.';

  @override
  String get legalIdentityRegime => 'VAT regime';

  @override
  String get legalIdentityRegimeNotSubject => 'Outside the scope of VAT';

  @override
  String get legalIdentityRegimeExempt => 'VAT-exempt (small-business scheme)';

  @override
  String get legalIdentityRegimeVatRegistered => 'VAT-registered (charges VAT)';

  @override
  String get legalIdentityRegimeHint =>
      'The regime decides which number the norm requires: a registration number outside the scope of VAT, a VAT number when exempt.';

  @override
  String get legalIdentityVatId => 'VAT number';

  @override
  String get legalIdentityLegalId => 'Company registration number';

  @override
  String get legalIdentityExemptionReason => 'Why no VAT is charged';

  @override
  String get legalIdentityStreet => 'Street';

  @override
  String get legalIdentityCity => 'City';

  @override
  String get legalIdentityPostalCode => 'Post code';

  @override
  String get legalIdentitySaved => 'Legal identity saved.';

  @override
  String get legalIdentityVatWarning =>
      'This workspace charges VAT but no rate is set up: invoices show no tax and the XML export stays disabled until you add one.';

  @override
  String get addressCountryLabel => 'Country';

  @override
  String get addressVatIdLabel => 'VAT number (if you invoice as a business)';

  @override
  String get invoiceProformaAction => 'Proforma invoice';

  @override
  String get invoicePdfProforma => 'Proforma';

  @override
  String get invoiceProformaShared => 'Proforma shared.';

  @override
  String get invoiceProformaNothing =>
      'Nothing tracked for this month — no proforma to send.';

  @override
  String get invoicePdfCopy => 'Copy';

  @override
  String get invoiceStatusPartiallyPaid => 'Partially paid';

  @override
  String get invoiceRegisterTitle => 'Invoice register';

  @override
  String get invoiceRegisterDate => 'Date';

  @override
  String get invoiceRegisterName => 'Name';

  @override
  String get invoiceRegisterAmount => 'Amount';

  @override
  String get invoiceRegisterTotal => 'Total';

  @override
  String get invoiceFacturXDownload => 'Download Factur-X (PDF)';

  @override
  String get invoiceFacturXShare => 'Share Factur-X (PDF)';

  @override
  String get invoiceFacturXExplain =>
      'One file: the invoice a human reads, with the machine-readable XML inside it. This is what most platforms expect.';

  @override
  String get invoiceSendAction => 'Send to the government platform';

  @override
  String get invoiceSendAccepted => 'Sent — the platform accepted it.';

  @override
  String get invoiceSendCustomerAction => 'Send to the customer\'s service';

  @override
  String get invoiceSendCustomerAccepted =>
      'Sent — the customer\'s service accepted it.';

  @override
  String get einvoiceCustomerSectionTitle => 'Customer delivery service';

  @override
  String get einvoiceCustomerSectionHelp =>
      'Where invoices go for the customer: their Peppol access point, portal or agreed upload API — separate from the government platform.';

  @override
  String get invoiceSendRejected => 'The platform refused it.';

  @override
  String invoiceSentOn(String date, String status) {
    return 'Sent $date · $status';
  }

  @override
  String get invoiceSendStatusAccepted => 'accepted';

  @override
  String get invoiceSendStatusRejected => 'rejected';

  @override
  String get invoiceSendStatusFailed => 'not delivered';

  @override
  String get einvoiceConfigTitle => 'E-invoicing platform';

  @override
  String get einvoiceConfigIntro =>
      'Where DesKilo posts your invoices. Any platform that accepts an upload with a token works — a plateforme agréée, a Peppol access point, a national platform. The token is stored server-side and never comes back out.';

  @override
  String get einvoiceConfigEndpoint => 'Upload URL';

  @override
  String get einvoiceConfigToken => 'Token or credential';

  @override
  String get einvoiceConfigHeader => 'Auth header (default Authorization)';

  @override
  String get einvoiceConfigField => 'File field name (default file)';

  @override
  String get einvoiceConfigSaved => 'Platform saved.';

  @override
  String get einvoiceConfigCleared => 'Platform removed.';

  @override
  String get einvoiceConfigClear => 'Remove the platform';

  @override
  String get einvoiceConfigTokenSet =>
      'A token is stored (type a new one to replace it).';

  @override
  String get invoiceAccountingExport => 'Accounting export';

  @override
  String get invoiceAccountingExportEmpty =>
      'Nothing to export for this period.';

  @override
  String get invoiceRegisterYear => 'Year';

  @override
  String get invoiceRegisterAllYears => 'All years';

  @override
  String get invoiceExportSafT => 'SAF-T (XML, international)';

  @override
  String get invoiceExportFec => 'FEC (France, required in an audit)';

  @override
  String get invoiceExportChoose => 'Export for accounting';

  @override
  String get fecAccountsTitle => 'Accounts to book';

  @override
  String get fecAccountsIntro =>
      'A FEC is made of accounting entries, so it needs account numbers. These are the French chart defaults — change them to your accountant\'s.';

  @override
  String get fecAccountCustomers => 'Customers';

  @override
  String get fecAccountRevenue => 'Revenue';

  @override
  String get fecAccountBank => 'Bank';

  @override
  String get fecMissingSiren =>
      'The FEC is named after your registration number — fill it in under Legal identity first.';

  @override
  String get invoiceEInvoiceStaleIdentity =>
      'Your legal identity is complete now, but this invoice was signed before it and keeps what it was issued with. Mark it erroneous and issue a replacement to carry the new identity.';

  @override
  String get einvoiceConfigUnavailable =>
      'The platform settings could not be loaded. Check your connection and try again.';

  @override
  String get einvoiceEnvTitle => 'Send to which platform?';

  @override
  String get einvoiceEnvProd => 'Production';

  @override
  String get einvoiceEnvUat => 'UAT (test platform)';

  @override
  String get einvoiceEnvDev => 'Dev (test platform)';

  @override
  String get einvoiceEnvProdHint => 'The real submission.';

  @override
  String get einvoiceEnvTestHint => 'A rehearsal — logged as a test send.';

  @override
  String invoiceSendAcceptedTest(String env) {
    return 'Test send accepted ($env).';
  }

  @override
  String get einvoiceTestEnvsTitle => 'Test environments (UAT / Dev)';

  @override
  String get einvoiceTestEnvsHelp =>
      'Separate endpoints and tokens for rehearsals. The choice appears at send time only while developer mode is on.';

  @override
  String get einvoiceUatEndpoint => 'UAT upload URL';

  @override
  String get einvoiceUatToken => 'UAT token or credential';

  @override
  String get einvoiceDevEndpoint => 'Dev upload URL';

  @override
  String get einvoiceDevToken => 'Dev token or credential';

  @override
  String get invoiceSentTestChip => 'test';

  @override
  String get invoiceTemplateTitle => 'Invoice PDF template';

  @override
  String get invoiceTemplateHint =>
      'Three report bands rendered on the PDF — the e-invoice XML is never touched. Liquid conditions and loops, then line markup:';

  @override
  String get invoiceTemplateIntroLabel => 'Intro (above the billed-to block)';

  @override
  String get invoiceTemplateFooterLabel =>
      'Footer (under the totals — payment terms, legal mentions)';

  @override
  String get invoiceTemplateSaved => 'Invoice template saved.';

  @override
  String get invoiceTemplateHeaderLabel => 'Header band';

  @override
  String get invoiceTemplateBodyLabel => 'Body band (the invoice lines)';

  @override
  String get invoiceTemplateReset => 'Reset to default';

  @override
  String get invoiceTemplatePreview => 'Preview';

  @override
  String get invoiceTemplateNoPreview =>
      'Issue an invoice first — the preview renders your newest one.';

  @override
  String get reminderPdfTitleFriendly => 'Payment reminder';

  @override
  String get reminderPdfTitleFirm => 'Reminder';

  @override
  String get reminderPdfOpeningFriendly =>
      'this is a friendly reminder that the invoice below is still open. Perhaps it simply slipped through — no worries.';

  @override
  String get reminderPdfOpeningFirm =>
      'despite our previous reminder, the invoice below remains unpaid. Please settle the amount without delay.';

  @override
  String get reminderPdfDaysOpen => 'Open for';

  @override
  String get reminderPdfDays => 'days';

  @override
  String get reminderPdfLevelLabel => 'Reminder level';

  @override
  String get reminderPdfClosing =>
      'If you have already paid, please disregard this letter.';

  @override
  String get dunningSettingsTitle => 'Reminder rules';

  @override
  String get dunningLevels => 'Number of reminder levels';

  @override
  String get dunningFirstAfterDays => 'Days until the first reminder';

  @override
  String get dunningBetweenDays => 'Days between reminders';

  @override
  String get dunningSaved => 'Reminder rules saved.';

  @override
  String dunningDueChip(int level) {
    return 'Reminder $level due';
  }

  @override
  String get invoiceTemplateDocInvoice => 'Invoice';

  @override
  String invoiceTemplateDocReminder(int level) {
    return 'Reminder $level';
  }

  @override
  String get reportPreviewTitle => 'Quick preview — your newest invoice';

  @override
  String get reportPreviewSimulated => 'Quick preview — sample data';

  @override
  String get reportPresetClassic => 'Classic';

  @override
  String get reportPresetFormalLetter => 'Formal letter';

  @override
  String get reportSubject => 'Subject';

  @override
  String get reportRegards => 'Kind regards';

  @override
  String get invoiceTemplatePresets => 'Templates';

  @override
  String get invoiceTemplateQuickPreview => 'Quick preview';

  @override
  String get invoiceTemplateDownload => 'Download PDF';

  @override
  String get invoiceTemplateShare => 'Share PDF';

  @override
  String get invoiceTemplateDocStatement => 'Statement';

  @override
  String get reportPresetSimple => 'Simple';

  @override
  String get reportPresetVerbose => 'Detailed';

  @override
  String get invoiceLegalSection => 'Invoice mentions';

  @override
  String get invoiceLegalIntro =>
      'The statutory lines printed on invoices and reminders. The payment clauses fall back to legal defaults when left empty.';

  @override
  String get invoiceLegalFormField => 'Legal form & capital';

  @override
  String get invoiceLegalFormHint => 'e.g. SARL au capital de 7 500 €';

  @override
  String get invoiceLegalRegistrationField => 'Trade register';

  @override
  String get invoiceLegalRegistrationHint =>
      'e.g. RCS Saint-Brieuc 680 357 910';

  @override
  String get invoiceLegalPaymentTermsField => 'Payment terms';

  @override
  String get invoiceLegalLatePenaltyField => 'Late-payment penalty';

  @override
  String get invoiceLegalRecoveryField => 'Recovery indemnity';

  @override
  String get invoiceLegalEscompteField => 'Early-payment discount';

  @override
  String get invoiceLegalInsuranceField => 'Professional insurance';

  @override
  String get invoiceLegalSpecialField => 'Special mentions';

  @override
  String get invoiceLegalPaymentTermsDefault => 'Payment on receipt.';

  @override
  String get invoiceLegalLatePenaltyDefault =>
      'Late-payment penalty: three times the statutory interest rate.';

  @override
  String get invoiceLegalRecoveryDefault =>
      'Fixed recovery indemnity for collection costs: €40.';

  @override
  String get invoiceLegalEscompteDefault => 'No discount for early payment.';

  @override
  String get reportColUnitPrice => 'Unit price';

  @override
  String get reportColQty => 'Qty';

  @override
  String get reportColTotal => 'Total';

  @override
  String get invoiceLegalKindField => 'Organization type';

  @override
  String get invoiceLegalKindCompany => 'Company / business';

  @override
  String get invoiceLegalKindAssociation => 'Association (non-profit)';

  @override
  String get invoiceLegalAssociationHint =>
      'The late-penalty, recovery-indemnity and discount clauses are printed only when filled — they are mandatory only between professionals.';

  @override
  String get invoiceLegalFormHintAssociation => 'e.g. Association loi 1901';

  @override
  String get invoiceLegalRegistrationHintAssociation =>
      'e.g. RNA W123456789 · SIRET if assigned';

  @override
  String get invoiceLegalAssociationReasonHint =>
      'e.g. \"TVA non applicable, art. 293 B du CGI\" — or \"Exonération de TVA, art. 261, 7-1° du CGI\" for services to members';

  @override
  String get reportEditorMarkup => 'Markup';

  @override
  String get reportEditorVisual => 'Visual';

  @override
  String get reportInsertImage => 'Insert image';

  @override
  String get reportImagesTitle => 'Report images';

  @override
  String get reportImagesEmpty =>
      'No image yet — upload your logo, a stamp or a signature and reference it with ![name].';

  @override
  String get reportImageUpload => 'Upload image';

  @override
  String get reportVisualAddLine => 'Add line';

  @override
  String get reportLineTitle => 'Title';

  @override
  String get reportLineSection => 'Section';

  @override
  String get reportLineText => 'Text';

  @override
  String get reportLineSmall => 'Small print';

  @override
  String get reportLineRow => 'Table row';

  @override
  String get reportLineBoldRow => 'Bold row';

  @override
  String get reportLineDivider => 'Divider';

  @override
  String get reportLineSpacer => 'Spacing';

  @override
  String get reportLineImage => 'Image';

  @override
  String get reportLineColumns => 'Columns start/end';

  @override
  String get reportLineColumnsSplit => 'Column break';

  @override
  String get reportLineLogic => 'Logic';

  @override
  String get reportDocAgreement => 'Financial agreement';

  @override
  String get reportDocPayments => 'Payments report';

  @override
  String get reportDocWorkspace => 'Workspace report';

  @override
  String get agreementExtraHalfDay => 'Extra half-day';

  @override
  String get paymentsPendingTag => 'pending validation';

  @override
  String get reportSectionFeatures => 'Features';

  @override
  String get reportSectionPrices => 'Prices';

  @override
  String get moneyMyAgreement => 'My conditions';

  @override
  String get memberSendAgreement => 'Send the financial agreement';

  @override
  String get reportQuickView => 'Quick view';

  @override
  String get reportDocWorkspaceSubtitle =>
      'Everything about the space — through the report editor\'s workspace template';

  @override
  String get reportTemplateLangDefault => 'Default (all languages)';

  @override
  String get reportLanguageAmbiguous =>
      'This country has several languages — set the workspace language in Workspace settings first.';

  @override
  String get reportDesignEmpty => 'Empty band — add an element below.';

  @override
  String get invoiceStatusRemainderCancelled =>
      'Partially paid · remainder cancelled';

  @override
  String get invoiceRemainingLabel => 'Remaining';

  @override
  String get invoiceWriteoffButton => 'Cancel outstanding amount';

  @override
  String get invoiceWriteoffExplain =>
      'The unpaid remainder of this invoice will be cancelled and the invoice archived as partially paid — once the validators confirm. Until then it stays open and owed.';

  @override
  String get invoiceWriteoffRequested =>
      'Write-off requested — awaiting validation.';

  @override
  String get eventTypeInvoiceWriteoff => 'Outstanding write-off';

  @override
  String eventInvoiceWriteoffLine(String actor, String number, String amount) {
    return '$actor asks to cancel the remainder of $number — $amount';
  }

  @override
  String get invoicePdfCreditNote => 'Credit note';

  @override
  String get invoiceStatusRefunded => 'Refunded';

  @override
  String get invoiceRefundLabel => 'To refund';

  @override
  String get invoiceRefundButton => 'Record the refund';

  @override
  String invoiceRefundExplain(String amount) {
    return 'This credit note means the WORKSPACE owes the member $amount. Record that the refund was paid out — the amount is booked against the member\'s balance and the document closes as Refunded.';
  }

  @override
  String get invoiceRefunded => 'Refund recorded.';

  @override
  String invoiceSummaryToRefund(int count, String amount) {
    return '$count to refund · $amount';
  }

  @override
  String get eventTypeInvoiceReminder => 'Payment reminder';

  @override
  String eventInvoiceReminderLine(String number, int level, String amount) {
    return 'Reminder $level: invoice $number — $amount still due';
  }

  @override
  String get dunningAutomatic => 'Automatic reminders';

  @override
  String get dunningAutomaticHint =>
      'Once a day, open invoices past the term get their next reminder level by themselves — an alert in the member\'s feed and a push. Off: you send each reminder yourself.';

  @override
  String get eventTypePriceNegotiation => 'Price negotiation';

  @override
  String eventPriceNegotiationLine(String actor, String member, String terms) {
    return '$actor proposes a deal for $member: $terms';
  }

  @override
  String eventPriceNegotiationItems(int count) {
    return '$count items';
  }

  @override
  String get journeyStepIssued => 'Issued';

  @override
  String get journeyStepPayment => 'Payment';

  @override
  String get journeyStepConfirmation => 'Confirmation';

  @override
  String get journeyStepClosed => 'Closed';

  @override
  String journeyIssuerMemberPays(String name, String amount, String date) {
    return 'Waiting for $name\'s payment of $amount — due $date';
  }

  @override
  String journeyIssuerMemberPaysOverdue(String name, String amount, int days) {
    return '$name owes $amount — overdue by $days days';
  }

  @override
  String journeyIssuerMemberPaysRemainder(String name, String amount) {
    return '$name still owes $amount after a partial payment';
  }

  @override
  String journeyIssuerAdminConfirms(String name, String amount) {
    return '$name declared a payment of $amount — another admin confirms it in Events';
  }

  @override
  String journeyIssuerMemberConfirms(String name, String amount) {
    return 'A payment of $amount was recorded — $name confirms it in Events';
  }

  @override
  String journeyIssuerMatches(String amount) {
    return 'A payment of $amount is registered — match it to this invoice';
  }

  @override
  String get journeyValidatorsMatch =>
      'Payment matched — awaiting the validators\' decision';

  @override
  String get journeyValidatorsWriteoff =>
      'Write-off of the remainder requested — awaiting the validators';

  @override
  String journeyIssuerRefunds(String name, String amount) {
    return 'Credit note — refund $amount to $name and record it';
  }

  @override
  String get journeyIssuerReplaces => 'Cancelled — issue the replacement';

  @override
  String journeyMemberPays(String amount, String date) {
    return 'Your move: pay $amount by $date';
  }

  @override
  String journeyMemberPaysOverdue(String amount, int days) {
    return 'Your move: pay $amount — overdue by $days days';
  }

  @override
  String journeyMemberPaysRemainder(String amount) {
    return 'Your move: pay the remaining $amount';
  }

  @override
  String journeyMemberDeclared(String amount) {
    return 'You declared $amount — the workspace is confirming it';
  }

  @override
  String journeyMemberConfirms(String amount) {
    return 'Your move: confirm the payment of $amount recorded for you, in Events';
  }

  @override
  String journeyMemberRegistered(String amount) {
    return 'Your payment of $amount is registered — the workspace matches it to this invoice';
  }

  @override
  String get journeyMemberValidators => 'Payment matched — awaiting validation';

  @override
  String get journeyMemberWriteoff =>
      'The workspace asked to cancel the remainder — awaiting validation';

  @override
  String journeyMemberRefund(String amount) {
    return 'The workspace owes you $amount — nothing to pay';
  }

  @override
  String get journeyMemberReplaces => 'Cancelled — a replacement follows';

  @override
  String journeyClosedPaid(String date) {
    return 'Paid on $date — closed';
  }

  @override
  String journeyClosedRemainder(String date) {
    return 'Closed — remainder cancelled on $date';
  }

  @override
  String journeyClosedRefunded(String date) {
    return 'Refunded on $date — closed';
  }

  @override
  String journeyClosedReplaced(String number) {
    return 'Cancelled — replaced by $number';
  }

  @override
  String get journeyClosedSettled =>
      'Regrouped into another invoice — that one is owed and chased';

  @override
  String get journeyStageIssue => 'To issue';

  @override
  String get journeyStageCollect => 'To collect';

  @override
  String get journeyStageConfirm => 'To confirm';

  @override
  String get journeyStageClosed => 'Closed';

  @override
  String journeyOverdueCount(int count) {
    return '$count overdue';
  }

  @override
  String get journeyStageStripLabel =>
      'The invoicing process: issue, collect, confirm, close';

  @override
  String get journeyHowButton => 'How it works';

  @override
  String get journeyHowTitle => 'How invoicing works';

  @override
  String get journeyHowIntro =>
      'Four steps, the same for every invoice. Each one says whose move it is.';

  @override
  String get journeyHowWorkspaceLabel => 'Workspace';

  @override
  String get journeyHowMemberLabel => 'Member';

  @override
  String get journeyHowIssuedWorkspace =>
      'Issues the invoice from the month\'s tracked data — numbered, signed, immutable — and shares the PDF or sends the e-invoice.';

  @override
  String get journeyHowIssuedMember =>
      'Finds it on the Invoices face: positions, balance, due date.';

  @override
  String get journeyHowPaymentWorkspace =>
      'Waits for the money. Past the term it sends the reminder levels it configured — by hand or automatically.';

  @override
  String get journeyHowPaymentMember =>
      'Pays online (settled at once) or by transfer, then records the payment so the workspace knows.';

  @override
  String get journeyHowConfirmationWorkspace =>
      'Another admin confirms the declared payment; the issuer then matches the registered payment to the invoice (Mark as paid) — a validation rule may hand the match to the validators. Paid more? A credit note. Paid less? Partially paid, the rest owed until paid or written off.';

  @override
  String get journeyHowConfirmationMember =>
      'Nothing to do — unless the workspace recorded the payment for them: then they confirm it in Events.';

  @override
  String get journeyHowClosedWorkspace =>
      'Paid, remainder cancelled or refunded: the invoice moves to the archive. A wrong invoice is marked erroneous and replaced — before payment, never after.';

  @override
  String get journeyHowClosedMember =>
      'The month reads settled and the invoice stays readable forever: quick view, PDF, share.';

  @override
  String get journeyTimelineTitle => 'Timeline';

  @override
  String journeyPrimaryRemind(int level) {
    return 'Send reminder $level';
  }

  @override
  String get journeyPrimaryConfirmInEvents => 'Open Events';

  @override
  String journeyOutstanding(String amount) {
    return '$amount outstanding';
  }

  @override
  String get eventTypeMemberJoin => 'New member';

  @override
  String get memberStatusPending => 'Pending';

  @override
  String get pendingApprovalTitle => 'Awaiting approval';

  @override
  String pendingApprovalBody(String workspace) {
    return 'You have joined $workspace. An administrator must approve your membership before you can use the workspace — you will get access as soon as they confirm.';
  }

  @override
  String get pendingApprovalRefresh => 'Check again';

  @override
  String get memberApprove => 'Approve membership';

  @override
  String get memberRejectJoin => 'Reject membership';

  @override
  String get workspaceConfigInvitations => 'Invitations';

  @override
  String get workspaceConfigInvitationCustom =>
      'Custom invitation message configured';

  @override
  String get workspaceConfigInvitationDefault =>
      'Built-in invitation message (all languages)';

  @override
  String get workspaceConfigInvitationSingleUse =>
      'Personal invitation codes are single-use and expire after 14 days; new members need admin approval';

  @override
  String get memberKioskLabel => 'Kiosk';

  @override
  String get memberMakeKiosk => 'Make kiosk device';

  @override
  String get memberUnmakeKiosk => 'Revert kiosk to member';

  @override
  String get memberBadgesTooltip => 'Badges';

  @override
  String memberBadgesTitle(String name) {
    return 'Badges — $name';
  }

  @override
  String get badgeIssue => 'New badge';

  @override
  String get badgeTokenOnce => 'Save this QR now — it is shown only once.';

  @override
  String get badgeNone => 'No badges yet.';

  @override
  String get badgeDefaultLabel => 'Badge';

  @override
  String get badgeRevoke => 'Revoke';

  @override
  String get badgeRevoked => 'Revoked';

  @override
  String get commonClose => 'Close';

  @override
  String get kioskCheckIn => 'Check in';

  @override
  String get kioskReserve => 'Reserve';

  @override
  String get kioskCheckOut => 'Check out';

  @override
  String get kioskPresentBadge => 'Present your badge';

  @override
  String get kioskBadgeHint => 'Scan your badge QR, or type its code.';

  @override
  String get kioskBadgeFieldLabel => 'Badge code';

  @override
  String get kioskBadgeConfirm => 'Confirm';

  @override
  String get kioskBadgeRejected => 'Badge not recognized.';

  @override
  String get kioskDone => 'Done — you\'re all set.';

  @override
  String get kioskTapHint => 'Tap a seat to check in';

  @override
  String get badgeSavePdf => 'Save as PDF';

  @override
  String get badgeRegisterCard => 'Register card';

  @override
  String get badgeTapCardTitle => 'Register a card';

  @override
  String get badgeTapCardHint =>
      'Hold the RFID/NFC card to the back of the device.';

  @override
  String get badgeCardRegistered => 'Card registered.';

  @override
  String get badgeCardAlreadyRegistered => 'That card is already registered.';

  @override
  String get kioskBadgeHintNfc =>
      'Tap your card, scan your QR, or type its code.';

  @override
  String get nfcConfigTitle => 'RFID / NFC badges';

  @override
  String get nfcConfigIntro =>
      'Members check in at a wall-mounted kiosk by tapping an RFID/NFC card. Register each member\'s card in Members & plans; at the kiosk they tap to reserve or check in.';

  @override
  String get nfcConfigEnable => 'Enable NFC badge check-in';

  @override
  String get nfcConfigEnableDesc =>
      'Show the card-tap option on kiosks and in the badge manager.';

  @override
  String get nfcConfigDeviceStatus => 'This device';

  @override
  String get nfcConfigChecking => 'Checking…';

  @override
  String get nfcConfigDeviceReady => 'NFC available and enabled';

  @override
  String get nfcConfigDeviceUnavailable =>
      'No NFC here — Android with NFC on is needed (iPads have no NFC). QR badges still work.';

  @override
  String get kioskConfirmAction => 'Confirm';

  @override
  String get kioskRejectAction => 'Reject';

  @override
  String get kioskGateTitle => 'Start kiosk mode?';

  @override
  String get kioskGateBody =>
      'This account is set up as the workspace kiosk. In kiosk mode the tablet only shows the floor plan for badge check-in — nothing else can be opened. To leave kiosk mode, restart the tablet.';

  @override
  String get kioskGateStart => 'Start kiosk mode';

  @override
  String get kioskGateReject => 'Not now — open the app normally';

  @override
  String get settingsFrontCamera => 'Scan with the front camera';

  @override
  String get settingsFrontCameraDesc =>
      'Badges are read with the screen-side camera — turn off to use the back camera.';

  @override
  String get kioskNfcOff =>
      'NFC is turned off in this tablet\'s Android settings — turn it on to read RFID cards.';

  @override
  String get kioskNfcUnsupported =>
      'This tablet has no NFC reader — scan the QR badge instead.';

  @override
  String get kioskNfcFailed =>
      'The RFID reader did not start — restart the app and try again.';

  @override
  String get nfcConfigDeviceOff =>
      'NFC is turned off in this device\'s Android settings — turn it on to read RFID cards.';

  @override
  String get kioskScanQr => 'Scan the QR badge';

  @override
  String get kioskRevertTitle => 'Kiosk device';

  @override
  String get kioskRevertDesc =>
      'This profile is set up as the workspace kiosk. Revert it to a regular member to stop the kiosk question at start.';

  @override
  String get kioskRevertDone => 'This profile is a regular member again.';

  @override
  String get memberNoActions =>
      'Only the workspace owner can change this member.';

  @override
  String get kioskNotCheckedIn =>
      'No active check-in found — the plan may have just updated.';

  @override
  String get kioskRestOfDay => 'Rest of the day';

  @override
  String get kioskPeriodCheckInHint =>
      'Until when will you stay? Checking in starts now.';

  @override
  String get kioskPeriodReserveHint => 'Pick the period — today only.';

  @override
  String get kioskCheckInRightAway => 'Check in right away';

  @override
  String get kioskCheckInRightAwayHint =>
      'You\'re here — the reservation starts checked in.';

  @override
  String get kioskPresentBadgeNext => 'Present the badge';

  @override
  String get kioskReserveAndCheckIn => 'Reserve & check in';

  @override
  String get badgeDeleteConfirm => 'Delete this revoked badge for good?';

  @override
  String get kioskClosedToday =>
      'The workspace is closed today — check-in and reservations are not possible.';

  @override
  String kioskBasis(String granularity, String hours) {
    return 'Rule: $granularity · today $hours';
  }

  @override
  String kioskBlockedContactHint(String name) {
    return 'Held by $name — you can message them from the app on your phone.';
  }

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSystemDefault => 'System default';

  @override
  String get levelReserveButton => 'Reserve level';

  @override
  String get levelReserveTitle => 'Reserve the whole level';

  @override
  String get levelPermissionTile => 'Level reservations';

  @override
  String get levelPermissionAllowed =>
      'May reserve a whole desk, office or level';

  @override
  String get levelPermissionDenied =>
      'May not reserve a whole desk, office or level';

  @override
  String get levelBookableToggle => 'Bookable as a whole';

  @override
  String get levelBookableDesc =>
      'The whole floor can be reserved as one booking.';

  @override
  String get levelPriceLabel => 'Price per half-day';

  @override
  String get levelAssignMember => 'For member';

  @override
  String get levelAssignMyself => 'Myself';

  @override
  String get levelSupplementLabel => 'Level reservations';

  @override
  String get levelNotAllowed =>
      'You are not allowed to reserve a whole desk, office or level.';

  @override
  String get levelConflict => 'The level has reservations in that period.';

  @override
  String get bookingOnePlace =>
      'You already have a booking in that period — one place at a time.';

  @override
  String get bookingCheckedInElsewhere =>
      'You are checked in elsewhere — check out there first.';

  @override
  String get spaceNotWholeBookable =>
      'This space is not set up for whole booking — the owner enables \"Bookable as a whole\" on it in the editor.';

  @override
  String get levelFeatureOff =>
      'Office & level reservations are switched off in Features.';

  @override
  String get levelDetail => 'Whole level';

  @override
  String get kioskLevelButton => 'This level';

  @override
  String get officeSupplementLabel => 'Office reservations';

  @override
  String get eventTypeSpaceReservation => 'Whole-space reservations';

  @override
  String get deskDetail => 'Whole desk';

  @override
  String get deskSupplementLabel => 'Desk reservations';

  @override
  String get editorLevelBookableOn => 'Bookable as a whole';

  @override
  String get editorLevelBookableOff => 'Not bookable as a whole';

  @override
  String get bookingPastError => 'This booking lies entirely in the past.';

  @override
  String get bookingWalkUpTodayError => 'A walk-up check-in must start today.';

  @override
  String get bookingOutsideHoursError =>
      'Bookings must stay within the working hours.';

  @override
  String get bookingOutsideOffError =>
      'Bookings outside the opening hours are not allowed.';

  @override
  String get bookingOutsideWalkUpError =>
      'Outside the opening hours only a spontaneous check-in is possible — booking ahead is not.';

  @override
  String get bookingSameDayError =>
      'A booking ends on the day it starts — book the next day separately.';

  @override
  String get membersTitle => 'Members & plans';

  @override
  String get membersPlanNone => 'No plan';

  @override
  String get memberRoleOwner => 'Owner';

  @override
  String get memberRoleAdmin => 'Admin';

  @override
  String get memberStatusPaused => 'Paused';

  @override
  String get memberStatusExited => 'Exited';

  @override
  String get membersInvite => 'Invite a member';

  @override
  String get profilesTitle => 'Profiles';

  @override
  String get profilesAdd => 'Add a profile';

  @override
  String get profilesActive => 'Active profile';

  @override
  String get memberRoleMember => 'Member';

  @override
  String get noteRefGone => 'This reservation no longer exists.';

  @override
  String get memberNoteDelete => 'Delete';

  @override
  String get memberNoteDeleteConfirm =>
      'Delete this message? This cannot be undone.';

  @override
  String get memberNoteReply => 'Reply';

  @override
  String get noteRefReservation => 'Link a reservation';

  @override
  String get noteRefSpace => 'Link a space';

  @override
  String get noteRefNoReservations => 'No upcoming reservations to link.';

  @override
  String get noteRefWholeLevel => 'whole level';

  @override
  String get memberMessagesAction => 'Messages';

  @override
  String get conversationEmpty => 'No messages yet — say hello!';

  @override
  String get notesFilterUnread => 'Unread';

  @override
  String get notesFilterEmpty => 'No unread messages — all caught up.';

  @override
  String get conversationGroup => 'Group';

  @override
  String get conversationUnknownMember => 'Member';

  @override
  String get conversationYesterday => 'Yesterday';

  @override
  String get conversationYou => 'You';

  @override
  String get messagesTitle => 'Messages';

  @override
  String get messagesEmpty => 'No conversations yet.';

  @override
  String conversationMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get newConversationTitle => 'New conversation';

  @override
  String get newConversationSearch => 'Search members';

  @override
  String get newConversationStart => 'Start chat';

  @override
  String get newConversationNoMembers => 'Nobody else here yet.';

  @override
  String get newGroupName => 'Group name';

  @override
  String get newGroupCreate => 'Create group';

  @override
  String get conversationGroupInfo => 'Group';

  @override
  String get conversationAddPeople => 'Add people';

  @override
  String get conversationLeave => 'Leave group';

  @override
  String get conversationLeaveConfirm =>
      'Leave this group? You stop receiving its messages; what you already sent stays.';

  @override
  String get conversationRemove => 'Remove';

  @override
  String get conversationAdmin => 'Admin';

  @override
  String get conversationLeft => 'Left';

  @override
  String get messageSearchHint => 'People, groups, messages';

  @override
  String get messageSearchPrompt => 'Search people, groups and what was said.';

  @override
  String get messageSearchNothing => 'Nothing matched.';

  @override
  String get messageSearchPeople => 'People';

  @override
  String get messageSearchGroups => 'Groups';

  @override
  String get messageSearchMessages => 'Messages';

  @override
  String get messageSearchTitle => 'Search';

  @override
  String get newGroupNameTaken =>
      'A group with that name already exists here. Pick another.';

  @override
  String get conversationSeeProfile => 'See profile';

  @override
  String get inboxChatsTab => 'Chats';

  @override
  String get memberMoneySettled => 'Nothing outstanding.';

  @override
  String memberMoreInvoices(int count) {
    return '+$count more';
  }

  @override
  String get memberMonthInProgress => 'This month';

  @override
  String get memberPayments => 'Payments';

  @override
  String memberInvoiceOpen(String amount) {
    return '$amount open';
  }

  @override
  String get memberInvoicePaid => 'Paid';

  @override
  String get memberInvoiceVoided => 'Voided';

  @override
  String get memberContactHeading => 'Contact';

  @override
  String memberPlanShare(String pct) {
    return 'Plan $pct%';
  }

  @override
  String get memberMoneyUnavailable =>
      'Money could not be loaded. Pull to refresh.';

  @override
  String get inboxAlertsTab => 'Alerts';

  @override
  String get inboxFilterAll => 'All';

  @override
  String get inboxFilterUnread => 'Unread';

  @override
  String get inboxFilterArchived => 'Archived';

  @override
  String get inboxNoUnread => 'Nothing unread — you are up to date.';

  @override
  String get inboxNoArchived => 'No archived conversations.';

  @override
  String get conversationPin => 'Pin to top';

  @override
  String get conversationUnpin => 'Unpin';

  @override
  String get conversationMute => 'Mute notifications';

  @override
  String get conversationUnmute => 'Unmute';

  @override
  String get conversationMarkUnread => 'Mark as unread';

  @override
  String get conversationArchive => 'Archive';

  @override
  String get conversationUnarchive => 'Restore from archive';

  @override
  String get conversationArchived => 'Conversation archived.';

  @override
  String get conversationMutedBadge => 'Muted';

  @override
  String get conversationLoadEarlier => 'Load earlier messages';

  @override
  String get conversationToday => 'Today';

  @override
  String get composerAttach => 'Attach a reference';

  @override
  String composerCharsLeft(int count) {
    return '$count characters left';
  }

  @override
  String get composerDraftKept => 'Draft kept';

  @override
  String get newConversationTapToOpen =>
      'Tap a person to open the chat; switch on Group to pick several.';

  @override
  String get newConversationGroupSwitch => 'Group';

  @override
  String get inboxRetry => 'Try again';

  @override
  String get memberNoteDeleteRead =>
      'Already read — this message can no longer be taken back.';

  @override
  String get memberNoteDeleteNotMine =>
      'Only the sender can take a message back.';

  @override
  String get moneyBaseFee => 'Base subscription';

  @override
  String moneyUsage(int used, int included) {
    return '$used of $included half-days used';
  }

  @override
  String moneyUsageUnlimited(int used) {
    return '$used half-days used';
  }

  @override
  String moneyOverage(int count) {
    return 'Overage ($count extra half-days)';
  }

  @override
  String get moneyCredits => 'Payments & credits';

  @override
  String get moneyBalance => 'Balance';

  @override
  String get moneyStatementSettled => 'Settled';

  @override
  String get moneyStatementOpen => 'Open';

  @override
  String get moneyRecordPayment => 'Record a payment';

  @override
  String get moneyAmountLabel => 'Amount';

  @override
  String get moneyNoteLabel => 'Note (optional)';

  @override
  String get moneySubmitPayment => 'Submit for confirmation';

  @override
  String get moneyPaymentPending =>
      'Payment submitted — waiting for confirmation.';

  @override
  String get moneyLedgerHeader => 'Ledger';

  @override
  String get moneyLedgerEmpty => 'No ledger entries yet.';

  @override
  String get moneySubmitExpense => 'Submit an expense';

  @override
  String get moneyExpenseCategoryLabel => 'Category';

  @override
  String get moneyDescriptionLabel => 'Description';

  @override
  String get moneyExpensePending => 'Expense submitted — waiting for approval.';

  @override
  String get expenseCategoryCoffee => 'Coffee & kitchen';

  @override
  String get expenseCategorySupplies => 'Supplies';

  @override
  String get expenseCategoryEquipment => 'Equipment';

  @override
  String get expenseCategoryOther => 'Other';

  @override
  String get ledgerCategorySubscription => 'Subscription';

  @override
  String get ledgerCategoryOverage => 'Overage';

  @override
  String get ledgerCategoryExpense => 'Expense reimbursement';

  @override
  String get ledgerCategoryPayment => 'Payment';

  @override
  String get ledgerCategoryAdjustment => 'Adjustment';

  @override
  String get ledgerCategoryService => 'Service';

  @override
  String get plansEditorTitle => 'Plans';

  @override
  String get plansEditorNew => 'New plan';

  @override
  String get plansEditorEdit => 'Edit plan';

  @override
  String get plansEditorInactive => 'Inactive';

  @override
  String get plansEditorUnlimited => 'unlimited half-days';

  @override
  String plansEditorQuota(int count) {
    return '$count half-days';
  }

  @override
  String plansEditorPerExtra(String price) {
    return '$price/extra half-day';
  }

  @override
  String get planNameLabel => 'Name';

  @override
  String get planBaseFeeLabel => 'Monthly base fee';

  @override
  String get planIncludedLabel => 'Included half-days';

  @override
  String get planIncludedHelper => 'Leave empty for unlimited';

  @override
  String get planOverageLabel => 'Price per extra half-day';

  @override
  String get planActiveLabel => 'Active';

  @override
  String get paymentMethodBankTransfer => 'Bank transfer';

  @override
  String get paymentMethodCash => 'Cash';

  @override
  String get paymentMethodPaypal => 'PayPal';

  @override
  String get paymentMethodTwint => 'TWINT';

  @override
  String get paymentMethodCard => 'Card';

  @override
  String get paymentMethodOther => 'Other';

  @override
  String get paymentMethodWero => 'Wero';

  @override
  String get paymentMethodLydia => 'Lydia';

  @override
  String get paymentMethodWise => 'Wise';

  @override
  String get moneyPaymentDateLabel => 'Payment date';

  @override
  String get moneyPaymentPeriodLabel => 'Applies to';

  @override
  String get moneySectionPay => 'Pay';

  @override
  String get moneySectionRequests => 'Requests';

  @override
  String get moneySectionDocuments => 'Documents';

  @override
  String get vatDeclTitle => 'VAT declaration';

  @override
  String get vatDeclPeriod => 'Period';

  @override
  String get vatDeclSeller => 'Seller';

  @override
  String get vatDeclVatId => 'VAT ID';

  @override
  String get vatDeclRate => 'Rate';

  @override
  String get vatDeclNet => 'Net base';

  @override
  String get vatDeclVat => 'VAT';

  @override
  String get vatDeclInvoices => 'Invoices';

  @override
  String get vatDeclTotals => 'Totals';

  @override
  String get vatDeclBoxes => 'Official form lines';

  @override
  String get vatDeclBox => 'Box';

  @override
  String get vatDeclStatus => 'Status';

  @override
  String get vatDeclDisclaimer =>
      'Generated from the period’s issued invoices. Verify against your accounting before filing — this is a filing aid, not tax advice.';

  @override
  String get vatDeclGenerate => 'Generate';

  @override
  String get vatDeclEmpty =>
      'No declarations yet — pick a period and generate the first one.';

  @override
  String get vatDeclDraft => 'Draft';

  @override
  String get vatDeclSubmitted => 'Submitted';

  @override
  String get vatDeclTransmit => 'Transmit';

  @override
  String get vatDeclMarkFiled => 'Mark as filed';

  @override
  String get vatDeclMarkFiledConfirm =>
      'Confirm you filed this declaration yourself (tax-office portal or your accountant). It becomes immutable.';

  @override
  String get vatDeclXml => 'XML export';

  @override
  String get vatDeclPdf => 'PDF';

  @override
  String get vatDeclSent => 'Declaration transmitted.';

  @override
  String get vatDeclRejected => 'The platform refused the declaration.';

  @override
  String get vatDeclRegimeGate =>
      'Declarations exist only under the VAT-registered regime — configure it under VAT settings.';

  @override
  String get featureVatManagementTitle => 'VAT management';

  @override
  String get featureVatManagementDesc =>
      'The VAT rate editor and the rate pickers on services, packs, accessories and the tariff. Off hides the configuration; stored rates keep applying.';

  @override
  String get featureVatDeclarationsTitle => 'VAT declarations';

  @override
  String get featureVatDeclarationsDesc =>
      'Generate the periodic VAT return from issued invoices, map it to the official form and transmit or export it.';

  @override
  String get featureEinvoiceCustomerDeliveryTitle =>
      'E-invoice delivery to customers';

  @override
  String get featureEinvoiceCustomerDeliveryDesc =>
      'A second sending channel beside the government platform: post the issued invoice straight to the customer\'s own e-invoicing service.';

  @override
  String priceVatIncluded(String rate) {
    return 'incl. VAT $rate';
  }

  @override
  String billingPricesVatHint(String rate) {
    return 'Prices are gross — VAT $rate (the workspace default rate) is included.';
  }

  @override
  String billingTariffVatHint(String rate) {
    return 'Prices are gross — VAT $rate (the tariff rate) is included.';
  }

  @override
  String get billingNewPackage => 'New package';

  @override
  String get priceGrossHint =>
      'Gross price — what the member pays; VAT is part of it.';

  @override
  String vatShareAmount(String amount) {
    return 'incl. VAT $amount';
  }

  @override
  String get reportDesignerDesign => 'Design';

  @override
  String get reportDesignerPreview => 'Preview';

  @override
  String get reportDesignerZoom => 'Zoom';

  @override
  String get reportDesignerZoomFit => 'Fit width';

  @override
  String get paymentBankNameLabel => 'Bank name';

  @override
  String get paymentAccountNumberLabel => 'Account number';

  @override
  String get paymentSortCodeLabel => 'Sort code';

  @override
  String get paymentRoutingNumberLabel => 'Routing number';

  @override
  String get paymentTransitNumberLabel => 'Transit · institution';

  @override
  String get paymentBankCodeLabel => 'Bank code';

  @override
  String get paymentBicLabel => 'BIC / SWIFT';

  @override
  String get paymentCopied => 'Copied.';

  @override
  String get moneyFacePayments => 'Payments';

  @override
  String get moneyFaceInvoices => 'Invoices';

  @override
  String get moneyNoInvoicesYet =>
      'No invoice yet — the month is invoiced by the workspace once it closes.';

  @override
  String get moneyFaceStatement => 'Statement';

  @override
  String get moneyFaceDocuments => 'Documents';

  @override
  String moneyOverdueBanner(int count, String amount) {
    return '$count overdue — $amount to settle';
  }

  @override
  String get moneyPayNow => 'Pay now';

  @override
  String get moneyOpenInvoicesTitle => 'Open invoices';

  @override
  String moneyOpenInvoicesSummary(int count, String amount) {
    return '$count open · $amount due';
  }

  @override
  String moneyDueIn(int days) {
    return 'Due in $days days';
  }

  @override
  String moneyOverdueBy(int days) {
    return 'Overdue by $days days';
  }

  @override
  String get moneyNothingOpen => 'Nothing open — you are up to date.';

  @override
  String get moneyDocumentLibrary => 'Document library';

  @override
  String get moneyStatementPdf => 'This month\'s statement (PDF)';

  @override
  String moneyRemindedTimes(int count) {
    return 'Reminded ×$count';
  }

  @override
  String get expenseSupplyToggle => 'This is a supply for the space';

  @override
  String get expenseSupplyHint =>
      'Coffee capsules, vacuum bags… Once validated, the item goes on the shelf as a consumable service: members who use it pay for it.';

  @override
  String get expenseSupplyItem => 'Item';

  @override
  String get expenseSupplyNewItem => 'New item';

  @override
  String get expenseSupplyQuantity => 'Quantity';

  @override
  String get expenseSupplyUnitPrice => 'Unit price (what a consumption costs)';

  @override
  String get expenseSupplyUnitPriceHint =>
      'Prefilled from amount ÷ quantity; round up if you like.';

  @override
  String serviceStockCount(int count) {
    return '$count in stock';
  }

  @override
  String get serviceOutOfStock => 'Out of stock';

  @override
  String get serviceOutOfStockHint =>
      'Nothing left on the shelf — the next supply restocks it.';

  @override
  String get negotiationCardTitle => 'My negotiated prices';

  @override
  String get negotiationOnTariff => 'You are on the workspace tariff.';

  @override
  String get negotiationPending => 'A deal is awaiting validation.';

  @override
  String negotiationActiveSince(String month) {
    return 'Your deal applies since $month.';
  }

  @override
  String get negotiationFee => 'Monthly fee';

  @override
  String get negotiationOverage => 'Overage per half-day';

  @override
  String get negotiationDiscount => 'Discount on supplements';

  @override
  String get negotiationDefaultColumn => 'Tariff';

  @override
  String get negotiationMineColumn => 'Mine';

  @override
  String get negotiationWhoCanSee => 'Who can see this';

  @override
  String get negotiationProposeTitle => 'Price negotiation';

  @override
  String get negotiationProposeHint =>
      'Leave a field empty to keep the tariff. The deal goes through validation before it applies.';

  @override
  String get negotiationNote => 'Note';

  @override
  String get negotiationValidFrom => 'Applies from';

  @override
  String get negotiationSubmit => 'Propose for validation';

  @override
  String get negotiationProposed => 'Deal proposed — waiting for validation.';

  @override
  String get negotiationPendingBadge => 'awaiting validation';

  @override
  String get negotiationOccupation => 'Occupation';

  @override
  String get negotiationOccupationHint =>
      'The share of open days included each month; applied to the member once validated.';

  @override
  String get negotiationKeepCurrent => 'Keep current';

  @override
  String get negotiationItems => 'Services and packages';

  @override
  String get negotiationItemsHint =>
      'A unit price for this member; empty keeps the catalogue.';

  @override
  String negotiationPercent(int value) {
    return '$value %';
  }

  @override
  String get negotiationReadOnly => 'Read only';

  @override
  String get scheduledExpensesTitle => 'Scheduled expenses';

  @override
  String get scheduledExpensesIntro =>
      'Subscriptions the space pays for — internet, phone, electricity. The schedule is validated once; every due date is presented to you before it counts.';

  @override
  String get scheduledExpensesEmpty => 'No scheduled expense yet.';

  @override
  String get scheduleNew => 'Schedule a recurring expense';

  @override
  String get scheduleCancel => 'End this schedule';

  @override
  String get scheduleTitleLabel => 'What (e.g. Internet)';

  @override
  String get scheduleStartsOn => 'First occurrence';

  @override
  String get scheduleEveryLabel => 'Every';

  @override
  String get scheduleUnitLabel => 'Unit';

  @override
  String get scheduleTimesLabel => 'Repetitions (empty = until the end date)';

  @override
  String get scheduleEndsOn => 'Until (optional)';

  @override
  String get scheduleNoEnd => 'No end date';

  @override
  String get scheduleValidationHint =>
      'The schedule goes to the validators first. Each due date is then presented to you: confirmed at this amount it counts immediately; a different amount explains itself and is validated again.';

  @override
  String get scheduleSubmit => 'Schedule it';

  @override
  String get scheduleMissingFields => 'Name and amount are needed.';

  @override
  String get schedulePending =>
      'Scheduled — waiting for the validators to confirm it.';

  @override
  String get scheduleStatusPending => 'Awaiting validation';

  @override
  String get scheduleStatusActive => 'Active';

  @override
  String get scheduleStatusRejected => 'Rejected';

  @override
  String get scheduleStatusEnded => 'Ended';

  @override
  String get scheduleDaily => 'daily';

  @override
  String get scheduleWeekly => 'weekly';

  @override
  String get scheduleMonthly => 'monthly';

  @override
  String get scheduleYearly => 'yearly';

  @override
  String scheduleEveryDays(Object count) {
    return 'every $count days';
  }

  @override
  String scheduleEveryWeeks(Object count) {
    return 'every $count weeks';
  }

  @override
  String scheduleEveryMonths(Object count) {
    return 'every $count months';
  }

  @override
  String scheduleTimes(Object count) {
    return '$count times';
  }

  @override
  String scheduleUntil(Object date) {
    return 'until $date';
  }

  @override
  String scheduleNextDue(Object date) {
    return 'next: $date';
  }

  @override
  String get occurrenceRejected =>
      'The validators rejected it — adjust the amount or the description and resend.';

  @override
  String occurrenceScheduledAmount(Object amount) {
    return 'Validated: $amount';
  }

  @override
  String get occurrenceReasonLabel => 'Why it differs (required)';

  @override
  String get occurrenceConfirm => 'Confirm this expense';

  @override
  String get occurrenceResend => 'Resend for validation';

  @override
  String get occurrenceReasonMissing =>
      'A different amount needs an explanation.';

  @override
  String get occurrenceSentForValidation =>
      'Sent to the validators — it counts once they confirm.';

  @override
  String get occurrenceAdded => 'Added to your expenses.';

  @override
  String get scheduledAwaitingTitle => 'Scheduled expenses awaiting you';

  @override
  String get scheduleUnitDays => 'days';

  @override
  String get scheduleUnitWeeks => 'weeks';

  @override
  String get scheduleUnitMonths => 'months';

  @override
  String get scheduleUnitYears => 'years';

  @override
  String get planDurationLabel => 'Duration';

  @override
  String get planNoLevels => 'The workspace has no floor plan yet.';

  @override
  String get planLevelLabel => 'Level';

  @override
  String get planCheckInTitle => 'Check in';

  @override
  String get planStartNow => 'Starts now';

  @override
  String get planUntilLabel => 'Until';

  @override
  String get planCheckInButton => 'Check in';

  @override
  String get planCheckInNotYetError =>
      'Check-in opens 15 minutes before the start.';

  @override
  String get planCheckInOverError =>
      'This reservation is over — check-in is no longer possible.';

  @override
  String planCheckInOpensAt(String time) {
    return 'Check-in opens at $time';
  }

  @override
  String planCheckInOpensOn(String date) {
    return 'Check-in opens on $date';
  }

  @override
  String planCheckInFor(String name) {
    return 'Check in $name';
  }

  @override
  String get planOverruleRemove => 'Remove reservation (overrule)';

  @override
  String planOverruleHint(String name) {
    return '$name and all admins will be notified.';
  }

  @override
  String planOverruleDone(String name) {
    return 'Reservation removed — $name was notified.';
  }

  @override
  String get planCheckOutButton => 'Check out';

  @override
  String get planCancelReservationButton => 'Cancel reservation';

  @override
  String get planSeatBlocked => 'This seat is blocked for maintenance.';

  @override
  String planReservedBy(String name) {
    return 'Reserved by $name';
  }

  @override
  String planOccupiedBy(String name) {
    return 'Occupied by $name';
  }

  @override
  String planUntil(String time) {
    return 'until $time';
  }

  @override
  String planCappedByNext(String time) {
    return 'The seat is reserved from $time.';
  }

  @override
  String get planCheckInFailed =>
      'Could not check in — the seat may have just been taken.';

  @override
  String get planYourSeat => 'Your seat';

  @override
  String get planListViewTooltip => 'List view';

  @override
  String get planMapViewTooltip => 'Plan view';

  @override
  String get planNowButton => 'Now';

  @override
  String get planLevelTooltip => 'Level';

  @override
  String get planReserveButton => 'Reserve';

  @override
  String get planReservationsEmpty => 'No reservations for this day.';

  @override
  String planStartsAt(String time) {
    return 'Starts at $time';
  }

  @override
  String get planRepeatLabel => 'Repeat';

  @override
  String get repeatNone => 'Does not repeat';

  @override
  String get repeatDaily => 'Every day';

  @override
  String get repeatWeekdays => 'Every weekday';

  @override
  String get repeatWeekly => 'Weekly';

  @override
  String get planUntilDateLabel => 'Repeat until';

  @override
  String seriesBookedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bookings created',
      one: '1 booking created',
    );
    return '$_temp0';
  }

  @override
  String get seriesSkippedTitle => 'Skipped (already taken):';

  @override
  String get commonOk => 'OK';

  @override
  String get reminderTitle => 'Check in soon';

  @override
  String reminderBody(String target, String time) {
    return '$target starts at $time';
  }

  @override
  String get planNoSeats => 'This level has no seats yet.';

  @override
  String get planStateFree => 'Free';

  @override
  String get planStateYours => 'Yours';

  @override
  String get planBookForLabel => 'Book for';

  @override
  String get planSendForConfirmation => 'Send for confirmation';

  @override
  String planBookedForPending(String name) {
    return 'Sent to $name for confirmation.';
  }

  @override
  String get planMakeNotReservable => 'Make not reservable';

  @override
  String get planMakeReservable => 'Make reservable';

  @override
  String get planAccessorySupplementHint => 'Supplements are per half-day.';

  @override
  String get planFromLabel => 'From';

  @override
  String get planToLabel => 'To';

  @override
  String get planEndBeforeStart => 'End must be after start.';

  @override
  String get planClosedDay => 'Closed on this day';

  @override
  String get planClosedDayError => 'The workspace is closed on that day.';

  @override
  String get planMorningChip => 'Morning';

  @override
  String get planAfternoonChip => 'Afternoon';

  @override
  String get planFullDayChip => 'Day';

  @override
  String get planHalfDayError => 'Bookings here are per half day.';

  @override
  String get a11ySeatFree => 'free';

  @override
  String get a11ySeatReserved => 'reserved';

  @override
  String get a11ySeatOccupied => 'occupied';

  @override
  String get a11ySeatMine => 'your seat';

  @override
  String get a11ySeatBlocked => 'not available';

  @override
  String get whatsappTitle => 'WhatsApp';

  @override
  String get whatsappNotShared => 'Not shared';

  @override
  String get whatsappFieldLabel => 'WhatsApp number';

  @override
  String get whatsappHint => '+44 7912 345678';

  @override
  String get whatsappHelper =>
      'Optional. Visible to members of your workspaces so they can reach you on WhatsApp. Leave empty to stop sharing it.';

  @override
  String get whatsappSaved => 'WhatsApp number saved';

  @override
  String get whatsappSaveFailed => 'Could not save the WhatsApp number';

  @override
  String get profileStatusTitle => 'Status';

  @override
  String get profileStatusNone => 'No status';

  @override
  String get profileStatusFieldLabel => 'Status';

  @override
  String get profileStatusHint => 'In a call · back at 14:00';

  @override
  String get profileStatusHelper =>
      'Optional. Visible to members of your workspaces in the member directory. Leave empty to clear it.';

  @override
  String get profileStatusSaved => 'Status saved';

  @override
  String get profileStatusSaveFailed => 'Could not save the status';

  @override
  String get profilePhotoTitle => 'Photo';

  @override
  String get profilePhotoSet => 'Tap to change';

  @override
  String get profilePhotoNone => 'Tap to add a photo';

  @override
  String get profilePhotoChoose => 'Choose a photo';

  @override
  String get profilePhotoRemove => 'Remove photo';

  @override
  String get profilePhotoSaved => 'Photo updated';

  @override
  String get profilePhotoRemoved => 'Photo removed';

  @override
  String get profilePhotoSaveFailed => 'Could not update the photo';

  @override
  String get profilePhotoFileType => 'Image';

  @override
  String get settingsBillingReports => 'Billing & reports';

  @override
  String get defaultPeriodTitle => 'Default booking period';

  @override
  String get defaultPeriodNone => 'No preference (full day)';

  @override
  String get privacyTitle => 'Privacy & data';

  @override
  String get privacyIntro =>
      'Your data stays in the EU, is never tracked or sold, and is readable only by the roles the rules below name. These are your rights under the GDPR — each one is a button.';

  @override
  String get privacyWhoCanSee => 'Who can see my data';

  @override
  String get privacyWhoCanSeeHint =>
      'The rule per category, the people it names today, and who actually looked.';

  @override
  String get privacyExport => 'Export my data';

  @override
  String get privacyExportHint =>
      'Everything you are the subject of, as one JSON file (art. 20).';

  @override
  String get privacyExportShareText => 'My DesKilo data export';

  @override
  String get privacyErase => 'Leave this workspace and erase my data';

  @override
  String get privacyEraseHint =>
      'Cancels your bookings, blanks your messages, clears your profile. Accounting records stay under the legal retention, by id, not by name (art. 17).';

  @override
  String get privacyEraseOwner =>
      'An owner hands the workspace over first (Members & plans → Co-ownership).';

  @override
  String get privacyEraseConfirmPhrase => 'ERASE';

  @override
  String privacyEraseConfirmHint(String phrase) {
    return 'This cannot be undone. Type $phrase to confirm.';
  }

  @override
  String get privacyEraseConfirmButton => 'Erase';

  @override
  String get privacyErased => 'Your data has been erased.';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get consentTitle => 'Your data, your rights';

  @override
  String get consentIntro =>
      'Before you use DesKilo, here is what the app does with your data, who can see it and what you can do about it. Two minutes; it is all there is.';

  @override
  String get consentWhatTitle => 'What DesKilo processes';

  @override
  String get consentWhatBody =>
      'Your account (e-mail, display name, hashed password), your profile as you fill it (photo, status, address, WhatsApp number — each optional), and what you do in a workspace: reservations and check-ins, messages, expenses and consumptions, your subscription, invoices and payments. Everything is stored in the EU (Supabase, eu-central-1).';

  @override
  String get consentNotTitle => 'What DesKilo never does';

  @override
  String get consentNotBody =>
      'No tracking, no analytics, no advertising, no sale or sharing of data. Push notifications carry no content — only \"you have a new message\"; the app itself writes the text. The F-Droid build has no Google services at all.';

  @override
  String get consentWhoTitle => 'Who can see what';

  @override
  String get consentWhoBody =>
      'Access follows roles and is enforced on the server: bookings are visible to the workspace (the floor plan shows occupancy); messages only to the people in the conversation, whatever their role; your finances and your commercial agreement only to you, the owners and the admins holding the matching permission. Settings → Privacy & data names the people and lists who actually looked.';

  @override
  String get consentControllerTitle => 'Who is responsible';

  @override
  String get consentControllerBody =>
      'Each workspace is operated by its owner — your community — who decides members, prices and payment providers. The app is open source (0BSD) and published by Florian Dittgen (Germany); the backend is Supabase in the EU. Online payments go through the provider the owner enabled (PayPal, Stripe, Mollie, Wero) under that provider\'s terms.';

  @override
  String get consentRetentionTitle => 'How long';

  @override
  String get consentRetentionBody =>
      'As long as you are a member. When you leave and erase, your profile and messages go; accounting records (invoices, payments) stay for the legal retention period, by identifier and not by name.';

  @override
  String get consentRightsTitle => 'Your rights';

  @override
  String get consentRightsBody =>
      'Access, rectification, export (art. 20), erasure (art. 17) and objection — each is a button in Settings → Privacy & data. For anything else: fdittgen@gmail.com. You may withdraw this consent by leaving the workspace and erasing your data at any time.';

  @override
  String get consentReviewTitle => 'Read it again anytime';

  @override
  String get consentReviewBody =>
      'This text stays available in Settings → Privacy & data, in the in-app help (Privacy) and in the project wiki. A change of the text asks for your acceptance again.';

  @override
  String get consentCheckbox =>
      'I have read this and I accept how DesKilo handles my data.';

  @override
  String get consentAccept => 'Accept and continue';

  @override
  String get consentVersion => 'Version';

  @override
  String consentAcceptedOn(String date, String version) {
    return 'Accepted on $date ($version)';
  }

  @override
  String get consentReadInHelp => 'Read in the help';

  @override
  String get consentReadOnWiki => 'Read on the wiki';

  @override
  String get consentReviewHint =>
      'The text you accepted, with the date — read it again anytime.';

  @override
  String get backendServerTitle => 'Server';

  @override
  String backendServerDefault(Object host) {
    return 'The app\'s own server ($host)';
  }

  @override
  String backendServerCustom(Object host) {
    return 'Your own server ($host)';
  }

  @override
  String get backendServerHint =>
      'By default this app uses its own server. If your community runs its own Supabase project, enter it here — the app then stores everything there.';

  @override
  String get backendUrlLabel => 'Project URL';

  @override
  String get backendKeyLabel => 'Publishable key';

  @override
  String get backendServerRestartHint =>
      'The app signs you out and applies the change on the next start.';

  @override
  String get backendServerReset => 'Use the app\'s server';

  @override
  String get backendServerSaved =>
      'Saved. Close and reopen the app to use the new server.';

  @override
  String get backendErrorUrlEmpty => 'Enter the project URL.';

  @override
  String get backendErrorUrlNotHttps => 'The URL must start with https://.';

  @override
  String get backendErrorUrlNoHost => 'That is not a complete address.';

  @override
  String get backendErrorKeyEmpty => 'Enter the publishable key.';

  @override
  String get backendErrorKeyNotSupabase =>
      'That is not a Supabase publishable key (sb_publishable_…).';

  @override
  String get backendCurrentTitle => 'This device uses';

  @override
  String get backendHowTitle => 'Use your own server';

  @override
  String get backendStep1 =>
      'Create a project at supabase.com (the free tier is enough to start).';

  @override
  String get backendStep2 =>
      'Install the app\'s schema: run the SQL files in supabase/migrations from the source repository, in order.';

  @override
  String get backendStep3 =>
      'In the Supabase dashboard, open Project Settings → API keys and copy the Project URL and the publishable key.';

  @override
  String get backendStep4 =>
      'Paste them below, test the connection, and save. Members join the same instance by scanning the QR above.';

  @override
  String get backendScan => 'Scan a server QR';

  @override
  String get backendScanNothing => 'That QR is not a DesKilo server code.';

  @override
  String get backendShare => 'Share this server';

  @override
  String get backendShareHint =>
      'Members scan this in Settings → Server to point their app at the same instance.';

  @override
  String get backendPaste => 'Paste';

  @override
  String get backendTest => 'Test the connection';

  @override
  String get backendTesting => 'Testing…';

  @override
  String get backendTestOk => 'Reached it — the app\'s schema is there.';

  @override
  String get backendTestUnreachable =>
      'Could not reach that address. Check the URL and your network.';

  @override
  String get backendTestBadKey =>
      'Reached it, but the key was refused. Copy the publishable key again from Project Settings → API keys.';

  @override
  String get backendTestSchemaMissing =>
      'Reached it, but the DesKilo tables are missing — run the migrations from supabase/migrations on that project first.';

  @override
  String get backendCopyLink => 'Copy';

  @override
  String get profilesDefault => 'Default at startup';

  @override
  String get profilesMakeDefault => 'Use as default at startup';

  @override
  String get eventTypeRoleChange => 'Role change';

  @override
  String eventRolePromote(String actor) {
    return '$actor promotes a member to admin';
  }

  @override
  String eventRoleDemote(String actor) {
    return '$actor demotes an admin to member';
  }

  @override
  String get memberMakeAdmin => 'Make admin';

  @override
  String get memberMakeMember => 'Make regular member';

  @override
  String get memberRoleChangeRequested => 'Role change sent for validation.';

  @override
  String get eventTypeQuota => 'Extra half-days';

  @override
  String eventQuotaRequested(String actor, int halfDays, String period) {
    return '$actor requests $halfDays extra half-days for $period';
  }

  @override
  String get quotaExceededError =>
      'Monthly half-day quota reached — request extra half-days from the Money tab.';

  @override
  String get quotaRequestButton => 'Request extra half-days';

  @override
  String get quotaRequestTitle => 'Request extra half-days';

  @override
  String quotaRequestExplainer(String period) {
    return 'Your reservations are capped by your subscription. Extra half-days for $period apply once validated.';
  }

  @override
  String get quotaRequestCountLabel => 'Number of half-days';

  @override
  String get quotaRequestPending => 'Request sent — waiting for validation.';

  @override
  String get memberReservationLimitTooltip => 'Reservation limit';

  @override
  String get memberReservationLimitLabel => 'Reservation limit';

  @override
  String get memberReservationLimitExplainer =>
      'How many open reservations this member may hold at the same time.';

  @override
  String get memberReservationLimitNone => 'No limit';

  @override
  String get memberReservationLimitCustom => 'Custom (1–100)';

  @override
  String memberReservationLimitChip(int n) {
    return 'max $n';
  }

  @override
  String get reservationLimitError =>
      'Reservation limit reached — you already hold the maximum number of open reservations.';

  @override
  String get memberPause => 'Pause membership';

  @override
  String get memberReactivate => 'Reactivate membership';

  @override
  String get memberNotifyAction => 'Send notification';

  @override
  String get memberNotifyAllAdmins => 'Notify all admins';

  @override
  String get memberAllAdmins => 'all admins';

  @override
  String memberNoteTitle(String name) {
    return 'Notify $name';
  }

  @override
  String get memberNoteHint => 'Your message';

  @override
  String get memberNoteSend => 'Send';

  @override
  String get memberNoteSent => 'Notification sent.';

  @override
  String memberNoteReceived(String name) {
    return 'Message from $name';
  }

  @override
  String get eventsMessagesHeader => 'Messages';

  @override
  String memberNoteTo(String name) {
    return 'To $name';
  }

  @override
  String get memberNoteToAllAdmins => 'To all admins';

  @override
  String get memberNoteDeleted => 'Message deleted.';

  @override
  String get memberSimultaneousLimitLabel => 'Simultaneous reservations';

  @override
  String get memberSimultaneousLimitExplainer =>
      'How many bookings this member may hold over the same period. Unset follows the workspace default.';

  @override
  String get memberSimultaneousLimitDefault => 'Workspace default';

  @override
  String memberSimultaneousLimitChip(int n) {
    return '$n at once';
  }

  @override
  String get reserveMonthView => 'Month';

  @override
  String monthFreeCount(int free, int total) {
    return '$free/$total';
  }

  @override
  String get reservationRecurring => 'Recurring booking';

  @override
  String get reservationEditTimes => 'Edit times';

  @override
  String get reservationUpdatedSnack => 'Reservation updated.';

  @override
  String get reservationCancelledSnack => 'Reservation cancelled.';

  @override
  String get reserveDayView => 'Day';

  @override
  String get reserveWeekView => 'Week';

  @override
  String get reserveFullDayChip => 'Full day';

  @override
  String get reservePickDateTooltip => 'Choose a date';

  @override
  String get reserveBookingFailed =>
      'Could not reserve — the seat may have just been taken.';

  @override
  String get spaceScanNfcHint => '…or hold the phone to a chair\'s NFC tag.';

  @override
  String get spaceScanUnknownTag => 'This tag is not linked to any chair.';

  @override
  String bookingCheckedInUntil(String until) {
    return 'Checked in until $until.';
  }

  @override
  String bookingCheckedInAtUntil(String space, String until) {
    return 'Checked in at $space until $until.';
  }

  @override
  String bookingReservedWhen(String when) {
    return 'Reserved: $when.';
  }

  @override
  String bookingReservedSpaceWhen(String space, String when) {
    return 'Reserved $space: $when.';
  }

  @override
  String bookingHorizonError(int days) {
    return 'Too far ahead — bookings are open $days days in advance.';
  }

  @override
  String bookingTooShortError(int minutes) {
    return 'Too short — a booking lasts at least $minutes minutes.';
  }

  @override
  String bookingTooLongError(int minutes) {
    return 'Too long — a booking lasts at most $minutes minutes.';
  }

  @override
  String get legendFree => 'Free';

  @override
  String get legendReserved => 'Reserved';

  @override
  String get legendOccupied => 'Checked in';

  @override
  String get legendMine => 'Mine';

  @override
  String get legendBlocked => 'Blocked';

  @override
  String get legendClosed => 'Closed day';

  @override
  String get reserveClosedShort => 'Closed';

  @override
  String planCheckOutFor(String name) {
    return 'Check out $name';
  }

  @override
  String get scanCameraWebUnavailable =>
      'Camera scanning is not available in the browser — type the code, or hold an NFC tag to the device (Chrome on Android).';

  @override
  String get bookingGateBlocked => 'Not bookable as chosen';

  @override
  String get servicesTitle => 'Services';

  @override
  String get servicesEmpty => 'No services yet.';

  @override
  String get servicesNew => 'New service';

  @override
  String get servicesEdit => 'Edit service';

  @override
  String get servicesName => 'Name';

  @override
  String get servicesPrice => 'Price';

  @override
  String get servicesInactive => 'Inactive';

  @override
  String get servicesActive => 'Active';

  @override
  String get authContinueWith => 'or continue with';

  @override
  String authSocialUnavailable(String provider) {
    return '$provider sign-in is not available yet — the server has not enabled it.';
  }

  @override
  String get linkedAccountsTitle => 'Linked accounts';

  @override
  String get linkedAccountsIntro =>
      'Sign into this account with any of these. Add Google, Microsoft, Apple, or Facebook to sign in without a password.';

  @override
  String get linkedAccountsLink => 'Link';

  @override
  String get linkedAccountsUnlink => 'Unlink';

  @override
  String get linkedAccountsLinked => 'Linked';

  @override
  String get linkedAccountsLinkStarted =>
      'Continue in the browser to finish linking.';

  @override
  String get spaceScanTitle => 'Scan a space code';

  @override
  String get spaceScanHint =>
      'Point the camera at the card of a seat, desk, office or level — or type its code.';

  @override
  String get spaceScanField => 'Code';

  @override
  String get spaceScanInvalid => 'Not a space code of this workspace.';

  @override
  String get spaceScanUnknown =>
      'This code does not match any space here anymore.';

  @override
  String get spaceSeatTaken => 'Taken';

  @override
  String get spaceNotBookable =>
      'This space is not set up for whole-space reservations.';

  @override
  String get spaceCodesTitle => 'Space QR codes (PDF)';

  @override
  String get spaceCodesDesc =>
      'One printable QR card per seat, desk, office and level — members scan to reserve or check in.';

  @override
  String get spaceKindDesk => 'Desk';

  @override
  String get spaceKindOffice => 'Office';

  @override
  String get spaceKindLevel => 'Level';

  @override
  String get spaceKindSeat => 'Seat';

  @override
  String get spaceYoursNow => 'Reserved by you for this slot.';

  @override
  String get spaceCardSizeLabel => 'Card size';

  @override
  String get spaceQrSizeLabel => 'QR code size';

  @override
  String get spaceCardSizeSmall => 'Small';

  @override
  String get spaceCardSizeMedium => 'Medium';

  @override
  String get spaceCardSizeLarge => 'Large';

  @override
  String get spaceCardInfoLabel => 'Information on the card';

  @override
  String get spaceCardInfoWorkspace => 'Workspace';

  @override
  String spaceMessageReserver(String name) {
    return 'Message $name';
  }

  @override
  String get spaceYoursCheckedIn => 'You are checked in here for this slot.';

  @override
  String get spaceBlockedByYou =>
      'You already hold this space for that period.';

  @override
  String get spaceManageMyBooking => 'Manage my booking';

  @override
  String get themeTitle => 'Theme';

  @override
  String get themeSystem => 'System default';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String eventValidations(int current, int required) {
    return '$current/$required validations';
  }

  @override
  String eventValidatedBy(String name, String when) {
    return 'Validated by $name · $when';
  }

  @override
  String eventRejectedBy(String name, String when) {
    return 'Declined by $name · $when';
  }

  @override
  String get eventSystemDecider => 'System';

  @override
  String get validationTitle => 'Validation rules';

  @override
  String get validationDefaultPolicy => 'Default policy';

  @override
  String get validationInherited => 'Inherits default';

  @override
  String get validationCustomized => 'Customized';

  @override
  String get validationRequiredCount => 'Required validations';

  @override
  String get validationAdminsMay => 'Admins may validate';

  @override
  String get validationOwnerOnly => 'Owner only';

  @override
  String get validationAllAdmins => 'All admins';

  @override
  String get validationSpecificAdmins => 'Specific admins';

  @override
  String get validationOwnerRequired => 'Owner must always validate';

  @override
  String get validationNotEnough => 'Not enough eligible validators.';

  @override
  String get validationSaved => 'Validation rule saved.';

  @override
  String get validationAutoValidateOwner => 'Owners delete without validation';

  @override
  String get validationAutoValidateAdmin => 'Admins delete without validation';

  @override
  String get validationAutoValidateDesc =>
      'Their own deletion request settles itself and stays marked as auto-validated.';

  @override
  String get vatTitle => 'VAT';

  @override
  String get vatIntro =>
      'Prices in DesKilo include VAT. Adding rates changes nothing about what members pay — the tax is extracted from the price you already charge and shown on the invoice.';

  @override
  String get vatRegimeHint =>
      'This workspace is not declared VAT-registered, so invoices show no VAT. Change that under Legal identity.';

  @override
  String get vatEmpty => 'No rate yet — invoices show no VAT.';

  @override
  String get vatSeed => 'Use the usual rates';

  @override
  String get vatAddRate => 'Add a rate';

  @override
  String get vatRateLabelField => 'Name';

  @override
  String get vatRatePercentField => 'Rate %';

  @override
  String get vatRateDefaultTooltip =>
      'Default rate — used by subscriptions and by anything without its own rate';

  @override
  String get vatRateRemoveTooltip => 'Remove';

  @override
  String get vatSaved => 'VAT rates saved.';

  @override
  String get vatNeedsDefault => 'Mark exactly one rate as the default.';

  @override
  String get vatRateIncomplete =>
      'Every rate needs a name and a percentage between 0 and 99.99.';

  @override
  String get vatRatesTile => 'VAT rates';

  @override
  String get vatAccountField => 'VAT account';

  @override
  String get vatAccountHint =>
      'Where the accounting export books collected VAT. Empty = 445710.';

  @override
  String get vatServiceRate => 'VAT rate';

  @override
  String get vatServiceRateDefault => 'Workspace default';

  @override
  String get vatPdfNet => 'Net';

  @override
  String get vatPdfVat => 'VAT';

  @override
  String get fecAccountVat => 'Collected VAT';

  @override
  String get vatKeptRate =>
      'A rate still used by an invoice or a service is kept, deactivated.';

  @override
  String get onboardingTitle => 'Welcome to DesKilo';

  @override
  String get onboardingCreateTab => 'Create a workspace';

  @override
  String get onboardingJoinTab => 'Join a workspace';

  @override
  String get workspaceNameLabel => 'Workspace name';

  @override
  String get workspaceCountryLabel => 'Country';

  @override
  String get workspaceCurrencyLabel => 'Currency';

  @override
  String get workspaceTimezoneLabel => 'Time zone';

  @override
  String get onboardingCreateButton => 'Create workspace';

  @override
  String get workspaceInviteCodeLabel => 'Invite code';

  @override
  String get onboardingJoinButton => 'Join';

  @override
  String get workspaceGenericError => 'Something went wrong. Please try again.';

  @override
  String get countryNameDE => 'Germany';

  @override
  String get countryNameAT => 'Austria';

  @override
  String get countryNameCH => 'Switzerland';

  @override
  String get countryNameFR => 'France';

  @override
  String get countryNameIT => 'Italy';

  @override
  String get countryNameES => 'Spain';

  @override
  String get countryNamePT => 'Portugal';

  @override
  String get countryNameNL => 'Netherlands';

  @override
  String get countryNameBE => 'Belgium';

  @override
  String get countryNameLU => 'Luxembourg';

  @override
  String get countryNameGB => 'United Kingdom';

  @override
  String get countryNameUS => 'United States';

  @override
  String get workspaceCodeTitle => 'Workspace ID & QR';

  @override
  String get workspaceCodeLabel => 'Workspace ID';

  @override
  String get workspaceCodeHint => '4–20 letters or digits, unique';

  @override
  String get workspaceCodeEdit => 'Change workspace ID';

  @override
  String get workspaceCodeRejected =>
      'That ID was rejected — it must be 4–20 letters or digits and not already taken.';

  @override
  String get workspaceCodeExplainer =>
      'Coworkers scan this QR code — or type the ID — to join this workspace.';

  @override
  String get workspaceCodeCopy => 'Copy ID';

  @override
  String get workspaceCodeCopied => 'Copied';

  @override
  String get inviteRoleMember => 'Member invite';

  @override
  String get inviteRoleAdmin => 'Admin invite';

  @override
  String get inviteAdminExplainer =>
      'This code is single-use: it admits ONE person as an admin, then expires. Give it only to the person it is meant for.';

  @override
  String get inviteAdminNewCode => 'New admin code';

  @override
  String get inviteOwnerNote =>
      'There is no owner invite — only an owner can grant ownership, in Members & plans.';

  @override
  String get scanJoinTitle => 'Scan workspace QR';

  @override
  String get onboardingScanButton => 'Scan QR code';

  @override
  String get scanJoinHelp =>
      'Point the camera at the invitation QR — the code is taken over and joined automatically.';

  @override
  String get scanJoinNotAnInvite =>
      'That QR is not a DesKilo invitation — scan the one from the invitation message.';

  @override
  String get workspaceCodeSharePng => 'Share as PNG';

  @override
  String get workspaceSettingsTitle => 'Workspace';

  @override
  String get workspaceSettingsSaved => 'Workspace saved.';

  @override
  String get workspaceSettingsCurrencyHelper =>
      'Defaults from the country — override if your community bills in another currency.';

  @override
  String get paymentInstructionsTitle => 'Payment instructions';

  @override
  String get paymentInstructionsHelper =>
      'Shown to members on an unpaid statement. Leave empty to show nothing.';

  @override
  String get paymentInstructionsPaypalLabel => 'PayPal.me link or handle';

  @override
  String get paymentInstructionsReferenceLabel => 'Payment reference hint';

  @override
  String get paymentInstructionsIbanTitle => 'IBAN';

  @override
  String get paymentInstructionsIbanCopied => 'IBAN copied.';

  @override
  String get paymentInstructionsWeroLabel => 'Wero phone number';

  @override
  String get paymentInstructionsLydiaLabel => 'Lydia phone number or username';

  @override
  String get paymentInstructionsWiseLabel => 'Wisetag or Wise payment link';

  @override
  String get paymentInstructionsValueCopied => 'Copied to clipboard.';

  @override
  String get workspaceWhatsappGroupTitle => 'WhatsApp group';

  @override
  String get workspaceWhatsappGroupHelper =>
      'Shown to members so they can join the community\'s WhatsApp group. Paste the group\'s invite link (https://chat.whatsapp.com/…). Leave empty to show nothing.';

  @override
  String get workspaceWhatsappGroupLabel => 'WhatsApp group link';

  @override
  String get workspaceWhatsappGroupInvalid =>
      'Must be a chat.whatsapp.com invite link';

  @override
  String get memberStatusActive => 'Active';

  @override
  String get workspaceConfigPdfExport => 'Export configuration (PDF)';

  @override
  String get workspaceConfigPdfExportSubtitle =>
      'Complete snapshot: settings, all members and the floor plan.';

  @override
  String get workspaceConfigPdfTitle => 'Workspace configuration';

  @override
  String workspaceConfigPdfGeneratedOn(String date) {
    return 'Generated on $date';
  }

  @override
  String get workspaceConfigOverview => 'Overview';

  @override
  String get workspaceConfigMembersSection => 'Members';

  @override
  String get workspaceConfigFeatures => 'Enabled features';

  @override
  String get workspaceConfigAvailability => 'Availability';

  @override
  String get workspaceConfigFloorPlan => 'Floor plan';

  @override
  String get workspaceConfigGranularity => 'Booking granularity';

  @override
  String get workspaceConfigColName => 'Name';

  @override
  String get workspaceConfigColRole => 'Role';

  @override
  String get workspaceConfigColStatus => 'Status';

  @override
  String get workspaceConfigOpenDays => 'Open days';

  @override
  String get workspaceConfigClosures => 'Closures';

  @override
  String get workspaceConfigBookableWhole => 'bookable as a whole';

  @override
  String get workspaceConfigSeats => 'Seats';

  @override
  String get workspaceConfigEmptyLevel => 'No rooms';

  @override
  String get workspaceConfigNone => 'None';

  @override
  String get workspaceDeskTransparencyTitle => 'Desk transparency';

  @override
  String get workspaceDeskTransparencyHelper =>
      'Lower the desk opacity so a level\'s background photo shows through the tables.';

  @override
  String workspaceDeskOpacityValue(int percent) {
    return 'Opacity: $percent%';
  }

  @override
  String get workspaceDangerZone => 'Danger zone';

  @override
  String get workspaceResetTitle => 'Reset workspace';

  @override
  String get workspaceResetSubtitle =>
      'Delete all bookings, money and the floor plan. Keeps settings and members.';

  @override
  String get workspaceResetDialogTitle => 'Reset this workspace?';

  @override
  String get workspaceResetWarning =>
      'This permanently deletes every reservation, all money and ledger entries, the activity feed, and the entire floor plan — floors, rooms, tables, seats and images. Workspace settings, fee bands, availability, features, catalogs and members are kept. This cannot be undone.';

  @override
  String get workspaceResetConfirmPhrase => 'I agree';

  @override
  String workspaceResetConfirmLabel(String phrase) {
    return 'Type \"$phrase\" to confirm';
  }

  @override
  String get workspaceResetConfirmButton => 'Reset workspace';

  @override
  String get workspaceResetDone => 'Workspace reset.';

  @override
  String get workspaceExcelExport => 'Export data (Excel)';

  @override
  String get workspaceExcelExportSubtitle =>
      'Every dataset in one workbook: bookings, payments, invoices, members and the floor plan — a tab each.';

  @override
  String get workspaceLanguageLabel => 'Workspace language';

  @override
  String get workspaceLanguageHelper =>
      'Invitations are written in this language by default.';

  @override
  String get workspaceLanguageUnset => 'Sender\'s app language';

  @override
  String get workspacePaymentsBillingTitle => 'Payments & billing';

  @override
  String get paymentMethodsSubtitle =>
      'IBAN, PayPal, Wero, Lydia, Wise and the payment reference';

  @override
  String get featureDocuments => 'Document library';

  @override
  String get featureDocumentsDesc =>
      'The workspace document library: statutes, guides, financial statements, minutes — linked from any drive, visible per role.';

  @override
  String get documentsTitle => 'Documents';

  @override
  String get documentsAdd => 'Add a document';

  @override
  String get documentsTitleLabel => 'Title';

  @override
  String get documentsUrlLabel => 'Link (https://…)';

  @override
  String get documentsUrlHelper =>
      'Paste the share link from your drive — access rights stay managed there.';

  @override
  String get documentsProviderLabel => 'Stored on';

  @override
  String get documentsCategoryLabel => 'Category';

  @override
  String get documentsRoleLabel => 'Visible to';

  @override
  String get documentsRoleMember => 'Every member';

  @override
  String get documentsRoleAdmin => 'Admins and owners';

  @override
  String get documentsRoleOwner => 'Owners only';

  @override
  String get documentsCategoryStatutes => 'Statutes & legal';

  @override
  String get documentsCategoryGuides => 'Guides & manuals';

  @override
  String get documentsCategoryFinance => 'Financial statements';

  @override
  String get documentsCategoryMinutes => 'Meeting minutes';

  @override
  String get documentsCategoryOther => 'Other documents';

  @override
  String get documentsEmpty =>
      'No document yet. Link your statutes, guides and statements from any drive.';

  @override
  String get documentsDelete => 'Remove document?';

  @override
  String get documentsInvalid =>
      'A document needs a title and an https:// link.';

  @override
  String get featureRoleManagement => 'Role management';

  @override
  String get featureRoleManagementDesc =>
      'The central role→permission matrix: the owner decides which role holds which permission; everyone else reads their own. Off, the defaults simply apply.';

  @override
  String get rolesTitle => 'Role management';

  @override
  String get rolesIntroEditor =>
      'The owner always holds every permission. Decide here what the other roles may do — a co-owner can hold less than an owner.';

  @override
  String get rolesIntroReadOnly =>
      'Read-only: these are the permissions each role holds. Your role is highlighted.';

  @override
  String get rolesYourRole => 'Your role';

  @override
  String get roleOwner => 'Owner';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleMember => 'Member';

  @override
  String get permManageRoles => 'Manage roles & permissions';

  @override
  String get permManageMembers => 'Manage members';

  @override
  String get permManageValidation => 'Configure validation policies';

  @override
  String get permWorkspaceSettings => 'Edit workspace settings';

  @override
  String get permIssueInvoices => 'Issue invoices & match payments';

  @override
  String get permViewFinances => 'View workspace finances';

  @override
  String get permManageDocuments => 'Manage the document library';

  @override
  String get permManageServices => 'Manage services & packages';

  @override
  String get permApproveExpenses => 'Approve expenses';

  @override
  String get regionalFormatsTitle => 'Region & formats';

  @override
  String get regionalFormatLocale => 'Numbers & dates';

  @override
  String regionalFormatLocaleAuto(String locale) {
    return 'Follows the app language ($locale)';
  }

  @override
  String get regionalFollowLanguage => 'Automatic';

  @override
  String get regionalClock => 'Clock';

  @override
  String get regionalClockAuto => 'Auto';

  @override
  String get regionalDeviceZone => 'Show times in my time zone';

  @override
  String get regionalDeviceZoneHint =>
      'Off: times show in the workspace\'s zone, the one bookings are made in. On: your device\'s, labelled where it differs.';

  @override
  String get workspaceTimezoneUnknown => 'Pick a time zone from the list';

  @override
  String get countryNameCY => 'Cyprus';

  @override
  String get countryNameEE => 'Estonia';

  @override
  String get countryNameFI => 'Finland';

  @override
  String get countryNameGR => 'Greece';

  @override
  String get countryNameHR => 'Croatia';

  @override
  String get countryNameIE => 'Ireland';

  @override
  String get countryNameLT => 'Lithuania';

  @override
  String get countryNameLV => 'Latvia';

  @override
  String get countryNameMT => 'Malta';

  @override
  String get countryNameSI => 'Slovenia';

  @override
  String get countryNameSK => 'Slovakia';

  @override
  String get countryNameBG => 'Bulgaria';

  @override
  String get countryNameCZ => 'Czechia';

  @override
  String get countryNameDK => 'Denmark';

  @override
  String get countryNameHU => 'Hungary';

  @override
  String get countryNamePL => 'Poland';

  @override
  String get countryNameRO => 'Romania';

  @override
  String get countryNameSE => 'Sweden';

  @override
  String get regionalClock24h => '24h';

  @override
  String get regionalClock12h => '12h';

  @override
  String get countryNameMX => 'Mexico';

  @override
  String get countryNameAU => 'Australia';

  @override
  String get countryNameJP => 'Japan';

  @override
  String get languageNameDE => 'German';

  @override
  String get languageNameEN => 'English';

  @override
  String get languageNameES => 'Spanish';

  @override
  String get languageNameFR => 'French';

  @override
  String get languageNameIT => 'Italian';

  @override
  String get languageNameNL => 'Dutch';

  @override
  String get languageNamePT => 'Portuguese';

  @override
  String get languageNamePL => 'Polish';

  @override
  String get languageNameSV => 'Swedish';

  @override
  String get languageNameDA => 'Danish';

  @override
  String get languageNameNB => 'Norwegian';

  @override
  String get languageNameFI => 'Finnish';

  @override
  String get languageNameCS => 'Czech';

  @override
  String get languageNameHU => 'Hungarian';

  @override
  String get languageNameRO => 'Romanian';

  @override
  String get languageNameEL => 'Greek';

  @override
  String get languageNameJA => 'Japanese';

  @override
  String get countryNameCA => 'Canada';

  @override
  String get countryNameNO => 'Norway';

  @override
  String get permViewNegotiations => 'View commercial agreements';

  @override
  String get permManageNegotiations => 'Manage commercial agreements';

  @override
  String get workspaceXmlExport => 'Export workspace (XML)';

  @override
  String get workspaceXmlExportSubtitle =>
      'Settings and floor plan as a shareable file. No members, bookings or money data.';

  @override
  String get workspaceXmlImport => 'Import workspace (XML)';

  @override
  String get workspaceXmlImportSubtitle =>
      'Restore settings and floor plan from an exported file. Replaces the current floor plan.';

  @override
  String get workspaceXmlFileTypeLabel => 'XML';

  @override
  String get workspaceXmlImportPreviewTitle => 'Replace floor plan?';

  @override
  String workspaceXmlImportPreviewCounts(
    int levels,
    int offices,
    int desks,
    int seats,
  ) {
    return 'Levels: $levels · Offices: $offices · Desks: $desks · Seats: $seats';
  }

  @override
  String workspaceXmlImportPreviewAccessories(int count) {
    return 'Accessories: $count';
  }

  @override
  String get workspaceXmlImportPreviewWarning =>
      'The current floor plan will be deleted and replaced, and the workspace settings will be overwritten. This cannot be undone.';

  @override
  String get workspaceXmlImportConfirm => 'Replace and import';

  @override
  String get workspaceXmlImportSuccess => 'Workspace imported.';

  @override
  String get workspaceXmlErrorMalformed => 'The file is not readable XML.';

  @override
  String get workspaceXmlErrorWrongRoot =>
      'This is not a DesKilo workspace file.';

  @override
  String get workspaceXmlErrorUnsupportedVersion =>
      'The file was exported by a newer version of DesKilo and cannot be imported.';

  @override
  String get workspaceXmlErrorMissingElement =>
      'The file is incomplete — a required section is missing.';

  @override
  String get workspaceXmlErrorMissingAttribute =>
      'The file is incomplete — a required value is missing.';

  @override
  String get workspaceXmlErrorInvalidValue =>
      'The file contains an invalid value and cannot be imported.';

  @override
  String get workspaceXmlErrorInvalidPlan =>
      'The floor plan in the file is invalid: rooms, desks or seats overlap or extend outside their parent.';

  @override
  String get workspaceXmlImportReservationsError =>
      'This workspace already has reservations, so its floor plan cannot be replaced. Imports are only possible before the first booking.';
}
