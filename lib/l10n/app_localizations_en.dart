// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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
}
