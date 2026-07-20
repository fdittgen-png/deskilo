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
      'Half days: bookings cover the morning (until 13:00), the afternoon (from 13:00) or the whole day.';

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
  String get payOnlineButton => 'Pay online with PayPal';

  @override
  String get payOnlineNotConfigured =>
      'Online payments aren\'t set up yet. Ask the workspace owner.';

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
  String get developerMode => 'Developer mode';

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
  String get languageTitle => 'Language';

  @override
  String get languageSystemDefault => 'System default';

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
      'Whoever scans this QR code — or types this code — joins as an admin. Share it only with people who should manage this workspace.';

  @override
  String get inviteOwnerNote =>
      'There is no owner invite — only an owner can grant ownership, in Members & plans.';

  @override
  String get scanJoinTitle => 'Scan workspace QR';

  @override
  String get onboardingScanButton => 'Scan QR code';

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
