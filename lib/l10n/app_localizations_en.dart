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
  String get policyGridHoursTitle => 'Minute bookings within working hours';

  @override
  String get policyGridHoursDesc =>
      'Confine minute-grid bookings to the working day; evening walk-ups stay possible.';

  @override
  String get policyAdminCheckoutTitle => 'Admins may check members out';

  @override
  String get policyAdminCheckoutDesc =>
      'An admin can end a member\'s running check-in.';

  @override
  String get policyOutsideHoursTitle => 'Outside the opening hours';

  @override
  String get policyOutsideHoursDesc =>
      'Off refuses such bookings; Free never counts them; Charged counts them unless the member already has a regular booking that day.';

  @override
  String get policyOutsideHoursOff => 'Off';

  @override
  String get policyOutsideHoursFree => 'Free';

  @override
  String get policyOutsideHoursCharged => 'Charged';

  @override
  String get policySimultaneousTitle => 'Simultaneous reservations per member';

  @override
  String get policySimultaneousDesc =>
      'How many overlapping bookings one member may hold. 1 keeps one place at a time.';

  @override
  String get myBadgeTitle => 'My badge';

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
  String get billPdfTitle => 'Monthly bill';

  @override
  String get billPdfExport => 'Export bill as PDF';

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
  String get reservationExtendButton => 'Stay longer';

  @override
  String get reservationExtendLaterOnly => 'Pick a time after the current end.';

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
      'Message members on WhatsApp and link the community group.';

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
      'Send a short notification to another member; admins can notify all admins including the owner.';

  @override
  String get featureDunning => 'Payment reminders (Mahnwesen)';

  @override
  String get featureDunningDesc =>
      'Configurable reminder rules and \"Reminder due\" suggestions on overdue invoices. Nothing is ever sent automatically.';

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
      'Short dismissible how-to hints on forms and screens, each linking into the matching guide section.';

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
  String get helpTitle => 'Help';

  @override
  String get helpContents => 'Contents';

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
      'Browse bookings by month; tap a day to see and manage its reservations.';

  @override
  String get helpHintCalendarTopic => 'Calendar';

  @override
  String get helpHintCalendarTip2 =>
      'The Mine / Everyone toggle shows just your bookings or the whole community\'s — red dots are yours, blue ones are other members\'.';

  @override
  String get helpHintCalendarTip3 =>
      'The shape toggle switches the lower half between the week grid and the agenda list; the floor chips filter both.';

  @override
  String get helpHintCalendarTip4 =>
      'Cancelling one occurrence of a series offers \"this and following\" — checked-in and completed occurrences keep their history.';

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
  String get invoiceAccountingExport => 'Accounting export (SAF-T)';

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
  String get whatsappNotesTitle => 'Receive messages on WhatsApp';

  @override
  String get whatsappNotesSubtitle => 'Member messages arrive on WhatsApp too.';

  @override
  String get messageLinkGone => 'This message lives in your inbox.';

  @override
  String get whatsappNotesUnconfigured =>
      'Channel not configured — messages arrive in-app and by push only.';

  @override
  String get whatsappChannelTitle => 'WhatsApp channel';

  @override
  String get whatsappChannelConfigured =>
      'Channel configured — messages mirror to WhatsApp, with their links; the DesKilo link opens the conversation in the app.';

  @override
  String get whatsappChannelNotConfigured =>
      'Not configured — messages arrive in-app and by push only.';

  @override
  String get whatsappChannelHelp =>
      '1. Create a (free) app on developers.facebook.com and add the WhatsApp product.\n2. Under WhatsApp → API setup, copy the permanent access token and the phone number ID.\n3. Paste both below — member messages are then sent from that number.\nNote: WhatsApp only delivers within 24 h of the recipient\'s last WhatsApp message to your number (their service window).';

  @override
  String get whatsappChannelToken => 'Access token';

  @override
  String get whatsappChannelPhoneId => 'Phone number ID';

  @override
  String get whatsappChannelKeepHint => 'Leave blank to keep the stored value.';

  @override
  String get whatsappChannelSaved => 'WhatsApp channel saved.';

  @override
  String get notesFilterUnread => 'Unread';

  @override
  String get notesFilterEmpty => 'No unread messages — all caught up.';

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
