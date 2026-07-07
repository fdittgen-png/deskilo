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
}
