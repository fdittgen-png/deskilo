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
  String get authDisplayNameLabel => 'Display name';

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
  String get comingSoon => 'Coming soon';

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
