import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
  ];

  /// Heading on the auth screen in sign-in mode
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignInTitle;

  /// Heading on the auth screen in sign-up mode
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authSignUpTitle;

  /// Label of the email input field
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// Label of the password input field
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// Label of the display-name input field (sign-up only)
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get authDisplayNameLabel;

  /// Submit button in sign-in mode
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignInButton;

  /// Submit button in sign-up mode
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authSignUpButton;

  /// Link switching the auth screen to sign-up mode
  ///
  /// In en, this message translates to:
  /// **'New here? Create an account'**
  String get authToggleToSignUp;

  /// Link switching the auth screen to sign-in mode
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get authToggleToSignIn;

  /// Validation message for an empty mandatory field
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get authFieldRequired;

  /// Validation message for a too-short password
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get authPasswordTooShort;

  /// Snackbar shown when sign-in/sign-up fails
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Check your credentials and try again.'**
  String get authGenericError;

  /// Sign-out action in settings
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get authSignOut;

  /// Calendar filter showing only the user's reservations
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get calendarMineTab;

  /// Calendar filter for admins showing all reservations
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get calendarEveryoneTab;

  /// Empty state under the month grid
  ///
  /// In en, this message translates to:
  /// **'No reservations on this day.'**
  String get calendarNoReservations;

  /// Series cancel scope: only the tapped instance
  ///
  /// In en, this message translates to:
  /// **'Cancel this occurrence'**
  String get calendarCancelOccurrence;

  /// Series cancel scope: the tapped instance and all later ones
  ///
  /// In en, this message translates to:
  /// **'Cancel this and following'**
  String get calendarCancelFollowing;

  /// Tooltip of the back arrow in the month header
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get calendarPreviousMonth;

  /// Tooltip of the forward arrow in the month header
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get calendarNextMonth;

  /// Tooltip of the per-reservation overflow button
  ///
  /// In en, this message translates to:
  /// **'Reservation actions'**
  String get calendarReservationActions;

  /// Application name shown in the task switcher and app bar. Brand name — identical in all locales.
  ///
  /// In en, this message translates to:
  /// **'DesKilo'**
  String get appTitle;

  /// Bottom-navigation label for the floor-plan tab
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get tabPlan;

  /// Bottom-navigation label for the reservations calendar tab
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get tabCalendar;

  /// Bottom-navigation label for the events feed tab
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get tabEvents;

  /// Bottom-navigation label for the ledger/statements tab
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get tabMoney;

  /// Title of the settings screen and tooltip of the app-bar settings action
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Placeholder body shown on tabs whose feature is not yet implemented
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// App-bar title of the owner-only workspace editor
  ///
  /// In en, this message translates to:
  /// **'Workspace editor'**
  String get editorTitle;

  /// Tooltip of the app-bar icon opening the editor (owners only)
  ///
  /// In en, this message translates to:
  /// **'Edit workspace'**
  String get editorOpenTooltip;

  /// FAB label / dialog title for creating a level (floor)
  ///
  /// In en, this message translates to:
  /// **'Add level'**
  String get editorAddLevel;

  /// Empty state of the editor before any level exists
  ///
  /// In en, this message translates to:
  /// **'No levels yet. Add the first floor of your workspace.'**
  String get editorNoLevels;

  /// Label of the level-name input in add/rename dialogs
  ///
  /// In en, this message translates to:
  /// **'Level name'**
  String get editorLevelNameLabel;

  /// Menu action renaming a level
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get editorRenameLevel;

  /// Tooltip of the per-level overflow menu
  ///
  /// In en, this message translates to:
  /// **'Level actions'**
  String get editorLevelActions;

  /// Confirmation body before deleting a level
  ///
  /// In en, this message translates to:
  /// **'Delete this level? All offices, desks and seats on it are removed.'**
  String get editorDeleteLevelConfirm;

  /// Canvas tool: select/inspect elements, pan and zoom
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get editorToolSelect;

  /// Canvas tool: drag to draw an office (room)
  ///
  /// In en, this message translates to:
  /// **'Office'**
  String get editorToolOffice;

  /// Canvas tool: drag to draw a desk inside an office
  ///
  /// In en, this message translates to:
  /// **'Desk'**
  String get editorToolDesk;

  /// Canvas tool: tap an element to delete it
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get editorToolErase;

  /// Dialog title after drawing an office rectangle
  ///
  /// In en, this message translates to:
  /// **'New office'**
  String get editorNewOffice;

  /// Label of the office-name input
  ///
  /// In en, this message translates to:
  /// **'Office name'**
  String get editorOfficeNameLabel;

  /// Default office name prefix; a number is appended
  ///
  /// In en, this message translates to:
  /// **'Office'**
  String get editorOfficeNameDefault;

  /// Default desk name prefix; a number is appended
  ///
  /// In en, this message translates to:
  /// **'Desk'**
  String get editorDeskNameDefault;

  /// Label of the desk-name input
  ///
  /// In en, this message translates to:
  /// **'Desk name'**
  String get editorDeskNameLabel;

  /// Snackbar when a drawn rectangle collides with a sibling
  ///
  /// In en, this message translates to:
  /// **'Overlaps an existing element.'**
  String get editorPlacementOverlap;

  /// Snackbar when a desk/seat is not fully inside its parent
  ///
  /// In en, this message translates to:
  /// **'Must be fully inside an office.'**
  String get editorPlacementOutside;

  /// Title of the office property sheet
  ///
  /// In en, this message translates to:
  /// **'Office'**
  String get editorOfficeProperties;

  /// Title of the desk property dialog
  ///
  /// In en, this message translates to:
  /// **'Desk'**
  String get editorDeskProperties;

  /// Switch making the office itself the reservable unit
  ///
  /// In en, this message translates to:
  /// **'Bookable as a whole'**
  String get editorBookableAsWhole;

  /// Confirmation body for the erase tool
  ///
  /// In en, this message translates to:
  /// **'Delete this element? Anything placed on it is removed too.'**
  String get editorDeleteElementConfirm;

  /// Canvas tool: tap a desk to stamp a 6×4 seat footprint
  ///
  /// In en, this message translates to:
  /// **'Seat'**
  String get editorToolSeat;

  /// Title of the seat property sheet
  ///
  /// In en, this message translates to:
  /// **'Seat'**
  String get editorSeatProperties;

  /// Label of the seat-name input
  ///
  /// In en, this message translates to:
  /// **'Seat name'**
  String get editorSeatNameLabel;

  /// Default seat name prefix; a number is appended
  ///
  /// In en, this message translates to:
  /// **'Seat'**
  String get editorSeatNameDefault;

  /// Label above the seat orientation arrows (n/e/s/w)
  ///
  /// In en, this message translates to:
  /// **'Sitting direction'**
  String get editorOrientationLabel;

  /// Label of the free-text chair-type input
  ///
  /// In en, this message translates to:
  /// **'Chair type'**
  String get editorChairLabel;

  /// Label above the amenity filter chips
  ///
  /// In en, this message translates to:
  /// **'Amenities'**
  String get editorAmenitiesLabel;

  /// Switch blocking a seat for maintenance
  ///
  /// In en, this message translates to:
  /// **'Blocked (maintenance)'**
  String get editorBlockedLabel;

  /// Snackbar when the seat tool is used outside any desk
  ///
  /// In en, this message translates to:
  /// **'Seats can only be placed on a desk.'**
  String get editorSeatNoDesk;

  /// Seat amenity chip
  ///
  /// In en, this message translates to:
  /// **'Monitor'**
  String get amenityMonitor;

  /// Seat amenity chip
  ///
  /// In en, this message translates to:
  /// **'Standing desk'**
  String get amenityStandingDesk;

  /// Seat amenity chip
  ///
  /// In en, this message translates to:
  /// **'Window seat'**
  String get amenityWindow;

  /// Seat amenity chip
  ///
  /// In en, this message translates to:
  /// **'Docking station'**
  String get amenityDock;

  /// Seat amenity chip
  ///
  /// In en, this message translates to:
  /// **'Ergonomic chair'**
  String get amenityErgonomicChair;

  /// Generic cancel action in dialogs
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Generic save/confirm action in dialogs
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Generic delete action in dialogs and menus
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// Header above pinned pending-confirmation cards (spec §8)
  ///
  /// In en, this message translates to:
  /// **'Waiting for your confirmation'**
  String get eventsPendingHeader;

  /// Confirm button on a pending event
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get eventAccept;

  /// Reject button on a pending event; voids what it would apply
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get eventReject;

  /// Empty state of the Events tab
  ///
  /// In en, this message translates to:
  /// **'No events yet.'**
  String get eventsEmpty;

  /// Type filter chip showing every event type
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get eventsFilterAll;

  /// Event type label / filter chip
  ///
  /// In en, this message translates to:
  /// **'Reservation'**
  String get eventTypeReservation;

  /// Event type label / filter chip
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get eventTypePayment;

  /// Event type label / filter chip
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get eventTypeExpense;

  /// Event type label / filter chip
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get eventTypeAdjustment;

  /// Feed line for a created reservation
  ///
  /// In en, this message translates to:
  /// **'{actor} booked {target}'**
  String eventReservationCreated(String actor, String target);

  /// Feed line for a modified reservation (incl. check-in/out)
  ///
  /// In en, this message translates to:
  /// **'{actor} changed the booking of {target}'**
  String eventReservationModified(String actor, String target);

  /// Feed line for a cancelled reservation
  ///
  /// In en, this message translates to:
  /// **'{actor} cancelled the booking of {target}'**
  String eventReservationCancelled(String actor, String target);

  /// Suffix when an admin acted on someone else's behalf
  ///
  /// In en, this message translates to:
  /// **'for {name}'**
  String eventForSubject(String name);

  /// Empty state of the Plan tab before the owner drew levels
  ///
  /// In en, this message translates to:
  /// **'The workspace has no floor plan yet.'**
  String get planNoLevels;

  /// Label of the level dropdown above the live plan
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get planLevelLabel;

  /// Fallback title of the walk-up check-in sheet
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get planCheckInTitle;

  /// Walk-up check-in: the start time is the current time
  ///
  /// In en, this message translates to:
  /// **'Starts now'**
  String get planStartNow;

  /// Label of the adjustable end time in the check-in sheet
  ///
  /// In en, this message translates to:
  /// **'Until'**
  String get planUntilLabel;

  /// Confirm button of the check-in sheet / my-seat sheet
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get planCheckInButton;

  /// Action ending the current presence on a seat
  ///
  /// In en, this message translates to:
  /// **'Check out'**
  String get planCheckOutButton;

  /// Action cancelling one's own reservation
  ///
  /// In en, this message translates to:
  /// **'Cancel reservation'**
  String get planCancelReservationButton;

  /// Snackbar when tapping a blocked seat
  ///
  /// In en, this message translates to:
  /// **'This seat is blocked for maintenance.'**
  String get planSeatBlocked;

  /// Snackbar fragment for a seat reserved by someone else
  ///
  /// In en, this message translates to:
  /// **'Reserved by {name}'**
  String planReservedBy(String name);

  /// Snackbar fragment for a seat someone is checked in on
  ///
  /// In en, this message translates to:
  /// **'Occupied by {name}'**
  String planOccupiedBy(String name);

  /// Suffix showing when the current booking ends
  ///
  /// In en, this message translates to:
  /// **'until {time}'**
  String planUntil(String time);

  /// Hint in the check-in sheet when a later reservation caps the stay
  ///
  /// In en, this message translates to:
  /// **'The seat is reserved from {time}.'**
  String planCappedByNext(String time);

  /// Snackbar when the atomic walk-up RPC rejects (race lost)
  ///
  /// In en, this message translates to:
  /// **'Could not check in — the seat may have just been taken.'**
  String get planCheckInFailed;

  /// Fallback title of the my-seat sheet for unnamed seats
  ///
  /// In en, this message translates to:
  /// **'Your seat'**
  String get planYourSeat;

  /// Tooltip toggling from the plan to the reservation list
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get planListViewTooltip;

  /// Tooltip toggling from the reservation list back to the plan
  ///
  /// In en, this message translates to:
  /// **'Plan view'**
  String get planMapViewTooltip;

  /// Time-scroller button snapping back to live occupancy
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get planNowButton;

  /// Confirm button when booking a future slot from the scroller
  ///
  /// In en, this message translates to:
  /// **'Reserve'**
  String get planReserveButton;

  /// Empty state of the reservation list view
  ///
  /// In en, this message translates to:
  /// **'No reservations for this day.'**
  String get planReservationsEmpty;

  /// Booking sheet start line for a future reservation
  ///
  /// In en, this message translates to:
  /// **'Starts at {time}'**
  String planStartsAt(String time);

  /// Label of the recurrence dropdown in the booking sheet
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get planRepeatLabel;

  /// Recurrence option: single reservation
  ///
  /// In en, this message translates to:
  /// **'Does not repeat'**
  String get repeatNone;

  /// Recurrence option: daily series
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get repeatDaily;

  /// Recurrence option: Monday–Friday series
  ///
  /// In en, this message translates to:
  /// **'Every weekday'**
  String get repeatWeekdays;

  /// Recurrence option: same weekday every week
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get repeatWeekly;

  /// Label of the series end-date picker
  ///
  /// In en, this message translates to:
  /// **'Repeat until'**
  String get planUntilDateLabel;

  /// Title of the series result dialog
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 booking created} other{{count} bookings created}}'**
  String seriesBookedCount(int count);

  /// Heading above the list of conflicted series instances
  ///
  /// In en, this message translates to:
  /// **'Skipped (already taken):'**
  String get seriesSkippedTitle;

  /// Generic acknowledge button
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// App-bar title of the first-run onboarding screen
  ///
  /// In en, this message translates to:
  /// **'Welcome to DesKilo'**
  String get onboardingTitle;

  /// Segmented-button label switching onboarding to create mode
  ///
  /// In en, this message translates to:
  /// **'Create a workspace'**
  String get onboardingCreateTab;

  /// Segmented-button label switching onboarding to join mode
  ///
  /// In en, this message translates to:
  /// **'Join a workspace'**
  String get onboardingJoinTab;

  /// Label of the workspace-name input
  ///
  /// In en, this message translates to:
  /// **'Workspace name'**
  String get workspaceNameLabel;

  /// Label of the country dropdown; the country presets currency and time zone
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get workspaceCountryLabel;

  /// Label of the ISO-4217 currency input
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get workspaceCurrencyLabel;

  /// Label of the IANA time-zone input
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get workspaceTimezoneLabel;

  /// Submit button creating the workspace (caller becomes owner)
  ///
  /// In en, this message translates to:
  /// **'Create workspace'**
  String get onboardingCreateButton;

  /// Label of the invite-code input in join mode
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get workspaceInviteCodeLabel;

  /// Submit button joining a workspace by invite code
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get onboardingJoinButton;

  /// Snackbar shown when creating/joining a workspace fails
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get workspaceGenericError;

  /// Country display name (workspace creation dropdown)
  ///
  /// In en, this message translates to:
  /// **'Germany'**
  String get countryNameDE;

  /// No description provided for @countryNameAT.
  ///
  /// In en, this message translates to:
  /// **'Austria'**
  String get countryNameAT;

  /// No description provided for @countryNameCH.
  ///
  /// In en, this message translates to:
  /// **'Switzerland'**
  String get countryNameCH;

  /// No description provided for @countryNameFR.
  ///
  /// In en, this message translates to:
  /// **'France'**
  String get countryNameFR;

  /// No description provided for @countryNameIT.
  ///
  /// In en, this message translates to:
  /// **'Italy'**
  String get countryNameIT;

  /// No description provided for @countryNameES.
  ///
  /// In en, this message translates to:
  /// **'Spain'**
  String get countryNameES;

  /// No description provided for @countryNamePT.
  ///
  /// In en, this message translates to:
  /// **'Portugal'**
  String get countryNamePT;

  /// No description provided for @countryNameNL.
  ///
  /// In en, this message translates to:
  /// **'Netherlands'**
  String get countryNameNL;

  /// No description provided for @countryNameBE.
  ///
  /// In en, this message translates to:
  /// **'Belgium'**
  String get countryNameBE;

  /// No description provided for @countryNameLU.
  ///
  /// In en, this message translates to:
  /// **'Luxembourg'**
  String get countryNameLU;

  /// No description provided for @countryNameGB.
  ///
  /// In en, this message translates to:
  /// **'United Kingdom'**
  String get countryNameGB;

  /// No description provided for @countryNameUS.
  ///
  /// In en, this message translates to:
  /// **'United States'**
  String get countryNameUS;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
