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

  /// App-bar title of the owner/admin accessory-catalog editor and its settings tile (#167)
  ///
  /// In en, this message translates to:
  /// **'Accessories'**
  String get accessoriesTitle;

  /// Empty state of the accessory-catalog editor
  ///
  /// In en, this message translates to:
  /// **'No accessories yet.'**
  String get accessoriesEmpty;

  /// FAB tooltip and sheet title when creating an accessory
  ///
  /// In en, this message translates to:
  /// **'New accessory'**
  String get accessoriesNew;

  /// Sheet title when editing an existing accessory
  ///
  /// In en, this message translates to:
  /// **'Edit accessory'**
  String get accessoriesEdit;

  /// Label of the accessory name field
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get accessoriesName;

  /// Label of the accessory supplement field (major currency units, per half-day billing unit)
  ///
  /// In en, this message translates to:
  /// **'Supplement per half-day'**
  String get accessoriesSupplement;

  /// List subtitle for a priced accessory; the amount is pre-formatted in the workspace currency
  ///
  /// In en, this message translates to:
  /// **'{amount} / half-day'**
  String accessoriesPerHalfDay(String amount);

  /// List subtitle for an accessory with a zero supplement
  ///
  /// In en, this message translates to:
  /// **'No supplement'**
  String get accessoriesNoSupplement;

  /// Trailing badge on deactivated accessories in the catalog list
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get accessoriesInactive;

  /// Label of the activate/deactivate switch in the edit sheet
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get accessoriesActive;

  /// Features screen name for the #869 window-envelope address placement flag
  ///
  /// In en, this message translates to:
  /// **'Envelope address window'**
  String get featureInvoiceAddressWindow;

  /// Features screen description for the #869 window-envelope address placement flag
  ///
  /// In en, this message translates to:
  /// **'Place the recipient where a window envelope shows it, so a printed invoice can be folded and posted. The side follows the country and can be overridden.'**
  String get featureInvoiceAddressWindowDesc;

  /// Invoice design setting choosing where the recipient is placed for a window envelope (#869)
  ///
  /// In en, this message translates to:
  /// **'Address window'**
  String get addressWindowTitle;

  /// Explains the address-window setting and names the DIN field geometry (#869)
  ///
  /// In en, this message translates to:
  /// **'Where the recipient is printed so it shows through a window envelope. The address field is 85 × 45 mm, 45 mm from the top of the sheet.'**
  String get addressWindowSubtitle;

  /// Address-window option: take the convention implied by the workspace country (#869)
  ///
  /// In en, this message translates to:
  /// **'Follow the country'**
  String get addressWindowCountry;

  /// Address-window option: DIN 5008 left-hand window (#869)
  ///
  /// In en, this message translates to:
  /// **'Left (DIN 5008)'**
  String get addressWindowLeft;

  /// Address-window option: French right-hand window (#869)
  ///
  /// In en, this message translates to:
  /// **'Right (French)'**
  String get addressWindowRight;

  /// Address-window option: keep the flow layout, print no window block (#869)
  ///
  /// In en, this message translates to:
  /// **'No window'**
  String get addressWindowOff;

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

  /// Tooltip of the eye button while the password is hidden
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// Tooltip of the eye button while the password is visible
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// Label of the display-name input field (sign-up only)
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get authDisplayNameLabel;

  /// Sign-in link opening the reset-password sheet
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// Title of the reset-password sheet
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get authResetTitle;

  /// Explainer before the reset code is requested
  ///
  /// In en, this message translates to:
  /// **'We\'ll email you a one-time code. Use it here to set a new password.'**
  String get authResetExplainer;

  /// Button requesting the one-time reset code email
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get authResetSendCode;

  /// Explainer after the reset code email went out
  ///
  /// In en, this message translates to:
  /// **'Code sent — check your email.'**
  String get authResetCodeSent;

  /// Label of the one-time code input
  ///
  /// In en, this message translates to:
  /// **'Code from the email'**
  String get authResetCodeLabel;

  /// Label of the new-password input in the reset sheet
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get authResetNewPasswordLabel;

  /// Button redeeming the code and setting the new password
  ///
  /// In en, this message translates to:
  /// **'Set new password'**
  String get authResetSubmit;

  /// Snackbar after a successful password reset
  ///
  /// In en, this message translates to:
  /// **'Password updated — you are signed in.'**
  String get authResetDone;

  /// Inline error when the server rejects the reset code
  ///
  /// In en, this message translates to:
  /// **'That code is invalid or expired.'**
  String get authResetInvalidCode;

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

  /// Snackbar when the auth call fails before reaching the server (connectivity)
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Check your connection and try again.'**
  String get authNetworkError;

  /// App-bar title of the owner availability editor and its settings tile
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get availabilityTitle;

  /// Section header above the seven weekday chips
  ///
  /// In en, this message translates to:
  /// **'Open weekdays'**
  String get availabilityOpenWeekdays;

  /// Section header above the list of one-off closure days
  ///
  /// In en, this message translates to:
  /// **'Closure days'**
  String get availabilityClosureDays;

  /// FAB tooltip and reason-dialog title for adding a closure day
  ///
  /// In en, this message translates to:
  /// **'Add closure day'**
  String get availabilityAddClosure;

  /// Label of the optional reason field when adding a closure day
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get availabilityClosureReason;

  /// Snackbar shown when the owner tries to uncheck the last open weekday
  ///
  /// In en, this message translates to:
  /// **'At least one weekday must stay open.'**
  String get availabilityLastOpenDay;

  /// Empty state under the closure-days section header
  ///
  /// In en, this message translates to:
  /// **'No closure days.'**
  String get availabilityNoClosures;

  /// Section header above the booking-granularity radio options
  ///
  /// In en, this message translates to:
  /// **'Booking granularity'**
  String get availabilityGranularityTitle;

  /// One-line explanation of the half-day granularity under the section header
  ///
  /// In en, this message translates to:
  /// **'Half days: bookings cover the morning, the afternoon or the whole working day — the windows follow the configured working hours.'**
  String get availabilityGranularityDescription;

  /// Radio option: members book any start and end time
  ///
  /// In en, this message translates to:
  /// **'Free time period'**
  String get availabilityGranularityFlexible;

  /// Radio option: bookings must cover a half day or the full day
  ///
  /// In en, this message translates to:
  /// **'Half days (morning & afternoon)'**
  String get availabilityGranularityHalfDay;

  /// Radio option: bookings start and end on the 5-minute grid (0032)
  ///
  /// In en, this message translates to:
  /// **'5-minute slots'**
  String get availabilityGranularity5;

  /// Radio option: bookings start and end on the 15-minute grid (0032)
  ///
  /// In en, this message translates to:
  /// **'15-minute slots'**
  String get availabilityGranularity15;

  /// Radio option: bookings start and end on the 30-minute grid (0032)
  ///
  /// In en, this message translates to:
  /// **'30-minute slots'**
  String get availabilityGranularity30;

  /// Radio option: bookings start and end on the hour grid (0032)
  ///
  /// In en, this message translates to:
  /// **'1-hour slots'**
  String get availabilityGranularity60;

  /// Radio option: every booking covers the whole day (0032)
  ///
  /// In en, this message translates to:
  /// **'Full days only'**
  String get availabilityGranularityFullDay;

  /// Booking error when the server rejects a misaligned window under a minute granularity (0032)
  ///
  /// In en, this message translates to:
  /// **'Bookings must start and end on the {minutes}-minute grid.'**
  String planSlotError(int minutes);

  /// Booking error when the server rejects a non-full-day window under full-day granularity (0032)
  ///
  /// In en, this message translates to:
  /// **'Bookings here cover the full day.'**
  String get planFullDayError;

  /// No description provided for @availabilityGranularityHours.
  ///
  /// In en, this message translates to:
  /// **'Real hours (exact from–to, half/full days as shortcuts)'**
  String get availabilityGranularityHours;

  /// No description provided for @availabilityWorkHoursTitle.
  ///
  /// In en, this message translates to:
  /// **'Working hours'**
  String get availabilityWorkHoursTitle;

  /// No description provided for @availabilityWorkHoursDescription.
  ///
  /// In en, this message translates to:
  /// **'The half-day and full-day windows everywhere — reservations, check-in and invoicing — follow these hours.'**
  String get availabilityWorkHoursDescription;

  /// No description provided for @availabilityWorkStart.
  ///
  /// In en, this message translates to:
  /// **'Day starts'**
  String get availabilityWorkStart;

  /// No description provided for @availabilityHalfBoundary.
  ///
  /// In en, this message translates to:
  /// **'Half-day boundary'**
  String get availabilityHalfBoundary;

  /// No description provided for @availabilityWorkEnd.
  ///
  /// In en, this message translates to:
  /// **'Day ends'**
  String get availabilityWorkEnd;

  /// No description provided for @availabilityHalfDayHours.
  ///
  /// In en, this message translates to:
  /// **'Hours billed as a half day'**
  String get availabilityHalfDayHours;

  /// No description provided for @availabilityFullDayHours.
  ///
  /// In en, this message translates to:
  /// **'Hours billed as a full day'**
  String get availabilityFullDayHours;

  /// Dropdown option: a whole-hour count (#446)
  ///
  /// In en, this message translates to:
  /// **'{count} h'**
  String availabilityHourOption(int count);

  /// No description provided for @availabilityWorkHoursInvalid.
  ///
  /// In en, this message translates to:
  /// **'The day must run start < half-day boundary < end.'**
  String get availabilityWorkHoursInvalid;

  /// No description provided for @availabilityPoliciesTitle.
  ///
  /// In en, this message translates to:
  /// **'Booking policies'**
  String get availabilityPoliciesTitle;

  /// No description provided for @policyAllowPastTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow past bookings'**
  String get policyAllowPastTitle;

  /// No description provided for @policyAllowPastDesc.
  ///
  /// In en, this message translates to:
  /// **'Members may record a booking that already ended (backfill).'**
  String get policyAllowPastDesc;

  /// No description provided for @policyAdminCheckoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Admins may check members out'**
  String get policyAdminCheckoutTitle;

  /// No description provided for @policyAdminCheckoutDesc.
  ///
  /// In en, this message translates to:
  /// **'An admin can end a member\'s running check-in.'**
  String get policyAdminCheckoutDesc;

  /// No description provided for @policyOutsideHoursTitle.
  ///
  /// In en, this message translates to:
  /// **'Outside the opening hours'**
  String get policyOutsideHoursTitle;

  /// #634 - helper text above the four outside-hours options
  ///
  /// In en, this message translates to:
  /// **'What may happen outside the working day — one answer, on every granularity. A booking that touches the working hours is an ordinary booking.'**
  String get policyOutsideHoursDesc;

  /// No description provided for @policyOutsideHoursOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get policyOutsideHoursOff;

  /// No description provided for @policyOutsideHoursOffDesc.
  ///
  /// In en, this message translates to:
  /// **'Nothing outside the hours: no booking ahead, no walk-up, and a booking running past the day end is refused too.'**
  String get policyOutsideHoursOffDesc;

  /// #634 - outside-hours option: walk-ups yes, booking ahead no
  ///
  /// In en, this message translates to:
  /// **'Spontaneous only'**
  String get policyOutsideHoursWalkUp;

  /// No description provided for @policyOutsideHoursWalkUpDesc.
  ///
  /// In en, this message translates to:
  /// **'Walk-up check-ins stay possible, evening overtime included; booking ahead outside the hours is refused.'**
  String get policyOutsideHoursWalkUpDesc;

  /// No description provided for @policyOutsideHoursFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get policyOutsideHoursFree;

  /// No description provided for @policyOutsideHoursFreeDesc.
  ///
  /// In en, this message translates to:
  /// **'Allowed, never counted and never charged — pure presence information.'**
  String get policyOutsideHoursFreeDesc;

  /// No description provided for @policyOutsideHoursCharged.
  ///
  /// In en, this message translates to:
  /// **'Charged'**
  String get policyOutsideHoursCharged;

  /// No description provided for @policyOutsideHoursChargedDesc.
  ///
  /// In en, this message translates to:
  /// **'Allowed and counted like ordinary usage — except on a day the member already holds a regular booking.'**
  String get policyOutsideHoursChargedDesc;

  /// #628 - title of the workspace-wide simultaneous-reservations stepper
  ///
  /// In en, this message translates to:
  /// **'Simultaneous reservations per member'**
  String get policySimultaneousTitle;

  /// #628 - subtitle explaining the simultaneous-reservations stepper
  ///
  /// In en, this message translates to:
  /// **'How many overlapping bookings one member may hold. 1 keeps one place at a time.'**
  String get policySimultaneousDesc;

  /// #649 - section header for the three numeric booking limits
  ///
  /// In en, this message translates to:
  /// **'Booking limits'**
  String get policyLimitsTitle;

  /// #649 - subtitle of the booking-limits section
  ///
  /// In en, this message translates to:
  /// **'How far ahead a booking may be made, and how short or long it may be. These hold on every granularity.'**
  String get policyLimitsDesc;

  /// #649 - advance_horizon_days control title
  ///
  /// In en, this message translates to:
  /// **'Advance booking horizon'**
  String get policyHorizonTitle;

  /// #649 - advance_horizon_days explanation
  ///
  /// In en, this message translates to:
  /// **'How many days ahead a booking may start. Beyond it the booking is refused.'**
  String get policyHorizonDesc;

  /// #649 - min_duration_minutes control title
  ///
  /// In en, this message translates to:
  /// **'Minimum duration'**
  String get policyMinDurationTitle;

  /// #649 - min_duration_minutes explanation
  ///
  /// In en, this message translates to:
  /// **'The shortest booking accepted. It is why arriving at 11:45 for a 12:00 half-day boundary is refused as too short.'**
  String get policyMinDurationDesc;

  /// #649 - max_duration_minutes control title
  ///
  /// In en, this message translates to:
  /// **'Maximum duration'**
  String get policyMaxDurationTitle;

  /// #649 - max_duration_minutes explanation
  ///
  /// In en, this message translates to:
  /// **'The longest booking accepted. A booking ends on the day it starts, so a full day is the ceiling.'**
  String get policyMaxDurationDesc;

  /// #649 - error when the minimum duration exceeds the maximum
  ///
  /// In en, this message translates to:
  /// **'The minimum cannot exceed the maximum — no booking would be accepted.'**
  String get policyDurationConflict;

  /// #649 - a day count shown beside the horizon slider
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String policyDaysValue(int count);

  /// #649 - a minute count shown beside a duration control
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String policyMinutesValue(int count);

  /// #649 - an hour count shown beside a duration control
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour} other{{count} hours}}'**
  String policyHoursValue(int count);

  /// No description provided for @myBadgeTitle.
  ///
  /// In en, this message translates to:
  /// **'My badge'**
  String get myBadgeTitle;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'Sign in with your badge'**
  String get badgeSignInTitle;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'Hold your badge against the phone.'**
  String get badgeSignInTapPrompt;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'No badge reader is available on this device.'**
  String get badgeSignInNoReader;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get badgeSignInRetry;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'Hello {name}'**
  String badgeSignInHello(String name);

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'Your PIN'**
  String get badgeSignInPinLabel;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get badgeSignInButton;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'Use my e-mail instead'**
  String get badgeSignInUseEmail;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'That did not work. Check the badge and the PIN, or sign in with your e-mail.'**
  String get badgeSignInRefused;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a few minutes, or sign in with your e-mail.'**
  String get badgeSignInLocked;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'Badge sign-in is not reachable right now. Sign in with your e-mail instead.'**
  String get badgeSignInUnavailable;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'Sign in with a badge'**
  String get badgeSignInEntry;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'My badge'**
  String get badgePinSectionTitle;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'PIN set'**
  String get badgePinSet;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'No PIN yet'**
  String get badgePinNotSet;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'Your PIN lets you sign in by scanning your badge instead of typing your e-mail. Only you can set it, and nobody — not even an owner — can read it back.'**
  String get badgePinExplain;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'Set a PIN'**
  String get badgePinSetAction;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get badgePinChangeAction;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'Remove PIN'**
  String get badgePinClearAction;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'New PIN'**
  String get badgePinNewLabel;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'Repeat it'**
  String get badgePinConfirmLabel;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'The two entries do not match.'**
  String get badgePinMismatch;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'Use at least {min} digits.'**
  String badgePinTooShort(int min);

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'PIN saved.'**
  String get badgePinSaved;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'PIN removed. Your badges no longer sign you in.'**
  String get badgePinCleared;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'Signs me in'**
  String get badgeAuthEnabledLabel;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'Off by default: a badge that checks you in does not log you in until you say so.'**
  String get badgeAuthEnabledHint;

  /// #662 - badge sign-in
  ///
  /// In en, this message translates to:
  /// **'Set a sign-in PIN first — a badge alone must never be enough.'**
  String get badgeAuthNeedsPin;

  /// Bill section header (#132): the member's percentage; the band fee renders as the trailing amount
  ///
  /// In en, this message translates to:
  /// **'Subscription {pct}%'**
  String billSubscription(int pct);

  /// Entitlement line under the subscription header
  ///
  /// In en, this message translates to:
  /// **'{used} of {included} half-days used ({openDays} open days)'**
  String billEntitlement(int used, int included, int openDays);

  /// Overage line, shown only when extra half-days exist; the amount renders trailing
  ///
  /// In en, this message translates to:
  /// **'{extra} extra half-days'**
  String billOverage(int extra);

  /// Bill section header for confirmed service consumptions of the period
  ///
  /// In en, this message translates to:
  /// **'Consumed services'**
  String get billServices;

  /// Total line closing the consumed-services section
  ///
  /// In en, this message translates to:
  /// **'Services total'**
  String get billServicesTotal;

  /// Bill section header for pending money events that are not on the bill yet
  ///
  /// In en, this message translates to:
  /// **'Open positions'**
  String get billOpenPositions;

  /// Badge on the open-positions section: these amounts await confirmation
  ///
  /// In en, this message translates to:
  /// **'pending validation'**
  String get billPendingBadge;

  /// Bill section header for confirmed credits of the period
  ///
  /// In en, this message translates to:
  /// **'Payments & credits'**
  String get billPaymentsCredits;

  /// Bill footer label; the bold period total renders trailing
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get billBalance;

  /// Footer state when the period balance is zero or positive
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get billSettled;

  /// Footer state when the member still owes for the period
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get billOutstanding;

  /// Bill line for priced seat accessories charged per booked half-day (#170), shown only when the amount is non-zero; the amount renders trailing
  ///
  /// In en, this message translates to:
  /// **'Accessory supplements'**
  String get billAccessorySupplements;

  /// Header of the prominent usage card at the top of the bill: days included, used and left for the current month
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get entitlementTitle;

  /// Usage headline; both values are already formatted as day counts (may be fractional, e.g. 3.5)
  ///
  /// In en, this message translates to:
  /// **'{used} of {total} days used'**
  String entitlementDaysUsed(String used, String total);

  /// Remaining days within the monthly cap; value already formatted (may be fractional)
  ///
  /// In en, this message translates to:
  /// **'{left} days left'**
  String entitlementDaysLeft(String left);

  /// Footer of the usage card for a blocked member who has used their whole cap
  ///
  /// In en, this message translates to:
  /// **'You\'ve used all your days this month. Ask an admin for more or request extra half-days below.'**
  String get entitlementBlockedFull;

  /// Footer of the usage card for a pay-as-you-go member; rate is a formatted price per extra day
  ///
  /// In en, this message translates to:
  /// **'Extra days beyond your plan bill at {rate} each.'**
  String entitlementPaygRate(String rate);

  /// Footer of the usage card for a package member who has used their whole cap
  ///
  /// In en, this message translates to:
  /// **'You\'ve used all your days this month. Buy a package to keep booking.'**
  String get entitlementPackageFull;

  /// Bill section header for day packages bought this period (migration 0042); charge lines render trailing
  ///
  /// In en, this message translates to:
  /// **'Day packages'**
  String get billPackages;

  /// Button on an outstanding bill that starts an online payment (provider chosen next when several are configured)
  ///
  /// In en, this message translates to:
  /// **'Pay online'**
  String get payOnlineButton;

  /// Shown when the member taps Pay online but the deployment has no payment provider configured
  ///
  /// In en, this message translates to:
  /// **'Online payments aren\'t set up yet. Ask the workspace owner.'**
  String get payOnlineNotConfigured;

  /// Title of the provider chooser sheet
  ///
  /// In en, this message translates to:
  /// **'Pay online'**
  String get payOnlineChooseTitle;

  /// Provider button: card payments through Stripe Checkout
  ///
  /// In en, this message translates to:
  /// **'Credit card (Stripe)'**
  String get paymentProviderStripe;

  /// Provider button: Mollie hosted checkout (iDEAL, Bancontact, cards…)
  ///
  /// In en, this message translates to:
  /// **'Mollie — iDEAL, Bancontact…'**
  String get paymentProviderMollie;

  /// Title of the admin diagnostics dialog when no provider can charge
  ///
  /// In en, this message translates to:
  /// **'Online payments — not configured'**
  String get payOnlineDiagTitle;

  /// Hint above the per-provider missing-config lines in the diagnostics dialog
  ///
  /// In en, this message translates to:
  /// **'The server is missing this configuration (docs/design/payments-integration.md):'**
  String get payOnlineDiagHint;

  /// Bill card title for the invoice covering the browsed month (#510)
  ///
  /// In en, this message translates to:
  /// **'Invoice {number}'**
  String billInvoiceCard(String number);

  /// Bill card title when the covering document is a credit note (#508)
  ///
  /// In en, this message translates to:
  /// **'Credit note {number}'**
  String billCreditNoteCard(String number);

  /// Bill invoice card: face value line; issue date renders as detail
  ///
  /// In en, this message translates to:
  /// **'Invoice total'**
  String get billInvoiceTotal;

  /// Bill invoice card: validated instalments on a partially paid invoice
  ///
  /// In en, this message translates to:
  /// **'Paid so far'**
  String get billInvoicePaid;

  /// Bill invoice card: what is still owed on a partially paid invoice
  ///
  /// In en, this message translates to:
  /// **'Remaining to pay'**
  String get billInvoiceRemaining;

  /// Bill credit-note card: refund still due from the workspace
  ///
  /// In en, this message translates to:
  /// **'The workspace owes you this amount — nothing to pay on your side.'**
  String get billCreditNoteDue;

  /// Bill credit-note card: the refund was validated and paid out
  ///
  /// In en, this message translates to:
  /// **'The workspace refunded you this amount.'**
  String get billCreditNoteRefunded;

  /// Money tab: title of the cross-month account position card (#512)
  ///
  /// In en, this message translates to:
  /// **'Your account'**
  String get accountCardTitle;

  /// Account card: unconsumed credit spendable on open invoices
  ///
  /// In en, this message translates to:
  /// **'Credit on account'**
  String get accountCredit;

  /// Account card: open credit notes the workspace still owes
  ///
  /// In en, this message translates to:
  /// **'Refund due from the workspace'**
  String get accountRefundDue;

  /// Account card: credit + refunds − open remainders
  ///
  /// In en, this message translates to:
  /// **'Net position'**
  String get accountNet;

  /// Account card: open invoice detail line when partially paid
  ///
  /// In en, this message translates to:
  /// **'{period} · {paid} paid'**
  String accountOpenPartial(String period, String paid);

  /// Account card hint shown when credit and open invoices coexist (#512)
  ///
  /// In en, this message translates to:
  /// **'Your credit can settle open invoices — the workspace applies it when matching payments.'**
  String get accountImputationHint;

  /// #669 - accounting export formats
  ///
  /// In en, this message translates to:
  /// **'SAF-T (Portugal)'**
  String get invoiceExportSafTPt;

  /// #669 - accounting export formats
  ///
  /// In en, this message translates to:
  /// **'DATEV (Buchungsstapel)'**
  String get invoiceExportDatev;

  /// #669 - accounting export formats
  ///
  /// In en, this message translates to:
  /// **'Sage 50 (audit trail)'**
  String get invoiceExportSage;

  /// #669 - accounting export formats
  ///
  /// In en, this message translates to:
  /// **'Accounting CSV'**
  String get invoiceExportAccountantCsv;

  /// #669 - accounting export formats
  ///
  /// In en, this message translates to:
  /// **'Audit trail'**
  String get invoiceExportAuditTrail;

  /// #669 - accounting export formats
  ///
  /// In en, this message translates to:
  /// **'The format your tax authority asks for.'**
  String get exportClaimRegulatory;

  /// #669 - accounting export formats
  ///
  /// In en, this message translates to:
  /// **'For your accountant to import and review — not a filing.'**
  String get exportClaimExchange;

  /// #669 - accounting export formats
  ///
  /// In en, this message translates to:
  /// **'Invoices and payments only; no general ledger. The file says so in its header.'**
  String get exportClaimSubset;

  /// #669 - accounting export formats
  ///
  /// In en, this message translates to:
  /// **'Built to the published spec, but DesKilo is not certified software in this country — check with your accountant whether that is required of you.'**
  String get exportUncertifiedSoftware;

  /// #669 - accounting export formats
  ///
  /// In en, this message translates to:
  /// **'DATEV export'**
  String get datevAccountsTitle;

  /// #669 - accounting export formats
  ///
  /// In en, this message translates to:
  /// **'Your accountant gives you the consultant and client numbers. DATEV refuses a file whose numbers do not match — which is what keeps it out of the wrong company’s books.'**
  String get datevAccountsIntro;

  /// #669 - accounting export formats
  ///
  /// In en, this message translates to:
  /// **'Beraternummer'**
  String get datevConsultantNumber;

  /// #669 - accounting export formats
  ///
  /// In en, this message translates to:
  /// **'Mandantennummer'**
  String get datevClientNumber;

  /// #669 - accounting export formats
  ///
  /// In en, this message translates to:
  /// **'Sage export'**
  String get sageAccountsTitle;

  /// #669 - accounting export formats
  ///
  /// In en, this message translates to:
  /// **'The defaults are Sage’s own shipped nominal codes. The tax code decides which VAT return these land on, so check it with your accountant if you are not on the standard rate.'**
  String get sageAccountsIntro;

  /// #669 - accounting export formats
  ///
  /// In en, this message translates to:
  /// **'VAT code (T1 / T0 / T9)'**
  String get sageTaxCode;

  /// #669 - SAF-T derived postings
  ///
  /// In en, this message translates to:
  /// **'Include postings?'**
  String get saftLedgerTitle;

  /// #669 - SAF-T derived postings
  ///
  /// In en, this message translates to:
  /// **'With account numbers, the file carries double-entry postings your accountant can import instead of keying in. They cover your sales and the payments against them — not your whole books.'**
  String get saftLedgerIntro;

  /// #669 - SAF-T derived postings
  ///
  /// In en, this message translates to:
  /// **'Documents only'**
  String get saftDocumentsOnly;

  /// #669 - SAF-T derived postings
  ///
  /// In en, this message translates to:
  /// **'With postings'**
  String get saftWithPostings;

  /// Document title on the exported bill PDF (#133)
  ///
  /// In en, this message translates to:
  /// **'Monthly bill'**
  String get billPdfTitle;

  /// Tooltip of the PDF export button next to the period header on the money tab
  ///
  /// In en, this message translates to:
  /// **'Export bill as PDF'**
  String get billPdfExport;

  /// #671 - report document text (reportCoaTitle)
  ///
  /// In en, this message translates to:
  /// **'Chart of accounts — preview'**
  String get reportCoaTitle;

  /// #671 - report document text (reportCoaIntro)
  ///
  /// In en, this message translates to:
  /// **'A suggestion, not your accounting. These are the accounts a bookkeeper in your country would usually use for a space like yours.'**
  String get reportCoaIntro;

  /// #671 - report document text (reportCoaAccounts)
  ///
  /// In en, this message translates to:
  /// **'Suggested accounts'**
  String get reportCoaAccounts;

  /// #671 - report document text (reportCoaNumber)
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get reportCoaNumber;

  /// #671 - report document text (reportCoaLabel)
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get reportCoaLabel;

  /// #671 - report document text (reportCoaDisclaimer)
  ///
  /// In en, this message translates to:
  /// **'Preview only. DesKilo does not keep a ledger and does not do your accounting — your accountant\'s chart always wins.'**
  String get reportCoaDisclaimer;

  /// #671 - report document text (reportBadgesTitle)
  ///
  /// In en, this message translates to:
  /// **'Member badges'**
  String get reportBadgesTitle;

  /// #671 - report document text (reportBadgesIntro)
  ///
  /// In en, this message translates to:
  /// **'Cut along the lines. Each card carries one member\'s badge code — present it at the kiosk to check in.'**
  String get reportBadgesIntro;

  /// #671 - report document text (reportBadgesFooter)
  ///
  /// In en, this message translates to:
  /// **'A lost badge should be revoked in Members & plans, not just replaced.'**
  String get reportBadgesFooter;

  /// #671 - report document text (reportSpaceCodesTitle)
  ///
  /// In en, this message translates to:
  /// **'Space codes'**
  String get reportSpaceCodesTitle;

  /// #671 - report document text (reportSpaceCodesIntro)
  ///
  /// In en, this message translates to:
  /// **'One card per seat, table, room and floor. Stick each card on its space: scanning it opens the same sheet the kiosk shows.'**
  String get reportSpaceCodesIntro;

  /// #671 - report document text (reportSpaceCodesFooter)
  ///
  /// In en, this message translates to:
  /// **'A card that no longer matches its space misleads whoever scans it — reprint the sheet after moving or renaming a space.'**
  String get reportSpaceCodesFooter;

  /// Owner billing editor (#128): fee bands + subscription levels; screen title and settings entry
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get billingTitle;

  /// Section header of the fee-band editor
  ///
  /// In en, this message translates to:
  /// **'Fee bands'**
  String get billingFeeBands;

  /// Derived lower boundary of a band row (exclusive)
  ///
  /// In en, this message translates to:
  /// **'from {from}%'**
  String billingBandFrom(int from);

  /// Label of a band's upper boundary field (inclusive)
  ///
  /// In en, this message translates to:
  /// **'To %'**
  String get billingBandTo;

  /// Label of a band's monthly fee field
  ///
  /// In en, this message translates to:
  /// **'Monthly fee'**
  String get billingBandFee;

  /// Label of a band's price-per-extra-half-day field
  ///
  /// In en, this message translates to:
  /// **'Overage'**
  String get billingBandOverage;

  /// Button splitting the last band into two
  ///
  /// In en, this message translates to:
  /// **'Add band'**
  String get billingAddBand;

  /// Tooltip of the per-row remove button; the range merges into the next band
  ///
  /// In en, this message translates to:
  /// **'Remove band'**
  String get billingRemoveBand;

  /// Validation error blocking the band save
  ///
  /// In en, this message translates to:
  /// **'Bands must increase and end at 100%.'**
  String get billingBandsInvalid;

  /// Snackbar after a successful billing save
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get billingSaved;

  /// Section header of the offered-levels editor
  ///
  /// In en, this message translates to:
  /// **'Subscription levels'**
  String get billingLevels;

  /// Tooltip of the add-level button
  ///
  /// In en, this message translates to:
  /// **'Add level'**
  String get billingAddLevel;

  /// Label of the new-level percentage input
  ///
  /// In en, this message translates to:
  /// **'Level (1–100)'**
  String get billingLevelValue;

  /// Switch: members may hold a per-person negotiated percentage
  ///
  /// In en, this message translates to:
  /// **'Allow negotiated custom value'**
  String get billingAllowCustom;

  /// Title of the per-member subscription picker dialog
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get memberSubscriptionLabel;

  /// Label of the owner-override custom percentage field
  ///
  /// In en, this message translates to:
  /// **'Custom (1–100)'**
  String get memberSubscriptionCustom;

  /// Statement line for the band fee of the member's percentage
  ///
  /// In en, this message translates to:
  /// **'Subscription {pct}%'**
  String moneySubscriptionPct(int pct);

  /// A plain percentage value (level chips, member rows)
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String percentValue(int value);

  /// Title of the per-member over-consumption policy picker dialog
  ///
  /// In en, this message translates to:
  /// **'When days run out'**
  String get memberOveragePolicyLabel;

  /// Tooltip of the members-screen button opening the over-consumption policy picker
  ///
  /// In en, this message translates to:
  /// **'Over-consumption'**
  String get memberOveragePolicyTooltip;

  /// Over-consumption option: the member cannot book past their monthly days
  ///
  /// In en, this message translates to:
  /// **'Block further booking'**
  String get overagePolicyBlocked;

  /// Over-consumption option: extra days are allowed and billed at the band overage rate
  ///
  /// In en, this message translates to:
  /// **'Charge overage (pay-as-you-go)'**
  String get overagePolicyPayg;

  /// Over-consumption option: the member must buy a package of days to book past their plan
  ///
  /// In en, this message translates to:
  /// **'Require buying a package'**
  String get overagePolicyPackage;

  /// Section header of the owner's day-package editor (migration 0042)
  ///
  /// In en, this message translates to:
  /// **'Day packages'**
  String get billingPackages;

  /// Sub-header explaining who buys packages
  ///
  /// In en, this message translates to:
  /// **'Members on the package plan buy these when their days run out.'**
  String get billingPackagesHint;

  /// Summary line under a package name in the editor: day count and formatted price
  ///
  /// In en, this message translates to:
  /// **'{days} days · {price}'**
  String billingPackageSummary(int days, String price);

  /// Label of the new-package name field
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get billingPackageName;

  /// Label of the new-package day-count field
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get billingPackageDays;

  /// Label of the new-package price field
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get billingPackagePrice;

  /// Tooltip of the add-package button
  ///
  /// In en, this message translates to:
  /// **'Add package'**
  String get billingAddPackage;

  /// Money-tab button opening the package buy sheet (package-plan members)
  ///
  /// In en, this message translates to:
  /// **'Buy a package'**
  String get buyPackageButton;

  /// Title of the package buy sheet
  ///
  /// In en, this message translates to:
  /// **'Buy a package'**
  String get buyPackageTitle;

  /// Day count of a package row in the buy sheet
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String buyPackageDays(int days);

  /// Snackbar when the owner has defined no packages yet
  ///
  /// In en, this message translates to:
  /// **'No packages are available yet.'**
  String get buyPackageNone;

  /// Snackbar after a member bought a package
  ///
  /// In en, this message translates to:
  /// **'Days added — enjoy the extra time.'**
  String get buyPackageDone;

  /// Owner screen to configure online-payment providers (0047)
  ///
  /// In en, this message translates to:
  /// **'Online payments'**
  String get payConfigTitle;

  /// Diagnostics dialog action opening the online-payments config screen
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get payConfigOpen;

  /// Intro on the online-payments config screen
  ///
  /// In en, this message translates to:
  /// **'Enter each payment provider you want to offer. Keys are stored securely on the server and never shown again. See docs/design/payments-integration.md.'**
  String get payConfigIntro;

  /// Chip: provider is configured
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get payConfigConfigured;

  /// Chip: provider is not configured
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get payConfigNotConfigured;

  /// Helper under a secret field that already holds a value
  ///
  /// In en, this message translates to:
  /// **'Set — leave blank to keep'**
  String get payConfigSecretSet;

  /// Snackbar after saving a provider's config
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get payConfigSaved;

  /// Button removing a provider's config
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get payConfigRemove;

  /// Snackbar after removing a provider's config
  ///
  /// In en, this message translates to:
  /// **'Removed.'**
  String get payConfigRemoved;

  /// PayPal client ID field
  ///
  /// In en, this message translates to:
  /// **'Client ID'**
  String get payFieldClientId;

  /// PayPal secret field
  ///
  /// In en, this message translates to:
  /// **'Secret'**
  String get payFieldSecret;

  /// PayPal environment (sandbox/live) field
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get payFieldEnv;

  /// PayPal webhook id field
  ///
  /// In en, this message translates to:
  /// **'Webhook ID'**
  String get payFieldWebhookId;

  /// Return URL the payer lands on after paying
  ///
  /// In en, this message translates to:
  /// **'Return URL'**
  String get payFieldReturnUrl;

  /// Stripe secret key field
  ///
  /// In en, this message translates to:
  /// **'Secret key'**
  String get payFieldSecretKey;

  /// Stripe webhook signing secret field
  ///
  /// In en, this message translates to:
  /// **'Webhook signing secret'**
  String get payFieldWebhookSecret;

  /// Mollie API key field
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get payFieldApiKey;

  /// Provider button/label: Wero paid through Mollie's checkout (0048)
  ///
  /// In en, this message translates to:
  /// **'Wero (via Mollie)'**
  String get paymentProviderWero;

  /// No description provided for @billingRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice schedule'**
  String get billingRulesTitle;

  /// No description provided for @billingRulesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When subscription and end-of-month invoices go out'**
  String get billingRulesSubtitle;

  /// No description provided for @billingRulesSaved.
  ///
  /// In en, this message translates to:
  /// **'Invoice schedule saved.'**
  String get billingRulesSaved;

  /// No description provided for @billingSubscriptionSection.
  ///
  /// In en, this message translates to:
  /// **'Subscription, in advance'**
  String get billingSubscriptionSection;

  /// No description provided for @billingSubscriptionAuto.
  ///
  /// In en, this message translates to:
  /// **'Issue automatically'**
  String get billingSubscriptionAuto;

  /// No description provided for @billingSubscriptionOff.
  ///
  /// In en, this message translates to:
  /// **'Switch on “Subscription invoices” in Features to use this.'**
  String get billingSubscriptionOff;

  /// No description provided for @billingAdvanceDays.
  ///
  /// In en, this message translates to:
  /// **'Days before the month starts'**
  String get billingAdvanceDays;

  /// Invoice schedule: when a subscription invoice goes out and the month it charges (#802)
  ///
  /// In en, this message translates to:
  /// **'Issued on {day} for {month}'**
  String billingSubscriptionWhen(String day, String month);

  /// No description provided for @billingUsageSection.
  ///
  /// In en, this message translates to:
  /// **'The month just finished'**
  String get billingUsageSection;

  /// No description provided for @billingUsageAuto.
  ///
  /// In en, this message translates to:
  /// **'Issue automatically'**
  String get billingUsageAuto;

  /// No description provided for @billingUsageOff.
  ///
  /// In en, this message translates to:
  /// **'Switch on “End-of-month invoices” in Features to use this.'**
  String get billingUsageOff;

  /// No description provided for @billingUsageWhenZero.
  ///
  /// In en, this message translates to:
  /// **'Also when there is nothing to pay'**
  String get billingUsageWhenZero;

  /// No description provided for @billingUsageWhenZeroHint.
  ///
  /// In en, this message translates to:
  /// **'Sends a document reading zero, as confirmation that the subscription covered the whole month.'**
  String get billingUsageWhenZeroHint;

  /// No description provided for @invoiceKindSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription, in advance'**
  String get invoiceKindSubscription;

  /// No description provided for @invoiceKindUsage.
  ///
  /// In en, this message translates to:
  /// **'The month\'s extras'**
  String get invoiceKindUsage;

  /// No description provided for @invoiceKindSettlement.
  ///
  /// In en, this message translates to:
  /// **'Regrouped invoices'**
  String get invoiceKindSettlement;

  /// No description provided for @invoiceKindFull.
  ///
  /// In en, this message translates to:
  /// **'Whole month'**
  String get invoiceKindFull;

  /// No description provided for @settlementRegroups.
  ///
  /// In en, this message translates to:
  /// **'This invoice regroups'**
  String get settlementRegroups;

  /// No description provided for @settlementVatNote.
  ///
  /// In en, this message translates to:
  /// **'The lines and their VAT are carried over from the regrouped invoices; the VAT declaration counts the originals once.'**
  String get settlementVatNote;

  /// No description provided for @settlementSettledBy.
  ///
  /// In en, this message translates to:
  /// **'Regrouped into another invoice — that one is what is owed and chased.'**
  String get settlementSettledBy;

  /// No description provided for @settlementAction.
  ///
  /// In en, this message translates to:
  /// **'Regroup into one invoice'**
  String get settlementAction;

  /// Confirm regrouping N invoices into one (#804)
  ///
  /// In en, this message translates to:
  /// **'Regroup {count} invoices into one of {amount}?'**
  String settlementConfirm(int count, String amount);

  /// No description provided for @settlementDone.
  ///
  /// In en, this message translates to:
  /// **'Regrouped into {number}.'**
  String settlementDone(String number);

  /// No description provided for @settlementNeedsTwo.
  ///
  /// In en, this message translates to:
  /// **'Pick at least two open invoices of the same member.'**
  String get settlementNeedsTwo;

  /// No description provided for @settlementFoldedIn.
  ///
  /// In en, this message translates to:
  /// **'Regrouped in {number}'**
  String settlementFoldedIn(String number);

  /// No description provided for @settlementDocumentationOnly.
  ///
  /// In en, this message translates to:
  /// **'Documentation only — every operation happens on the regrouping invoice.'**
  String get settlementDocumentationOnly;

  /// No description provided for @settlementSourcePdf.
  ///
  /// In en, this message translates to:
  /// **'PDF (regrouped)'**
  String get settlementSourcePdf;

  /// No description provided for @settlementRegroupsNumbers.
  ///
  /// In en, this message translates to:
  /// **'Regroups {numbers}'**
  String settlementRegroupsNumbers(String numbers);

  /// No description provided for @invoicePdfSettledIn.
  ///
  /// In en, this message translates to:
  /// **'Regrouped in {number}'**
  String invoicePdfSettledIn(String number);

  /// No description provided for @settlementPaidThrough.
  ///
  /// In en, this message translates to:
  /// **'Paid through {number}'**
  String settlementPaidThrough(String number);

  /// No description provided for @settlementAnnexTitle.
  ///
  /// In en, this message translates to:
  /// **'Attach the regrouped invoices?'**
  String get settlementAnnexTitle;

  /// No description provided for @settlementAnnexAlone.
  ///
  /// In en, this message translates to:
  /// **'This invoice only'**
  String get settlementAnnexAlone;

  /// No description provided for @settlementAnnexWith.
  ///
  /// In en, this message translates to:
  /// **'Attach them'**
  String get settlementAnnexWith;

  /// No description provided for @settlementAnnexBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The invoice this one replaces can follow it, on its own pages and stamped as regrouped.} other{The {count} invoices this one replaces can follow it, each on its own pages and stamped as regrouped.}}'**
  String settlementAnnexBody(int count);

  /// Detail sheet: extend a running booking's end (#574)
  ///
  /// In en, this message translates to:
  /// **'Stay longer'**
  String get reservationExtendButton;

  /// Extend flow: picked time not after the current end (#574)
  ///
  /// In en, this message translates to:
  /// **'Pick a time after the current end.'**
  String get reservationExtendLaterOnly;

  /// Detail sheet: shrink a running booking's end (#638)
  ///
  /// In en, this message translates to:
  /// **'End earlier'**
  String get reservationEndEarlyButton;

  /// End-earlier flow: picked time not ahead of now, or not before the current end (#638)
  ///
  /// In en, this message translates to:
  /// **'Pick a time still ahead of now and before the current end.'**
  String get reservationEndEarlyAheadOnly;

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

  /// Reservation detail sheet button jumping to the Plan tab with the seat's level shown and the seat highlighted (#182)
  ///
  /// In en, this message translates to:
  /// **'Show on plan'**
  String get calendarShowOnPlan;

  /// Tooltip of the calendar toggle switching the selected-day area to the plain reservation list (#187)
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get calendarListView;

  /// Tooltip of the calendar toggle switching the selected-day area to the per-seat 24h timeline (#187)
  ///
  /// In en, this message translates to:
  /// **'Timeline view'**
  String get calendarTimelineView;

  /// Empty state of the day timeline: the selected level has no seats or no visible reservations that day (#187)
  ///
  /// In en, this message translates to:
  /// **'No reservations on this level for this day.'**
  String get calendarTimelineEmpty;

  /// First chip of the timeline level selector: stacks every level's rows under level-name headers on one shared axis (#221)
  ///
  /// In en, this message translates to:
  /// **'All levels'**
  String get calendarAllLevels;

  /// Empty state of the day timeline in all-levels mode: no level has seats with a visible reservation that day (#221)
  ///
  /// In en, this message translates to:
  /// **'No reservations on any level for this day.'**
  String get calendarTimelineAllEmpty;

  /// Accessibility label of a collapsed level header in the all-levels timeline; tapping expands it
  ///
  /// In en, this message translates to:
  /// **'{level}, collapsed'**
  String calendarLevelCollapsed(String level);

  /// Accessibility label of an expanded level header in the all-levels timeline; tapping collapses it
  ///
  /// In en, this message translates to:
  /// **'{level}, expanded'**
  String calendarLevelExpanded(String level);

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'Who can see this'**
  String get calendarWhoCanSee;

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get calendarPrevious;

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get calendarNext;

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get calendarDay;

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get calendarRange;

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get calendarMemberMe;

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'Nothing on these dates.'**
  String get calendarNothingHere;

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'Not visible to you for this member: {kinds}'**
  String calendarLockedKinds(String kinds);

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'Alert: {label}'**
  String calendarEventTitle(String label);

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get calendarKindReservation;

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'Check-ins'**
  String get calendarKindCheckIn;

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'Check-outs'**
  String get calendarKindCheckOut;

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get calendarKindEvent;

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get calendarKindMessage;

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get calendarKindInvoice;

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get calendarKindPayment;

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'Consumption'**
  String get calendarKindConsumption;

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get calendarKindReminder;

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'nobody else'**
  String get accessNobodyElse;

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'Every member of the workspace — the floor plan shows occupancy to everyone.'**
  String get accessRuleReservations;

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'You, the member who acted, and the admins.'**
  String get accessRuleEvents;

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'Only the people in the conversation — no role can read a conversation it is not part of.'**
  String get accessRuleMessages;

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'You, and those with the finance permission: {people}.'**
  String accessRuleFinances(String people);

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'Only you.'**
  String get accessRuleReminders;

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'Who accessed your data'**
  String get accessLogTitle;

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'Nobody has looked at your finances or messages.'**
  String get accessLogEmpty;

  /// #718/#719 - calendar hub
  ///
  /// In en, this message translates to:
  /// **'{actor} read {category} of {subject}'**
  String accessLogRow(String actor, String category, String subject);

  /// No description provided for @calendarEventActionCreated.
  ///
  /// In en, this message translates to:
  /// **'created'**
  String get calendarEventActionCreated;

  /// No description provided for @calendarEventActionModified.
  ///
  /// In en, this message translates to:
  /// **'changed'**
  String get calendarEventActionModified;

  /// No description provided for @calendarEventActionCancelled.
  ///
  /// In en, this message translates to:
  /// **'cancelled'**
  String get calendarEventActionCancelled;

  /// No description provided for @calendarEventActionSubmitted.
  ///
  /// In en, this message translates to:
  /// **'submitted'**
  String get calendarEventActionSubmitted;

  /// No description provided for @calendarEventActionApproved.
  ///
  /// In en, this message translates to:
  /// **'approved'**
  String get calendarEventActionApproved;

  /// No description provided for @calendarEventActionRejected.
  ///
  /// In en, this message translates to:
  /// **'rejected'**
  String get calendarEventActionRejected;

  /// No description provided for @calendarEventStatusPending.
  ///
  /// In en, this message translates to:
  /// **'awaiting confirmation'**
  String get calendarEventStatusPending;

  /// No description provided for @calendarEventStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'rejected'**
  String get calendarEventStatusRejected;

  /// No description provided for @calendarEventStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'expired'**
  String get calendarEventStatusExpired;

  /// No description provided for @accessKindNegotiations.
  ///
  /// In en, this message translates to:
  /// **'Price negotiations'**
  String get accessKindNegotiations;

  /// No description provided for @accessRuleNegotiations.
  ///
  /// In en, this message translates to:
  /// **'You, the owners and the finance admins: {people}. Every read by someone else is on the record below.'**
  String accessRuleNegotiations(String people);

  /// No description provided for @calendarViewAgenda.
  ///
  /// In en, this message translates to:
  /// **'Agenda'**
  String get calendarViewAgenda;

  /// No description provided for @calendarViewWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get calendarViewWeek;

  /// No description provided for @calendarViewMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get calendarViewMonth;

  /// No description provided for @calendarToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get calendarToday;

  /// No description provided for @calendarTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get calendarTomorrow;

  /// No description provided for @calendarYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get calendarYesterday;

  /// No description provided for @calendarKindDue.
  ///
  /// In en, this message translates to:
  /// **'Payments due'**
  String get calendarKindDue;

  /// No description provided for @calendarKindScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled expenses'**
  String get calendarKindScheduled;

  /// No description provided for @calendarDueTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment due · {number}'**
  String calendarDueTitle(String number);

  /// No description provided for @calendarScheduledTitle.
  ///
  /// In en, this message translates to:
  /// **'Scheduled expense · {name}'**
  String calendarScheduledTitle(String name);

  /// No description provided for @calendarClosedDay.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get calendarClosedDay;

  /// No description provided for @calendarClosedDayReason.
  ///
  /// In en, this message translates to:
  /// **'Closed — {reason}'**
  String calendarClosedDayReason(String reason);

  /// No description provided for @calendarGroupBookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings & presence'**
  String get calendarGroupBookings;

  /// No description provided for @calendarGroupActivity.
  ///
  /// In en, this message translates to:
  /// **'Alerts & messages'**
  String get calendarGroupActivity;

  /// No description provided for @calendarGroupMoney.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get calendarGroupMoney;

  /// No description provided for @calendarAgendaEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned in the next {days} days.'**
  String calendarAgendaEmpty(int days);

  /// No description provided for @calendarAgendaRange.
  ///
  /// In en, this message translates to:
  /// **'Next {days} days'**
  String calendarAgendaRange(int days);

  /// No description provided for @calendarWeekEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing this week.'**
  String get calendarWeekEmpty;

  /// No description provided for @calendarDayEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing on this day.'**
  String get calendarDayEmpty;

  /// No description provided for @calendarItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String calendarItemCount(int count);

  /// #843 - calendar kind chip: decisions taken on events
  ///
  /// In en, this message translates to:
  /// **'Validations'**
  String get calendarKindValidation;

  /// #843 - a calendar row for an accepted decision
  ///
  /// In en, this message translates to:
  /// **'Validated: {what}'**
  String calendarValidationValidated(String what);

  /// #843 - a calendar row for a refused decision
  ///
  /// In en, this message translates to:
  /// **'Refused: {what}'**
  String calendarValidationRefused(String what);

  /// #843 - verb of an accepted decision
  ///
  /// In en, this message translates to:
  /// **'validated'**
  String get calendarEventActionValidated;

  /// #843 - verb of a refused decision
  ///
  /// In en, this message translates to:
  /// **'refused'**
  String get calendarEventActionRefused;

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

  /// Tooltip of the app-bar events bell and title of the events feed screen it pushes (#230; formerly the bottom-tab label)
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

  /// Settings section header grouping the owner/admin workspace-management entries (workspace, members, billing, …)
  ///
  /// In en, this message translates to:
  /// **'Administration'**
  String get settingsSectionAdministration;

  /// Settings section header grouping the personal preference entries (language, theme)
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsSectionPreferences;

  /// Settings section header grouping the developer/diagnostics entries
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get settingsSectionAdvanced;

  /// Placeholder body shown on tabs whose feature is not yet implemented
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// Tooltip of the raised centre Reserve button in the bottom bar, and title of the reservation screen it opens
  ///
  /// In en, this message translates to:
  /// **'Reserve'**
  String get shellReserveButton;

  /// Success snackbar after an export is saved locally on the device (not shared); shows the file's full path.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String commonSavedTo(String path);

  /// Error snackbar when a local file export fails.
  ///
  /// In en, this message translates to:
  /// **'Could not save the file.'**
  String get commonSaveFailed;

  /// Generic retry button
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonRetry;

  /// Settings section header: About (#560)
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// Version line under the app name (#560)
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// About tile: licence (#560)
  ///
  /// In en, this message translates to:
  /// **'Open source (0BSD)'**
  String get aboutOpenSource;

  /// About tile subtitle: source on GitHub (#560)
  ///
  /// In en, this message translates to:
  /// **'Source code on GitHub'**
  String get aboutOpenSourceDesc;

  /// About tile: privacy policy link (#560)
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get aboutPrivacy;

  /// About tile: GitHub issue link (#560)
  ///
  /// In en, this message translates to:
  /// **'Report a bug / suggest a feature'**
  String get aboutReportBug;

  /// Support block title (#560)
  ///
  /// In en, this message translates to:
  /// **'Support this project'**
  String get aboutSupportTitle;

  /// Support block body (#560)
  ///
  /// In en, this message translates to:
  /// **'This app is free, open source and ad-free. If you find it useful, support the developer.'**
  String get aboutSupportBody;

  /// Button + sheet title recording my own consumed services (#129)
  ///
  /// In en, this message translates to:
  /// **'Add consumption'**
  String get consumptionAdd;

  /// Sheet title / tooltip when an admin records for another member
  ///
  /// In en, this message translates to:
  /// **'Add service for {name}'**
  String consumptionAddForMember(String name);

  /// Label of the service dropdown in the consumption sheet
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get consumptionService;

  /// Label of the quantity stepper (1–999)
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get consumptionQuantity;

  /// Label of the billing-period input; prefilled with the current month
  ///
  /// In en, this message translates to:
  /// **'Billing period (YYYY-MM)'**
  String get consumptionPeriodLabel;

  /// Snackbar when the workspace offers no active services
  ///
  /// In en, this message translates to:
  /// **'No active services to record.'**
  String get consumptionNoServices;

  /// Snackbar after submitting; the charge stays pending until confirmed
  ///
  /// In en, this message translates to:
  /// **'Consumption recorded — waiting for confirmation.'**
  String get consumptionRecorded;

  /// Event type label / filter chip for service charges
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get eventTypeServiceCharge;

  /// Feed/card line for a service charge, e.g. 'Coffee ×2 — €3.00'; amount is preformatted currency
  ///
  /// In en, this message translates to:
  /// **'{name} ×{quantity} — {amount}'**
  String eventServiceChargeTitle(String name, int quantity, String amount);

  /// Member-sheet action opening the co-owner dialog (0058)
  ///
  /// In en, this message translates to:
  /// **'Co-ownership'**
  String get coOwnerAction;

  /// Co-owner dialog option: clear the role
  ///
  /// In en, this message translates to:
  /// **'No co-owner role'**
  String get coOwnerNone;

  /// Co-owner dialog option: the active flavor
  ///
  /// In en, this message translates to:
  /// **'Active co-owner — owner permissions now, automatic succession'**
  String get coOwnerActive;

  /// Co-owner dialog option: the passive flavor
  ///
  /// In en, this message translates to:
  /// **'Passive co-owner — becomes owner when activated or when the owner leaves'**
  String get coOwnerPassive;

  /// Member-sheet action promoting a co-owner to full owner
  ///
  /// In en, this message translates to:
  /// **'Promote to owner now'**
  String get coOwnerActivate;

  /// Members-list chip for an active co-owner
  ///
  /// In en, this message translates to:
  /// **'Co-owner'**
  String get memberCoOwnerChip;

  /// Members-list chip for a passive co-owner
  ///
  /// In en, this message translates to:
  /// **'Co-owner (passive)'**
  String get memberCoOwnerPassiveChip;

  /// Settings toggle enabling the local diagnostics screen
  ///
  /// In en, this message translates to:
  /// **'Developer mode'**
  String get developerMode;

  /// Subtitle under the workspace-wide dev-mode switch (#419)
  ///
  /// In en, this message translates to:
  /// **'Applies to every member of this workspace.'**
  String get developerModeWorkspaceHint;

  /// App-bar title and settings entry of the trace viewer
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developerTitle;

  /// App-bar action sharing the trace log as a file
  ///
  /// In en, this message translates to:
  /// **'Export trace'**
  String get developerExport;

  /// App-bar action emptying the trace buffer and file
  ///
  /// In en, this message translates to:
  /// **'Clear trace'**
  String get developerClear;

  /// Placeholder when the trace list is empty
  ///
  /// In en, this message translates to:
  /// **'No trace entries yet.'**
  String get developerEmpty;

  /// Filter chip showing every trace level
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get developerFilterAll;

  /// Filter chip showing only error-level entries
  ///
  /// In en, this message translates to:
  /// **'Errors'**
  String get developerFilterErrors;

  /// Filter chip showing warnings and errors
  ///
  /// In en, this message translates to:
  /// **'Warnings+'**
  String get developerFilterWarnings;

  /// Settings status line: push pipeline registered (#424)
  ///
  /// In en, this message translates to:
  /// **'Push notifications are active'**
  String get pushStatusRegistered;

  /// Settings status line: Firebase not configured (#428)
  ///
  /// In en, this message translates to:
  /// **'Push notifications are not set up yet'**
  String get pushStatusNotConfigured;

  /// Fix hint under the not-configured line (#428)
  ///
  /// In en, this message translates to:
  /// **'The workspace owner completes the Firebase setup (push-setup guide).'**
  String get pushStatusNotConfiguredHint;

  /// Settings warning when Android suppresses the app's notifications (#436)
  ///
  /// In en, this message translates to:
  /// **'Android is blocking DesKilo notifications'**
  String get notificationsSystemOff;

  /// Fix hint under the system-notifications warning (#436)
  ///
  /// In en, this message translates to:
  /// **'Allow them under system Settings → Apps → DesKilo → Notifications — the icon badge needs them.'**
  String get notificationsSystemOffHint;

  /// #677 - developer reservation export
  ///
  /// In en, this message translates to:
  /// **'Export reservations'**
  String get developerExportReservations;

  /// #677 - developer reservation export
  ///
  /// In en, this message translates to:
  /// **'Every booking and check-in — past, present and future, every state — as CSV, for analysis and debugging.'**
  String get developerExportReservationsHint;

  /// #716 - F-Droid build without a push transport
  ///
  /// In en, this message translates to:
  /// **'This build has no push notifications'**
  String get pushStatusNoTransport;

  /// #716 - F-Droid build without a push transport
  ///
  /// In en, this message translates to:
  /// **'Notifications arrive in the app and as local notifications on this device.'**
  String get pushStatusNoTransportHint;

  /// Member directory title: bottom-tab label and app-bar title of the Members tab (#230) plus its settings entry (#224), visible to every member. Keep it short — it must fit a bottom-bar tab.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get directoryTitle;

  /// Empty state of the member directory
  ///
  /// In en, this message translates to:
  /// **'No members yet.'**
  String get directoryEmpty;

  /// Directory status chip: member is checked in right now (seat name unknown)
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get directoryCheckedIn;

  /// Directory status chip: member is checked in right now on the named seat/office
  ///
  /// In en, this message translates to:
  /// **'Checked in · {seat}'**
  String directoryCheckedInSeat(String seat);

  /// Directory status chip: heartbeat younger than the presence window (#223)
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get directoryOnline;

  /// Directory status chip: member has an active reservation later today
  ///
  /// In en, this message translates to:
  /// **'Reserved today'**
  String get directoryReservedToday;

  /// Directory offline chip: compact relative last-seen, under an hour
  ///
  /// In en, this message translates to:
  /// **'Seen {minutes} min ago'**
  String directoryLastSeenMinutes(int minutes);

  /// Directory offline chip: compact relative last-seen, under a day
  ///
  /// In en, this message translates to:
  /// **'Seen {hours} h ago'**
  String directoryLastSeenHours(int hours);

  /// Directory offline chip: compact relative last-seen, a day or more
  ///
  /// In en, this message translates to:
  /// **'Seen {days} d ago'**
  String directoryLastSeenDays(int days);

  /// Tooltip of the wa.me contact button on a directory row (#223 opt-in); also the swipe-right background label and the contact button in the member detail sheet (#232)
  ///
  /// In en, this message translates to:
  /// **'Chat on WhatsApp'**
  String get directoryWhatsapp;

  /// Tile above the directory list opening the owner-configured WhatsApp group invite link (#231/#232); shown to every member, hidden when no link is set
  ///
  /// In en, this message translates to:
  /// **'Open WhatsApp group'**
  String get directoryOpenGroup;

  /// Dismiss button of the member detail sheet (#232)
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get directoryClose;

  /// Directory reservation chip (#237): an active reservation covers now but the member has not checked in (seat name unknown)
  ///
  /// In en, this message translates to:
  /// **'Reserved now'**
  String get directoryReservedNow;

  /// Directory reservation chip (#237): an active reservation on the named seat/office covers now but the member has not checked in
  ///
  /// In en, this message translates to:
  /// **'Reserved now · {seat}'**
  String directoryReservedNowSeat(String seat);

  /// Section heading in the member detail sheet listing that member's upcoming reservations, each tappable to open its detail
  ///
  /// In en, this message translates to:
  /// **'Reservations'**
  String get directoryReservationsHeading;

  /// Shown under the Reservations heading in the member detail sheet when the member has no active booking ahead
  ///
  /// In en, this message translates to:
  /// **'No upcoming reservations'**
  String get directoryNoUpcoming;

  /// No description provided for @memberPageEmailAction.
  ///
  /// In en, this message translates to:
  /// **'E-mail'**
  String get memberPageEmailAction;

  /// No description provided for @memberPageAddService.
  ///
  /// In en, this message translates to:
  /// **'Add a service'**
  String get memberPageAddService;

  /// No description provided for @memberPageNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get memberPageNone;

  /// No description provided for @memberPageWorkspaceDefaultValue.
  ///
  /// In en, this message translates to:
  /// **'Workspace default ({count})'**
  String memberPageWorkspaceDefaultValue(int count);

  /// No description provided for @memberPageLevelTitle.
  ///
  /// In en, this message translates to:
  /// **'Whole-level bookings'**
  String get memberPageLevelTitle;

  /// No description provided for @memberPageGroupMembership.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get memberPageGroupMembership;

  /// No description provided for @memberPageGroupBooking.
  ///
  /// In en, this message translates to:
  /// **'Booking rules'**
  String get memberPageGroupBooking;

  /// No description provided for @memberPageGroupBilling.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get memberPageGroupBilling;

  /// No description provided for @memberPageGroupAccess.
  ///
  /// In en, this message translates to:
  /// **'Badges & access'**
  String get memberPageGroupAccess;

  /// No description provided for @memberPageManageHeading.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get memberPageManageHeading;

  /// No description provided for @memberPageStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get memberPageStatusActive;

  /// No description provided for @memberPageNeverSeen.
  ///
  /// In en, this message translates to:
  /// **'Not seen yet'**
  String get memberPageNeverSeen;

  /// No description provided for @memberPageYou.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String memberPageYou(String name);

  /// No description provided for @memberPageSince.
  ///
  /// In en, this message translates to:
  /// **'Member since {date}'**
  String memberPageSince(String date);

  /// No description provided for @memberPageCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Checked in · {seat} · since {time}'**
  String memberPageCheckedIn(String seat, String time);

  /// No description provided for @memberPageReservedNow.
  ///
  /// In en, this message translates to:
  /// **'Reserved now · {seat} · until {time}'**
  String memberPageReservedNow(String seat, String time);

  /// No description provided for @memberPageNext.
  ///
  /// In en, this message translates to:
  /// **'Next: {label}'**
  String memberPageNext(String label);

  /// No description provided for @memberPageNowHeading.
  ///
  /// In en, this message translates to:
  /// **'Right now'**
  String get memberPageNowHeading;

  /// Editor app-bar action opening the level background-image menu (0036)
  ///
  /// In en, this message translates to:
  /// **'Background image'**
  String get editorBackgroundImage;

  /// Menu item: pick a photo/blueprint of the real space as the level background
  ///
  /// In en, this message translates to:
  /// **'Set background image'**
  String get editorBackgroundSet;

  /// Menu item shown when a background is already set
  ///
  /// In en, this message translates to:
  /// **'Replace background image'**
  String get editorBackgroundReplace;

  /// Menu item removing the level background image
  ///
  /// In en, this message translates to:
  /// **'Remove background image'**
  String get editorBackgroundRemove;

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

  /// Editor tool: place a resizable illustration image on the plan (0037)
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get editorToolImage;

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

  /// Label above the seat sheet's accessory chips (workspace catalog)
  ///
  /// In en, this message translates to:
  /// **'Accessories'**
  String get editorAccessoriesLabel;

  /// Hint in the seat sheet when the workspace accessory catalog is empty
  ///
  /// In en, this message translates to:
  /// **'No accessories yet — add them in Settings → Accessories.'**
  String get editorNoAccessories;

  /// No description provided for @editorSeatNfcLabel.
  ///
  /// In en, this message translates to:
  /// **'NFC/RFID tag'**
  String get editorSeatNfcLabel;

  /// No description provided for @editorSeatNfcHelp.
  ///
  /// In en, this message translates to:
  /// **'Tag uid in hex — leave empty for no tag.'**
  String get editorSeatNfcHelp;

  /// No description provided for @editorSeatNfcRead.
  ///
  /// In en, this message translates to:
  /// **'Read a tag now'**
  String get editorSeatNfcRead;

  /// No description provided for @editorSeatNfcReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the tag reader.'**
  String get editorSeatNfcReadFailed;

  /// No description provided for @editorSeatNfcDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This tag is already linked to another chair.'**
  String get editorSeatNfcDuplicate;

  /// #587 delete despite reservations — audit substitution warning
  ///
  /// In en, this message translates to:
  /// **'Delete this element? Anything placed on it is removed too. Bookings that reference it keep a text snapshot for audits; open bookings are cancelled.'**
  String get editorDeleteElementConfirmAudit;

  /// #587 delete despite reservations — audit substitution warning
  ///
  /// In en, this message translates to:
  /// **'Delete this level? All offices, desks and seats on it are removed. Bookings that reference them keep a text snapshot for audits; open bookings are cancelled.'**
  String get editorDeleteLevelConfirmAudit;

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

  /// Feed line for payment events
  ///
  /// In en, this message translates to:
  /// **'{actor} recorded a payment of {amount}'**
  String eventPaymentSubmitted(String actor, String amount);

  /// Feed line for expense events
  ///
  /// In en, this message translates to:
  /// **'{actor} submitted an expense of {amount}'**
  String eventExpenseSubmitted(String actor, String amount);

  /// Suffix when an admin acted on someone else's behalf
  ///
  /// In en, this message translates to:
  /// **'for {name}'**
  String eventForSubject(String name);

  /// Push notification title (#72) — brand name, usually untranslated
  ///
  /// In en, this message translates to:
  /// **'DesKilo'**
  String get pushPendingTitle;

  /// Generic push body for a pending confirmation; deliberately carries no personal data
  ///
  /// In en, this message translates to:
  /// **'Someone needs your confirmation.'**
  String get pushPendingBody;

  /// Push title when an admin removed a reservation (#424)
  ///
  /// In en, this message translates to:
  /// **'Reservation removed'**
  String get pushCancelledTitle;

  /// Push body for the removed-reservation ping — generic, no personal data (#424)
  ///
  /// In en, this message translates to:
  /// **'A reservation was removed by an admin.'**
  String get pushCancelledBody;

  /// Reservation deletion requests (#492)
  ///
  /// In en, this message translates to:
  /// **'Booking deletion'**
  String get eventTypeReservationDelete;

  /// Reservation deletion requests (#492)
  ///
  /// In en, this message translates to:
  /// **'{actor} asks to delete the booking of {date} ({state})'**
  String eventReservationDeleteLine(String actor, String date, String state);

  /// Reservation deletion requests (#492)
  ///
  /// In en, this message translates to:
  /// **'checked in'**
  String get eventReservationDeleteCheckedIn;

  /// Reservation deletion requests (#492)
  ///
  /// In en, this message translates to:
  /// **'never used'**
  String get eventReservationDeleteUnused;

  /// Feed marker for a deletion the rule settled itself, with no peer review (#636)
  ///
  /// In en, this message translates to:
  /// **'Auto-validated'**
  String get eventAutoValidated;

  /// Reservation deletion requests (#492)
  ///
  /// In en, this message translates to:
  /// **'Request deletion'**
  String get reservationDeleteRequestButton;

  /// Reservation deletion requests (#492)
  ///
  /// In en, this message translates to:
  /// **'Past or checked-in bookings are not deleted directly. An owner or admin will decide: was the check-in simply forgotten (the booking stays), or was it never used (it is removed)?'**
  String get reservationDeleteRequestExplain;

  /// Reservation deletion requests (#492)
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get reservationDeleteReasonLabel;

  /// Reservation deletion requests (#492)
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get reservationDeleteSubmit;

  /// Reservation deletion requests (#492)
  ///
  /// In en, this message translates to:
  /// **'Deletion requested — an owner or admin will decide.'**
  String get reservationDeleteSubmitted;

  /// No description provided for @notifCategoryCheckIns.
  ///
  /// In en, this message translates to:
  /// **'Check-ins'**
  String get notifCategoryCheckIns;

  /// No description provided for @notifCategoryMoney.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get notifCategoryMoney;

  /// No description provided for @notifCategoryMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get notifCategoryMembers;

  /// No description provided for @notesFilterRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get notesFilterRead;

  /// No description provided for @notifSortByDate.
  ///
  /// In en, this message translates to:
  /// **'Sort by date'**
  String get notifSortByDate;

  /// No description provided for @notifGroupBy.
  ///
  /// In en, this message translates to:
  /// **'Group by'**
  String get notifGroupBy;

  /// No description provided for @notifGroupByType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get notifGroupByType;

  /// No description provided for @notifGroupByDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get notifGroupByDate;

  /// No description provided for @notifGroupByUser.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get notifGroupByUser;

  /// No description provided for @notifUngroup.
  ///
  /// In en, this message translates to:
  /// **'Ungroup'**
  String get notifUngroup;

  /// No description provided for @validationScopeLabel.
  ///
  /// In en, this message translates to:
  /// **'Who validates'**
  String get validationScopeLabel;

  /// No description provided for @validationScopeAdmins.
  ///
  /// In en, this message translates to:
  /// **'Admins'**
  String get validationScopeAdmins;

  /// No description provided for @validationScopeListed.
  ///
  /// In en, this message translates to:
  /// **'Listed persons'**
  String get validationScopeListed;

  /// No description provided for @validationScopeMembers.
  ///
  /// In en, this message translates to:
  /// **'All members'**
  String get validationScopeMembers;

  /// No description provided for @validationScopeHint.
  ///
  /// In en, this message translates to:
  /// **'The owner always may. Admins: every admin, or the ones you list. Listed: exactly these people, whatever their role. All members: anyone active.'**
  String get validationScopeHint;

  /// No description provided for @validationPickPersons.
  ///
  /// In en, this message translates to:
  /// **'Pick the persons'**
  String get validationPickPersons;

  /// No description provided for @eventTypeExpenseSchedule.
  ///
  /// In en, this message translates to:
  /// **'Scheduled expense'**
  String get eventTypeExpenseSchedule;

  /// No description provided for @eventExpenseScheduleLine.
  ///
  /// In en, this message translates to:
  /// **'{actor} schedules “{title}” — {amount} recurring'**
  String eventExpenseScheduleLine(Object actor, Object amount, Object title);

  /// No description provided for @eventExpenseDeviation.
  ///
  /// In en, this message translates to:
  /// **'validated {scheduled} — {reason}'**
  String eventExpenseDeviation(Object reason, Object scheduled);

  /// No description provided for @eventExpenseRepartitionLine.
  ///
  /// In en, this message translates to:
  /// **'{actor} distributes “{title}” — {amount} over {count} members'**
  String eventExpenseRepartitionLine(
    String actor,
    String title,
    String amount,
    int count,
  );

  /// No description provided for @eventTypeExpenseRepartition.
  ///
  /// In en, this message translates to:
  /// **'Shared expense'**
  String get eventTypeExpenseRepartition;

  /// #833 - event type: an accepted early departure
  ///
  /// In en, this message translates to:
  /// **'Early departure'**
  String get eventTypeUsageCorrection;

  /// #833 - event type: removing a usage record
  ///
  /// In en, this message translates to:
  /// **'Usage record removal'**
  String get eventTypeUsageRecordDelete;

  /// #833 - feed line for an early-departure request
  ///
  /// In en, this message translates to:
  /// **'{actor} asks to be billed {to} instead of {from}'**
  String eventUsageCorrectionLine(String actor, String from, String to);

  /// #833 - feed line for a record removal
  ///
  /// In en, this message translates to:
  /// **'{actor} asks to remove a usage record ({space})'**
  String eventUsageRecordDeleteLine(String actor, String space);

  /// App-bar title of the owner feature-management screen and its settings tile
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get featuresTitle;

  /// Feature switch: the Calendar bottom tab
  ///
  /// In en, this message translates to:
  /// **'Calendar tab'**
  String get featureCalendarTab;

  /// One-line description under the Calendar tab switch
  ///
  /// In en, this message translates to:
  /// **'Monthly overview of bookings and closed days.'**
  String get featureCalendarTabDesc;

  /// Feature switch: the Events bottom tab
  ///
  /// In en, this message translates to:
  /// **'Events tab'**
  String get featureEventsTab;

  /// One-line description under the Events tab switch
  ///
  /// In en, this message translates to:
  /// **'Activity feed and pending confirmations.'**
  String get featureEventsTabDesc;

  /// Feature switch: the Money bottom tab
  ///
  /// In en, this message translates to:
  /// **'Money tab'**
  String get featureMoneyTab;

  /// One-line description under the Money tab switch
  ///
  /// In en, this message translates to:
  /// **'Monthly bills, payments and expenses.'**
  String get featureMoneyTabDesc;

  /// Feature switch: service catalog + consumptions
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get featureServices;

  /// One-line description under the Services switch
  ///
  /// In en, this message translates to:
  /// **'Service catalog and consumption tracking.'**
  String get featureServicesDesc;

  /// Feature switch: bill PDF export
  ///
  /// In en, this message translates to:
  /// **'PDF export'**
  String get featurePdfExport;

  /// One-line description under the PDF export switch
  ///
  /// In en, this message translates to:
  /// **'Export the monthly bill as a PDF.'**
  String get featurePdfExportDesc;

  /// Feature switch: recurring reservations
  ///
  /// In en, this message translates to:
  /// **'Series booking'**
  String get featureSeriesBooking;

  /// One-line description under the series booking switch
  ///
  /// In en, this message translates to:
  /// **'Repeat a reservation daily, weekly or on weekdays.'**
  String get featureSeriesBookingDesc;

  /// Feature switch: admins/owners booking for other members
  ///
  /// In en, this message translates to:
  /// **'Book for others'**
  String get featureBookForOthers;

  /// One-line description under the book-for-others switch
  ///
  /// In en, this message translates to:
  /// **'Admins and owners book seats for other members.'**
  String get featureBookForOthersDesc;

  /// Feature switch: push delivery of confirmations (FCM, ADR 0011)
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get featurePushNotifications;

  /// One-line description under the push notifications switch
  ///
  /// In en, this message translates to:
  /// **'Deliver pending confirmations to members\' devices.'**
  String get featurePushNotificationsDesc;

  /// Feature switch: admins may mark seats not reservable (#161)
  ///
  /// In en, this message translates to:
  /// **'Admins can block seats'**
  String get featureAdminSeatBlocking;

  /// One-line description under the admin-seat-blocking switch (#161)
  ///
  /// In en, this message translates to:
  /// **'Admins mark seats not reservable for maintenance. The owner always can.'**
  String get featureAdminSeatBlockingDesc;

  /// Feature switch: bill priced seat accessories on monthly statements (#170)
  ///
  /// In en, this message translates to:
  /// **'Accessory supplements'**
  String get featureAccessorySupplements;

  /// One-line description under the accessory-supplements switch (#170); no retroactive charging
  ///
  /// In en, this message translates to:
  /// **'Bill priced seat accessories per booked half-day. Applies to bookings from activation on.'**
  String get featureAccessorySupplementsDesc;

  /// Feature switch: members pay their bill through a payment provider (0043)
  ///
  /// In en, this message translates to:
  /// **'Online payments'**
  String get featureOnlinePayments;

  /// One-line description under the online-payments switch (0043)
  ///
  /// In en, this message translates to:
  /// **'Let members pay their bill online (PayPal). Needs the payment provider configured on the server.'**
  String get featureOnlinePaymentsDesc;

  /// Feature switch: RFID/NFC card check-in at a kiosk (0046)
  ///
  /// In en, this message translates to:
  /// **'RFID / NFC badges'**
  String get featureNfcBadges;

  /// One-line description under the NFC-badges switch
  ///
  /// In en, this message translates to:
  /// **'Members check in at a kiosk by tapping an RFID/NFC card. Needs an Android device with NFC.'**
  String get featureNfcBadgesDesc;

  /// No description provided for @featureLevelBooking.
  ///
  /// In en, this message translates to:
  /// **'Desk, office & level reservations'**
  String get featureLevelBooking;

  /// No description provided for @featureLevelBookingDesc.
  ///
  /// In en, this message translates to:
  /// **'Reserve a whole desk, office or floor as one booking, priced per half-day. Grant the right per member.'**
  String get featureLevelBookingDesc;

  /// No description provided for @featureAdminLevelAssign.
  ///
  /// In en, this message translates to:
  /// **'Admins can assign levels'**
  String get featureAdminLevelAssign;

  /// No description provided for @featureAdminLevelAssignDesc.
  ///
  /// In en, this message translates to:
  /// **'Admins assign level reservations to members. The owner always can.'**
  String get featureAdminLevelAssignDesc;

  /// Feature toggle: the wall-tablet module (0043)
  ///
  /// In en, this message translates to:
  /// **'Kiosk mode'**
  String get featureKioskMode;

  /// Subtitle of the kiosk-mode feature toggle
  ///
  /// In en, this message translates to:
  /// **'Wall-tablet accounts locked to the live plan; members act through badges.'**
  String get featureKioskModeDesc;

  /// Feature toggle: the community tab (#224)
  ///
  /// In en, this message translates to:
  /// **'Members directory'**
  String get featureMembersDirectory;

  /// Subtitle of the directory feature toggle
  ///
  /// In en, this message translates to:
  /// **'The community tab: who is here, statuses, presence.'**
  String get featureMembersDirectoryDesc;

  /// Feature toggle: WhatsApp affordances riding the directory
  ///
  /// In en, this message translates to:
  /// **'WhatsApp integration'**
  String get featureWhatsappIntegration;

  /// Subtitle of the WhatsApp feature toggle
  ///
  /// In en, this message translates to:
  /// **'Members share their WhatsApp number on their profile; one tap on a member opens a chat with it; the community group link in the directory. No server-side WhatsApp integration.'**
  String get featureWhatsappIntegrationDesc;

  /// Feature toggle: printable per-space QR + scan-to-book (#335)
  ///
  /// In en, this message translates to:
  /// **'Space QR codes'**
  String get featureSpaceQrCodes;

  /// Subtitle of the space-QR feature toggle
  ///
  /// In en, this message translates to:
  /// **'Printable QR cards per seat, desk, office and level — scan to reserve or check in.'**
  String get featureSpaceQrCodesDesc;

  /// Hierarchy note under a child feature's switch
  ///
  /// In en, this message translates to:
  /// **'Requires {feature}'**
  String featureRequires(String feature);

  /// Feature toggle: co-ownership (0058)
  ///
  /// In en, this message translates to:
  /// **'Co-owners'**
  String get featureCoOwner;

  /// Subtitle of the co-owner feature toggle
  ///
  /// In en, this message translates to:
  /// **'Appoint co-owners: owner permissions now (active) or succession-in-waiting (passive).'**
  String get featureCoOwnerDesc;

  /// Feature toggle (#396): reservations never checked in or out complete themselves once their time has passed.
  ///
  /// In en, this message translates to:
  /// **'Auto check-in/out at day end'**
  String get featureAutoCheckInOut;

  /// Feature toggle (#395): the owner can download the workspace data as an Excel workbook.
  ///
  /// In en, this message translates to:
  /// **'Data export (Excel)'**
  String get featureDataExport;

  /// Description under the auto check-in/out feature toggle (#396).
  ///
  /// In en, this message translates to:
  /// **'Reservations never checked in or out complete themselves once their time has passed.'**
  String get featureAutoCheckInOutDesc;

  /// Description under the data-export feature toggle (#395).
  ///
  /// In en, this message translates to:
  /// **'Download all workspace data as an Excel workbook.'**
  String get featureDataExportDesc;

  /// No description provided for @featureWorkingHours.
  ///
  /// In en, this message translates to:
  /// **'Working hours'**
  String get featureWorkingHours;

  /// No description provided for @featureWorkingHoursDesc.
  ///
  /// In en, this message translates to:
  /// **'Configure the working day and offer exact-hours booking; off keeps the 8:00–17:00 defaults.'**
  String get featureWorkingHoursDesc;

  /// No description provided for @featureInvoicePdfTemplate.
  ///
  /// In en, this message translates to:
  /// **'Invoice PDF template'**
  String get featureInvoicePdfTemplate;

  /// No description provided for @featureInvoicePdfTemplateDesc.
  ///
  /// In en, this message translates to:
  /// **'Owner-written intro and footer text on the invoice PDF. Never touches the e-invoice XML.'**
  String get featureInvoicePdfTemplateDesc;

  /// No description provided for @featureMemberNotifications.
  ///
  /// In en, this message translates to:
  /// **'Member notifications'**
  String get featureMemberNotifications;

  /// No description provided for @featureMemberNotificationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Messaging between members: private and group conversations, read receipts, links to a reservation or a space; admins can notify all admins, owner included.'**
  String get featureMemberNotificationsDesc;

  /// Feature-registry completeness (#502)
  ///
  /// In en, this message translates to:
  /// **'Payment reminders (Mahnwesen)'**
  String get featureDunning;

  /// Feature-registry completeness (#502)
  ///
  /// In en, this message translates to:
  /// **'Configurable reminder levels and delays, a reminder letter per level, and “Reminder due” flags on late invoices. Sending stays a manual tap unless Automatic payment reminders is on.'**
  String get featureDunningDesc;

  /// Feature-registry completeness (#502)
  ///
  /// In en, this message translates to:
  /// **'Member reports'**
  String get featureMemberReports;

  /// Feature-registry completeness (#502)
  ///
  /// In en, this message translates to:
  /// **'The financial agreement and the monthly payments report — self-service for members, sendable per member.'**
  String get featureMemberReportsDesc;

  /// Feature-registry completeness (#502)
  ///
  /// In en, this message translates to:
  /// **'Booking deletion requests'**
  String get featureDeletionRequests;

  /// Feature-registry completeness (#502)
  ///
  /// In en, this message translates to:
  /// **'Members may REQUEST deletion of a past or checked-in booking; an owner/admin validates. Off, such bookings cannot be deleted at all.'**
  String get featureDeletionRequestsDesc;

  /// Feature-registry completeness (#587)
  ///
  /// In en, this message translates to:
  /// **'Delete spaces with history'**
  String get featurePlanObjectDeleteTitle;

  /// Feature-registry completeness (#587)
  ///
  /// In en, this message translates to:
  /// **'Owners may delete levels, offices, desks and seats even when past reservations reference them — the bookings keep a text snapshot for audits and reports.'**
  String get featurePlanObjectDeleteDesc;

  /// Feature-registry completeness (#598)
  ///
  /// In en, this message translates to:
  /// **'Notification feed grouping'**
  String get featureNotificationGroupingTitle;

  /// Feature-registry completeness (#598)
  ///
  /// In en, this message translates to:
  /// **'Members may fold the notification feed into groups by type, day or member; tapping the group symbol returns to the flat list.'**
  String get featureNotificationGroupingDesc;

  /// No description provided for @featureBookingPoliciesTitle.
  ///
  /// In en, this message translates to:
  /// **'Booking policies'**
  String get featureBookingPoliciesTitle;

  /// No description provided for @featureBookingPoliciesDesc.
  ///
  /// In en, this message translates to:
  /// **'Owner-configurable booking behavior: past bookings, minute bookings outside the working hours, and check-out by admins.'**
  String get featureBookingPoliciesDesc;

  /// No description provided for @featureNfcSeatTagsTitle.
  ///
  /// In en, this message translates to:
  /// **'NFC/RFID chair tags'**
  String get featureNfcSeatTagsTitle;

  /// No description provided for @featureNfcSeatTagsDesc.
  ///
  /// In en, this message translates to:
  /// **'A physical NFC/RFID tag on a chair resolves to its seat like the printed QR card; owners fill the tag field by tapping the chip.'**
  String get featureNfcSeatTagsDesc;

  /// No description provided for @featureQrBadgesTitle.
  ///
  /// In en, this message translates to:
  /// **'QR badges'**
  String get featureQrBadgesTitle;

  /// No description provided for @featureQrBadgesDesc.
  ///
  /// In en, this message translates to:
  /// **'Printable QR badge cards for the kiosk, beside the NFC/RFID cards.'**
  String get featureQrBadgesDesc;

  /// No description provided for @featureFormHelpHintsTitle.
  ///
  /// In en, this message translates to:
  /// **'Help hints'**
  String get featureFormHelpHintsTitle;

  /// No description provided for @featureFormHelpHintsDesc.
  ///
  /// In en, this message translates to:
  /// **'A dismissible tip carousel on every main screen, and a small ? beside every parameter and entry field — one tap opens the guide at the right section. Restorable from Settings.'**
  String get featureFormHelpHintsDesc;

  /// No description provided for @featureUiAnimationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Interface animations'**
  String get featureUiAnimationsTitle;

  /// No description provided for @featureUiAnimationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Smooth transitions and state animations across the app. Off means every change is instant; the device\'s reduced-motion setting always wins.'**
  String get featureUiAnimationsDesc;

  /// No description provided for @featureKioskMemberPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'Member photos at the kiosk'**
  String get featureKioskMemberPhotosTitle;

  /// No description provided for @featureKioskMemberPhotosDesc.
  ///
  /// In en, this message translates to:
  /// **'The kiosk receipt shows the member\'s profile photo — the visual wrong-badge check.'**
  String get featureKioskMemberPhotosDesc;

  /// No description provided for @featurePlanMemberPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'Member photos on the plan'**
  String get featurePlanMemberPhotosTitle;

  /// No description provided for @featurePlanMemberPhotosDesc.
  ///
  /// In en, this message translates to:
  /// **'Occupied seats on the Plan tab and Reserve hub show the occupant\'s profile photo instead of the initial.'**
  String get featurePlanMemberPhotosDesc;

  /// #662 - feature registry entry
  ///
  /// In en, this message translates to:
  /// **'Sign in with a badge'**
  String get featureBadgeSignInTitle;

  /// #662 - feature registry entry
  ///
  /// In en, this message translates to:
  /// **'Members can sign in by scanning their badge and entering their PIN, instead of typing an e-mail on a shared tablet. Each member sets their own PIN and arms their own badge.'**
  String get featureBadgeSignInDesc;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Region & formats'**
  String get featureRegionalFormatsTitle;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Members choose how numbers, dates, the clock and the time zone are shown to them. Off: everyone reads in the app language\'s home region, 24-hour, workspace time.'**
  String get featureRegionalFormatsDesc;

  /// #718/#719
  ///
  /// In en, this message translates to:
  /// **'Calendar hub'**
  String get featureCalendarHubTitle;

  /// #718/#719
  ///
  /// In en, this message translates to:
  /// **'The calendar shows everything dated — bookings, check-ins, alerts, messages, invoices, payments, consumption, reminders — for a day or a range, each row opening its source. Off: reservations only.'**
  String get featureCalendarHubDesc;

  /// #718/#719
  ///
  /// In en, this message translates to:
  /// **'Data access log'**
  String get featureDataAccessLogTitle;

  /// #718/#719
  ///
  /// In en, this message translates to:
  /// **'Members see who looked at their finances and when (written by the server, never skippable). Off hides the row; the log is still kept.'**
  String get featureDataAccessLogDesc;

  /// #718/#719
  ///
  /// In en, this message translates to:
  /// **'Export & erasure'**
  String get featureMemberDataExportTitle;

  /// #718/#719
  ///
  /// In en, this message translates to:
  /// **'Every member can export their data as one file (GDPR art. 20) and leave the workspace with their personal data cleared (art. 17) from Settings → Privacy & data.'**
  String get featureMemberDataExportDesc;

  /// No description provided for @featureFinanceFacesTitle.
  ///
  /// In en, this message translates to:
  /// **'Finances in four faces'**
  String get featureFinanceFacesTitle;

  /// No description provided for @featureFinanceFacesDesc.
  ///
  /// In en, this message translates to:
  /// **'The Finances tab reads as four faces — Statement, Payments, Invoices, Documents — under one month chooser, each with its own help. Off: a single column.'**
  String get featureFinanceFacesDesc;

  /// No description provided for @featurePaymentRemindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic payment reminders'**
  String get featurePaymentRemindersTitle;

  /// No description provided for @featurePaymentRemindersDesc.
  ///
  /// In en, this message translates to:
  /// **'Open invoices past the configured term get their reminder levels automatically — an alert in the member\'s feed and a push, once a day. Off: reminders stay a manual action.'**
  String get featurePaymentRemindersDesc;

  /// No description provided for @featureSupplyExpensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Supplies from expenses'**
  String get featureSupplyExpensesTitle;

  /// No description provided for @featureSupplyExpensesDesc.
  ///
  /// In en, this message translates to:
  /// **'An expense can be a supply for the space (coffee capsules, vacuum bags…): once validated it restocks or creates a consumable service with a unit price, and consumptions count the stock down.'**
  String get featureSupplyExpensesDesc;

  /// No description provided for @featureValidationScopesTitle.
  ///
  /// In en, this message translates to:
  /// **'Validators by role or person'**
  String get featureValidationScopesTitle;

  /// No description provided for @featureValidationScopesDesc.
  ///
  /// In en, this message translates to:
  /// **'Each validation rule names who validates: the admins, listed persons of any role, or every member — plus how many. Off: owner and admins as before.'**
  String get featureValidationScopesDesc;

  /// No description provided for @featurePriceNegotiationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Price negotiations'**
  String get featurePriceNegotiationsTitle;

  /// No description provided for @featurePriceNegotiationsDesc.
  ///
  /// In en, this message translates to:
  /// **'The tariff is the default; a member can hold their own conditions — monthly fee, overage rate, discount on supplements, unit prices per service and package, the occupation percentage — proposed by whoever holds Manage commercial agreements and validated by the rules. Seen by the member, the owners and the holders of View commercial agreements; every read is logged.'**
  String get featurePriceNegotiationsDesc;

  /// No description provided for @featureScheduledExpensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Scheduled expenses'**
  String get featureScheduledExpensesTitle;

  /// No description provided for @featureUniqueMonogramsTitle.
  ///
  /// In en, this message translates to:
  /// **'Distinct avatar initials'**
  String get featureUniqueMonogramsTitle;

  /// No description provided for @featureMessageGesturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Swipe to quote or take back'**
  String get featureMessageGesturesTitle;

  /// No description provided for @featureSubscriptionInvoicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription invoices'**
  String get featureSubscriptionInvoicesTitle;

  /// No description provided for @featureSubscriptionInvoicesDesc.
  ///
  /// In en, this message translates to:
  /// **'The membership fee is invoiced before the month it pays for, on a date you choose. Off: the fee stays on the whole-month invoice.'**
  String get featureSubscriptionInvoicesDesc;

  /// No description provided for @featureUsageInvoicesTitle.
  ///
  /// In en, this message translates to:
  /// **'End-of-month invoices'**
  String get featureUsageInvoicesTitle;

  /// No description provided for @featureUsageInvoicesDesc.
  ///
  /// In en, this message translates to:
  /// **'Once a month is over, what it actually cost beyond the subscription — overage, accessories, services — is invoiced separately. Off: those stay on the whole-month invoice.'**
  String get featureUsageInvoicesDesc;

  /// No description provided for @featureInvoiceSettlementTitle.
  ///
  /// In en, this message translates to:
  /// **'Regroup invoices'**
  String get featureInvoiceSettlementTitle;

  /// No description provided for @featureInvoiceSettlementDesc.
  ///
  /// In en, this message translates to:
  /// **'Several of a member\'s open invoices can be regrouped into one they pay. The originals stay in the archive, traceable position by position, and stop being chased separately.'**
  String get featureInvoiceSettlementDesc;

  /// Snack naming the dependencies switched on with a feature (#800)
  ///
  /// In en, this message translates to:
  /// **'Also switched on: {features}'**
  String featureAlsoEnabled(String features);

  /// Subtitle note: what this switch would also enable (#800)
  ///
  /// In en, this message translates to:
  /// **'Switching this on also enables {features}'**
  String featureAlsoEnables(String features);

  /// Subtitle note: the feature is on but its parent is off (#800)
  ///
  /// In en, this message translates to:
  /// **'Waiting on the feature above — switch that on and this one works again.'**
  String get featureHeldBack;

  /// No description provided for @featureMessageGesturesDesc.
  ///
  /// In en, this message translates to:
  /// **'Swipe a message right to quote it in your reply; swipe left to take your own message back while nobody has read it yet, after a confirmation. Off: messages are deleted by holding them.'**
  String get featureMessageGesturesDesc;

  /// No description provided for @featureUniqueMonogramsDesc.
  ///
  /// In en, this message translates to:
  /// **'An avatar without a photo shows initials that belong to one member: first and family initial, a further letter when two members would clash, numbers only as a last resort. Off: the first letter alone, repeated across everyone who shares it.'**
  String get featureUniqueMonogramsDesc;

  /// No description provided for @featureScheduledExpensesDesc.
  ///
  /// In en, this message translates to:
  /// **'Recurring expenses (internet, phone, electricity): any member schedules one with its rule (every X days/weeks/months/years, X times or until a date); the schedule is validated once, and every due date is presented to the member — the validated amount counts immediately, a different amount explains itself and passes the expense validation.'**
  String get featureScheduledExpensesDesc;

  /// No description provided for @featureInvoiceJourneyTitle.
  ///
  /// In en, this message translates to:
  /// **'The journey of an invoice'**
  String get featureInvoiceJourneyTitle;

  /// No description provided for @featureInvoiceJourneyDesc.
  ///
  /// In en, this message translates to:
  /// **'Every invoice shows where it stands — Issued, Payment, Confirmation, Closed — and whose move it is: the member pays, an admin confirms the declared payment, the issuer matches it, the validators decide. The issuers\' hub adds a stage strip with live counts and a How-it-works explainer.'**
  String get featureInvoiceJourneyDesc;

  /// No description provided for @featureBookingGateTitle.
  ///
  /// In en, this message translates to:
  /// **'Booking gate'**
  String get featureBookingGateTitle;

  /// No description provided for @featureBookingGateDesc.
  ///
  /// In en, this message translates to:
  /// **'Every booking surface — plan, day, week and month views, the booking sheet, the kiosk, a QR or NFC scan — checks the availability parameters before offering a window and names the reason when it cannot; closed days draw as closed in every view, a legend names the seat states, and admins may check members out where the policy allows.'**
  String get featureBookingGateDesc;

  /// No description provided for @featureCalendarViewsTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar views'**
  String get featureCalendarViewsTitle;

  /// No description provided for @featureCalendarViewsDesc.
  ///
  /// In en, this message translates to:
  /// **'The Calendar tab as agenda, week and month: per-day markers by kind, closed days drawn as closed, Today / Tomorrow headers, payment due dates and scheduled expenses in the feed. Off: the plain day-or-range selector over the feed.'**
  String get featureCalendarViewsDesc;

  /// No description provided for @featureMessagesHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages, reworked'**
  String get featureMessagesHubTitle;

  /// No description provided for @featureMessagesHubDesc.
  ///
  /// In en, this message translates to:
  /// **'One inbox bar (All / Unread / Archived and search), pin, mute, archive and mark-unread on a thread, the conversation as a full page with date separators, an attach menu and a kept draft in the composer, a person opened with one tap. Off: the two-bar inbox and the sheet thread.'**
  String get featureMessagesHubDesc;

  /// No description provided for @featureReportDesignerTitle.
  ///
  /// In en, this message translates to:
  /// **'Report designer'**
  String get featureReportDesignerTitle;

  /// No description provided for @featureReportDesignerDesc.
  ///
  /// In en, this message translates to:
  /// **'The report editor as a full-screen designer: elements edited in place in their real typography, drag to reorder, an insert palette, a searchable field picker, undo and redo, image size and alignment, a discard guard, presets and reset behind a confirmation, the template error spelled out, design and preview side by side on a wide screen. Off: the editor sheet.'**
  String get featureReportDesignerDesc;

  /// No description provided for @featureMemberPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Member page'**
  String get featureMemberPageTitle;

  /// No description provided for @featureMemberPageDesc.
  ///
  /// In en, this message translates to:
  /// **'One page per member: photo and presence, when they were last seen, what they have booked and what comes next, quick actions to message, WhatsApp or e-mail them, contact and money cards, and for admins every setting grouped by topic with its current value. Off: the profile sheet and the Members & plans action sheet.'**
  String get featureMemberPageDesc;

  /// No description provided for @featureInvoicingWizardTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoicing wizard'**
  String get featureInvoicingWizardTitle;

  /// No description provided for @featureInvoicingWizardDesc.
  ///
  /// In en, this message translates to:
  /// **'One guided month-close process for the finance person: a start-of-month run for the subscriptions paid ahead and an end-of-month run for usage and extra charges — review, issue in one batch, send, remind what is due, register and validate payments, match them to invoices, regroup, write off or refund, and a summary with whose move is left. Off: the separate screens.'**
  String get featureInvoicingWizardDesc;

  /// No description provided for @featureExpenseRepartitionTitle.
  ///
  /// In en, this message translates to:
  /// **'Shared expenses'**
  String get featureExpenseRepartitionTitle;

  /// No description provided for @featureExpenseRepartitionDesc.
  ///
  /// In en, this message translates to:
  /// **'A shared expense (a cleaning bill, an internet upgrade, a broken chair) split over the members — equal shares, pro rata of the subscription, pro rata of usage, or a key per member — with every share previewed before it is booked. The shares land as charge lines on the next usage invoice; a reversal books credit notes. Through the validation rules. Off: no distribution.'**
  String get featureExpenseRepartitionDesc;

  /// No description provided for @featureSettlementFoldTitle.
  ///
  /// In en, this message translates to:
  /// **'Regrouped invoices fold'**
  String get featureSettlementFoldTitle;

  /// No description provided for @featureSettlementFoldDesc.
  ///
  /// In en, this message translates to:
  /// **'Invoices regrouped into one disappear from the lists as peers and nest under the regrouping invoice, which carries all their lines. On a regrouped invoice every operation is off; the one thing left is its PDF, stamped with the number it was regrouped in. Off: the regrouped invoices stay listed beside the regrouping one.'**
  String get featureSettlementFoldDesc;

  /// #840 - feature title
  ///
  /// In en, this message translates to:
  /// **'Chained validations'**
  String get featureValidationChainTitle;

  /// #840 - feature description
  ///
  /// In en, this message translates to:
  /// **'A validation rule can ask for its validations one after another, each step requested once the previous passed, and can let the owner — never an admin — validate their own act. Off: every validation is asked at once and nobody validates their own event.'**
  String get featureValidationChainDesc;

  /// #842 - feature title
  ///
  /// In en, this message translates to:
  /// **'References in messages'**
  String get featureRichMessageRefsTitle;

  /// #842 - feature description
  ///
  /// In en, this message translates to:
  /// **'A message can point at an alert, at the validation trail behind one, and at an invoice, a payment or a refund — each one a link that opens what it names. Every reference picker filters as you type. Off: only reservations and spaces can be referenced.'**
  String get featureRichMessageRefsDesc;

  /// #843 - feature title
  ///
  /// In en, this message translates to:
  /// **'Validations on the calendar'**
  String get featureCalendarValidationsTitle;

  /// #843 - feature description
  ///
  /// In en, this message translates to:
  /// **'Every decision taken on an event appears on the calendar at the moment it was taken, not at the moment of the event: who validated or refused what, and when. Tapping one opens its trail. Off: the calendar carries no decisions.'**
  String get featureCalendarValidationsDesc;

  /// #833 - feature title
  ///
  /// In en, this message translates to:
  /// **'Usage records'**
  String get featureUsageRecordsTitle;

  /// #833 - feature description
  ///
  /// In en, this message translates to:
  /// **'Every counted booking leaves a record: the window booked, the time actually present, and what of it bills. A booking nobody checked into bills in full. A member who left early can ask for the unused time to stop billing, and somebody else decides it — never them. Off: no records and no correction.'**
  String get featureUsageRecordsDesc;

  /// #864 - feature title
  ///
  /// In en, this message translates to:
  /// **'Export and import report designs'**
  String get featureReportDesignExchangeTitle;

  /// #864 - feature description
  ///
  /// In en, this message translates to:
  /// **'Every report design can be written out as one self-describing file and read back in. The file carries the design plus what its fields mean, the markup it accepts and the placeholders that exist, so a person or a tool can edit it outside the app and hand it back. A file for another report, or from a newer version, is refused with the reason. Off: designs are only editable in the designer.'**
  String get featureReportDesignExchangeDesc;

  /// No description provided for @helpTitle.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get helpTitle;

  /// No description provided for @helpContents.
  ///
  /// In en, this message translates to:
  /// **'Contents'**
  String get helpContents;

  /// #695 - messaging help hints
  ///
  /// In en, this message translates to:
  /// **'Every conversation in one list, newest first. Tap the pencil to write to someone or start a group.'**
  String get helpHintMessages;

  /// #695 - messaging help hints
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get helpHintMessagesTopic;

  /// #695 - messaging help hints
  ///
  /// In en, this message translates to:
  /// **'Pick one person for a private chat, or several to make a group — the name field appears once there are two, and a group name is unique here, so nobody has to guess which “Team” they mean.'**
  String get helpHintMessagesTip2;

  /// #695 - messaging help hints
  ///
  /// In en, this message translates to:
  /// **'Tap a name at the top of a chat to see their profile: today’s booking, whether they are checked in, and how to reach them.'**
  String get helpHintMessagesTip3;

  /// #695 - messaging help hints
  ///
  /// In en, this message translates to:
  /// **'Search finds people, groups and the words inside messages — a result takes you straight there.'**
  String get helpHintMessagesTip4;

  /// #695 - messaging help hints
  ///
  /// In en, this message translates to:
  /// **'Link a reservation or a space in a message instead of describing it; the reader taps it and lands on the right one.'**
  String get helpHintMessagesTip5;

  /// No description provided for @helpHintLearnMore.
  ///
  /// In en, this message translates to:
  /// **'Learn more'**
  String get helpHintLearnMore;

  /// No description provided for @helpHintDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss hint'**
  String get helpHintDismiss;

  /// No description provided for @helpHintPrevTip.
  ///
  /// In en, this message translates to:
  /// **'Previous tip'**
  String get helpHintPrevTip;

  /// No description provided for @helpHintNextTip.
  ///
  /// In en, this message translates to:
  /// **'Next tip'**
  String get helpHintNextTip;

  /// No description provided for @helpHintRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Show help hints again'**
  String get helpHintRestoreTitle;

  /// No description provided for @helpHintRestored.
  ///
  /// In en, this message translates to:
  /// **'Help hints will be shown again.'**
  String get helpHintRestored;

  /// No description provided for @helpHintReserve.
  ///
  /// In en, this message translates to:
  /// **'Pick a day and time window, then tap a free seat to book it.'**
  String get helpHintReserve;

  /// No description provided for @helpHintReserveTopic.
  ///
  /// In en, this message translates to:
  /// **'Reserve hub'**
  String get helpHintReserveTopic;

  /// No description provided for @helpHintReserveTip2.
  ///
  /// In en, this message translates to:
  /// **'The Week and Month views find a free half-day at a glance — tap a free cell or day to book right there.'**
  String get helpHintReserveTip2;

  /// No description provided for @helpHintReserveTip3.
  ///
  /// In en, this message translates to:
  /// **'Tap the scan button and point the camera at a space\'s QR card — the sheet shows exactly what you may do there.'**
  String get helpHintReserveTip3;

  /// No description provided for @helpHintReserveTip3Topic.
  ///
  /// In en, this message translates to:
  /// **'Scan a space code'**
  String get helpHintReserveTip3Topic;

  /// No description provided for @helpHintReserveTip4.
  ///
  /// In en, this message translates to:
  /// **'The morning, afternoon and full-day chips pick your window before you choose a seat — a booked morning counts as half a day.'**
  String get helpHintReserveTip4;

  /// No description provided for @helpHintReserveTip4Topic.
  ///
  /// In en, this message translates to:
  /// **'How booking behaves'**
  String get helpHintReserveTip4Topic;

  /// No description provided for @helpHintReserveTip5.
  ///
  /// In en, this message translates to:
  /// **'Set your default booking period in Settings — the hub preselects it on every visit.'**
  String get helpHintReserveTip5;

  /// No description provided for @helpHintReserveTip5Topic.
  ///
  /// In en, this message translates to:
  /// **'Settings & profile'**
  String get helpHintReserveTip5Topic;

  /// No description provided for @helpHintPlan.
  ///
  /// In en, this message translates to:
  /// **'The live floor plan: tap a free seat to book it, tap your own booking to check in.'**
  String get helpHintPlan;

  /// No description provided for @helpHintPlanTopic.
  ///
  /// In en, this message translates to:
  /// **'floor plan'**
  String get helpHintPlanTopic;

  /// No description provided for @helpHintPlanTip2.
  ///
  /// In en, this message translates to:
  /// **'Standing at a free seat? Tap it — the sheet suggests now until closing, and confirming checks you in on the spot.'**
  String get helpHintPlanTip2;

  /// No description provided for @helpHintPlanTip3.
  ///
  /// In en, this message translates to:
  /// **'Browse another moment with the date chip and the time scroller — the plan shows who sits where at any future time.'**
  String get helpHintPlanTip3;

  /// No description provided for @helpHintPlanTip4.
  ///
  /// In en, this message translates to:
  /// **'Double-tap a desk, a room or the floor itself — or tap the layers icon on the level rail — to reserve the whole space at once.'**
  String get helpHintPlanTip4;

  /// No description provided for @helpHintPlanTip5.
  ///
  /// In en, this message translates to:
  /// **'Tap your own seat for its sheet: check in from 15 minutes before your start, check out when you leave.'**
  String get helpHintPlanTip5;

  /// No description provided for @helpHintPlanTip5Topic.
  ///
  /// In en, this message translates to:
  /// **'How booking behaves'**
  String get helpHintPlanTip5Topic;

  /// #718/#719 - help hints
  ///
  /// In en, this message translates to:
  /// **'Pick a day or a range: everything dated that you may see, in one list, each row opening its source.'**
  String get helpHintCalendar;

  /// No description provided for @helpHintCalendarTopic.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get helpHintCalendarTopic;

  /// #718/#719 - help hints
  ///
  /// In en, this message translates to:
  /// **'Switch Day to Range to see a whole week or month at once — the arrows step by the size of your selection.'**
  String get helpHintCalendarTip2;

  /// #718/#719 - help hints
  ///
  /// In en, this message translates to:
  /// **'Tap a kind chip to see only that: bookings, alerts, messages, invoices, payments, consumption, reminders.'**
  String get helpHintCalendarTip3;

  /// #718/#719 - help hints
  ///
  /// In en, this message translates to:
  /// **'Every row opens its source — the booking, the conversation, the alert, the invoice, or that month on Finances.'**
  String get helpHintCalendarTip4;

  /// No description provided for @helpHintCalendarTip4Topic.
  ///
  /// In en, this message translates to:
  /// **'How booking behaves'**
  String get helpHintCalendarTip4Topic;

  /// No description provided for @helpHintEvents.
  ///
  /// In en, this message translates to:
  /// **'Everything that happened, in one feed. Decisions waiting for you sit on top; the chips filter the rest.'**
  String get helpHintEvents;

  /// No description provided for @helpHintEventsTopic.
  ///
  /// In en, this message translates to:
  /// **'confirmations'**
  String get helpHintEventsTopic;

  /// No description provided for @helpHintEventsTip2.
  ///
  /// In en, this message translates to:
  /// **'The filter chips remember your choice across visits — and the Unread chip narrows the list to unread messages.'**
  String get helpHintEventsTip2;

  /// No description provided for @helpHintEventsTip3.
  ///
  /// In en, this message translates to:
  /// **'Group the feed by type, day or member from the Group by menu; tap the group symbol to return to the flat list.'**
  String get helpHintEventsTip3;

  /// No description provided for @helpHintEventsTip4.
  ///
  /// In en, this message translates to:
  /// **'Pending decisions sit pinned on top with Accept and reject — and nobody ever validates their own event.'**
  String get helpHintEventsTip4;

  /// No description provided for @helpHintEditor.
  ///
  /// In en, this message translates to:
  /// **'Draw rooms and desks, stamp seats onto them — tap a seat twice to edit its properties.'**
  String get helpHintEditor;

  /// No description provided for @helpHintEditorTopic.
  ///
  /// In en, this message translates to:
  /// **'space editor'**
  String get helpHintEditorTopic;

  /// No description provided for @helpHintEditorTip2.
  ///
  /// In en, this message translates to:
  /// **'Pick Office or Table in the toolbar and drag on the grid to draw it; Select moves and resizes what is already there.'**
  String get helpHintEditorTip2;

  /// No description provided for @helpHintEditorTip3.
  ///
  /// In en, this message translates to:
  /// **'The Seat tool stamps seats onto desks; a seat\'s sheet sets its direction, chair type, accessories and a maintenance block.'**
  String get helpHintEditorTip3;

  /// No description provided for @helpHintEditorTip4.
  ///
  /// In en, this message translates to:
  /// **'Give a seat its NFC/RFID tag from the seat sheet — tap the chip on the phone and the field fills itself.'**
  String get helpHintEditorTip4;

  /// No description provided for @helpHintEditorTip5.
  ///
  /// In en, this message translates to:
  /// **'Print a QR card for every seat, desk, office and level — pick the card size and what each card shows before exporting.'**
  String get helpHintEditorTip5;

  /// No description provided for @helpHintEditorTip5Topic.
  ///
  /// In en, this message translates to:
  /// **'Space QR codes'**
  String get helpHintEditorTip5Topic;

  /// No description provided for @helpHintAvailability.
  ///
  /// In en, this message translates to:
  /// **'Set the open weekdays and working hours, and add closure days nobody can book.'**
  String get helpHintAvailability;

  /// No description provided for @helpHintAvailabilityTopic.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get helpHintAvailabilityTopic;

  /// No description provided for @helpHintAvailabilityTip2.
  ///
  /// In en, this message translates to:
  /// **'The booking granularity decides what a window may look like: half-days, full days, minute grids or free times.'**
  String get helpHintAvailabilityTip2;

  /// No description provided for @helpHintAvailabilityTip3.
  ///
  /// In en, this message translates to:
  /// **'Day start, half-day boundary and day end drive every half-day and full-day slot — booking, check-in and billing follow them.'**
  String get helpHintAvailabilityTip3;

  /// No description provided for @helpHintAvailabilityTip4.
  ///
  /// In en, this message translates to:
  /// **'Three booking policies tighten or relax the rules: past bookings, minute bookings kept within working hours, and admin check-out.'**
  String get helpHintAvailabilityTip4;

  /// No description provided for @helpHintFeatures.
  ///
  /// In en, this message translates to:
  /// **'Switch workspace functionality on or off — every member\'s app follows immediately.'**
  String get helpHintFeatures;

  /// No description provided for @helpHintFeaturesTopic.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get helpHintFeaturesTopic;

  /// No description provided for @helpHintFeaturesTip2.
  ///
  /// In en, this message translates to:
  /// **'The list is hierarchical — a feature that needs another sits indented under it and greys out while its parent is off.'**
  String get helpHintFeaturesTip2;

  /// No description provided for @helpHintFeaturesTip3.
  ///
  /// In en, this message translates to:
  /// **'Switching a parent off takes its whole subtree out of the app; the children\'s stored choices return untouched with the parent.'**
  String get helpHintFeaturesTip3;

  /// No description provided for @helpHintFeaturesTip4.
  ///
  /// In en, this message translates to:
  /// **'A feature\'s settings entry only appears while the feature is on — the Features screen itself always stays reachable.'**
  String get helpHintFeaturesTip4;

  /// No description provided for @helpHintMembers.
  ///
  /// In en, this message translates to:
  /// **'Invite members, set their plan percentage and role, and manage their badges.'**
  String get helpHintMembers;

  /// No description provided for @helpHintMembersTopic.
  ///
  /// In en, this message translates to:
  /// **'Members & plans'**
  String get helpHintMembersTopic;

  /// No description provided for @helpHintMembersTip2.
  ///
  /// In en, this message translates to:
  /// **'Tap a member for their management sheet — subscription, reservation limit, badges, services and more in one place.'**
  String get helpHintMembersTip2;

  /// No description provided for @helpHintMembersTip3.
  ///
  /// In en, this message translates to:
  /// **'Badges live per member: mint a printable QR badge, or register their NFC card by holding it to the device.'**
  String get helpHintMembersTip3;

  /// No description provided for @helpHintMembersTip3Topic.
  ///
  /// In en, this message translates to:
  /// **'NFC badges'**
  String get helpHintMembersTip3Topic;

  /// No description provided for @helpHintMembersTip4.
  ///
  /// In en, this message translates to:
  /// **'Name admin grants admin rights after validation; the role matrix under Role management decides what every role may do.'**
  String get helpHintMembersTip4;

  /// No description provided for @helpHintMembersTip4Topic.
  ///
  /// In en, this message translates to:
  /// **'Role management'**
  String get helpHintMembersTip4Topic;

  /// No description provided for @helpHintMoney.
  ///
  /// In en, this message translates to:
  /// **'Your monthly bill: browse months with the arrows; pay, export or share from here.'**
  String get helpHintMoney;

  /// No description provided for @helpHintMoneyTopic.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get helpHintMoneyTopic;

  /// No description provided for @helpHintMoneyTip2.
  ///
  /// In en, this message translates to:
  /// **'Every document offers the same three actions: quick view on screen, download as PDF, and share to any app.'**
  String get helpHintMoneyTip2;

  /// No description provided for @helpHintMoneyTip2Topic.
  ///
  /// In en, this message translates to:
  /// **'Quick view, save, share'**
  String get helpHintMoneyTip2Topic;

  /// No description provided for @helpHintMoneyTip3.
  ///
  /// In en, this message translates to:
  /// **'Record a payment with the date the money moved and the month it settles — the other side confirms it.'**
  String get helpHintMoneyTip3;

  /// No description provided for @helpHintMoneyTip4.
  ///
  /// In en, this message translates to:
  /// **'Once the month is invoiced, the invoice decides: the month reads settled as soon as its invoice is paid.'**
  String get helpHintMoneyTip4;

  /// No description provided for @helpHintMoneyTip4Topic.
  ///
  /// In en, this message translates to:
  /// **'the invoice decides'**
  String get helpHintMoneyTip4Topic;

  /// No description provided for @helpHintValidation.
  ///
  /// In en, this message translates to:
  /// **'Decide which actions need confirmation, who confirms, and how many approvals it takes.'**
  String get helpHintValidation;

  /// No description provided for @helpHintValidationTopic.
  ///
  /// In en, this message translates to:
  /// **'confirmations'**
  String get helpHintValidationTopic;

  /// No description provided for @helpHintValidationTip2.
  ///
  /// In en, this message translates to:
  /// **'One card per event type, each inheriting from the default rule until you edit it — payments, expenses, role changes and more.'**
  String get helpHintValidationTip2;

  /// No description provided for @helpHintValidationTip3.
  ///
  /// In en, this message translates to:
  /// **'Nobody ever validates their own event, and unanswered requests expire after 7 days — nothing is granted silently.'**
  String get helpHintValidationTip3;

  /// No description provided for @helpHintWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Country, currency, language and billing details — documents and taxes follow these settings.'**
  String get helpHintWorkspace;

  /// No description provided for @helpHintWorkspaceTopic.
  ///
  /// In en, this message translates to:
  /// **'Workspace settings'**
  String get helpHintWorkspaceTopic;

  /// No description provided for @helpHintWorkspaceTip2.
  ///
  /// In en, this message translates to:
  /// **'Print the space QR cards from Exports — choose the card size and the info each card carries, ten per A4 page.'**
  String get helpHintWorkspaceTip2;

  /// No description provided for @helpHintWorkspaceTip2Topic.
  ///
  /// In en, this message translates to:
  /// **'Space QR codes'**
  String get helpHintWorkspaceTip2Topic;

  /// No description provided for @helpHintWorkspaceTip3.
  ///
  /// In en, this message translates to:
  /// **'Export the space as XML to back it up or template a new one; the setup questionnaire prefills a fresh workspace end to end.'**
  String get helpHintWorkspaceTip3;

  /// No description provided for @helpHintWorkspaceTip4.
  ///
  /// In en, this message translates to:
  /// **'Reset the workspace wipes reservations, accounting and the floor plan — settings and members survive, and a typed confirmation guards it.'**
  String get helpHintWorkspaceTip4;

  /// No description provided for @helpHintBadges.
  ///
  /// In en, this message translates to:
  /// **'Issue a printable QR badge or register an NFC card; revoke lost badges any time.'**
  String get helpHintBadges;

  /// No description provided for @helpHintBadgesTopic.
  ///
  /// In en, this message translates to:
  /// **'NFC badges'**
  String get helpHintBadgesTopic;

  /// No description provided for @helpHintBadgesTip2.
  ///
  /// In en, this message translates to:
  /// **'Register a card by holding it to the device — any readable chip works, and the dialog names the workspace it joins.'**
  String get helpHintBadgesTip2;

  /// No description provided for @helpHintBadgesTip3.
  ///
  /// In en, this message translates to:
  /// **'Save a QR badge as PDF to print ten credit-card copies on one A4 page — spares included.'**
  String get helpHintBadgesTip3;

  /// No description provided for @helpHintBadgesTip4.
  ///
  /// In en, this message translates to:
  /// **'Revoke a lost badge any time; swipe a revoked badge to the right to delete it for good.'**
  String get helpHintBadgesTip4;

  /// #718/#719 - help hints
  ///
  /// In en, this message translates to:
  /// **'The shield shows who can see each kind, and who actually looked at your finances.'**
  String get helpHintCalendarTip5;

  /// #718/#719 - help hints
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get helpHintCalendarTip5Topic;

  /// #718/#719 - help hints
  ///
  /// In en, this message translates to:
  /// **'See who can read your data and who did, export everything as one file, or leave with your personal data erased.'**
  String get helpHintPrivacy;

  /// #718/#719 - help hints
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get helpHintPrivacyTopic;

  /// #718/#719 - help hints
  ///
  /// In en, this message translates to:
  /// **'Messages are readable only by the people in the conversation, whatever their role; money only by you and the finance permission.'**
  String get helpHintPrivacyTip2;

  /// #718/#719 - help hints
  ///
  /// In en, this message translates to:
  /// **'Every read of your finances by someone else is logged by the server — the log cannot be skipped or edited.'**
  String get helpHintPrivacyTip3;

  /// No description provided for @helpHintMoneyPayments.
  ///
  /// In en, this message translates to:
  /// **'Settle and ask: the balance, how to pay it or pay online, record a payment — and submit an expense, request half-days or add a consumption.'**
  String get helpHintMoneyPayments;

  /// No description provided for @helpHintMoneyPaymentsTopic.
  ///
  /// In en, this message translates to:
  /// **'The Payments face'**
  String get helpHintMoneyPaymentsTopic;

  /// No description provided for @helpHintMoneyPaymentsTip2.
  ///
  /// In en, this message translates to:
  /// **'Record a payment with the date the money moved and the month it settles — the other side confirms it.'**
  String get helpHintMoneyPaymentsTip2;

  /// No description provided for @helpHintMoneyPaymentsTip3.
  ///
  /// In en, this message translates to:
  /// **'Pay online settles what is owed right away; the instructions card shows the manual way with the reference to quote.'**
  String get helpHintMoneyPaymentsTip3;

  /// No description provided for @helpHintMoneyPaymentsTip3Topic.
  ///
  /// In en, this message translates to:
  /// **'online payments'**
  String get helpHintMoneyPaymentsTip3Topic;

  /// No description provided for @helpHintMoneyStatement.
  ///
  /// In en, this message translates to:
  /// **'The month as it stands: your account, days used and left, subscription, services, packages, open positions, credits and the balance. Browse months with the arrows.'**
  String get helpHintMoneyStatement;

  /// No description provided for @helpHintMoneyStatementTopic.
  ///
  /// In en, this message translates to:
  /// **'The Statement face'**
  String get helpHintMoneyStatementTopic;

  /// No description provided for @helpHintMoneyStatementTip2.
  ///
  /// In en, this message translates to:
  /// **'A booked morning counts as half a day; days outside the opening hours follow the workspace\'s outside-hours policy.'**
  String get helpHintMoneyStatementTip2;

  /// No description provided for @helpHintMoneyStatementTip2Topic.
  ///
  /// In en, this message translates to:
  /// **'How booking behaves'**
  String get helpHintMoneyStatementTip2Topic;

  /// No description provided for @helpHintMoneyStatementTip3.
  ///
  /// In en, this message translates to:
  /// **'Out of days? Request extra half-days, buy a package, or keep booking pay-as-you-go — whichever your plan allows.'**
  String get helpHintMoneyStatementTip3;

  /// No description provided for @helpHintMoneyInvoices.
  ///
  /// In en, this message translates to:
  /// **'Your invoices: what is open and when it is due, every invoice issued to you with its status, one tap to the detail and to paying it.'**
  String get helpHintMoneyInvoices;

  /// No description provided for @helpHintMoneyInvoicesTopic.
  ///
  /// In en, this message translates to:
  /// **'The Invoices face'**
  String get helpHintMoneyInvoicesTopic;

  /// No description provided for @helpHintMoneyInvoicesTip2.
  ///
  /// In en, this message translates to:
  /// **'Past the workspace\'s payment term an open invoice reads overdue here, and the reminder levels the owner configured arrive by themselves — in your feed and as a push.'**
  String get helpHintMoneyInvoicesTip2;

  /// No description provided for @helpHintMoneyInvoicesTip2Topic.
  ///
  /// In en, this message translates to:
  /// **'Automatic payment reminders'**
  String get helpHintMoneyInvoicesTip2Topic;

  /// No description provided for @helpHintMoneyDocuments.
  ///
  /// In en, this message translates to:
  /// **'Your paperwork: your conditions, the payments report, the month\'s statement as PDF, the document library.'**
  String get helpHintMoneyDocuments;

  /// No description provided for @helpHintMoneyDocumentsTopic.
  ///
  /// In en, this message translates to:
  /// **'The Documents face'**
  String get helpHintMoneyDocumentsTopic;

  /// No description provided for @helpHintMoneyDocumentsTip3.
  ///
  /// In en, this message translates to:
  /// **'My conditions is your standing financial agreement — plan, rate, extras — rendered as a document you can keep.'**
  String get helpHintMoneyDocumentsTip3;

  /// No description provided for @helpHintValidationTipScopes.
  ///
  /// In en, this message translates to:
  /// **'Who validates is the rule\'s scope: the admins, listed persons of any role, or every member — and how many. The owner always may; nobody validates their own event.'**
  String get helpHintValidationTipScopes;

  /// No description provided for @helpHintValidationTipScopesTopic.
  ///
  /// In en, this message translates to:
  /// **'Role management'**
  String get helpHintValidationTipScopesTopic;

  /// No description provided for @helpHintMoneyPaymentsTipSupply.
  ///
  /// In en, this message translates to:
  /// **'Bought capsules or vacuum bags for the space? Submit the expense as a supply: validated, it goes on the shelf as a consumable that others pay for, and you are reimbursed.'**
  String get helpHintMoneyPaymentsTipSupply;

  /// No description provided for @helpHintMoneyPaymentsTipSupplyTopic.
  ///
  /// In en, this message translates to:
  /// **'Services and Accessories'**
  String get helpHintMoneyPaymentsTipSupplyTopic;

  /// No description provided for @helpHintMoneyStatementTipNegotiation.
  ///
  /// In en, this message translates to:
  /// **'Negotiated a deal? The card shows your prices beside the tariff, since when, and who can see them — the owners and finance admins, every read on the record.'**
  String get helpHintMoneyStatementTipNegotiation;

  /// No description provided for @helpHintMoneyStatementTipNegotiationTopic.
  ///
  /// In en, this message translates to:
  /// **'Price negotiations'**
  String get helpHintMoneyStatementTipNegotiationTopic;

  /// No description provided for @helpHintMembersTipNegotiation.
  ///
  /// In en, this message translates to:
  /// **'A member\'s own prices: open their sheet → Price negotiation, set the fee, overage or discount you agreed, and the rule\'s validators confirm it.'**
  String get helpHintMembersTipNegotiation;

  /// No description provided for @helpHintMembersTipNegotiationTopic.
  ///
  /// In en, this message translates to:
  /// **'Price negotiations'**
  String get helpHintMembersTipNegotiationTopic;

  /// No description provided for @helpDotTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open the guide'**
  String get helpDotTooltip;

  /// No description provided for @helpTopicLegalIdentity.
  ///
  /// In en, this message translates to:
  /// **'Legal identity'**
  String get helpTopicLegalIdentity;

  /// No description provided for @helpTopicEinvoice.
  ///
  /// In en, this message translates to:
  /// **'e-invoice'**
  String get helpTopicEinvoice;

  /// No description provided for @helpTopicReportEditor.
  ///
  /// In en, this message translates to:
  /// **'report editor'**
  String get helpTopicReportEditor;

  /// No description provided for @helpTopicDocumentLibrary.
  ///
  /// In en, this message translates to:
  /// **'document library'**
  String get helpTopicDocumentLibrary;

  /// No description provided for @helpTopicWorkspaceId.
  ///
  /// In en, this message translates to:
  /// **'Workspace ID'**
  String get helpTopicWorkspaceId;

  /// No description provided for @helpTopicVat.
  ///
  /// In en, this message translates to:
  /// **'VAT'**
  String get helpTopicVat;

  /// No description provided for @helpTopicSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings & profile'**
  String get helpTopicSettings;

  /// No description provided for @helpTopicKiosk.
  ///
  /// In en, this message translates to:
  /// **'Kiosk mode'**
  String get helpTopicKiosk;

  /// No description provided for @helpTopicBilling.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get helpTopicBilling;

  /// No description provided for @helpTopicWorkingHours.
  ///
  /// In en, this message translates to:
  /// **'Working hours'**
  String get helpTopicWorkingHours;

  /// No description provided for @helpTopicBookingPolicies.
  ///
  /// In en, this message translates to:
  /// **'Booking policies'**
  String get helpTopicBookingPolicies;

  /// No description provided for @helpTopicBookingLimits.
  ///
  /// In en, this message translates to:
  /// **'Booking limits'**
  String get helpTopicBookingLimits;

  /// No description provided for @helpTopicScheduledExpenses.
  ///
  /// In en, this message translates to:
  /// **'Scheduled expenses'**
  String get helpTopicScheduledExpenses;

  /// No description provided for @helpTopicServer.
  ///
  /// In en, this message translates to:
  /// **'your own server'**
  String get helpTopicServer;

  /// No description provided for @inviteSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite someone'**
  String get inviteSectionTitle;

  /// No description provided for @inviteViaWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get inviteViaWhatsapp;

  /// No description provided for @inviteViaSms.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get inviteViaSms;

  /// No description provided for @inviteViaShare.
  ///
  /// In en, this message translates to:
  /// **'Share…'**
  String get inviteViaShare;

  /// No description provided for @inviteFirstNameLabel.
  ///
  /// In en, this message translates to:
  /// **'First name (optional)'**
  String get inviteFirstNameLabel;

  /// No description provided for @inviteLastNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Last name (optional)'**
  String get inviteLastNameLabel;

  /// No description provided for @invitePhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional, with country code)'**
  String get invitePhoneLabel;

  /// No description provided for @inviteLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Message language'**
  String get inviteLanguageLabel;

  /// No description provided for @inviteSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the app for sending. The message was copied instead.'**
  String get inviteSendFailed;

  /// No description provided for @inviteCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the invitation. Check your connection and try again.'**
  String get inviteCreateFailed;

  /// Default invitation message; firstName is '' or ' Name'
  ///
  /// In en, this message translates to:
  /// **'Hi{firstName}! You\'re invited to join our coworking space \"{workspaceName}\" on DesKilo.\n\n1. Download the app:\n{downloadUrl}\n\n2. Open it, create your account (e-mail + password) and sign in.\n\n3. Choose \"Join a workspace\" and enter your personal invitation code:\n{workspaceId}\n(invitation link: {inviteLink})\n\nTip: simply copy this whole message and paste it into the app — the code is found automatically. Your code is personal, single-use and valid for 14 days.\n\nSee you soon at {workspaceName}!'**
  String invitationDefaultTemplate(
    String firstName,
    String workspaceName,
    String workspaceId,
    String downloadUrl,
    String inviteLink,
  );

  /// No description provided for @invitationTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'Invitation message'**
  String get invitationTemplateTitle;

  /// Help above the tag list
  ///
  /// In en, this message translates to:
  /// **'Sent when you invite someone via WhatsApp, SMS, or share. Leave empty to use the built-in message in the chosen language. Available tags:'**
  String get invitationTemplateHelp;

  /// Hint in the template editor
  ///
  /// In en, this message translates to:
  /// **'Custom invitation message using the tags above…'**
  String get invitationTemplateHint;

  /// No description provided for @workspaceInvitePasteHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the whole invitation message — the ID is found automatically.'**
  String get workspaceInvitePasteHint;

  /// No description provided for @workspaceInviteCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'No workspace ID found — paste the invitation or type the ID.'**
  String get workspaceInviteCodeInvalid;

  /// The invoice archive screen title and its Money entry button (0060)
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get invoicesTitle;

  /// Empty state of the invoice archive
  ///
  /// In en, this message translates to:
  /// **'No invoices yet.'**
  String get invoicesEmpty;

  /// FAB + sheet title issuing an invoice
  ///
  /// In en, this message translates to:
  /// **'New invoice'**
  String get invoiceCreate;

  /// Member dropdown label on the invoice form
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get invoiceMemberLabel;

  /// Submit button of the invoice form — issuing is final (immutable)
  ///
  /// In en, this message translates to:
  /// **'Issue invoice'**
  String get invoiceIssue;

  /// Snackbar after an invoice was issued
  ///
  /// In en, this message translates to:
  /// **'Invoice issued.'**
  String get invoiceIssued;

  /// Tooltip: save the invoice PDF to Downloads
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get invoiceDownload;

  /// Tooltip: share the invoice PDF via an app (mail, WhatsApp…)
  ///
  /// In en, this message translates to:
  /// **'Share PDF'**
  String get invoiceShare;

  /// PDF: the word before the invoice number
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get invoicePdfTitle;

  /// PDF: label before the issue date
  ///
  /// In en, this message translates to:
  /// **'Issued on'**
  String get invoicePdfIssuedOn;

  /// PDF: label before the issuer name
  ///
  /// In en, this message translates to:
  /// **'Issued by'**
  String get invoicePdfIssuedBy;

  /// PDF: label above the member block
  ///
  /// In en, this message translates to:
  /// **'Billed to'**
  String get invoicePdfBilledTo;

  /// PDF: caption above the integrity fingerprint
  ///
  /// In en, this message translates to:
  /// **'Digital signature (SHA-256)'**
  String get invoicePdfSignature;

  /// Settings tile: the member's postal address (printed on invoices)
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get addressTitle;

  /// Subtitle while no address is stored
  ///
  /// In en, this message translates to:
  /// **'No address'**
  String get addressNone;

  /// Snackbar after saving the address
  ///
  /// In en, this message translates to:
  /// **'Address saved'**
  String get addressSaved;

  /// Workspace-settings field: postal address printed on invoices
  ///
  /// In en, this message translates to:
  /// **'Workspace address'**
  String get workspaceAddressLabel;

  /// Feature toggle: the invoice archive (0060)
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get featureInvoicing;

  /// Subtitle of the invoicing toggle
  ///
  /// In en, this message translates to:
  /// **'Immutable, signed invoices in an archive — download or share as PDF.'**
  String get featureInvoicingDesc;

  /// Delegation toggle: admins may issue invoices
  ///
  /// In en, this message translates to:
  /// **'Admins issue invoices'**
  String get featureAdminInvoicing;

  /// Subtitle of the delegation toggle
  ///
  /// In en, this message translates to:
  /// **'Admins issue invoices too. The owner always can.'**
  String get featureAdminInvoicingDesc;

  /// Chip on an archive row of an invoice tagged erroneous (0061)
  ///
  /// In en, this message translates to:
  /// **'Erroneous'**
  String get invoiceVoidedChip;

  /// Menu action + confirm button tagging an invoice erroneous
  ///
  /// In en, this message translates to:
  /// **'Mark erroneous'**
  String get invoiceVoidAction;

  /// Confirm dialog body before tagging an invoice erroneous
  ///
  /// In en, this message translates to:
  /// **'Mark invoice {number} as erroneous? This cannot be undone.'**
  String invoiceVoidConfirm(String number);

  /// Snackbar after an invoice was tagged erroneous
  ///
  /// In en, this message translates to:
  /// **'Invoice marked as erroneous.'**
  String get invoiceVoided;

  /// Menu action opening the prefilled replacement form
  ///
  /// In en, this message translates to:
  /// **'Issue replacement'**
  String get invoiceReplaceAction;

  /// PDF banner + row label prefix before the void date
  ///
  /// In en, this message translates to:
  /// **'ERRONEOUS — voided on'**
  String get invoicePdfVoided;

  /// Label before the replaced invoice's number (row, sheet banner, PDF)
  ///
  /// In en, this message translates to:
  /// **'Replaces'**
  String get invoicePdfReplaces;

  /// Issue form: the picked month has no tracked positions (0062)
  ///
  /// In en, this message translates to:
  /// **'Nothing tracked for this month — nothing to invoice.'**
  String get invoiceNothingToInvoice;

  /// Fallback label of an adjustment position without a description
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get invoiceLineAdjustment;

  /// Archive member filter: no filter
  ///
  /// In en, this message translates to:
  /// **'All members'**
  String get invoiceFilterAllMembers;

  /// Archive month filter: no filter
  ///
  /// In en, this message translates to:
  /// **'All months'**
  String get invoiceFilterAllMonths;

  /// Archive month filter label
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get invoiceFilterMonthLabel;

  /// Archive sort menu tooltip
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get invoiceSortTooltip;

  /// Sort: newest issued first (default)
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get invoiceSortNewest;

  /// Sort: grouped by member name
  ///
  /// In en, this message translates to:
  /// **'By member'**
  String get invoiceSortByMember;

  /// Sort: newest invoiced month first
  ///
  /// In en, this message translates to:
  /// **'By month'**
  String get invoiceSortByMonth;

  /// Invoice bottom line (0063): consumptions minus payments — the solde
  ///
  /// In en, this message translates to:
  /// **'Balance due'**
  String get invoiceBalance;

  /// Issue form switch (0064): snapshot the annex into the invoice
  ///
  /// In en, this message translates to:
  /// **'Include the detailed annex (check-ins, services, payments)'**
  String get invoiceDetailedToggle;

  /// PDF positions table column header
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get invoicePdfDescription;

  /// PDF subtotal caption: sum of positive positions
  ///
  /// In en, this message translates to:
  /// **'Charges'**
  String get invoicePdfCharges;

  /// PDF subtotal caption: sum of credits
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get invoicePdfPayments;

  /// PDF annex section title
  ///
  /// In en, this message translates to:
  /// **'Annex — details'**
  String get invoicePdfAnnex;

  /// PDF annex: check-ins table title
  ///
  /// In en, this message translates to:
  /// **'Check-ins'**
  String get invoicePdfAttendance;

  /// PDF annex: ledger movements table title
  ///
  /// In en, this message translates to:
  /// **'Bookings & payments'**
  String get invoicePdfActivity;

  /// PDF annex suffix on a booked-but-not-attended row
  ///
  /// In en, this message translates to:
  /// **'reserved'**
  String get invoicePdfReserved;

  /// PDF footer page label
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get invoicePdfPage;

  /// Issuer menu: record + share a payment reminder (0066)
  ///
  /// In en, this message translates to:
  /// **'Send a reminder'**
  String get invoiceRemindAction;

  /// Snackbar after a reminder was recorded
  ///
  /// In en, this message translates to:
  /// **'Reminder recorded.'**
  String get invoiceReminded;

  /// Archive row badge: reminder count
  ///
  /// In en, this message translates to:
  /// **'Reminded ×{count}'**
  String invoiceRemindedBadge(int count);

  /// Share-sheet text accompanying the reminded invoice PDF
  ///
  /// In en, this message translates to:
  /// **'Friendly reminder: invoice {number} — balance due {amount}.'**
  String invoiceReminderMessage(String number, String amount);

  /// Menu: save the EN 16931 UBL XML to Downloads (EU workspaces)
  ///
  /// In en, this message translates to:
  /// **'Download e-invoice (XML)'**
  String get invoiceEInvoiceDownload;

  /// Menu: share the EN 16931 UBL XML (EU workspaces)
  ///
  /// In en, this message translates to:
  /// **'Share e-invoice (XML)'**
  String get invoiceEInvoiceShare;

  /// Invoicing hub tab: uninvoiced members of the previous month
  ///
  /// In en, this message translates to:
  /// **'To invoice'**
  String get invoiceTabToInvoice;

  /// Invoicing hub tab: invoices with a positive live solde
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get invoiceTabOpen;

  /// Invoicing hub tab: the full archive
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get invoiceTabArchive;

  /// Sweep button: issue for every listed member
  ///
  /// In en, this message translates to:
  /// **'Invoice all'**
  String get invoiceIssueAll;

  /// Per-member issue button on the to-invoice list
  ///
  /// In en, this message translates to:
  /// **'Issue'**
  String get invoiceIssueOne;

  /// To-invoice tab empty state
  ///
  /// In en, this message translates to:
  /// **'All caught up — nothing to invoice.'**
  String get invoiceAllCaughtUp;

  /// Open tab empty state
  ///
  /// In en, this message translates to:
  /// **'No open invoices.'**
  String get invoiceNoOpen;

  /// Summary strip: pending count
  ///
  /// In en, this message translates to:
  /// **'{count} to invoice'**
  String invoiceSummaryToInvoice(int count);

  /// Summary strip: open count + outstanding amount
  ///
  /// In en, this message translates to:
  /// **'{count} open · {amount} outstanding'**
  String invoiceSummaryOpen(int count, String amount);

  /// Open row: days since the invoice was issued
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String invoiceOpenAge(int days);

  /// Snackbar after the invoice-all sweep
  ///
  /// In en, this message translates to:
  /// **'{count} invoices issued.'**
  String invoiceIssuedCount(int count);

  /// Event type label + validation settings card (0067)
  ///
  /// In en, this message translates to:
  /// **'Invoice payment'**
  String get eventTypeInvoicePayment;

  /// Events feed line for a matched invoice payment
  ///
  /// In en, this message translates to:
  /// **'Invoice {number} paid — {amount}'**
  String eventInvoicePaid(String number, String amount);

  /// Open card button + match dialog title/confirm (0067)
  ///
  /// In en, this message translates to:
  /// **'Mark as paid'**
  String get invoiceMatchAction;

  /// Match dialog: note field
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get invoiceMatchNoteLabel;

  /// Match dialog inline error on the forced paths
  ///
  /// In en, this message translates to:
  /// **'A note is required.'**
  String get invoiceMatchNoteRequired;

  /// Match dialog: overpayment hint
  ///
  /// In en, this message translates to:
  /// **'The member paid {excess} more.'**
  String invoiceMatchOver(String excess);

  /// Overpayment resolution: credit note
  ///
  /// In en, this message translates to:
  /// **'Create a credit note for the excess'**
  String get invoiceMatchCreditNote;

  /// Overpayment resolution: forced accept
  ///
  /// In en, this message translates to:
  /// **'Accept anyway (note why)'**
  String get invoiceMatchForce;

  /// Match dialog: underpayment hint
  ///
  /// In en, this message translates to:
  /// **'The member paid {missing} less — accepting requires a note.'**
  String invoiceMatchUnder(String missing);

  /// Snackbar after a successful match
  ///
  /// In en, this message translates to:
  /// **'Invoice matched.'**
  String get invoiceMatched;

  /// Open card chip while the quorum decides
  ///
  /// In en, this message translates to:
  /// **'Awaiting validation'**
  String get invoiceMatchPendingBadge;

  /// Archive row badge: matched invoice
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get invoiceMatchedBadge;

  /// Pinned 0067 error: one active invoice per member+month
  ///
  /// In en, this message translates to:
  /// **'This month is already invoiced for this member.'**
  String get invoiceAlreadyInvoiced;

  /// Match dialog: caption above the payment picker (0068)
  ///
  /// In en, this message translates to:
  /// **'Select the registered payment'**
  String get invoiceMatchPickPayment;

  /// Match dialog: no unconsumed registered payments exist
  ///
  /// In en, this message translates to:
  /// **'No registered payment to match — record or confirm it first.'**
  String get invoiceMatchNoPayments;

  /// Lifecycle chip: issued, still waiting for its payment
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get invoiceStatusOpen;

  /// Archive: how many invoices the current filters show
  ///
  /// In en, this message translates to:
  /// **'{count} invoices'**
  String invoiceCountShown(int count);

  /// Archive empty state while filtering — NOT an empty archive
  ///
  /// In en, this message translates to:
  /// **'No invoice matches these filters.'**
  String get invoiceFilterNoMatch;

  /// Archive: back to the unfiltered list
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get invoiceFilterClear;

  /// Filter chip revealing cancelled (voided) invoices (#452)
  ///
  /// In en, this message translates to:
  /// **'Show cancelled'**
  String get invoiceShowCancelled;

  /// Detail sheet: the correction chain, downstream (0061)
  ///
  /// In en, this message translates to:
  /// **'Replaced by {number}'**
  String invoiceReplacedBy(String number);

  /// Detail sheet: the payment that closed the invoice (0067)
  ///
  /// In en, this message translates to:
  /// **'Paid {amount} on {date}'**
  String invoiceMatchSummary(String amount, String date);

  /// Detail sheet: when the last reminder went out (0066)
  ///
  /// In en, this message translates to:
  /// **'last reminder {date}'**
  String invoiceRemindedLast(String date);

  /// Detail sheet: what the snapshotted annex carries (0064)
  ///
  /// In en, this message translates to:
  /// **'Annex: {movements} movements, {checkIns} check-ins'**
  String invoiceAnnexSummary(int movements, int checkIns);

  /// Issue sheet placeholder before a member is chosen
  ///
  /// In en, this message translates to:
  /// **'Pick a member to see what their month tracked.'**
  String get invoicePickMember;

  /// Issue sheet warning when the picked month is the current one (0067)
  ///
  /// In en, this message translates to:
  /// **'This month is still running — its positions can still change, and a month can only be invoiced once.'**
  String get invoiceRunningMonth;

  /// Confirm dialog of the invoice-all sweep
  ///
  /// In en, this message translates to:
  /// **'Issue {count} invoices for {month}, {total} in total? An issued invoice can no longer be edited — a mistake is corrected with a replacement.'**
  String invoiceIssueAllConfirm(int count, String month, String total);

  /// Sweep result when some members could not be invoiced
  ///
  /// In en, this message translates to:
  /// **'{issued} issued, {failed} failed.'**
  String invoiceIssuedPartial(int issued, int failed);

  /// Detail sheet action opening the e-invoice sheet
  ///
  /// In en, this message translates to:
  /// **'E-invoice (XML)'**
  String get invoiceEInvoiceAction;

  /// E-invoice sheet: what the XML is
  ///
  /// In en, this message translates to:
  /// **'The machine-readable EN 16931 invoice — the file tax administrations and business customers ask for.'**
  String get invoiceEInvoiceExplain;

  /// E-invoice sheet: the domestic B2B channel and its syntax
  ///
  /// In en, this message translates to:
  /// **'Business customers: send it through {channel} as {format}.'**
  String invoiceEInvoiceBusinessRoute(String channel, String format);

  /// E-invoice sheet: the B2G channel (Directive 2014/55/EU)
  ///
  /// In en, this message translates to:
  /// **'Public-sector customers: {channel}.'**
  String invoiceEInvoicePublicRoute(String channel);

  /// E-invoice sheet: how the file travels on Peppol
  ///
  /// In en, this message translates to:
  /// **'An access point delivers it to the customer — no government platform in between.'**
  String get invoiceEInvoiceTransportPeppol;

  /// E-invoice sheet: clearance model (SdI, KSeF, e-Factura)
  ///
  /// In en, this message translates to:
  /// **'The national platform receives the invoice first and hands it on — sending it straight to the customer is not an option.'**
  String get invoiceEInvoiceTransportClearance;

  /// E-invoice sheet: accredited-platform model (France)
  ///
  /// In en, this message translates to:
  /// **'An accredited platform carries the invoice and reports it to the tax administration for you.'**
  String get invoiceEInvoiceTransportAccredited;

  /// E-invoice sheet: no transmission mandate (Germany today)
  ///
  /// In en, this message translates to:
  /// **'No channel is imposed: e-mail, a portal or Peppol — whatever you agree with the customer.'**
  String get invoiceEInvoiceTransportBilateral;

  /// E-invoice sheet warning where the domestic mandate runs on a national syntax
  ///
  /// In en, this message translates to:
  /// **'{channel} only accepts {format}: this EN 16931 file serves Peppol, public buyers and foreign customers — your platform or accountant converts the rest.'**
  String invoiceEInvoiceFormatMismatch(String channel, String format);

  /// E-invoice sheet: the file satisfies the norm
  ///
  /// In en, this message translates to:
  /// **'Ready — this file satisfies EN 16931.'**
  String get invoiceEInvoiceReady;

  /// E-invoice sheet: header above the fatal gaps
  ///
  /// In en, this message translates to:
  /// **'A validator would reject this file:'**
  String get invoiceEInvoiceBlockedTitle;

  /// E-invoice sheet: header above the non-fatal gaps
  ///
  /// In en, this message translates to:
  /// **'Valid, but the strict national profiles also want:'**
  String get invoiceEInvoiceIncompleteTitle;

  /// Gap: the workspace charges VAT, which the app cannot break down
  ///
  /// In en, this message translates to:
  /// **'The workspace charges VAT but this invoice carries no rate — add your VAT rates, then issue it again.'**
  String get invoiceGapVatNotSupported;

  /// Gap: BR-E-02 — exempt seller without a VAT identifier
  ///
  /// In en, this message translates to:
  /// **'The VAT number is missing — an exempt seller must state one.'**
  String get invoiceGapMissingVatId;

  /// Gap: BR-CO-26 — no seller identifier at all
  ///
  /// In en, this message translates to:
  /// **'The company registration number is missing (SIREN, HRB, CIF…) — nothing identifies you on the invoice.'**
  String get invoiceGapMissingLegalId;

  /// Gap: BR-E-10 — no exemption reason
  ///
  /// In en, this message translates to:
  /// **'The reason for not charging VAT is missing.'**
  String get invoiceGapMissingExemptionReason;

  /// Gap: BR-09 — seller country
  ///
  /// In en, this message translates to:
  /// **'The workspace country is missing.'**
  String get invoiceGapMissingSellerCountry;

  /// Gap: BR-11 — buyer country
  ///
  /// In en, this message translates to:
  /// **'The customer\'s country is missing.'**
  String get invoiceGapMissingBuyerCountry;

  /// Gap: BR-16 — an invoice needs at least one line
  ///
  /// In en, this message translates to:
  /// **'This invoice has no charge line — its month was fully covered by payments, so there is no invoice to send.'**
  String get invoiceGapNoChargeLines;

  /// Gap: seller city (national CIUS / Peppol)
  ///
  /// In en, this message translates to:
  /// **'the city of the workspace address'**
  String get invoiceGapMissingSellerCity;

  /// Gap: seller post code (national CIUS / Peppol)
  ///
  /// In en, this message translates to:
  /// **'the post code of the workspace address'**
  String get invoiceGapMissingSellerPostalCode;

  /// E-invoice sheet: jump to the legal-identity screen
  ///
  /// In en, this message translates to:
  /// **'Complete the legal identity'**
  String get invoiceEInvoiceFixIdentity;

  /// Screen title: the workspace legal identity
  ///
  /// In en, this message translates to:
  /// **'Legal identity & e-invoicing'**
  String get legalIdentityTitle;

  /// Workspace-settings tile subtitle
  ///
  /// In en, this message translates to:
  /// **'VAT regime and registration numbers — required by the e-invoice'**
  String get legalIdentitySubtitle;

  /// Screen intro paragraph
  ///
  /// In en, this message translates to:
  /// **'What an EN 16931 e-invoice must state about you. Invoices already issued keep the identity they were signed with.'**
  String get legalIdentityIntro;

  /// VAT regime dropdown label
  ///
  /// In en, this message translates to:
  /// **'VAT regime'**
  String get legalIdentityRegime;

  /// VAT regime option: category O
  ///
  /// In en, this message translates to:
  /// **'Outside the scope of VAT'**
  String get legalIdentityRegimeNotSubject;

  /// VAT regime option: category E
  ///
  /// In en, this message translates to:
  /// **'VAT-exempt (small-business scheme)'**
  String get legalIdentityRegimeExempt;

  /// VAT regime option: charges VAT
  ///
  /// In en, this message translates to:
  /// **'VAT-registered (charges VAT)'**
  String get legalIdentityRegimeVatRegistered;

  /// Explains that the regime drives which id is required
  ///
  /// In en, this message translates to:
  /// **'The regime decides which number the norm requires: a registration number outside the scope of VAT, a VAT number when exempt.'**
  String get legalIdentityRegimeHint;

  /// VAT number field label
  ///
  /// In en, this message translates to:
  /// **'VAT number'**
  String get legalIdentityVatId;

  /// Company registration number field label
  ///
  /// In en, this message translates to:
  /// **'Company registration number'**
  String get legalIdentityLegalId;

  /// Exemption reason field label
  ///
  /// In en, this message translates to:
  /// **'Why no VAT is charged'**
  String get legalIdentityExemptionReason;

  /// Street field label
  ///
  /// In en, this message translates to:
  /// **'Street'**
  String get legalIdentityStreet;

  /// City field label
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get legalIdentityCity;

  /// Post code field label
  ///
  /// In en, this message translates to:
  /// **'Post code'**
  String get legalIdentityPostalCode;

  /// Snackbar after saving the legal identity
  ///
  /// In en, this message translates to:
  /// **'Legal identity saved.'**
  String get legalIdentitySaved;

  /// Warning shown for the VAT-registered regime
  ///
  /// In en, this message translates to:
  /// **'This workspace charges VAT but no rate is set up: invoices show no tax and the XML export stays disabled until you add one.'**
  String get legalIdentityVatWarning;

  /// Country field on the member address sheet
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get addressCountryLabel;

  /// Member VAT number field on the address sheet
  ///
  /// In en, this message translates to:
  /// **'VAT number (if you invoice as a business)'**
  String get addressVatIdLabel;

  /// Tooltip of the proforma action on the hub rows (0072)
  ///
  /// In en, this message translates to:
  /// **'Proforma invoice'**
  String get invoiceProformaAction;

  /// The word a proforma document carries in its header and as its watermark
  ///
  /// In en, this message translates to:
  /// **'Proforma'**
  String get invoicePdfProforma;

  /// Snackbar after a proforma was handed to the share sheet
  ///
  /// In en, this message translates to:
  /// **'Proforma shared.'**
  String get invoiceProformaShared;

  /// Refusal when the month has nothing to put on a proforma
  ///
  /// In en, this message translates to:
  /// **'Nothing tracked for this month — no proforma to send.'**
  String get invoiceProformaNothing;

  /// The word stamped across a member's own render of an invoice (0072)
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get invoicePdfCopy;

  /// Lifecycle chip: matched to a payment that did not cover the whole invoice
  ///
  /// In en, this message translates to:
  /// **'Partially paid'**
  String get invoiceStatusPartiallyPaid;

  /// Screen title of the sortable invoice register (0072)
  ///
  /// In en, this message translates to:
  /// **'Invoice register'**
  String get invoiceRegisterTitle;

  /// Register column header, and its sort control
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get invoiceRegisterDate;

  /// Register column header: the member for an issuer, the invoice number for a member
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get invoiceRegisterName;

  /// Register column header
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get invoiceRegisterAmount;

  /// Register footer: sum of the listed invoices
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get invoiceRegisterTotal;

  /// E-invoice sheet: the hybrid PDF+XML document (0073)
  ///
  /// In en, this message translates to:
  /// **'Download Factur-X (PDF)'**
  String get invoiceFacturXDownload;

  /// E-invoice sheet: share the hybrid document
  ///
  /// In en, this message translates to:
  /// **'Share Factur-X (PDF)'**
  String get invoiceFacturXShare;

  /// E-invoice sheet: what the hybrid document is and why it is the default
  ///
  /// In en, this message translates to:
  /// **'One file: the invoice a human reads, with the machine-readable XML inside it. This is what most platforms expect.'**
  String get invoiceFacturXExplain;

  /// E-invoice sheet: post the document to the platform (0073)
  ///
  /// In en, this message translates to:
  /// **'Send to the government platform'**
  String get invoiceSendAction;

  /// Snackbar: the platform took the document
  ///
  /// In en, this message translates to:
  /// **'Sent — the platform accepted it.'**
  String get invoiceSendAccepted;

  /// E-invoice sheet: post the document to the customer's delivery service (#568)
  ///
  /// In en, this message translates to:
  /// **'Send to the customer\'s service'**
  String get invoiceSendCustomerAction;

  /// Snackbar: the customer's service took the document (#568)
  ///
  /// In en, this message translates to:
  /// **'Sent — the customer\'s service accepted it.'**
  String get invoiceSendCustomerAccepted;

  /// E-invoicing config: customer delivery section title (#568)
  ///
  /// In en, this message translates to:
  /// **'Customer delivery service'**
  String get einvoiceCustomerSectionTitle;

  /// E-invoicing config: customer delivery section help (#568)
  ///
  /// In en, this message translates to:
  /// **'Where invoices go for the customer: their Peppol access point, portal or agreed upload API — separate from the government platform.'**
  String get einvoiceCustomerSectionHelp;

  /// Snackbar: the platform refused it
  ///
  /// In en, this message translates to:
  /// **'The platform refused it.'**
  String get invoiceSendRejected;

  /// Detail sheet: when it left and what came back
  ///
  /// In en, this message translates to:
  /// **'Sent {date} · {status}'**
  String invoiceSentOn(String date, String status);

  /// Transmission status word
  ///
  /// In en, this message translates to:
  /// **'accepted'**
  String get invoiceSendStatusAccepted;

  /// Transmission status word
  ///
  /// In en, this message translates to:
  /// **'rejected'**
  String get invoiceSendStatusRejected;

  /// Transmission status word
  ///
  /// In en, this message translates to:
  /// **'not delivered'**
  String get invoiceSendStatusFailed;

  /// Owner screen: the e-invoicing platform credentials
  ///
  /// In en, this message translates to:
  /// **'E-invoicing platform'**
  String get einvoiceConfigTitle;

  /// Owner screen intro
  ///
  /// In en, this message translates to:
  /// **'Where DesKilo posts your invoices. Any platform that accepts an upload with a token works — a plateforme agréée, a Peppol access point, a national platform. The token is stored server-side and never comes back out.'**
  String get einvoiceConfigIntro;

  /// Field label: the upload URL
  ///
  /// In en, this message translates to:
  /// **'Upload URL'**
  String get einvoiceConfigEndpoint;

  /// Field label: the credential
  ///
  /// In en, this message translates to:
  /// **'Token or credential'**
  String get einvoiceConfigToken;

  /// Field label: which header carries the token
  ///
  /// In en, this message translates to:
  /// **'Auth header (default Authorization)'**
  String get einvoiceConfigHeader;

  /// Field label: the multipart field name
  ///
  /// In en, this message translates to:
  /// **'File field name (default file)'**
  String get einvoiceConfigField;

  /// Snackbar after saving the platform
  ///
  /// In en, this message translates to:
  /// **'Platform saved.'**
  String get einvoiceConfigSaved;

  /// Snackbar after forgetting the platform
  ///
  /// In en, this message translates to:
  /// **'Platform removed.'**
  String get einvoiceConfigCleared;

  /// Button: forget the platform
  ///
  /// In en, this message translates to:
  /// **'Remove the platform'**
  String get einvoiceConfigClear;

  /// Shown instead of the stored token
  ///
  /// In en, this message translates to:
  /// **'A token is stored (type a new one to replace it).'**
  String get einvoiceConfigTokenSet;

  /// Register action: the SAF-T file for the accountant (0074)
  ///
  /// In en, this message translates to:
  /// **'Accounting export'**
  String get invoiceAccountingExport;

  /// Refusal when the selected period holds nothing
  ///
  /// In en, this message translates to:
  /// **'Nothing to export for this period.'**
  String get invoiceAccountingExportEmpty;

  /// Register filter: which fiscal year the register shows
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get invoiceRegisterYear;

  /// Register filter: no year restriction
  ///
  /// In en, this message translates to:
  /// **'All years'**
  String get invoiceRegisterAllYears;

  /// Export chooser: the OECD audit file (0074)
  ///
  /// In en, this message translates to:
  /// **'SAF-T (XML, international)'**
  String get invoiceExportSafT;

  /// Export chooser: the French audit file (0075)
  ///
  /// In en, this message translates to:
  /// **'FEC (France, required in an audit)'**
  String get invoiceExportFec;

  /// Export chooser title
  ///
  /// In en, this message translates to:
  /// **'Export for accounting'**
  String get invoiceExportChoose;

  /// Dialog title: which accounts the FEC will book
  ///
  /// In en, this message translates to:
  /// **'Accounts to book'**
  String get fecAccountsTitle;

  /// Dialog body: why it asks
  ///
  /// In en, this message translates to:
  /// **'A FEC is made of accounting entries, so it needs account numbers. These are the French chart defaults — change them to your accountant\'s.'**
  String get fecAccountsIntro;

  /// Field label: the receivable account
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get fecAccountCustomers;

  /// Field label: the revenue account
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get fecAccountRevenue;

  /// Field label: the cash account
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get fecAccountBank;

  /// Refusal: the FEC file name is built from the SIREN, which is not set
  ///
  /// In en, this message translates to:
  /// **'The FEC is named after your registration number — fill it in under Legal identity first.'**
  String get fecMissingSiren;

  /// Explains that the invoice snapshot predates the completed legal identity
  ///
  /// In en, this message translates to:
  /// **'Your legal identity is complete now, but this invoice was signed before it and keeps what it was issued with. Mark it erroneous and issue a replacement to carry the new identity.'**
  String get invoiceEInvoiceStaleIdentity;

  /// Shown when the e-invoice platform status probe fails
  ///
  /// In en, this message translates to:
  /// **'The platform settings could not be loaded. Check your connection and try again.'**
  String get einvoiceConfigUnavailable;

  /// Title of the environment picker sheet (#393), shown only in developer mode.
  ///
  /// In en, this message translates to:
  /// **'Send to which platform?'**
  String get einvoiceEnvTitle;

  /// Environment label: the real platform.
  ///
  /// In en, this message translates to:
  /// **'Production'**
  String get einvoiceEnvProd;

  /// Environment label: the UAT endpoint.
  ///
  /// In en, this message translates to:
  /// **'UAT (test platform)'**
  String get einvoiceEnvUat;

  /// Environment label: the dev endpoint.
  ///
  /// In en, this message translates to:
  /// **'Dev (test platform)'**
  String get einvoiceEnvDev;

  /// Subtitle under the production option.
  ///
  /// In en, this message translates to:
  /// **'The real submission.'**
  String get einvoiceEnvProdHint;

  /// Subtitle under a test-environment option.
  ///
  /// In en, this message translates to:
  /// **'A rehearsal — logged as a test send.'**
  String get einvoiceEnvTestHint;

  /// Success snack for a non-production send — a rehearsal must never read like the real submission.
  ///
  /// In en, this message translates to:
  /// **'Test send accepted ({env}).'**
  String invoiceSendAcceptedTest(String env);

  /// Section title on the platform config screen.
  ///
  /// In en, this message translates to:
  /// **'Test environments (UAT / Dev)'**
  String get einvoiceTestEnvsTitle;

  /// Help text under the test-environments section.
  ///
  /// In en, this message translates to:
  /// **'Separate endpoints and tokens for rehearsals. The choice appears at send time only while developer mode is on.'**
  String get einvoiceTestEnvsHelp;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'UAT upload URL'**
  String get einvoiceUatEndpoint;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'UAT token or credential'**
  String get einvoiceUatToken;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Dev upload URL'**
  String get einvoiceDevEndpoint;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Dev token or credential'**
  String get einvoiceDevToken;

  /// Tiny chip on a transmission row whose environment is not production.
  ///
  /// In en, this message translates to:
  /// **'test'**
  String get invoiceSentTestChip;

  /// Invoice PDF template editor (#454)
  ///
  /// In en, this message translates to:
  /// **'Invoice PDF template'**
  String get invoiceTemplateTitle;

  /// Invoice PDF template editor (#454)
  ///
  /// In en, this message translates to:
  /// **'Three report bands rendered on the PDF — the e-invoice XML is never touched. Liquid conditions and loops, then line markup:'**
  String get invoiceTemplateHint;

  /// Invoice PDF template editor (#454)
  ///
  /// In en, this message translates to:
  /// **'Intro (above the billed-to block)'**
  String get invoiceTemplateIntroLabel;

  /// Invoice PDF template editor (#454)
  ///
  /// In en, this message translates to:
  /// **'Footer (under the totals — payment terms, legal mentions)'**
  String get invoiceTemplateFooterLabel;

  /// Invoice PDF template editor (#454)
  ///
  /// In en, this message translates to:
  /// **'Invoice template saved.'**
  String get invoiceTemplateSaved;

  /// Invoice report editor (#470)
  ///
  /// In en, this message translates to:
  /// **'Header band'**
  String get invoiceTemplateHeaderLabel;

  /// Invoice report editor (#470)
  ///
  /// In en, this message translates to:
  /// **'Body band (the invoice lines)'**
  String get invoiceTemplateBodyLabel;

  /// Invoice report editor (#470)
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get invoiceTemplateReset;

  /// Invoice report editor (#470)
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get invoiceTemplatePreview;

  /// Invoice report editor (#470)
  ///
  /// In en, this message translates to:
  /// **'Issue an invoice first — the preview renders your newest one.'**
  String get invoiceTemplateNoPreview;

  /// Mahnwesen / reminder letters (#472)
  ///
  /// In en, this message translates to:
  /// **'Payment reminder'**
  String get reminderPdfTitleFriendly;

  /// Mahnwesen / reminder letters (#472)
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminderPdfTitleFirm;

  /// Mahnwesen / reminder letters (#472)
  ///
  /// In en, this message translates to:
  /// **'this is a friendly reminder that the invoice below is still open. Perhaps it simply slipped through — no worries.'**
  String get reminderPdfOpeningFriendly;

  /// Mahnwesen / reminder letters (#472)
  ///
  /// In en, this message translates to:
  /// **'despite our previous reminder, the invoice below remains unpaid. Please settle the amount without delay.'**
  String get reminderPdfOpeningFirm;

  /// Mahnwesen / reminder letters (#472)
  ///
  /// In en, this message translates to:
  /// **'Open for'**
  String get reminderPdfDaysOpen;

  /// Mahnwesen / reminder letters (#472)
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get reminderPdfDays;

  /// Mahnwesen / reminder letters (#472)
  ///
  /// In en, this message translates to:
  /// **'Reminder level'**
  String get reminderPdfLevelLabel;

  /// Mahnwesen / reminder letters (#472)
  ///
  /// In en, this message translates to:
  /// **'If you have already paid, please disregard this letter.'**
  String get reminderPdfClosing;

  /// Mahnwesen / reminder letters (#472)
  ///
  /// In en, this message translates to:
  /// **'Reminder rules'**
  String get dunningSettingsTitle;

  /// Mahnwesen / reminder letters (#472)
  ///
  /// In en, this message translates to:
  /// **'Number of reminder levels'**
  String get dunningLevels;

  /// Mahnwesen / reminder letters (#472)
  ///
  /// In en, this message translates to:
  /// **'Days until the first reminder'**
  String get dunningFirstAfterDays;

  /// Mahnwesen / reminder letters (#472)
  ///
  /// In en, this message translates to:
  /// **'Days between reminders'**
  String get dunningBetweenDays;

  /// Mahnwesen / reminder letters (#472)
  ///
  /// In en, this message translates to:
  /// **'Reminder rules saved.'**
  String get dunningSaved;

  /// Mahnwesen / reminder letters (#472)
  ///
  /// In en, this message translates to:
  /// **'Reminder {level} due'**
  String dunningDueChip(int level);

  /// Mahnwesen / reminder letters (#472)
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get invoiceTemplateDocInvoice;

  /// Mahnwesen / reminder letters (#472)
  ///
  /// In en, this message translates to:
  /// **'Reminder {level}'**
  String invoiceTemplateDocReminder(int level);

  /// Report UX: presets, quick preview, download (#474)
  ///
  /// In en, this message translates to:
  /// **'Quick preview — your newest invoice'**
  String get reportPreviewTitle;

  /// Report UX: presets, quick preview, download (#474)
  ///
  /// In en, this message translates to:
  /// **'Quick preview — sample data'**
  String get reportPreviewSimulated;

  /// Report UX: presets, quick preview, download (#474)
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get reportPresetClassic;

  /// Report UX: presets, quick preview, download (#474)
  ///
  /// In en, this message translates to:
  /// **'Formal letter'**
  String get reportPresetFormalLetter;

  /// Report UX: presets, quick preview, download (#474)
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get reportSubject;

  /// Report UX: presets, quick preview, download (#474)
  ///
  /// In en, this message translates to:
  /// **'Kind regards'**
  String get reportRegards;

  /// Report UX: presets, quick preview, download (#474)
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get invoiceTemplatePresets;

  /// Report UX: presets, quick preview, download (#474)
  ///
  /// In en, this message translates to:
  /// **'Quick preview'**
  String get invoiceTemplateQuickPreview;

  /// Report UX: presets, quick preview, download (#474)
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get invoiceTemplateDownload;

  /// Report UX: presets, quick preview, download (#474)
  ///
  /// In en, this message translates to:
  /// **'Share PDF'**
  String get invoiceTemplateShare;

  /// Report-editor document chip (#476)
  ///
  /// In en, this message translates to:
  /// **'Statement'**
  String get invoiceTemplateDocStatement;

  /// Legal invoice mentions (#480)
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get reportPresetSimple;

  /// Legal invoice mentions (#480)
  ///
  /// In en, this message translates to:
  /// **'Detailed'**
  String get reportPresetVerbose;

  /// Legal invoice mentions (#480)
  ///
  /// In en, this message translates to:
  /// **'Invoice mentions'**
  String get invoiceLegalSection;

  /// Legal invoice mentions (#480)
  ///
  /// In en, this message translates to:
  /// **'The statutory lines printed on invoices and reminders. The payment clauses fall back to legal defaults when left empty.'**
  String get invoiceLegalIntro;

  /// Legal invoice mentions (#480)
  ///
  /// In en, this message translates to:
  /// **'Legal form & capital'**
  String get invoiceLegalFormField;

  /// Legal invoice mentions (#480)
  ///
  /// In en, this message translates to:
  /// **'e.g. SARL au capital de 7 500 €'**
  String get invoiceLegalFormHint;

  /// Legal invoice mentions (#480)
  ///
  /// In en, this message translates to:
  /// **'Trade register'**
  String get invoiceLegalRegistrationField;

  /// Legal invoice mentions (#480)
  ///
  /// In en, this message translates to:
  /// **'e.g. RCS Saint-Brieuc 680 357 910'**
  String get invoiceLegalRegistrationHint;

  /// Legal invoice mentions (#480)
  ///
  /// In en, this message translates to:
  /// **'Payment terms'**
  String get invoiceLegalPaymentTermsField;

  /// Legal invoice mentions (#480)
  ///
  /// In en, this message translates to:
  /// **'Late-payment penalty'**
  String get invoiceLegalLatePenaltyField;

  /// Legal invoice mentions (#480)
  ///
  /// In en, this message translates to:
  /// **'Recovery indemnity'**
  String get invoiceLegalRecoveryField;

  /// Legal invoice mentions (#480)
  ///
  /// In en, this message translates to:
  /// **'Early-payment discount'**
  String get invoiceLegalEscompteField;

  /// Legal invoice mentions (#480)
  ///
  /// In en, this message translates to:
  /// **'Professional insurance'**
  String get invoiceLegalInsuranceField;

  /// Legal invoice mentions (#480)
  ///
  /// In en, this message translates to:
  /// **'Special mentions'**
  String get invoiceLegalSpecialField;

  /// Legal invoice mentions (#480)
  ///
  /// In en, this message translates to:
  /// **'Payment on receipt.'**
  String get invoiceLegalPaymentTermsDefault;

  /// Legal invoice mentions (#480)
  ///
  /// In en, this message translates to:
  /// **'Late-payment penalty: three times the statutory interest rate.'**
  String get invoiceLegalLatePenaltyDefault;

  /// Legal invoice mentions (#480)
  ///
  /// In en, this message translates to:
  /// **'Fixed recovery indemnity for collection costs: €40.'**
  String get invoiceLegalRecoveryDefault;

  /// Legal invoice mentions (#480)
  ///
  /// In en, this message translates to:
  /// **'No discount for early payment.'**
  String get invoiceLegalEscompteDefault;

  /// French facture layout: line-table column headers (#482)
  ///
  /// In en, this message translates to:
  /// **'Unit price'**
  String get reportColUnitPrice;

  /// French facture layout: line-table column headers (#482)
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get reportColQty;

  /// French facture layout: line-table column headers (#482)
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get reportColTotal;

  /// Association invoicing + VAT regime gate (#484)
  ///
  /// In en, this message translates to:
  /// **'Organization type'**
  String get invoiceLegalKindField;

  /// Association invoicing + VAT regime gate (#484)
  ///
  /// In en, this message translates to:
  /// **'Company / business'**
  String get invoiceLegalKindCompany;

  /// Association invoicing + VAT regime gate (#484)
  ///
  /// In en, this message translates to:
  /// **'Association (non-profit)'**
  String get invoiceLegalKindAssociation;

  /// Association invoicing + VAT regime gate (#484)
  ///
  /// In en, this message translates to:
  /// **'The late-penalty, recovery-indemnity and discount clauses are printed only when filled — they are mandatory only between professionals.'**
  String get invoiceLegalAssociationHint;

  /// Association invoicing + VAT regime gate (#484)
  ///
  /// In en, this message translates to:
  /// **'e.g. Association loi 1901'**
  String get invoiceLegalFormHintAssociation;

  /// Association invoicing + VAT regime gate (#484)
  ///
  /// In en, this message translates to:
  /// **'e.g. RNA W123456789 · SIRET if assigned'**
  String get invoiceLegalRegistrationHintAssociation;

  /// Association invoicing + VAT regime gate (#484)
  ///
  /// In en, this message translates to:
  /// **'e.g. \"TVA non applicable, art. 293 B du CGI\" — or \"Exonération de TVA, art. 261, 7-1° du CGI\" for services to members'**
  String get invoiceLegalAssociationReasonHint;

  /// Report WYSIWYG editor + image library (#488)
  ///
  /// In en, this message translates to:
  /// **'Markup'**
  String get reportEditorMarkup;

  /// Report WYSIWYG editor + image library (#488)
  ///
  /// In en, this message translates to:
  /// **'Visual'**
  String get reportEditorVisual;

  /// Report WYSIWYG editor + image library (#488)
  ///
  /// In en, this message translates to:
  /// **'Insert image'**
  String get reportInsertImage;

  /// Report WYSIWYG editor + image library (#488)
  ///
  /// In en, this message translates to:
  /// **'Report images'**
  String get reportImagesTitle;

  /// Report WYSIWYG editor + image library (#488)
  ///
  /// In en, this message translates to:
  /// **'No image yet — upload your logo, a stamp or a signature and reference it with ![name].'**
  String get reportImagesEmpty;

  /// Report WYSIWYG editor + image library (#488)
  ///
  /// In en, this message translates to:
  /// **'Upload image'**
  String get reportImageUpload;

  /// Report WYSIWYG editor + image library (#488)
  ///
  /// In en, this message translates to:
  /// **'Add line'**
  String get reportVisualAddLine;

  /// Report WYSIWYG editor + image library (#488)
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get reportLineTitle;

  /// Report WYSIWYG editor + image library (#488)
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get reportLineSection;

  /// Report WYSIWYG editor + image library (#488)
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get reportLineText;

  /// Report WYSIWYG editor + image library (#488)
  ///
  /// In en, this message translates to:
  /// **'Small print'**
  String get reportLineSmall;

  /// Report WYSIWYG editor + image library (#488)
  ///
  /// In en, this message translates to:
  /// **'Table row'**
  String get reportLineRow;

  /// Report WYSIWYG editor + image library (#488)
  ///
  /// In en, this message translates to:
  /// **'Bold row'**
  String get reportLineBoldRow;

  /// Report WYSIWYG editor + image library (#488)
  ///
  /// In en, this message translates to:
  /// **'Divider'**
  String get reportLineDivider;

  /// Report WYSIWYG editor + image library (#488)
  ///
  /// In en, this message translates to:
  /// **'Spacing'**
  String get reportLineSpacer;

  /// Report WYSIWYG editor + image library (#488)
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get reportLineImage;

  /// Report WYSIWYG editor + image library (#488)
  ///
  /// In en, this message translates to:
  /// **'Columns start/end'**
  String get reportLineColumns;

  /// Report WYSIWYG editor + image library (#488)
  ///
  /// In en, this message translates to:
  /// **'Column break'**
  String get reportLineColumnsSplit;

  /// Report WYSIWYG editor + image library (#488)
  ///
  /// In en, this message translates to:
  /// **'Logic'**
  String get reportLineLogic;

  /// Report suite: agreement/payments/workspace docs (#494)
  ///
  /// In en, this message translates to:
  /// **'Financial agreement'**
  String get reportDocAgreement;

  /// Report suite: agreement/payments/workspace docs (#494)
  ///
  /// In en, this message translates to:
  /// **'Payments report'**
  String get reportDocPayments;

  /// Report suite: agreement/payments/workspace docs (#494)
  ///
  /// In en, this message translates to:
  /// **'Workspace report'**
  String get reportDocWorkspace;

  /// Report suite: agreement/payments/workspace docs (#494)
  ///
  /// In en, this message translates to:
  /// **'Extra half-day'**
  String get agreementExtraHalfDay;

  /// Report suite: agreement/payments/workspace docs (#494)
  ///
  /// In en, this message translates to:
  /// **'pending validation'**
  String get paymentsPendingTag;

  /// Report suite: agreement/payments/workspace docs (#494)
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get reportSectionFeatures;

  /// Report suite: agreement/payments/workspace docs (#494)
  ///
  /// In en, this message translates to:
  /// **'Prices'**
  String get reportSectionPrices;

  /// Report suite: agreement/payments/workspace docs (#494)
  ///
  /// In en, this message translates to:
  /// **'My conditions'**
  String get moneyMyAgreement;

  /// Report suite: agreement/payments/workspace docs (#494)
  ///
  /// In en, this message translates to:
  /// **'Send the financial agreement'**
  String get memberSendAgreement;

  /// Report suite: agreement/payments/workspace docs (#494)
  ///
  /// In en, this message translates to:
  /// **'Quick view'**
  String get reportQuickView;

  /// Report suite: agreement/payments/workspace docs (#494)
  ///
  /// In en, this message translates to:
  /// **'Everything about the space — through the report editor\'s workspace template'**
  String get reportDocWorkspaceSubtitle;

  /// Report language resolution + per-language templates (#496)
  ///
  /// In en, this message translates to:
  /// **'Default (all languages)'**
  String get reportTemplateLangDefault;

  /// Report language resolution + per-language templates (#496)
  ///
  /// In en, this message translates to:
  /// **'This country has several languages — set the workspace language in Workspace settings first.'**
  String get reportLanguageAmbiguous;

  /// True WYSIWYG design surface (#498)
  ///
  /// In en, this message translates to:
  /// **'Empty band — add an element below.'**
  String get reportDesignEmpty;

  /// Partial payments stay open until a validated write-off (#504)
  ///
  /// In en, this message translates to:
  /// **'Partially paid · remainder cancelled'**
  String get invoiceStatusRemainderCancelled;

  /// Partial payments stay open until a validated write-off (#504)
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get invoiceRemainingLabel;

  /// Partial payments stay open until a validated write-off (#504)
  ///
  /// In en, this message translates to:
  /// **'Cancel outstanding amount'**
  String get invoiceWriteoffButton;

  /// Partial payments stay open until a validated write-off (#504)
  ///
  /// In en, this message translates to:
  /// **'The unpaid remainder of this invoice will be cancelled and the invoice archived as partially paid — once the validators confirm. Until then it stays open and owed.'**
  String get invoiceWriteoffExplain;

  /// Partial payments stay open until a validated write-off (#504)
  ///
  /// In en, this message translates to:
  /// **'Write-off requested — awaiting validation.'**
  String get invoiceWriteoffRequested;

  /// Partial payments stay open until a validated write-off (#504)
  ///
  /// In en, this message translates to:
  /// **'Outstanding write-off'**
  String get eventTypeInvoiceWriteoff;

  /// Partial payments stay open until a validated write-off (#504)
  ///
  /// In en, this message translates to:
  /// **'{actor} asks to cancel the remainder of {number} — {amount}'**
  String eventInvoiceWriteoffLine(String actor, String number, String amount);

  /// Negative invoices are credit notes the workspace refunds (#508)
  ///
  /// In en, this message translates to:
  /// **'Credit note'**
  String get invoicePdfCreditNote;

  /// Negative invoices are credit notes the workspace refunds (#508)
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get invoiceStatusRefunded;

  /// Negative invoices are credit notes the workspace refunds (#508)
  ///
  /// In en, this message translates to:
  /// **'To refund'**
  String get invoiceRefundLabel;

  /// Negative invoices are credit notes the workspace refunds (#508)
  ///
  /// In en, this message translates to:
  /// **'Record the refund'**
  String get invoiceRefundButton;

  /// Negative invoices are credit notes the workspace refunds (#508)
  ///
  /// In en, this message translates to:
  /// **'This credit note means the WORKSPACE owes the member {amount}. Record that the refund was paid out — the amount is booked against the member\'s balance and the document closes as Refunded.'**
  String invoiceRefundExplain(String amount);

  /// Negative invoices are credit notes the workspace refunds (#508)
  ///
  /// In en, this message translates to:
  /// **'Refund recorded.'**
  String get invoiceRefunded;

  /// Summary strip: open credit notes the workspace still owes (#508/#510)
  ///
  /// In en, this message translates to:
  /// **'{count} to refund · {amount}'**
  String invoiceSummaryToRefund(int count, String amount);

  /// No description provided for @eventTypeInvoiceReminder.
  ///
  /// In en, this message translates to:
  /// **'Payment reminder'**
  String get eventTypeInvoiceReminder;

  /// No description provided for @eventInvoiceReminderLine.
  ///
  /// In en, this message translates to:
  /// **'Reminder {level}: invoice {number} — {amount} still due'**
  String eventInvoiceReminderLine(String number, int level, String amount);

  /// No description provided for @dunningAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic reminders'**
  String get dunningAutomatic;

  /// No description provided for @dunningAutomaticHint.
  ///
  /// In en, this message translates to:
  /// **'Once a day, open invoices past the term get their next reminder level by themselves — an alert in the member\'s feed and a push. Off: you send each reminder yourself.'**
  String get dunningAutomaticHint;

  /// No description provided for @eventTypePriceNegotiation.
  ///
  /// In en, this message translates to:
  /// **'Price negotiation'**
  String get eventTypePriceNegotiation;

  /// No description provided for @eventPriceNegotiationLine.
  ///
  /// In en, this message translates to:
  /// **'{actor} proposes a deal for {member}: {terms}'**
  String eventPriceNegotiationLine(String actor, String member, String terms);

  /// No description provided for @eventPriceNegotiationItems.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String eventPriceNegotiationItems(int count);

  /// No description provided for @journeyStepIssued.
  ///
  /// In en, this message translates to:
  /// **'Issued'**
  String get journeyStepIssued;

  /// No description provided for @journeyStepPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get journeyStepPayment;

  /// No description provided for @journeyStepConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Confirmation'**
  String get journeyStepConfirmation;

  /// No description provided for @journeyStepClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get journeyStepClosed;

  /// No description provided for @journeyIssuerMemberPays.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {name}\'s payment of {amount} — due {date}'**
  String journeyIssuerMemberPays(String name, String amount, String date);

  /// No description provided for @journeyIssuerMemberPaysOverdue.
  ///
  /// In en, this message translates to:
  /// **'{name} owes {amount} — overdue by {days} days'**
  String journeyIssuerMemberPaysOverdue(String name, String amount, int days);

  /// No description provided for @journeyIssuerMemberPaysRemainder.
  ///
  /// In en, this message translates to:
  /// **'{name} still owes {amount} after a partial payment'**
  String journeyIssuerMemberPaysRemainder(String name, String amount);

  /// No description provided for @journeyIssuerAdminConfirms.
  ///
  /// In en, this message translates to:
  /// **'{name} declared a payment of {amount} — another admin confirms it in Events'**
  String journeyIssuerAdminConfirms(String name, String amount);

  /// No description provided for @journeyIssuerMemberConfirms.
  ///
  /// In en, this message translates to:
  /// **'A payment of {amount} was recorded — {name} confirms it in Events'**
  String journeyIssuerMemberConfirms(String name, String amount);

  /// No description provided for @journeyIssuerMatches.
  ///
  /// In en, this message translates to:
  /// **'A payment of {amount} is registered — match it to this invoice'**
  String journeyIssuerMatches(String amount);

  /// No description provided for @journeyValidatorsMatch.
  ///
  /// In en, this message translates to:
  /// **'Payment matched — awaiting the validators\' decision'**
  String get journeyValidatorsMatch;

  /// No description provided for @journeyValidatorsWriteoff.
  ///
  /// In en, this message translates to:
  /// **'Write-off of the remainder requested — awaiting the validators'**
  String get journeyValidatorsWriteoff;

  /// No description provided for @journeyIssuerRefunds.
  ///
  /// In en, this message translates to:
  /// **'Credit note — refund {amount} to {name} and record it'**
  String journeyIssuerRefunds(String name, String amount);

  /// No description provided for @journeyIssuerReplaces.
  ///
  /// In en, this message translates to:
  /// **'Cancelled — issue the replacement'**
  String get journeyIssuerReplaces;

  /// No description provided for @journeyMemberPays.
  ///
  /// In en, this message translates to:
  /// **'Your move: pay {amount} by {date}'**
  String journeyMemberPays(String amount, String date);

  /// No description provided for @journeyMemberPaysOverdue.
  ///
  /// In en, this message translates to:
  /// **'Your move: pay {amount} — overdue by {days} days'**
  String journeyMemberPaysOverdue(String amount, int days);

  /// No description provided for @journeyMemberPaysRemainder.
  ///
  /// In en, this message translates to:
  /// **'Your move: pay the remaining {amount}'**
  String journeyMemberPaysRemainder(String amount);

  /// No description provided for @journeyMemberDeclared.
  ///
  /// In en, this message translates to:
  /// **'You declared {amount} — the workspace is confirming it'**
  String journeyMemberDeclared(String amount);

  /// No description provided for @journeyMemberConfirms.
  ///
  /// In en, this message translates to:
  /// **'Your move: confirm the payment of {amount} recorded for you, in Events'**
  String journeyMemberConfirms(String amount);

  /// No description provided for @journeyMemberRegistered.
  ///
  /// In en, this message translates to:
  /// **'Your payment of {amount} is registered — the workspace matches it to this invoice'**
  String journeyMemberRegistered(String amount);

  /// No description provided for @journeyMemberValidators.
  ///
  /// In en, this message translates to:
  /// **'Payment matched — awaiting validation'**
  String get journeyMemberValidators;

  /// No description provided for @journeyMemberWriteoff.
  ///
  /// In en, this message translates to:
  /// **'The workspace asked to cancel the remainder — awaiting validation'**
  String get journeyMemberWriteoff;

  /// No description provided for @journeyMemberRefund.
  ///
  /// In en, this message translates to:
  /// **'The workspace owes you {amount} — nothing to pay'**
  String journeyMemberRefund(String amount);

  /// No description provided for @journeyMemberReplaces.
  ///
  /// In en, this message translates to:
  /// **'Cancelled — a replacement follows'**
  String get journeyMemberReplaces;

  /// No description provided for @journeyClosedPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid on {date} — closed'**
  String journeyClosedPaid(String date);

  /// No description provided for @journeyClosedRemainder.
  ///
  /// In en, this message translates to:
  /// **'Closed — remainder cancelled on {date}'**
  String journeyClosedRemainder(String date);

  /// No description provided for @journeyClosedRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded on {date} — closed'**
  String journeyClosedRefunded(String date);

  /// No description provided for @journeyClosedReplaced.
  ///
  /// In en, this message translates to:
  /// **'Cancelled — replaced by {number}'**
  String journeyClosedReplaced(String number);

  /// No description provided for @journeyClosedSettled.
  ///
  /// In en, this message translates to:
  /// **'Regrouped into another invoice — that one is owed and chased'**
  String get journeyClosedSettled;

  /// No description provided for @journeyStageIssue.
  ///
  /// In en, this message translates to:
  /// **'To issue'**
  String get journeyStageIssue;

  /// No description provided for @journeyStageCollect.
  ///
  /// In en, this message translates to:
  /// **'To collect'**
  String get journeyStageCollect;

  /// No description provided for @journeyStageConfirm.
  ///
  /// In en, this message translates to:
  /// **'To confirm'**
  String get journeyStageConfirm;

  /// No description provided for @journeyStageClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get journeyStageClosed;

  /// No description provided for @journeyOverdueCount.
  ///
  /// In en, this message translates to:
  /// **'{count} overdue'**
  String journeyOverdueCount(int count);

  /// No description provided for @journeyStageStripLabel.
  ///
  /// In en, this message translates to:
  /// **'The invoicing process: issue, collect, confirm, close'**
  String get journeyStageStripLabel;

  /// No description provided for @journeyHowButton.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get journeyHowButton;

  /// No description provided for @journeyHowTitle.
  ///
  /// In en, this message translates to:
  /// **'How invoicing works'**
  String get journeyHowTitle;

  /// No description provided for @journeyHowIntro.
  ///
  /// In en, this message translates to:
  /// **'Four steps, the same for every invoice. Each one says whose move it is.'**
  String get journeyHowIntro;

  /// No description provided for @journeyHowWorkspaceLabel.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get journeyHowWorkspaceLabel;

  /// No description provided for @journeyHowMemberLabel.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get journeyHowMemberLabel;

  /// No description provided for @journeyHowIssuedWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Issues the invoice from the month\'s tracked data — numbered, signed, immutable — and shares the PDF or sends the e-invoice.'**
  String get journeyHowIssuedWorkspace;

  /// No description provided for @journeyHowIssuedMember.
  ///
  /// In en, this message translates to:
  /// **'Finds it on the Invoices face: positions, balance, due date.'**
  String get journeyHowIssuedMember;

  /// No description provided for @journeyHowPaymentWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Waits for the money. Past the term it sends the reminder levels it configured — by hand or automatically.'**
  String get journeyHowPaymentWorkspace;

  /// No description provided for @journeyHowPaymentMember.
  ///
  /// In en, this message translates to:
  /// **'Pays online (settled at once) or by transfer, then records the payment so the workspace knows.'**
  String get journeyHowPaymentMember;

  /// No description provided for @journeyHowConfirmationWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Another admin confirms the declared payment; the issuer then matches the registered payment to the invoice (Mark as paid) — a validation rule may hand the match to the validators. Paid more? A credit note. Paid less? Partially paid, the rest owed until paid or written off.'**
  String get journeyHowConfirmationWorkspace;

  /// No description provided for @journeyHowConfirmationMember.
  ///
  /// In en, this message translates to:
  /// **'Nothing to do — unless the workspace recorded the payment for them: then they confirm it in Events.'**
  String get journeyHowConfirmationMember;

  /// No description provided for @journeyHowClosedWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Paid, remainder cancelled or refunded: the invoice moves to the archive. A wrong invoice is marked erroneous and replaced — before payment, never after.'**
  String get journeyHowClosedWorkspace;

  /// No description provided for @journeyHowClosedMember.
  ///
  /// In en, this message translates to:
  /// **'The month reads settled and the invoice stays readable forever: quick view, PDF, share.'**
  String get journeyHowClosedMember;

  /// No description provided for @journeyTimelineTitle.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get journeyTimelineTitle;

  /// No description provided for @journeyPrimaryRemind.
  ///
  /// In en, this message translates to:
  /// **'Send reminder {level}'**
  String journeyPrimaryRemind(int level);

  /// No description provided for @journeyPrimaryConfirmInEvents.
  ///
  /// In en, this message translates to:
  /// **'Open Events'**
  String get journeyPrimaryConfirmInEvents;

  /// No description provided for @journeyOutstanding.
  ///
  /// In en, this message translates to:
  /// **'{amount} outstanding'**
  String journeyOutstanding(String amount);

  /// No description provided for @reportEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Report editor'**
  String get reportEditorTitle;

  /// No description provided for @reportDesignerUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get reportDesignerUndo;

  /// No description provided for @reportDesignerRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get reportDesignerRedo;

  /// No description provided for @reportDesignerDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving?'**
  String get reportDesignerDiscardTitle;

  /// No description provided for @reportDesignerDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'Your changes to the templates are not saved.'**
  String get reportDesignerDiscardBody;

  /// No description provided for @reportDesignerDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get reportDesignerDiscard;

  /// No description provided for @reportDesignerKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get reportDesignerKeepEditing;

  /// No description provided for @reportDesignerReplaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace the current layout?'**
  String get reportDesignerReplaceTitle;

  /// No description provided for @reportDesignerReplaceBody.
  ///
  /// In en, this message translates to:
  /// **'The bands of this document are replaced. Undo brings them back.'**
  String get reportDesignerReplaceBody;

  /// No description provided for @reportDesignerReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get reportDesignerReplace;

  /// No description provided for @reportDesignerPages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 page} other{{count} pages}}'**
  String reportDesignerPages(int count);

  /// No description provided for @reportDesignerError.
  ///
  /// In en, this message translates to:
  /// **'The template does not render — {message}'**
  String reportDesignerError(String message);

  /// No description provided for @reportDesignerInsert.
  ///
  /// In en, this message translates to:
  /// **'Insert element'**
  String get reportDesignerInsert;

  /// No description provided for @reportDesignerFields.
  ///
  /// In en, this message translates to:
  /// **'Fields'**
  String get reportDesignerFields;

  /// No description provided for @reportDesignerFieldsSearch.
  ///
  /// In en, this message translates to:
  /// **'Search a field'**
  String get reportDesignerFieldsSearch;

  /// No description provided for @reportDesignerMoveTo.
  ///
  /// In en, this message translates to:
  /// **'Move to band'**
  String get reportDesignerMoveTo;

  /// No description provided for @reportDesignerDrag.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get reportDesignerDrag;

  /// No description provided for @reportImageSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get reportImageSize;

  /// No description provided for @reportImageSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get reportImageSizeSmall;

  /// No description provided for @reportImageSizeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get reportImageSizeMedium;

  /// No description provided for @reportImageSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get reportImageSizeLarge;

  /// No description provided for @reportImageAlign.
  ///
  /// In en, this message translates to:
  /// **'Alignment'**
  String get reportImageAlign;

  /// No description provided for @reportImageAlignLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get reportImageAlignLeft;

  /// No description provided for @reportImageAlignCenter.
  ///
  /// In en, this message translates to:
  /// **'Centre'**
  String get reportImageAlignCenter;

  /// No description provided for @reportImageAlignRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get reportImageAlignRight;

  /// No description provided for @reportTemplateLangOverridden.
  ///
  /// In en, this message translates to:
  /// **'Own template'**
  String get reportTemplateLangOverridden;

  /// No description provided for @reportTemplateLangInherits.
  ///
  /// In en, this message translates to:
  /// **'Inherits the default'**
  String get reportTemplateLangInherits;

  /// No description provided for @reportTemplateClearOverlay.
  ///
  /// In en, this message translates to:
  /// **'Use the default for this language'**
  String get reportTemplateClearOverlay;

  /// No description provided for @reportDocCoa.
  ///
  /// In en, this message translates to:
  /// **'Chart of accounts'**
  String get reportDocCoa;

  /// No description provided for @reportDocBadges.
  ///
  /// In en, this message translates to:
  /// **'Member badges'**
  String get reportDocBadges;

  /// No description provided for @reportDocSpaceCodes.
  ///
  /// In en, this message translates to:
  /// **'Space QR cards'**
  String get reportDocSpaceCodes;

  /// No description provided for @reportFieldGroupDocument.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get reportFieldGroupDocument;

  /// No description provided for @reportFieldGroupMember.
  ///
  /// In en, this message translates to:
  /// **'Member & workspace'**
  String get reportFieldGroupMember;

  /// No description provided for @reportFieldGroupMoney.
  ///
  /// In en, this message translates to:
  /// **'Amounts'**
  String get reportFieldGroupMoney;

  /// No description provided for @reportFieldGroupLegal.
  ///
  /// In en, this message translates to:
  /// **'Legal mentions'**
  String get reportFieldGroupLegal;

  /// No description provided for @reportFieldGroupLoops.
  ///
  /// In en, this message translates to:
  /// **'Lines & VAT loops'**
  String get reportFieldGroupLoops;

  /// No description provided for @reportDesignerSideBySide.
  ///
  /// In en, this message translates to:
  /// **'Design and preview side by side'**
  String get reportDesignerSideBySide;

  /// No description provided for @wizardTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoicing wizard'**
  String get wizardTitle;

  /// No description provided for @invoiceWizardAction.
  ///
  /// In en, this message translates to:
  /// **'Month-close wizard'**
  String get invoiceWizardAction;

  /// No description provided for @wizardCardHint.
  ///
  /// In en, this message translates to:
  /// **'Issue, send, remind, register and validate payments, match and close — one guided process.'**
  String get wizardCardHint;

  /// No description provided for @wizardRunStart.
  ///
  /// In en, this message translates to:
  /// **'Start of month'**
  String get wizardRunStart;

  /// No description provided for @wizardRunEnd.
  ///
  /// In en, this message translates to:
  /// **'End of month'**
  String get wizardRunEnd;

  /// No description provided for @wizardRunStartHint.
  ///
  /// In en, this message translates to:
  /// **'The subscriptions members pay ahead: issue them for the coming month, send them, plan the reminders — then the payment side.'**
  String get wizardRunStartHint;

  /// No description provided for @wizardRunEndHint.
  ///
  /// In en, this message translates to:
  /// **'What the month that just ended cost: usage, consumption and extra charges. Issue, send, remind — then register, validate and match the payments, and close.'**
  String get wizardRunEndHint;

  /// No description provided for @wizardStepReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get wizardStepReview;

  /// No description provided for @wizardStepIssue.
  ///
  /// In en, this message translates to:
  /// **'Issue'**
  String get wizardStepIssue;

  /// No description provided for @wizardStepSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get wizardStepSend;

  /// No description provided for @wizardStepRemind.
  ///
  /// In en, this message translates to:
  /// **'Remind'**
  String get wizardStepRemind;

  /// No description provided for @wizardStepPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get wizardStepPayments;

  /// No description provided for @wizardStepMatch.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get wizardStepMatch;

  /// No description provided for @wizardStepClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get wizardStepClose;

  /// No description provided for @wizardStepSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get wizardStepSummary;

  /// No description provided for @wizardNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get wizardNext;

  /// No description provided for @wizardBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get wizardBack;

  /// No description provided for @wizardFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get wizardFinish;

  /// No description provided for @wizardReviewToIssue.
  ///
  /// In en, this message translates to:
  /// **'To issue'**
  String get wizardReviewToIssue;

  /// No description provided for @wizardReviewIssued.
  ///
  /// In en, this message translates to:
  /// **'Already issued'**
  String get wizardReviewIssued;

  /// No description provided for @wizardReviewOpen.
  ///
  /// In en, this message translates to:
  /// **'Open invoices'**
  String get wizardReviewOpen;

  /// No description provided for @wizardReviewOverdue.
  ///
  /// In en, this message translates to:
  /// **'Reminders due'**
  String get wizardReviewOverdue;

  /// No description provided for @wizardReviewPending.
  ///
  /// In en, this message translates to:
  /// **'Payments to validate'**
  String get wizardReviewPending;

  /// No description provided for @wizardPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'Period: {period}'**
  String wizardPeriodLabel(String period);

  /// No description provided for @wizardIssueHint.
  ///
  /// In en, this message translates to:
  /// **'Untick a member to leave them out of this batch. Members already covered are shown as done.'**
  String get wizardIssueHint;

  /// No description provided for @wizardIssueNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing to issue for this period.'**
  String get wizardIssueNothing;

  /// No description provided for @wizardIssuedChip.
  ///
  /// In en, this message translates to:
  /// **'Issued {number}'**
  String wizardIssuedChip(String number);

  /// No description provided for @wizardIssueAll.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Issue 1 invoice} other{Issue {count} invoices}}'**
  String wizardIssueAll(int count);

  /// No description provided for @wizardIssueFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not issue for {name}.'**
  String wizardIssueFailed(String name);

  /// No description provided for @wizardSendHint.
  ///
  /// In en, this message translates to:
  /// **'Hand each invoice to its member — share the PDF, or download it to send it your own way.'**
  String get wizardSendHint;

  /// No description provided for @wizardSendNone.
  ///
  /// In en, this message translates to:
  /// **'No invoice of this run to send yet.'**
  String get wizardSendNone;

  /// No description provided for @wizardSendShare.
  ///
  /// In en, this message translates to:
  /// **'Share the PDF'**
  String get wizardSendShare;

  /// No description provided for @wizardSendDownload.
  ///
  /// In en, this message translates to:
  /// **'Download the PDF'**
  String get wizardSendDownload;

  /// No description provided for @wizardRemindHint.
  ///
  /// In en, this message translates to:
  /// **'Overdue by your reminder rules. One tap records every reminder and notifies the members; the letter opens per row.'**
  String get wizardRemindHint;

  /// No description provided for @wizardRemindNone.
  ///
  /// In en, this message translates to:
  /// **'No reminder is due by your rules.'**
  String get wizardRemindNone;

  /// No description provided for @wizardRemindLevel.
  ///
  /// In en, this message translates to:
  /// **'reminder {level}'**
  String wizardRemindLevel(int level);

  /// No description provided for @wizardRemindAll.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Send 1 reminder} other{Send {count} reminders}}'**
  String wizardRemindAll(int count);

  /// No description provided for @wizardRemindOne.
  ///
  /// In en, this message translates to:
  /// **'Reminder letter'**
  String get wizardRemindOne;

  /// No description provided for @wizardPaymentsHint.
  ///
  /// In en, this message translates to:
  /// **'What members declared waits for your confirmation below. A payment that reached the account without a declaration is registered here — the member then confirms it.'**
  String get wizardPaymentsHint;

  /// No description provided for @wizardPaymentsNone.
  ///
  /// In en, this message translates to:
  /// **'No declared payment waits for you.'**
  String get wizardPaymentsNone;

  /// No description provided for @wizardPaymentAccept.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get wizardPaymentAccept;

  /// No description provided for @wizardPaymentReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get wizardPaymentReject;

  /// No description provided for @wizardMatchHint.
  ///
  /// In en, this message translates to:
  /// **'An invoice is paid once a real payment is matched to it. Rows with credit on the member\'s account are ready.'**
  String get wizardMatchHint;

  /// No description provided for @wizardMatchNone.
  ///
  /// In en, this message translates to:
  /// **'Every invoice is paid or closed.'**
  String get wizardMatchNone;

  /// No description provided for @wizardMatchPending.
  ///
  /// In en, this message translates to:
  /// **'Awaiting validation'**
  String get wizardMatchPending;

  /// No description provided for @wizardMatchCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit available: {amount}'**
  String wizardMatchCredit(String amount);

  /// No description provided for @wizardMatchNoCredit.
  ///
  /// In en, this message translates to:
  /// **'No payment on the account yet'**
  String get wizardMatchNoCredit;

  /// No description provided for @wizardMatchAction.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get wizardMatchAction;

  /// No description provided for @wizardCloseHint.
  ///
  /// In en, this message translates to:
  /// **'A member with several open invoices can pay ONE; a partly paid invoice can have its remainder written off; a credit note is refunded. Each goes through validation.'**
  String get wizardCloseHint;

  /// No description provided for @wizardCloseNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing to regroup, write off or refund.'**
  String get wizardCloseNone;

  /// No description provided for @wizardSettle.
  ///
  /// In en, this message translates to:
  /// **'Regroup {count}'**
  String wizardSettle(int count);

  /// No description provided for @wizardWriteoff.
  ///
  /// In en, this message translates to:
  /// **'Write off'**
  String get wizardWriteoff;

  /// No description provided for @wizardRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get wizardRefund;

  /// No description provided for @wizardSummaryHint.
  ///
  /// In en, this message translates to:
  /// **'What this run did'**
  String get wizardSummaryHint;

  /// No description provided for @wizardTallyIssued.
  ///
  /// In en, this message translates to:
  /// **'Invoices issued'**
  String get wizardTallyIssued;

  /// No description provided for @wizardTallyShared.
  ///
  /// In en, this message translates to:
  /// **'PDFs shared or downloaded'**
  String get wizardTallyShared;

  /// No description provided for @wizardTallyReminded.
  ///
  /// In en, this message translates to:
  /// **'Reminders sent'**
  String get wizardTallyReminded;

  /// No description provided for @wizardTallyDecided.
  ///
  /// In en, this message translates to:
  /// **'Payments confirmed or rejected'**
  String get wizardTallyDecided;

  /// No description provided for @wizardTallyRegistered.
  ///
  /// In en, this message translates to:
  /// **'Payments registered'**
  String get wizardTallyRegistered;

  /// No description provided for @wizardTallyMatched.
  ///
  /// In en, this message translates to:
  /// **'Invoices matched'**
  String get wizardTallyMatched;

  /// No description provided for @wizardTallySettled.
  ///
  /// In en, this message translates to:
  /// **'Regroupings'**
  String get wizardTallySettled;

  /// No description provided for @wizardTallyWriteoffs.
  ///
  /// In en, this message translates to:
  /// **'Write-offs requested'**
  String get wizardTallyWriteoffs;

  /// No description provided for @wizardTallyRefunds.
  ///
  /// In en, this message translates to:
  /// **'Refunds'**
  String get wizardTallyRefunds;

  /// No description provided for @wizardTallyNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing was changed.'**
  String get wizardTallyNothing;

  /// No description provided for @wizardTodoHeading.
  ///
  /// In en, this message translates to:
  /// **'Still open — whose move'**
  String get wizardTodoHeading;

  /// No description provided for @wizardTodoNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing left open.'**
  String get wizardTodoNone;

  /// No description provided for @wizardWhoYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get wizardWhoYou;

  /// No description provided for @wizardWhoValidators.
  ///
  /// In en, this message translates to:
  /// **'Validators'**
  String get wizardWhoValidators;

  /// No description provided for @registerPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Register a payment'**
  String get registerPaymentTitle;

  /// No description provided for @registerPaymentHint.
  ///
  /// In en, this message translates to:
  /// **'A payment that reached the workspace — the member confirms it, then it can be matched to an invoice.'**
  String get registerPaymentHint;

  /// No description provided for @registerPaymentMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get registerPaymentMember;

  /// No description provided for @registerPaymentAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get registerPaymentAmount;

  /// No description provided for @registerPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get registerPaymentMethod;

  /// No description provided for @registerPaymentDate.
  ///
  /// In en, this message translates to:
  /// **'Paid on'**
  String get registerPaymentDate;

  /// No description provided for @registerPaymentNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get registerPaymentNote;

  /// No description provided for @registerPaymentSubmit.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerPaymentSubmit;

  /// No description provided for @registerPaymentDone.
  ///
  /// In en, this message translates to:
  /// **'Payment registered — the member confirms it from their side.'**
  String get registerPaymentDone;

  /// No description provided for @repartitionAction.
  ///
  /// In en, this message translates to:
  /// **'Distribute an expense'**
  String get repartitionAction;

  /// No description provided for @repartitionTitle.
  ///
  /// In en, this message translates to:
  /// **'Distribute an expense'**
  String get repartitionTitle;

  /// No description provided for @repartitionHint.
  ///
  /// In en, this message translates to:
  /// **'Split a shared cost over the members. The shares land as lines on each member\'s next usage invoice; a reversal gives the money back as credit notes.'**
  String get repartitionHint;

  /// No description provided for @repartitionTitleField.
  ///
  /// In en, this message translates to:
  /// **'What for'**
  String get repartitionTitleField;

  /// No description provided for @repartitionAmount.
  ///
  /// In en, this message translates to:
  /// **'Total amount'**
  String get repartitionAmount;

  /// No description provided for @repartitionReverse.
  ///
  /// In en, this message translates to:
  /// **'Reversal — give back as credit notes'**
  String get repartitionReverse;

  /// No description provided for @repartitionMethod.
  ///
  /// In en, this message translates to:
  /// **'Split by'**
  String get repartitionMethod;

  /// No description provided for @repartitionMethodEqual.
  ///
  /// In en, this message translates to:
  /// **'Equal'**
  String get repartitionMethodEqual;

  /// No description provided for @repartitionMethodSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get repartitionMethodSubscription;

  /// No description provided for @repartitionMethodUsage.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get repartitionMethodUsage;

  /// No description provided for @repartitionMethodCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom key'**
  String get repartitionMethodCustom;

  /// No description provided for @repartitionPeriod.
  ///
  /// In en, this message translates to:
  /// **'Lands on'**
  String get repartitionPeriod;

  /// No description provided for @repartitionWeight.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get repartitionWeight;

  /// No description provided for @repartitionPreview.
  ///
  /// In en, this message translates to:
  /// **'Shares'**
  String get repartitionPreview;

  /// No description provided for @repartitionNoShares.
  ///
  /// In en, this message translates to:
  /// **'Nobody carries a share — check the key.'**
  String get repartitionNoShares;

  /// No description provided for @repartitionSum.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member · {amount}} other{{count} members · {amount}}}'**
  String repartitionSum(int count, String amount);

  /// No description provided for @repartitionSubmit.
  ///
  /// In en, this message translates to:
  /// **'Book the shares'**
  String get repartitionSubmit;

  /// No description provided for @repartitionFiled.
  ///
  /// In en, this message translates to:
  /// **'Shares booked — they appear on the next usage invoice.'**
  String get repartitionFiled;

  /// No description provided for @repartitionFiledPending.
  ///
  /// In en, this message translates to:
  /// **'Shares filed — they book once validated.'**
  String get repartitionFiledPending;

  /// No description provided for @repartitionHistory.
  ///
  /// In en, this message translates to:
  /// **'Distributions'**
  String get repartitionHistory;

  /// No description provided for @repartitionHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No distribution yet.'**
  String get repartitionHistoryEmpty;

  /// No description provided for @repartitionStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Awaiting validation'**
  String get repartitionStatusPending;

  /// No description provided for @repartitionStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Booked'**
  String get repartitionStatusConfirmed;

  /// No description provided for @repartitionStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get repartitionStatusRejected;

  /// No description provided for @repartitionStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get repartitionStatusExpired;

  /// #864 - file type in the design import picker
  ///
  /// In en, this message translates to:
  /// **'JSON'**
  String get reportDesignFileTypeLabel;

  /// #864 - action exporting the open report design
  ///
  /// In en, this message translates to:
  /// **'Export this design'**
  String get reportDesignExport;

  /// #864 - action importing a design file
  ///
  /// In en, this message translates to:
  /// **'Import a design'**
  String get reportDesignImport;

  /// #864 - the import landed but is not saved yet
  ///
  /// In en, this message translates to:
  /// **'Design imported. Save to keep it.'**
  String get reportDesignImported;

  /// #864 - import refusal: not JSON
  ///
  /// In en, this message translates to:
  /// **'That file is not readable JSON.'**
  String get reportDesignErrorMalformed;

  /// #864 - import refusal: not one of our files
  ///
  /// In en, this message translates to:
  /// **'That file is not a DesKilo report design.'**
  String get reportDesignErrorNotADesign;

  /// #864 - import refusal: newer schema
  ///
  /// In en, this message translates to:
  /// **'That design was written by a newer version of DesKilo.'**
  String get reportDesignErrorVersion;

  /// #864 - import refusal: no such report here
  ///
  /// In en, this message translates to:
  /// **'That design is for a report this workspace does not have.'**
  String get reportDesignErrorUnknownKind;

  /// #864 - import refusal: a design for another report
  ///
  /// In en, this message translates to:
  /// **'That design belongs to a different report. Open that report and import it there.'**
  String get reportDesignErrorWrongKind;

  /// #864 - import refusal: no readable design
  ///
  /// In en, this message translates to:
  /// **'That file carries no readable design.'**
  String get reportDesignErrorInvalidDesign;

  /// No description provided for @eventTypeMemberJoin.
  ///
  /// In en, this message translates to:
  /// **'New member'**
  String get eventTypeMemberJoin;

  /// No description provided for @memberStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get memberStatusPending;

  /// No description provided for @pendingApprovalTitle.
  ///
  /// In en, this message translates to:
  /// **'Awaiting approval'**
  String get pendingApprovalTitle;

  /// No description provided for @pendingApprovalBody.
  ///
  /// In en, this message translates to:
  /// **'You have joined {workspace}. An administrator must approve your membership before you can use the workspace — you will get access as soon as they confirm.'**
  String pendingApprovalBody(String workspace);

  /// No description provided for @pendingApprovalRefresh.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get pendingApprovalRefresh;

  /// No description provided for @memberApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve membership'**
  String get memberApprove;

  /// No description provided for @memberRejectJoin.
  ///
  /// In en, this message translates to:
  /// **'Reject membership'**
  String get memberRejectJoin;

  /// No description provided for @workspaceConfigInvitations.
  ///
  /// In en, this message translates to:
  /// **'Invitations'**
  String get workspaceConfigInvitations;

  /// No description provided for @workspaceConfigInvitationCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom invitation message configured'**
  String get workspaceConfigInvitationCustom;

  /// No description provided for @workspaceConfigInvitationDefault.
  ///
  /// In en, this message translates to:
  /// **'Built-in invitation message (all languages)'**
  String get workspaceConfigInvitationDefault;

  /// No description provided for @workspaceConfigInvitationSingleUse.
  ///
  /// In en, this message translates to:
  /// **'Personal invitation codes are single-use and expire after 14 days; new members need admin approval'**
  String get workspaceConfigInvitationSingleUse;

  /// Subtitle chip of a kiosk device account in the members list (0043)
  ///
  /// In en, this message translates to:
  /// **'Kiosk'**
  String get memberKioskLabel;

  /// Owner action flagging a member account as a wall-mounted kiosk
  ///
  /// In en, this message translates to:
  /// **'Make kiosk device'**
  String get memberMakeKiosk;

  /// Owner action reverting a kiosk account to a regular member
  ///
  /// In en, this message translates to:
  /// **'Revert kiosk to member'**
  String get memberUnmakeKiosk;

  /// Tooltip of the badge-manager button on a member row
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get memberBadgesTooltip;

  /// Title of a member's badge-manager dialog
  ///
  /// In en, this message translates to:
  /// **'Badges — {name}'**
  String memberBadgesTitle(String name);

  /// Button minting a new kiosk badge for the member
  ///
  /// In en, this message translates to:
  /// **'New badge'**
  String get badgeIssue;

  /// Warning under the freshly issued badge QR; the raw token is never recoverable later
  ///
  /// In en, this message translates to:
  /// **'Save this QR now — it is shown only once.'**
  String get badgeTokenOnce;

  /// Empty state of the badge list
  ///
  /// In en, this message translates to:
  /// **'No badges yet.'**
  String get badgeNone;

  /// Fallback name of an unlabelled badge
  ///
  /// In en, this message translates to:
  /// **'Badge'**
  String get badgeDefaultLabel;

  /// Button revoking a badge (kiosks reject it from then on)
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get badgeRevoke;

  /// State line under a revoked badge
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get badgeRevoked;

  /// Generic dialog close action
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// Kiosk seat action: walk-up check-in (or into an existing reservation)
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get kioskCheckIn;

  /// Kiosk seat action: reserve the seat for today's window
  ///
  /// In en, this message translates to:
  /// **'Reserve'**
  String get kioskReserve;

  /// Kiosk seat action: complete the badge member's active check-in
  ///
  /// In en, this message translates to:
  /// **'Check out'**
  String get kioskCheckOut;

  /// Title of the kiosk badge prompt sheet
  ///
  /// In en, this message translates to:
  /// **'Present your badge'**
  String get kioskPresentBadge;

  /// Explainer in the badge prompt: wedge scanners type into the field
  ///
  /// In en, this message translates to:
  /// **'Scan your badge QR, or type its code.'**
  String get kioskBadgeHint;

  /// Label of the badge-code input
  ///
  /// In en, this message translates to:
  /// **'Badge code'**
  String get kioskBadgeFieldLabel;

  /// Submit button of the badge prompt
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get kioskBadgeConfirm;

  /// Error when kiosk_act rejects the presented badge (unknown/revoked)
  ///
  /// In en, this message translates to:
  /// **'Badge not recognized.'**
  String get kioskBadgeRejected;

  /// Success snackbar after a kiosk operation; the member is signed out already
  ///
  /// In en, this message translates to:
  /// **'Done — you\'re all set.'**
  String get kioskDone;

  /// Header hint on the kiosk plan view
  ///
  /// In en, this message translates to:
  /// **'Tap a seat to check in'**
  String get kioskTapHint;

  /// Badge dialog action: download the one-time QR as a printable badge card PDF
  ///
  /// In en, this message translates to:
  /// **'Save as PDF'**
  String get badgeSavePdf;

  /// Badge dialog action: register a physical RFID/NFC card as the member's badge (Android + NFC)
  ///
  /// In en, this message translates to:
  /// **'Register card'**
  String get badgeRegisterCard;

  /// Title of the tap-the-card prompt
  ///
  /// In en, this message translates to:
  /// **'Register a card'**
  String get badgeTapCardTitle;

  /// Instruction in the tap-the-card prompt
  ///
  /// In en, this message translates to:
  /// **'Hold the RFID/NFC card to the back of the device.'**
  String get badgeTapCardHint;

  /// Snackbar after an RFID/NFC card was registered as a badge
  ///
  /// In en, this message translates to:
  /// **'Card registered.'**
  String get badgeCardRegistered;

  /// Error when the tapped card's UID is already a badge in the workspace
  ///
  /// In en, this message translates to:
  /// **'That card is already registered.'**
  String get badgeCardAlreadyRegistered;

  /// Kiosk badge prompt hint when NFC is available (RFID tap path)
  ///
  /// In en, this message translates to:
  /// **'Tap your card, scan your QR, or type its code.'**
  String get kioskBadgeHintNfc;

  /// Owner NFC configuration screen title (0046)
  ///
  /// In en, this message translates to:
  /// **'RFID / NFC badges'**
  String get nfcConfigTitle;

  /// Intro on the NFC config screen
  ///
  /// In en, this message translates to:
  /// **'Members check in at a wall-mounted kiosk by tapping an RFID/NFC card. Register each member\'s card in Members & plans; at the kiosk they tap to reserve or check in.'**
  String get nfcConfigIntro;

  /// Workspace toggle for NFC badges
  ///
  /// In en, this message translates to:
  /// **'Enable NFC badge check-in'**
  String get nfcConfigEnable;

  /// Subtitle of the NFC enable toggle
  ///
  /// In en, this message translates to:
  /// **'Show the card-tap option on kiosks and in the badge manager.'**
  String get nfcConfigEnableDesc;

  /// Title of the device NFC status card
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get nfcConfigDeviceStatus;

  /// While the device NFC status is being read
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get nfcConfigChecking;

  /// Device NFC status: usable
  ///
  /// In en, this message translates to:
  /// **'NFC available and enabled'**
  String get nfcConfigDeviceReady;

  /// Device NFC status: not usable
  ///
  /// In en, this message translates to:
  /// **'No NFC here — Android with NFC on is needed (iPads have no NFC). QR badges still work.'**
  String get nfcConfigDeviceUnavailable;

  /// No description provided for @kioskConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get kioskConfirmAction;

  /// No description provided for @kioskRejectAction.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get kioskRejectAction;

  /// Title of the kiosk gate a kiosk account sees on every app start
  ///
  /// In en, this message translates to:
  /// **'Start kiosk mode?'**
  String get kioskGateTitle;

  /// Explainer on the kiosk gate: confirmed kiosk mode locks the pad until restart
  ///
  /// In en, this message translates to:
  /// **'This account is set up as the workspace kiosk. In kiosk mode the tablet only shows the floor plan for badge check-in — nothing else can be opened. To leave kiosk mode, restart the tablet.'**
  String get kioskGateBody;

  /// Gate button confirming and locking kiosk mode
  ///
  /// In en, this message translates to:
  /// **'Start kiosk mode'**
  String get kioskGateStart;

  /// Gate button rejecting kiosk mode for this run of the app
  ///
  /// In en, this message translates to:
  /// **'Not now — open the app normally'**
  String get kioskGateReject;

  /// Settings switch: badge QR scanning uses the screen-side camera (default on)
  ///
  /// In en, this message translates to:
  /// **'Scan with the front camera'**
  String get settingsFrontCamera;

  /// Subtitle of the front-camera switch
  ///
  /// In en, this message translates to:
  /// **'Badges are read with the screen-side camera — turn off to use the back camera.'**
  String get settingsFrontCameraDesc;

  /// Kiosk badge sheet RFID status: adapter present but disabled in Android settings
  ///
  /// In en, this message translates to:
  /// **'NFC is turned off in this tablet\'s Android settings — turn it on to read RFID cards.'**
  String get kioskNfcOff;

  /// Kiosk badge sheet RFID status: no NFC hardware on this device
  ///
  /// In en, this message translates to:
  /// **'This tablet has no NFC reader — scan the QR badge instead.'**
  String get kioskNfcUnsupported;

  /// Kiosk badge sheet RFID status: the read session failed to start (details in the trace)
  ///
  /// In en, this message translates to:
  /// **'The RFID reader did not start — restart the app and try again.'**
  String get kioskNfcFailed;

  /// Owner NFC config device status: adapter present but disabled in Android settings
  ///
  /// In en, this message translates to:
  /// **'NFC is turned off in this device\'s Android settings — turn it on to read RFID cards.'**
  String get nfcConfigDeviceOff;

  /// Kiosk badge sheet button mounting the camera for QR scanning while NFC card mode is active
  ///
  /// In en, this message translates to:
  /// **'Scan the QR badge'**
  String get kioskScanQr;

  /// Settings tile on a kiosk profile: revert this profile to a regular member (0056)
  ///
  /// In en, this message translates to:
  /// **'Kiosk device'**
  String get kioskRevertTitle;

  /// Subtitle of the kiosk revert tile and body of its confirm dialog
  ///
  /// In en, this message translates to:
  /// **'This profile is set up as the workspace kiosk. Revert it to a regular member to stop the kiosk question at start.'**
  String get kioskRevertDesc;

  /// Snackbar after the kiosk profile reverted itself
  ///
  /// In en, this message translates to:
  /// **'This profile is a regular member again.'**
  String get kioskRevertDone;

  /// Empty member-sheet explainer when the viewer has no actions for this row (e.g. an admin viewing a kiosk)
  ///
  /// In en, this message translates to:
  /// **'Only the workspace owner can change this member.'**
  String get memberNoActions;

  /// Kiosk error when a check-out finds no active check-in (#430)
  ///
  /// In en, this message translates to:
  /// **'No active check-in found — the plan may have just updated.'**
  String get kioskNotCheckedIn;

  /// Kiosk period chip after the working day: now until midnight
  ///
  /// In en, this message translates to:
  /// **'Rest of the day'**
  String get kioskRestOfDay;

  /// Kiosk period step hint for a check-in (start pinned to now)
  ///
  /// In en, this message translates to:
  /// **'Until when will you stay? Checking in starts now.'**
  String get kioskPeriodCheckInHint;

  /// Kiosk period step hint for a reservation (kiosk never books the future)
  ///
  /// In en, this message translates to:
  /// **'Pick the period — today only.'**
  String get kioskPeriodReserveHint;

  /// Kiosk period step switch: the reservation starts checked in
  ///
  /// In en, this message translates to:
  /// **'Check in right away'**
  String get kioskCheckInRightAway;

  /// Subtitle of the check-in-right-away switch
  ///
  /// In en, this message translates to:
  /// **'You\'re here — the reservation starts checked in.'**
  String get kioskCheckInRightAwayHint;

  /// Kiosk period step continue button — leads to the badge prompt
  ///
  /// In en, this message translates to:
  /// **'Present the badge'**
  String get kioskPresentBadgeNext;

  /// Kiosk summary title when a reservation starts checked in
  ///
  /// In en, this message translates to:
  /// **'Reserve & check in'**
  String get kioskReserveAndCheckIn;

  /// Confirmation before deleting a revoked badge by swipe (#523)
  ///
  /// In en, this message translates to:
  /// **'Delete this revoked badge for good?'**
  String get badgeDeleteConfirm;

  /// Kiosk banner/snack when today is not an open day (open weekdays or a closure day)
  ///
  /// In en, this message translates to:
  /// **'The workspace is closed today — check-in and reservations are not possible.'**
  String get kioskClosedToday;

  /// Kiosk sheet line naming the settings the derived window follows
  ///
  /// In en, this message translates to:
  /// **'Rule: {granularity} · today {hours}'**
  String kioskBasis(String granularity, String hours);

  /// Appended to a kiosk occupancy refusal: names the reservation holder and points to the app for messaging — the wall device itself cannot write as the member (#622)
  ///
  /// In en, this message translates to:
  /// **'Held by {name} — you can message them from the app on your phone.'**
  String kioskBlockedContactHint(String name);

  /// Settings entry and dialog title for the in-app language selection
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// Language option that follows the device locale instead of an override
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemDefault;

  /// No description provided for @levelReserveButton.
  ///
  /// In en, this message translates to:
  /// **'Reserve level'**
  String get levelReserveButton;

  /// No description provided for @levelReserveTitle.
  ///
  /// In en, this message translates to:
  /// **'Reserve the whole level'**
  String get levelReserveTitle;

  /// No description provided for @levelPermissionTile.
  ///
  /// In en, this message translates to:
  /// **'Level reservations'**
  String get levelPermissionTile;

  /// No description provided for @levelPermissionAllowed.
  ///
  /// In en, this message translates to:
  /// **'May reserve a whole desk, office or level'**
  String get levelPermissionAllowed;

  /// No description provided for @levelPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'May not reserve a whole desk, office or level'**
  String get levelPermissionDenied;

  /// No description provided for @levelBookableToggle.
  ///
  /// In en, this message translates to:
  /// **'Bookable as a whole'**
  String get levelBookableToggle;

  /// No description provided for @levelBookableDesc.
  ///
  /// In en, this message translates to:
  /// **'The whole floor can be reserved as one booking.'**
  String get levelBookableDesc;

  /// No description provided for @levelPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price per half-day'**
  String get levelPriceLabel;

  /// No description provided for @levelAssignMember.
  ///
  /// In en, this message translates to:
  /// **'For member'**
  String get levelAssignMember;

  /// No description provided for @levelAssignMyself.
  ///
  /// In en, this message translates to:
  /// **'Myself'**
  String get levelAssignMyself;

  /// No description provided for @levelSupplementLabel.
  ///
  /// In en, this message translates to:
  /// **'Level reservations'**
  String get levelSupplementLabel;

  /// No description provided for @levelNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'You are not allowed to reserve a whole desk, office or level.'**
  String get levelNotAllowed;

  /// No description provided for @levelConflict.
  ///
  /// In en, this message translates to:
  /// **'The level has reservations in that period.'**
  String get levelConflict;

  /// Refusal when the member already holds an overlapping active reservation (#412)
  ///
  /// In en, this message translates to:
  /// **'You already have a booking in that period — one place at a time.'**
  String get bookingOnePlace;

  /// Refusal when checking in while checked in elsewhere on a running reservation (#412)
  ///
  /// In en, this message translates to:
  /// **'You are checked in elsewhere — check out there first.'**
  String get bookingCheckedInElsewhere;

  /// Refusal when a desk/office/level lacks the bookable-as-a-whole toggle (#412)
  ///
  /// In en, this message translates to:
  /// **'This space is not set up for whole booking — the owner enables \"Bookable as a whole\" on it in the editor.'**
  String get spaceNotWholeBookable;

  /// Refusal when the officeLevelReservations feature is off (#412)
  ///
  /// In en, this message translates to:
  /// **'Office & level reservations are switched off in Features.'**
  String get levelFeatureOff;

  /// No description provided for @levelDetail.
  ///
  /// In en, this message translates to:
  /// **'Whole level'**
  String get levelDetail;

  /// No description provided for @kioskLevelButton.
  ///
  /// In en, this message translates to:
  /// **'This level'**
  String get kioskLevelButton;

  /// Bill line: sum of whole-office reservation prices this period (0057)
  ///
  /// In en, this message translates to:
  /// **'Office reservations'**
  String get officeSupplementLabel;

  /// Event/validation domain: whole desk/office/level reservations (0059)
  ///
  /// In en, this message translates to:
  /// **'Whole-space reservations'**
  String get eventTypeSpaceReservation;

  /// Detail-sheet line naming a whole-desk reservation
  ///
  /// In en, this message translates to:
  /// **'Whole desk'**
  String get deskDetail;

  /// Bill line: sum of whole-desk reservation prices this period (0059)
  ///
  /// In en, this message translates to:
  /// **'Desk reservations'**
  String get deskSupplementLabel;

  /// Level row booking-state subtitle in the editor (#466)
  ///
  /// In en, this message translates to:
  /// **'Bookable as a whole'**
  String get editorLevelBookableOn;

  /// Level row booking-state subtitle in the editor (#466)
  ///
  /// In en, this message translates to:
  /// **'Not bookable as a whole'**
  String get editorLevelBookableOff;

  /// No description provided for @bookingPastError.
  ///
  /// In en, this message translates to:
  /// **'This booking lies entirely in the past.'**
  String get bookingPastError;

  /// No description provided for @bookingWalkUpTodayError.
  ///
  /// In en, this message translates to:
  /// **'A walk-up check-in must start today.'**
  String get bookingWalkUpTodayError;

  /// No description provided for @bookingOutsideHoursError.
  ///
  /// In en, this message translates to:
  /// **'Bookings must stay within the working hours.'**
  String get bookingOutsideHoursError;

  /// No description provided for @bookingOutsideOffError.
  ///
  /// In en, this message translates to:
  /// **'Bookings outside the opening hours are not allowed.'**
  String get bookingOutsideOffError;

  /// #634 - refusal under the walkup_only outside-hours mode
  ///
  /// In en, this message translates to:
  /// **'Outside the opening hours only a spontaneous check-in is possible — booking ahead is not.'**
  String get bookingOutsideWalkUpError;

  /// No description provided for @bookingSameDayError.
  ///
  /// In en, this message translates to:
  /// **'A booking ends on the day it starts — book the next day separately.'**
  String get bookingSameDayError;

  /// Title of the owner-only member management screen + its settings entry
  ///
  /// In en, this message translates to:
  /// **'Members & plans'**
  String get membersTitle;

  /// Plan dropdown option for members without a plan
  ///
  /// In en, this message translates to:
  /// **'No plan'**
  String get membersPlanNone;

  /// Role tag on a member row
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get memberRoleOwner;

  /// Role tag on a member row
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get memberRoleAdmin;

  /// Status tag: membership paused (no fee, no access)
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get memberStatusPaused;

  /// Status tag: member left; ledger stays until settled
  ///
  /// In en, this message translates to:
  /// **'Exited'**
  String get memberStatusExited;

  /// App-bar action on the members screen linking to the workspace ID & QR invite surface (#195)
  ///
  /// In en, this message translates to:
  /// **'Invite a member'**
  String get membersInvite;

  /// Profile switcher screen (#89): one profile per workspace membership
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get profilesTitle;

  /// FAB opening create/join to add another membership
  ///
  /// In en, this message translates to:
  /// **'Add a profile'**
  String get profilesAdd;

  /// Semantic label of the active-profile check mark
  ///
  /// In en, this message translates to:
  /// **'Active profile'**
  String get profilesActive;

  /// Role chip for plain workers
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get memberRoleMember;

  /// Tapping a message reservation reference whose target was deleted (#523)
  ///
  /// In en, this message translates to:
  /// **'This reservation no longer exists.'**
  String get noteRefGone;

  /// Delete button on a message (sheet + confirm dialog, #523)
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get memberNoteDelete;

  /// Confirmation asked before any message delete — swipe or button (#523)
  ///
  /// In en, this message translates to:
  /// **'Delete this message? This cannot be undone.'**
  String get memberNoteDeleteConfirm;

  /// Reply button on the full-message sheet (#523)
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get memberNoteReply;

  /// Composer chip inserting a reservation reference (#523)
  ///
  /// In en, this message translates to:
  /// **'Link a reservation'**
  String get noteRefReservation;

  /// Composer chip inserting a seat/table/room/level reference (#523)
  ///
  /// In en, this message translates to:
  /// **'Link a space'**
  String get noteRefSpace;

  /// Reservation picker when the sender has nothing upcoming (#523)
  ///
  /// In en, this message translates to:
  /// **'No upcoming reservations to link.'**
  String get noteRefNoReservations;

  /// Space picker: the level-as-a-whole entry suffix (#523)
  ///
  /// In en, this message translates to:
  /// **'whole level'**
  String get noteRefWholeLevel;

  /// Member-sheet/profile action opening the conversation thread (messaging refactor)
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get memberMessagesAction;

  /// Empty state of a fresh conversation thread
  ///
  /// In en, this message translates to:
  /// **'No messages yet — say hello!'**
  String get conversationEmpty;

  /// Messages-inbox filter chip showing only unread messages (#539)
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notesFilterUnread;

  /// Empty state of the unread filter (#539)
  ///
  /// In en, this message translates to:
  /// **'No unread messages — all caught up.'**
  String get notesFilterEmpty;

  /// #687 - messaging centre
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get conversationGroup;

  /// #687 - messaging centre
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get conversationUnknownMember;

  /// #687 - messaging centre
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get conversationYesterday;

  /// #687 - messaging centre
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get conversationYou;

  /// #687 - messaging centre
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messagesTitle;

  /// #687 - messaging centre
  ///
  /// In en, this message translates to:
  /// **'No conversations yet.'**
  String get messagesEmpty;

  /// #687 - messaging centre
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String conversationMemberCount(int count);

  /// #687 - messaging centre
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get newConversationTitle;

  /// #687 - messaging centre
  ///
  /// In en, this message translates to:
  /// **'Search members'**
  String get newConversationSearch;

  /// #687 - messaging centre
  ///
  /// In en, this message translates to:
  /// **'Start chat'**
  String get newConversationStart;

  /// #687 - messaging centre
  ///
  /// In en, this message translates to:
  /// **'Nobody else here yet.'**
  String get newConversationNoMembers;

  /// #687 - messaging centre
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get newGroupName;

  /// #687 - messaging centre
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get newGroupCreate;

  /// #687 - messaging centre
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get conversationGroupInfo;

  /// #687 - messaging centre
  ///
  /// In en, this message translates to:
  /// **'Add people'**
  String get conversationAddPeople;

  /// #687 - messaging centre
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get conversationLeave;

  /// #687 - messaging centre
  ///
  /// In en, this message translates to:
  /// **'Leave this group? You stop receiving its messages; what you already sent stays.'**
  String get conversationLeaveConfirm;

  /// #687 - messaging centre
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get conversationRemove;

  /// #687 - messaging centre
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get conversationAdmin;

  /// #687 - messaging centre
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get conversationLeft;

  /// #687 - messaging search
  ///
  /// In en, this message translates to:
  /// **'People, groups, messages'**
  String get messageSearchHint;

  /// #687 - messaging search
  ///
  /// In en, this message translates to:
  /// **'Search people, groups and what was said.'**
  String get messageSearchPrompt;

  /// #687 - messaging search
  ///
  /// In en, this message translates to:
  /// **'Nothing matched.'**
  String get messageSearchNothing;

  /// #687 - messaging search
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get messageSearchPeople;

  /// #687 - messaging search
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get messageSearchGroups;

  /// #687 - messaging search
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messageSearchMessages;

  /// #687 - messaging search
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get messageSearchTitle;

  /// #694 - group names are unique per workspace
  ///
  /// In en, this message translates to:
  /// **'A group with that name already exists here. Pick another.'**
  String get newGroupNameTaken;

  /// #695 - profile from a conversation
  ///
  /// In en, this message translates to:
  /// **'See profile'**
  String get conversationSeeProfile;

  /// #702 - the inbox tab that holds conversations
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get inboxChatsTab;

  /// #704 - the money section of a member profile
  ///
  /// In en, this message translates to:
  /// **'Nothing outstanding.'**
  String get memberMoneySettled;

  /// #704 - the money section of a member profile
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String memberMoreInvoices(int count);

  /// #704 - the money section of a member profile
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get memberMonthInProgress;

  /// #704 - the money section of a member profile
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get memberPayments;

  /// #704 - the money section of a member profile
  ///
  /// In en, this message translates to:
  /// **'{amount} open'**
  String memberInvoiceOpen(String amount);

  /// #704 - the money section of a member profile
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get memberInvoicePaid;

  /// #704 - the money section of a member profile
  ///
  /// In en, this message translates to:
  /// **'Voided'**
  String get memberInvoiceVoided;

  /// #704 - the contact section of a member profile
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get memberContactHeading;

  /// #704 - the contact section of a member profile
  ///
  /// In en, this message translates to:
  /// **'Plan {pct}%'**
  String memberPlanShare(String pct);

  /// #709 - the money section of a profile could not be read
  ///
  /// In en, this message translates to:
  /// **'Money could not be loaded. Pull to refresh.'**
  String get memberMoneyUnavailable;

  /// No description provided for @inboxAlertsTab.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get inboxAlertsTab;

  /// No description provided for @inboxFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get inboxFilterAll;

  /// No description provided for @inboxFilterUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get inboxFilterUnread;

  /// No description provided for @inboxFilterArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get inboxFilterArchived;

  /// No description provided for @inboxNoUnread.
  ///
  /// In en, this message translates to:
  /// **'Nothing unread — you are up to date.'**
  String get inboxNoUnread;

  /// No description provided for @inboxNoArchived.
  ///
  /// In en, this message translates to:
  /// **'No archived conversations.'**
  String get inboxNoArchived;

  /// No description provided for @conversationPin.
  ///
  /// In en, this message translates to:
  /// **'Pin to top'**
  String get conversationPin;

  /// No description provided for @conversationUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get conversationUnpin;

  /// No description provided for @conversationMute.
  ///
  /// In en, this message translates to:
  /// **'Mute notifications'**
  String get conversationMute;

  /// No description provided for @conversationUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get conversationUnmute;

  /// No description provided for @conversationMarkUnread.
  ///
  /// In en, this message translates to:
  /// **'Mark as unread'**
  String get conversationMarkUnread;

  /// No description provided for @conversationArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get conversationArchive;

  /// No description provided for @conversationUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Restore from archive'**
  String get conversationUnarchive;

  /// No description provided for @conversationArchived.
  ///
  /// In en, this message translates to:
  /// **'Conversation archived.'**
  String get conversationArchived;

  /// No description provided for @conversationMutedBadge.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get conversationMutedBadge;

  /// No description provided for @conversationLoadEarlier.
  ///
  /// In en, this message translates to:
  /// **'Load earlier messages'**
  String get conversationLoadEarlier;

  /// No description provided for @conversationToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get conversationToday;

  /// No description provided for @composerAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach a reference'**
  String get composerAttach;

  /// No description provided for @composerCharsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} characters left'**
  String composerCharsLeft(int count);

  /// No description provided for @composerDraftKept.
  ///
  /// In en, this message translates to:
  /// **'Draft kept'**
  String get composerDraftKept;

  /// No description provided for @newConversationTapToOpen.
  ///
  /// In en, this message translates to:
  /// **'Tap a person to open the chat; switch on Group to pick several.'**
  String get newConversationTapToOpen;

  /// No description provided for @newConversationGroupSwitch.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get newConversationGroupSwitch;

  /// No description provided for @inboxRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get inboxRetry;

  /// No description provided for @memberNoteDeleteRead.
  ///
  /// In en, this message translates to:
  /// **'Already read — this message can no longer be taken back.'**
  String get memberNoteDeleteRead;

  /// No description provided for @memberNoteDeleteNotMine.
  ///
  /// In en, this message translates to:
  /// **'Only the sender can take a message back.'**
  String get memberNoteDeleteNotMine;

  /// #842 - label of the filter field in a reference picker
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get noteRefFilterLabel;

  /// #842 - how many candidates the filter is showing
  ///
  /// In en, this message translates to:
  /// **'{shown} of {total}'**
  String noteRefFilterCount(int shown, int total);

  /// #842 - the filter matched nothing
  ///
  /// In en, this message translates to:
  /// **'Nothing matches.'**
  String get noteRefFilterEmpty;

  /// #842 - attach-menu entry: reference an alert
  ///
  /// In en, this message translates to:
  /// **'Alert'**
  String get noteRefAlert;

  /// #842 - attach-menu entry: reference a validation
  ///
  /// In en, this message translates to:
  /// **'Validation'**
  String get noteRefValidation;

  /// #842 - attach-menu entry: reference an invoice
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get noteRefInvoice;

  /// #842 - attach-menu entry: reference a payment
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get noteRefPayment;

  /// #842 - label of a refund reference
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get noteRefRefund;

  /// #842 - title of the alert picker
  ///
  /// In en, this message translates to:
  /// **'Which alert?'**
  String get noteRefPickAlert;

  /// #842 - title of the validation picker
  ///
  /// In en, this message translates to:
  /// **'Which validation?'**
  String get noteRefPickValidation;

  /// #842 - title of the invoice picker
  ///
  /// In en, this message translates to:
  /// **'Which invoice?'**
  String get noteRefPickInvoice;

  /// #842 - title of the payment picker
  ///
  /// In en, this message translates to:
  /// **'Which payment?'**
  String get noteRefPickPayment;

  /// #842 - there is nothing of that kind to reference
  ///
  /// In en, this message translates to:
  /// **'Nothing to reference yet.'**
  String get noteRefNone;

  /// Statement line for the plan's monthly fee
  ///
  /// In en, this message translates to:
  /// **'Base subscription'**
  String get moneyBaseFee;

  /// Statement usage line for quota plans
  ///
  /// In en, this message translates to:
  /// **'{used} of {included} half-days used'**
  String moneyUsage(int used, int included);

  /// Statement usage line for unlimited plans
  ///
  /// In en, this message translates to:
  /// **'{used} half-days used'**
  String moneyUsageUnlimited(int used);

  /// Statement line for usage beyond the included quota
  ///
  /// In en, this message translates to:
  /// **'Overage ({count} extra half-days)'**
  String moneyOverage(int count);

  /// Statement line summing confirmed payments and credits
  ///
  /// In en, this message translates to:
  /// **'Payments & credits'**
  String get moneyCredits;

  /// Statement bottom line; negative = member owes
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get moneyBalance;

  /// Chip when the period balance is zero or positive
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get moneyStatementSettled;

  /// Chip when the member still owes for the period
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get moneyStatementOpen;

  /// Button + sheet title for recording a made payment
  ///
  /// In en, this message translates to:
  /// **'Record a payment'**
  String get moneyRecordPayment;

  /// Label of the payment amount input
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get moneyAmountLabel;

  /// Label of the payment note input
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get moneyNoteLabel;

  /// Submit button — the payment stays pending until the other side confirms (spec §7.4)
  ///
  /// In en, this message translates to:
  /// **'Submit for confirmation'**
  String get moneySubmitPayment;

  /// Snackbar after recording a payment
  ///
  /// In en, this message translates to:
  /// **'Payment submitted — waiting for confirmation.'**
  String get moneyPaymentPending;

  /// Header above the ledger entry list
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get moneyLedgerHeader;

  /// Empty state of the ledger list
  ///
  /// In en, this message translates to:
  /// **'No ledger entries yet.'**
  String get moneyLedgerEmpty;

  /// Button + sheet title for community expenses (spec §9)
  ///
  /// In en, this message translates to:
  /// **'Submit an expense'**
  String get moneySubmitExpense;

  /// Label of the expense category dropdown
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get moneyExpenseCategoryLabel;

  /// Label of the expense description input
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get moneyDescriptionLabel;

  /// Snackbar after submitting an expense (another admin approves)
  ///
  /// In en, this message translates to:
  /// **'Expense submitted — waiting for approval.'**
  String get moneyExpensePending;

  /// Expense category option
  ///
  /// In en, this message translates to:
  /// **'Coffee & kitchen'**
  String get expenseCategoryCoffee;

  /// Expense category option
  ///
  /// In en, this message translates to:
  /// **'Supplies'**
  String get expenseCategorySupplies;

  /// Expense category option
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get expenseCategoryEquipment;

  /// Expense category option
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get expenseCategoryOther;

  /// Ledger entry category
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get ledgerCategorySubscription;

  /// Ledger entry category
  ///
  /// In en, this message translates to:
  /// **'Overage'**
  String get ledgerCategoryOverage;

  /// Ledger entry category
  ///
  /// In en, this message translates to:
  /// **'Expense reimbursement'**
  String get ledgerCategoryExpense;

  /// Ledger entry category
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get ledgerCategoryPayment;

  /// Ledger entry category
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get ledgerCategoryAdjustment;

  /// Ledger entry category for confirmed service charges (#129)
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get ledgerCategoryService;

  /// Owner plan-editor screen title (#105)
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get plansEditorTitle;

  /// FAB tooltip / sheet title creating a plan
  ///
  /// In en, this message translates to:
  /// **'New plan'**
  String get plansEditorNew;

  /// Sheet title editing a plan
  ///
  /// In en, this message translates to:
  /// **'Edit plan'**
  String get plansEditorEdit;

  /// Trailing label on deactivated plans
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get plansEditorInactive;

  /// Quota summary when included_half_days is null
  ///
  /// In en, this message translates to:
  /// **'unlimited half-days'**
  String get plansEditorUnlimited;

  /// Quota summary
  ///
  /// In en, this message translates to:
  /// **'{count} half-days'**
  String plansEditorQuota(int count);

  /// Overage summary; price is preformatted currency
  ///
  /// In en, this message translates to:
  /// **'{price}/extra half-day'**
  String plansEditorPerExtra(String price);

  /// Plan name field label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get planNameLabel;

  /// Base fee field label
  ///
  /// In en, this message translates to:
  /// **'Monthly base fee'**
  String get planBaseFeeLabel;

  /// Included half-days field label
  ///
  /// In en, this message translates to:
  /// **'Included half-days'**
  String get planIncludedLabel;

  /// Helper: empty quota means unlimited
  ///
  /// In en, this message translates to:
  /// **'Leave empty for unlimited'**
  String get planIncludedHelper;

  /// Overage price field label
  ///
  /// In en, this message translates to:
  /// **'Price per extra half-day'**
  String get planOverageLabel;

  /// Active switch label
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get planActiveLabel;

  /// Payment-method chip/label: SEPA/bank transfer (#154).
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get paymentMethodBankTransfer;

  /// Payment-method chip/label: cash (#154).
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentMethodCash;

  /// Payment-method chip/label: PayPal — brand name, identical in every locale (#154).
  ///
  /// In en, this message translates to:
  /// **'PayPal'**
  String get paymentMethodPaypal;

  /// Payment-method chip/label: TWINT — brand name, identical in every locale (#154).
  ///
  /// In en, this message translates to:
  /// **'TWINT'**
  String get paymentMethodTwint;

  /// Payment-method chip/label: debit/credit card (#154).
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get paymentMethodCard;

  /// Payment-method chip/label: anything else (#154).
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get paymentMethodOther;

  /// Payment-method chip/label: Wero — brand name, identical in every locale (#192).
  ///
  /// In en, this message translates to:
  /// **'Wero'**
  String get paymentMethodWero;

  /// Payment-method chip/label: Lydia — brand name, identical in every locale (#192).
  ///
  /// In en, this message translates to:
  /// **'Lydia'**
  String get paymentMethodLydia;

  /// Payment-method chip/label: Wise — brand name, identical in every locale (#192).
  ///
  /// In en, this message translates to:
  /// **'Wise'**
  String get paymentMethodWise;

  /// Payment sheet: the day the money actually moved (0070)
  ///
  /// In en, this message translates to:
  /// **'Payment date'**
  String get moneyPaymentDateLabel;

  /// Payment sheet: the month the payment settles — decides which bill and invoice it lands on
  ///
  /// In en, this message translates to:
  /// **'Applies to'**
  String get moneyPaymentPeriodLabel;

  /// Finance/settings UX + workspace language (#486)
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get moneySectionPay;

  /// Finance/settings UX + workspace language (#486)
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get moneySectionRequests;

  /// Finance/settings UX + workspace language (#486)
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get moneySectionDocuments;

  /// Title of the periodic VAT declaration screen/PDF (#534)
  ///
  /// In en, this message translates to:
  /// **'VAT declaration'**
  String get vatDeclTitle;

  /// Filing-period label
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get vatDeclPeriod;

  /// Seller identity line on the declaration PDF
  ///
  /// In en, this message translates to:
  /// **'Seller'**
  String get vatDeclSeller;

  /// VAT identifier label
  ///
  /// In en, this message translates to:
  /// **'VAT ID'**
  String get vatDeclVatId;

  /// Rate column
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get vatDeclRate;

  /// Net taxable base column
  ///
  /// In en, this message translates to:
  /// **'Net base'**
  String get vatDeclNet;

  /// Tax amount column
  ///
  /// In en, this message translates to:
  /// **'VAT'**
  String get vatDeclVat;

  /// Invoice-count column
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get vatDeclInvoices;

  /// Totals row
  ///
  /// In en, this message translates to:
  /// **'Totals'**
  String get vatDeclTotals;

  /// Header of the official-box mapping (CA3/UStVA)
  ///
  /// In en, this message translates to:
  /// **'Official form lines'**
  String get vatDeclBoxes;

  /// Box-code column
  ///
  /// In en, this message translates to:
  /// **'Box'**
  String get vatDeclBox;

  /// Status label on the PDF
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get vatDeclStatus;

  /// Disclaimer at the bottom of the declaration PDF
  ///
  /// In en, this message translates to:
  /// **'Generated from the period’s issued invoices. Verify against your accounting before filing — this is a filing aid, not tax advice.'**
  String get vatDeclDisclaimer;

  /// Generate-declaration button
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get vatDeclGenerate;

  /// Empty state of the declarations list
  ///
  /// In en, this message translates to:
  /// **'No declarations yet — pick a period and generate the first one.'**
  String get vatDeclEmpty;

  /// Draft status chip
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get vatDeclDraft;

  /// Submitted status chip
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get vatDeclSubmitted;

  /// Send through the configured platform channel
  ///
  /// In en, this message translates to:
  /// **'Transmit'**
  String get vatDeclTransmit;

  /// Manual-filing action
  ///
  /// In en, this message translates to:
  /// **'Mark as filed'**
  String get vatDeclMarkFiled;

  /// Confirmation before marking a declaration manually filed
  ///
  /// In en, this message translates to:
  /// **'Confirm you filed this declaration yourself (tax-office portal or your accountant). It becomes immutable.'**
  String get vatDeclMarkFiledConfirm;

  /// Machine-readable export button
  ///
  /// In en, this message translates to:
  /// **'XML export'**
  String get vatDeclXml;

  /// PDF button on a declaration card
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get vatDeclPdf;

  /// Success snack after platform transmission
  ///
  /// In en, this message translates to:
  /// **'Declaration transmitted.'**
  String get vatDeclSent;

  /// Error snack when the platform rejects
  ///
  /// In en, this message translates to:
  /// **'The platform refused the declaration.'**
  String get vatDeclRejected;

  /// Gate banner when the workspace is not vat_registered
  ///
  /// In en, this message translates to:
  /// **'Declarations exist only under the VAT-registered regime — configure it under VAT settings.'**
  String get vatDeclRegimeGate;

  /// Feature toggle title: VAT management (#544)
  ///
  /// In en, this message translates to:
  /// **'VAT management'**
  String get featureVatManagementTitle;

  /// Feature toggle description: VAT management (#544)
  ///
  /// In en, this message translates to:
  /// **'The VAT rate editor and the rate pickers on services, packs, accessories and the tariff. Off hides the configuration; stored rates keep applying.'**
  String get featureVatManagementDesc;

  /// Feature toggle title (#534)
  ///
  /// In en, this message translates to:
  /// **'VAT declarations'**
  String get featureVatDeclarationsTitle;

  /// Feature toggle description (#534)
  ///
  /// In en, this message translates to:
  /// **'Generate the periodic VAT return from issued invoices, map it to the official form and transmit or export it.'**
  String get featureVatDeclarationsDesc;

  /// Features screen: e-invoice customer delivery flag name (#568)
  ///
  /// In en, this message translates to:
  /// **'E-invoice delivery to customers'**
  String get featureEinvoiceCustomerDeliveryTitle;

  /// Features screen: e-invoice customer delivery flag description (#568)
  ///
  /// In en, this message translates to:
  /// **'A second sending channel beside the government platform: post the issued invoice straight to the customer\'s own e-invoicing service.'**
  String get featureEinvoiceCustomerDeliveryDesc;

  /// Suffix after a gross price naming the included VAT rate (#537)
  ///
  /// In en, this message translates to:
  /// **'incl. VAT {rate}'**
  String priceVatIncluded(String rate);

  /// Hint under the billing fee-band section under a VAT-charging regime (#537)
  ///
  /// In en, this message translates to:
  /// **'Prices are gross — VAT {rate} (the workspace default rate) is included.'**
  String billingPricesVatHint(String rate);

  /// Fee-band hint when the tariff carries its own configured rate (#542)
  ///
  /// In en, this message translates to:
  /// **'Prices are gross — VAT {rate} (the tariff rate) is included.'**
  String billingTariffVatHint(String rate);

  /// Title above the new-day-pack form on the billing screen (#537)
  ///
  /// In en, this message translates to:
  /// **'New package'**
  String get billingNewPackage;

  /// Helper under price inputs clarifying gross-inclusive pricing (#537)
  ///
  /// In en, this message translates to:
  /// **'Gross price — what the member pays; VAT is part of it.'**
  String get priceGrossHint;

  /// Helper under an amount field: the VAT share contained in the gross amount (#537)
  ///
  /// In en, this message translates to:
  /// **'incl. VAT {amount}'**
  String vatShareAmount(String amount);

  /// Report page designer: the editable-fields mode (#548)
  ///
  /// In en, this message translates to:
  /// **'Design'**
  String get reportDesignerDesign;

  /// Report page designer: the merged-data preview mode (#548)
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get reportDesignerPreview;

  /// Report page designer: zoom menu tooltip (#548)
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get reportDesignerZoom;

  /// Report page designer: fit-the-width zoom option (#548)
  ///
  /// In en, this message translates to:
  /// **'Fit width'**
  String get reportDesignerZoomFit;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Bank name'**
  String get paymentBankNameLabel;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Account number'**
  String get paymentAccountNumberLabel;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Sort code'**
  String get paymentSortCodeLabel;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Routing number'**
  String get paymentRoutingNumberLabel;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Transit · institution'**
  String get paymentTransitNumberLabel;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Bank code'**
  String get paymentBankCodeLabel;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'BIC / SWIFT'**
  String get paymentBicLabel;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Copied.'**
  String get paymentCopied;

  /// No description provided for @moneyFacePayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get moneyFacePayments;

  /// No description provided for @moneyFaceInvoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get moneyFaceInvoices;

  /// No description provided for @moneyNoInvoicesYet.
  ///
  /// In en, this message translates to:
  /// **'No invoice yet — the month is invoiced by the workspace once it closes.'**
  String get moneyNoInvoicesYet;

  /// No description provided for @moneyFaceStatement.
  ///
  /// In en, this message translates to:
  /// **'Statement'**
  String get moneyFaceStatement;

  /// No description provided for @moneyFaceDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get moneyFaceDocuments;

  /// No description provided for @moneyOverdueBanner.
  ///
  /// In en, this message translates to:
  /// **'{count} overdue — {amount} to settle'**
  String moneyOverdueBanner(int count, String amount);

  /// No description provided for @moneyPayNow.
  ///
  /// In en, this message translates to:
  /// **'Pay now'**
  String get moneyPayNow;

  /// No description provided for @moneyOpenInvoicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Open invoices'**
  String get moneyOpenInvoicesTitle;

  /// No description provided for @moneyOpenInvoicesSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} open · {amount} due'**
  String moneyOpenInvoicesSummary(int count, String amount);

  /// No description provided for @moneyDueIn.
  ///
  /// In en, this message translates to:
  /// **'Due in {days} days'**
  String moneyDueIn(int days);

  /// No description provided for @moneyOverdueBy.
  ///
  /// In en, this message translates to:
  /// **'Overdue by {days} days'**
  String moneyOverdueBy(int days);

  /// No description provided for @moneyNothingOpen.
  ///
  /// In en, this message translates to:
  /// **'Nothing open — you are up to date.'**
  String get moneyNothingOpen;

  /// No description provided for @moneyDocumentLibrary.
  ///
  /// In en, this message translates to:
  /// **'Document library'**
  String get moneyDocumentLibrary;

  /// No description provided for @moneyStatementPdf.
  ///
  /// In en, this message translates to:
  /// **'This month\'s statement (PDF)'**
  String get moneyStatementPdf;

  /// No description provided for @moneyRemindedTimes.
  ///
  /// In en, this message translates to:
  /// **'Reminded ×{count}'**
  String moneyRemindedTimes(int count);

  /// No description provided for @expenseSupplyToggle.
  ///
  /// In en, this message translates to:
  /// **'This is a supply for the space'**
  String get expenseSupplyToggle;

  /// No description provided for @expenseSupplyHint.
  ///
  /// In en, this message translates to:
  /// **'Coffee capsules, vacuum bags… Once validated, the item goes on the shelf as a consumable service: members who use it pay for it.'**
  String get expenseSupplyHint;

  /// No description provided for @expenseSupplyItem.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get expenseSupplyItem;

  /// No description provided for @expenseSupplyNewItem.
  ///
  /// In en, this message translates to:
  /// **'New item'**
  String get expenseSupplyNewItem;

  /// No description provided for @expenseSupplyQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get expenseSupplyQuantity;

  /// No description provided for @expenseSupplyUnitPrice.
  ///
  /// In en, this message translates to:
  /// **'Unit price (what a consumption costs)'**
  String get expenseSupplyUnitPrice;

  /// No description provided for @expenseSupplyUnitPriceHint.
  ///
  /// In en, this message translates to:
  /// **'Prefilled from amount ÷ quantity; round up if you like.'**
  String get expenseSupplyUnitPriceHint;

  /// No description provided for @serviceStockCount.
  ///
  /// In en, this message translates to:
  /// **'{count} in stock'**
  String serviceStockCount(int count);

  /// No description provided for @serviceOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get serviceOutOfStock;

  /// No description provided for @serviceOutOfStockHint.
  ///
  /// In en, this message translates to:
  /// **'Nothing left on the shelf — the next supply restocks it.'**
  String get serviceOutOfStockHint;

  /// No description provided for @negotiationCardTitle.
  ///
  /// In en, this message translates to:
  /// **'My negotiated prices'**
  String get negotiationCardTitle;

  /// No description provided for @negotiationOnTariff.
  ///
  /// In en, this message translates to:
  /// **'You are on the workspace tariff.'**
  String get negotiationOnTariff;

  /// No description provided for @negotiationPending.
  ///
  /// In en, this message translates to:
  /// **'A deal is awaiting validation.'**
  String get negotiationPending;

  /// No description provided for @negotiationActiveSince.
  ///
  /// In en, this message translates to:
  /// **'Your deal applies since {month}.'**
  String negotiationActiveSince(String month);

  /// No description provided for @negotiationFee.
  ///
  /// In en, this message translates to:
  /// **'Monthly fee'**
  String get negotiationFee;

  /// No description provided for @negotiationOverage.
  ///
  /// In en, this message translates to:
  /// **'Overage per half-day'**
  String get negotiationOverage;

  /// No description provided for @negotiationDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount on supplements'**
  String get negotiationDiscount;

  /// No description provided for @negotiationDefaultColumn.
  ///
  /// In en, this message translates to:
  /// **'Tariff'**
  String get negotiationDefaultColumn;

  /// No description provided for @negotiationMineColumn.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get negotiationMineColumn;

  /// No description provided for @negotiationWhoCanSee.
  ///
  /// In en, this message translates to:
  /// **'Who can see this'**
  String get negotiationWhoCanSee;

  /// No description provided for @negotiationProposeTitle.
  ///
  /// In en, this message translates to:
  /// **'Price negotiation'**
  String get negotiationProposeTitle;

  /// No description provided for @negotiationProposeHint.
  ///
  /// In en, this message translates to:
  /// **'Leave a field empty to keep the tariff. The deal goes through validation before it applies.'**
  String get negotiationProposeHint;

  /// No description provided for @negotiationNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get negotiationNote;

  /// No description provided for @negotiationValidFrom.
  ///
  /// In en, this message translates to:
  /// **'Applies from'**
  String get negotiationValidFrom;

  /// No description provided for @negotiationSubmit.
  ///
  /// In en, this message translates to:
  /// **'Propose for validation'**
  String get negotiationSubmit;

  /// No description provided for @negotiationProposed.
  ///
  /// In en, this message translates to:
  /// **'Deal proposed — waiting for validation.'**
  String get negotiationProposed;

  /// No description provided for @negotiationPendingBadge.
  ///
  /// In en, this message translates to:
  /// **'awaiting validation'**
  String get negotiationPendingBadge;

  /// No description provided for @negotiationOccupation.
  ///
  /// In en, this message translates to:
  /// **'Occupation'**
  String get negotiationOccupation;

  /// No description provided for @negotiationOccupationHint.
  ///
  /// In en, this message translates to:
  /// **'The share of open days included each month; applied to the member once validated.'**
  String get negotiationOccupationHint;

  /// No description provided for @negotiationKeepCurrent.
  ///
  /// In en, this message translates to:
  /// **'Keep current'**
  String get negotiationKeepCurrent;

  /// No description provided for @negotiationItems.
  ///
  /// In en, this message translates to:
  /// **'Services and packages'**
  String get negotiationItems;

  /// No description provided for @negotiationItemsHint.
  ///
  /// In en, this message translates to:
  /// **'A unit price for this member; empty keeps the catalogue.'**
  String get negotiationItemsHint;

  /// No description provided for @negotiationPercent.
  ///
  /// In en, this message translates to:
  /// **'{value} %'**
  String negotiationPercent(int value);

  /// No description provided for @negotiationReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read only'**
  String get negotiationReadOnly;

  /// No description provided for @scheduledExpensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Scheduled expenses'**
  String get scheduledExpensesTitle;

  /// No description provided for @scheduledExpensesIntro.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions the space pays for — internet, phone, electricity. The schedule is validated once; every due date is presented to you before it counts.'**
  String get scheduledExpensesIntro;

  /// No description provided for @scheduledExpensesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No scheduled expense yet.'**
  String get scheduledExpensesEmpty;

  /// No description provided for @scheduleNew.
  ///
  /// In en, this message translates to:
  /// **'Schedule a recurring expense'**
  String get scheduleNew;

  /// No description provided for @scheduleCancel.
  ///
  /// In en, this message translates to:
  /// **'End this schedule'**
  String get scheduleCancel;

  /// No description provided for @scheduleTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'What (e.g. Internet)'**
  String get scheduleTitleLabel;

  /// No description provided for @scheduleStartsOn.
  ///
  /// In en, this message translates to:
  /// **'First occurrence'**
  String get scheduleStartsOn;

  /// No description provided for @scheduleEveryLabel.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get scheduleEveryLabel;

  /// No description provided for @scheduleUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get scheduleUnitLabel;

  /// No description provided for @scheduleTimesLabel.
  ///
  /// In en, this message translates to:
  /// **'Repetitions (empty = until the end date)'**
  String get scheduleTimesLabel;

  /// No description provided for @scheduleEndsOn.
  ///
  /// In en, this message translates to:
  /// **'Until (optional)'**
  String get scheduleEndsOn;

  /// No description provided for @scheduleNoEnd.
  ///
  /// In en, this message translates to:
  /// **'No end date'**
  String get scheduleNoEnd;

  /// No description provided for @scheduleValidationHint.
  ///
  /// In en, this message translates to:
  /// **'The schedule goes to the validators first. Each due date is then presented to you: confirmed at this amount it counts immediately; a different amount explains itself and is validated again.'**
  String get scheduleValidationHint;

  /// No description provided for @scheduleSubmit.
  ///
  /// In en, this message translates to:
  /// **'Schedule it'**
  String get scheduleSubmit;

  /// No description provided for @scheduleMissingFields.
  ///
  /// In en, this message translates to:
  /// **'Name and amount are needed.'**
  String get scheduleMissingFields;

  /// No description provided for @schedulePending.
  ///
  /// In en, this message translates to:
  /// **'Scheduled — waiting for the validators to confirm it.'**
  String get schedulePending;

  /// No description provided for @scheduleStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Awaiting validation'**
  String get scheduleStatusPending;

  /// No description provided for @scheduleStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get scheduleStatusActive;

  /// No description provided for @scheduleStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get scheduleStatusRejected;

  /// No description provided for @scheduleStatusEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get scheduleStatusEnded;

  /// No description provided for @scheduleDaily.
  ///
  /// In en, this message translates to:
  /// **'daily'**
  String get scheduleDaily;

  /// No description provided for @scheduleWeekly.
  ///
  /// In en, this message translates to:
  /// **'weekly'**
  String get scheduleWeekly;

  /// No description provided for @scheduleMonthly.
  ///
  /// In en, this message translates to:
  /// **'monthly'**
  String get scheduleMonthly;

  /// No description provided for @scheduleYearly.
  ///
  /// In en, this message translates to:
  /// **'yearly'**
  String get scheduleYearly;

  /// No description provided for @scheduleEveryDays.
  ///
  /// In en, this message translates to:
  /// **'every {count} days'**
  String scheduleEveryDays(Object count);

  /// No description provided for @scheduleEveryWeeks.
  ///
  /// In en, this message translates to:
  /// **'every {count} weeks'**
  String scheduleEveryWeeks(Object count);

  /// No description provided for @scheduleEveryMonths.
  ///
  /// In en, this message translates to:
  /// **'every {count} months'**
  String scheduleEveryMonths(Object count);

  /// No description provided for @scheduleTimes.
  ///
  /// In en, this message translates to:
  /// **'{count} times'**
  String scheduleTimes(Object count);

  /// No description provided for @scheduleUntil.
  ///
  /// In en, this message translates to:
  /// **'until {date}'**
  String scheduleUntil(Object date);

  /// No description provided for @scheduleNextDue.
  ///
  /// In en, this message translates to:
  /// **'next: {date}'**
  String scheduleNextDue(Object date);

  /// No description provided for @occurrenceRejected.
  ///
  /// In en, this message translates to:
  /// **'The validators rejected it — adjust the amount or the description and resend.'**
  String get occurrenceRejected;

  /// No description provided for @occurrenceScheduledAmount.
  ///
  /// In en, this message translates to:
  /// **'Validated: {amount}'**
  String occurrenceScheduledAmount(Object amount);

  /// No description provided for @occurrenceReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Why it differs (required)'**
  String get occurrenceReasonLabel;

  /// No description provided for @occurrenceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm this expense'**
  String get occurrenceConfirm;

  /// No description provided for @occurrenceResend.
  ///
  /// In en, this message translates to:
  /// **'Resend for validation'**
  String get occurrenceResend;

  /// No description provided for @occurrenceReasonMissing.
  ///
  /// In en, this message translates to:
  /// **'A different amount needs an explanation.'**
  String get occurrenceReasonMissing;

  /// No description provided for @occurrenceSentForValidation.
  ///
  /// In en, this message translates to:
  /// **'Sent to the validators — it counts once they confirm.'**
  String get occurrenceSentForValidation;

  /// No description provided for @occurrenceAdded.
  ///
  /// In en, this message translates to:
  /// **'Added to your expenses.'**
  String get occurrenceAdded;

  /// No description provided for @scheduledAwaitingTitle.
  ///
  /// In en, this message translates to:
  /// **'Scheduled expenses awaiting you'**
  String get scheduledAwaitingTitle;

  /// No description provided for @scheduleUnitDays.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get scheduleUnitDays;

  /// No description provided for @scheduleUnitWeeks.
  ///
  /// In en, this message translates to:
  /// **'weeks'**
  String get scheduleUnitWeeks;

  /// No description provided for @scheduleUnitMonths.
  ///
  /// In en, this message translates to:
  /// **'months'**
  String get scheduleUnitMonths;

  /// No description provided for @scheduleUnitYears.
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get scheduleUnitYears;

  /// #833 - the Money tab face showing usage records
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get moneyFaceUsage;

  /// The recurring position on an ASSOCIATION's bill and invoice (#870). A non-profit collects a member participation, not a subscription: 'abonnement' reads as a commercial supply and can pull the association into the VAT-liable trading sector, so the wording follows the seller kind.
  ///
  /// In en, this message translates to:
  /// **'Participation {pct}%'**
  String billParticipation(int pct);

  /// #886 personal-information form / feature: featurePersonalInfo
  ///
  /// In en, this message translates to:
  /// **'Personal information'**
  String get featurePersonalInfo;

  /// #886 personal-information form / feature: featurePersonalInfoDesc
  ///
  /// In en, this message translates to:
  /// **'Members enter their name, postal address, phone, e-mail and legal ids in Settings; invoices and letters print them in the standard postal block.'**
  String get featurePersonalInfoDesc;

  /// #886 personal-information form / feature: personalInfoTitle
  ///
  /// In en, this message translates to:
  /// **'Personal information'**
  String get personalInfoTitle;

  /// #886 personal-information form / feature: personalInfoSubtitle
  ///
  /// In en, this message translates to:
  /// **'Printed on your invoices and letters. Your family name is written in capitals, as on official mail.'**
  String get personalInfoSubtitle;

  /// #886 personal-information form / feature: personalInfoFirstName
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get personalInfoFirstName;

  /// #886 personal-information form / feature: personalInfoLastName
  ///
  /// In en, this message translates to:
  /// **'Family name'**
  String get personalInfoLastName;

  /// #886 personal-information form / feature: personalInfoCompany
  ///
  /// In en, this message translates to:
  /// **'Company (optional)'**
  String get personalInfoCompany;

  /// #886 personal-information form / feature: personalInfoStreet
  ///
  /// In en, this message translates to:
  /// **'Street and number'**
  String get personalInfoStreet;

  /// #886 personal-information form / feature: personalInfoPostalCode
  ///
  /// In en, this message translates to:
  /// **'Postal code'**
  String get personalInfoPostalCode;

  /// #886 personal-information form / feature: personalInfoCity
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get personalInfoCity;

  /// #886 personal-information form / feature: personalInfoCountry
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get personalInfoCountry;

  /// #886 personal-information form / feature: personalInfoPhone
  ///
  /// In en, this message translates to:
  /// **'Telephone'**
  String get personalInfoPhone;

  /// #886 personal-information form / feature: personalInfoEmail
  ///
  /// In en, this message translates to:
  /// **'E-mail for documents'**
  String get personalInfoEmail;

  /// #886 personal-information form / feature: personalInfoVatId
  ///
  /// In en, this message translates to:
  /// **'VAT number (optional)'**
  String get personalInfoVatId;

  /// #886 personal-information form / feature: personalInfoLegalId
  ///
  /// In en, this message translates to:
  /// **'Company / registration id (optional)'**
  String get personalInfoLegalId;

  /// #886 personal-information form / feature: personalInfoSaved
  ///
  /// In en, this message translates to:
  /// **'Personal information saved'**
  String get personalInfoSaved;

  /// #886 personal-information form / feature: personalInfoNone
  ///
  /// In en, this message translates to:
  /// **'Not filled in yet'**
  String get personalInfoNone;

  /// #886 personal-information form / feature: personalInfoPreview
  ///
  /// In en, this message translates to:
  /// **'On your documents'**
  String get personalInfoPreview;

  /// #886 personal-information form: save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get personalInfoSave;

  /// Booking sheet: grid duration slider label (#574)
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get planDurationLabel;

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

  /// Error when checking in before the 15-minute window opens (#408)
  ///
  /// In en, this message translates to:
  /// **'Check-in opens 15 minutes before the start.'**
  String get planCheckInNotYetError;

  /// Error/hint when checking in after the reservation ended (#408)
  ///
  /// In en, this message translates to:
  /// **'This reservation is over — check-in is no longer possible.'**
  String get planCheckInOverError;

  /// Disabled check-in tile hint with the window-opening time (#408)
  ///
  /// In en, this message translates to:
  /// **'Check-in opens at {time}'**
  String planCheckInOpensAt(String time);

  /// No description provided for @planCheckInOpensOn.
  ///
  /// In en, this message translates to:
  /// **'Check-in opens on {date}'**
  String planCheckInOpensOn(String date);

  /// Admin action: check in another member who is present (#408)
  ///
  /// In en, this message translates to:
  /// **'Check in {name}'**
  String planCheckInFor(String name);

  /// Admin overrule tile: remove another member's reservation (#412)
  ///
  /// In en, this message translates to:
  /// **'Remove reservation (overrule)'**
  String get planOverruleRemove;

  /// Subtitle under the overrule tile (#412)
  ///
  /// In en, this message translates to:
  /// **'{name} and all admins will be notified.'**
  String planOverruleHint(String name);

  /// Snack after an overrule removal (#412)
  ///
  /// In en, this message translates to:
  /// **'Reservation removed — {name} was notified.'**
  String planOverruleDone(String name);

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

  /// Tooltip of the compact level-picker dropdown in the plan header
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get planLevelTooltip;

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

  /// Local notification title 15 minutes before a reservation starts
  ///
  /// In en, this message translates to:
  /// **'Check in soon'**
  String get reminderTitle;

  /// Local notification body
  ///
  /// In en, this message translates to:
  /// **'{target} starts at {time}'**
  String reminderBody(String target, String time);

  /// List-view empty state when the level has no seats (#104)
  ///
  /// In en, this message translates to:
  /// **'This level has no seats yet.'**
  String get planNoSeats;

  /// Seat state label in the list view
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get planStateFree;

  /// Seat state label for the caller's own booking
  ///
  /// In en, this message translates to:
  /// **'Yours'**
  String get planStateYours;

  /// Member picker label in the booking sheet (#106, admins only)
  ///
  /// In en, this message translates to:
  /// **'Book for'**
  String get planBookForLabel;

  /// Booking-sheet button when booking for another member
  ///
  /// In en, this message translates to:
  /// **'Send for confirmation'**
  String get planSendForConfirmation;

  /// Snackbar after booking for another member
  ///
  /// In en, this message translates to:
  /// **'Sent to {name} for confirmation.'**
  String planBookedForPending(String name);

  /// Booking-sheet action starting an open-ended maintenance block on the seat (#161, owner/admin only)
  ///
  /// In en, this message translates to:
  /// **'Make not reservable'**
  String get planMakeNotReservable;

  /// Blocked-seat sheet action clearing the maintenance block (#161, owner/admin only)
  ///
  /// In en, this message translates to:
  /// **'Make reservable'**
  String get planMakeReservable;

  /// Unit hint under the booking sheet's accessory chips when the accessorySupplements toggle shows (+price) suffixes (#169)
  ///
  /// In en, this message translates to:
  /// **'Supplements are per half-day.'**
  String get planAccessorySupplementHint;

  /// Tooltip of the browse-window start time chip in the plan header (#184)
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get planFromLabel;

  /// Tooltip of the browse-window end time chip in the plan header (#184)
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get planToLabel;

  /// Snackbar when the picked browse-window end is not after its start (#184)
  ///
  /// In en, this message translates to:
  /// **'End must be after start.'**
  String get planEndBeforeStart;

  /// Banner under the plan header and seat-tap snackbar when the browsed/live day is a closed day of the workspace (#186)
  ///
  /// In en, this message translates to:
  /// **'Closed on this day'**
  String get planClosedDay;

  /// Snackbar when the server rejects a booking or check-in because the workspace is closed on a touched day (#186)
  ///
  /// In en, this message translates to:
  /// **'The workspace is closed on that day.'**
  String get planClosedDayError;

  /// Header chip browsing the 00:00–13:00 half-day window under half-day granularity (#201)
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get planMorningChip;

  /// Header chip browsing the 13:00–24:00 half-day window under half-day granularity (#201)
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get planAfternoonChip;

  /// Header chip browsing the full 00:00–24:00 window under half-day granularity (#201)
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get planFullDayChip;

  /// Snackbar when the server rejects a booking for violating the half-day granularity (enforce_booking_rules, migration 0025, #201)
  ///
  /// In en, this message translates to:
  /// **'Bookings here are per half day.'**
  String get planHalfDayError;

  /// Screen-reader state of a free seat on the floor plan (#402).
  ///
  /// In en, this message translates to:
  /// **'free'**
  String get a11ySeatFree;

  /// Screen-reader state of a reserved seat.
  ///
  /// In en, this message translates to:
  /// **'reserved'**
  String get a11ySeatReserved;

  /// Screen-reader state of an occupied seat.
  ///
  /// In en, this message translates to:
  /// **'occupied'**
  String get a11ySeatOccupied;

  /// Screen-reader state of the signed-in member’s own seat.
  ///
  /// In en, this message translates to:
  /// **'your seat'**
  String get a11ySeatMine;

  /// Screen-reader state of a blocked seat.
  ///
  /// In en, this message translates to:
  /// **'not available'**
  String get a11ySeatBlocked;

  /// Settings tile and dialog title of the opt-in WhatsApp number on my profile (#223)
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get whatsappTitle;

  /// Settings tile subtitle when no WhatsApp number is shared
  ///
  /// In en, this message translates to:
  /// **'Not shared'**
  String get whatsappNotShared;

  /// Label of the WhatsApp number input
  ///
  /// In en, this message translates to:
  /// **'WhatsApp number'**
  String get whatsappFieldLabel;

  /// Example number in international format; localized to a plausible local example
  ///
  /// In en, this message translates to:
  /// **'+44 7912 345678'**
  String get whatsappHint;

  /// Helper text under the WhatsApp input explaining opt-in visibility and how to clear
  ///
  /// In en, this message translates to:
  /// **'Optional. Visible to members of your workspaces so they can reach you on WhatsApp. Leave empty to stop sharing it.'**
  String get whatsappHelper;

  /// Success snackbar after saving or clearing the WhatsApp number
  ///
  /// In en, this message translates to:
  /// **'WhatsApp number saved'**
  String get whatsappSaved;

  /// Error snackbar when saving the WhatsApp number fails
  ///
  /// In en, this message translates to:
  /// **'Could not save the WhatsApp number'**
  String get whatsappSaveFailed;

  /// Settings tile and dialog title of the self-set status line on my profile (#231)
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get profileStatusTitle;

  /// Settings tile subtitle when no status line is set
  ///
  /// In en, this message translates to:
  /// **'No status'**
  String get profileStatusNone;

  /// Label of the status-line input (max 40 characters)
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get profileStatusFieldLabel;

  /// Example status line in the input; localized to a plausible local example
  ///
  /// In en, this message translates to:
  /// **'In a call · back at 14:00'**
  String get profileStatusHint;

  /// Helper text under the status input explaining visibility and how to clear
  ///
  /// In en, this message translates to:
  /// **'Optional. Visible to members of your workspaces in the member directory. Leave empty to clear it.'**
  String get profileStatusHelper;

  /// Success snackbar after saving or clearing the status line
  ///
  /// In en, this message translates to:
  /// **'Status saved'**
  String get profileStatusSaved;

  /// Error snackbar when saving the status line fails
  ///
  /// In en, this message translates to:
  /// **'Could not save the status'**
  String get profileStatusSaveFailed;

  /// Settings entry: the member's profile photo (0038).
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get profilePhotoTitle;

  /// Subtitle of the Photo entry when the member already has a photo.
  ///
  /// In en, this message translates to:
  /// **'Tap to change'**
  String get profilePhotoSet;

  /// Subtitle of the Photo entry when the member has no photo yet.
  ///
  /// In en, this message translates to:
  /// **'Tap to add a photo'**
  String get profilePhotoNone;

  /// Action in the photo sheet: pick an image from the device.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get profilePhotoChoose;

  /// Action in the photo sheet: delete the current profile photo.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get profilePhotoRemove;

  /// Success snackbar after uploading a new profile photo.
  ///
  /// In en, this message translates to:
  /// **'Photo updated'**
  String get profilePhotoSaved;

  /// Success snackbar after removing the profile photo.
  ///
  /// In en, this message translates to:
  /// **'Photo removed'**
  String get profilePhotoRemoved;

  /// Error snackbar when uploading or removing the photo fails.
  ///
  /// In en, this message translates to:
  /// **'Could not update the photo'**
  String get profilePhotoSaveFailed;

  /// File-picker type label when choosing a profile photo; the word is identical across locales but the key exists for parity.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get profilePhotoFileType;

  /// Admin settings entry to the invoicing hub (#478)
  ///
  /// In en, this message translates to:
  /// **'Billing & reports'**
  String get settingsBillingReports;

  /// No description provided for @defaultPeriodTitle.
  ///
  /// In en, this message translates to:
  /// **'Default booking period'**
  String get defaultPeriodTitle;

  /// No description provided for @defaultPeriodNone.
  ///
  /// In en, this message translates to:
  /// **'No preference (full day)'**
  String get defaultPeriodNone;

  /// #719 - privacy & data
  ///
  /// In en, this message translates to:
  /// **'Privacy & data'**
  String get privacyTitle;

  /// #719 - privacy & data
  ///
  /// In en, this message translates to:
  /// **'Your data stays in the EU, is never tracked or sold, and is readable only by the roles the rules below name. These are your rights under the GDPR — each one is a button.'**
  String get privacyIntro;

  /// #719 - privacy & data
  ///
  /// In en, this message translates to:
  /// **'Who can see my data'**
  String get privacyWhoCanSee;

  /// #719 - privacy & data
  ///
  /// In en, this message translates to:
  /// **'The rule per category, the people it names today, and who actually looked.'**
  String get privacyWhoCanSeeHint;

  /// #719 - privacy & data
  ///
  /// In en, this message translates to:
  /// **'Export my data'**
  String get privacyExport;

  /// #719 - privacy & data
  ///
  /// In en, this message translates to:
  /// **'Everything you are the subject of, as one JSON file (art. 20).'**
  String get privacyExportHint;

  /// #719 - privacy & data
  ///
  /// In en, this message translates to:
  /// **'My DesKilo data export'**
  String get privacyExportShareText;

  /// #719 - privacy & data
  ///
  /// In en, this message translates to:
  /// **'Leave this workspace and erase my data'**
  String get privacyErase;

  /// #719 - privacy & data
  ///
  /// In en, this message translates to:
  /// **'Cancels your bookings, blanks your messages, clears your profile. Accounting records stay under the legal retention, by id, not by name (art. 17).'**
  String get privacyEraseHint;

  /// #719 - privacy & data
  ///
  /// In en, this message translates to:
  /// **'An owner hands the workspace over first (Members & plans → Co-ownership).'**
  String get privacyEraseOwner;

  /// #719 - privacy & data
  ///
  /// In en, this message translates to:
  /// **'ERASE'**
  String get privacyEraseConfirmPhrase;

  /// #719 - privacy & data
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone. Type {phrase} to confirm.'**
  String privacyEraseConfirmHint(String phrase);

  /// #719 - privacy & data
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get privacyEraseConfirmButton;

  /// #719 - privacy & data
  ///
  /// In en, this message translates to:
  /// **'Your data has been erased.'**
  String get privacyErased;

  /// #719 - privacy & data
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @consentTitle.
  ///
  /// In en, this message translates to:
  /// **'Your data, your rights'**
  String get consentTitle;

  /// No description provided for @consentIntro.
  ///
  /// In en, this message translates to:
  /// **'Before you use DesKilo, here is what the app does with your data, who can see it and what you can do about it. Two minutes; it is all there is.'**
  String get consentIntro;

  /// No description provided for @consentWhatTitle.
  ///
  /// In en, this message translates to:
  /// **'What DesKilo processes'**
  String get consentWhatTitle;

  /// No description provided for @consentWhatBody.
  ///
  /// In en, this message translates to:
  /// **'Your account (e-mail, display name, hashed password), your profile as you fill it (photo, status, address, WhatsApp number — each optional), and what you do in a workspace: reservations and check-ins, messages, expenses and consumptions, your subscription, invoices and payments. Everything is stored in the EU (Supabase, eu-central-1).'**
  String get consentWhatBody;

  /// No description provided for @consentNotTitle.
  ///
  /// In en, this message translates to:
  /// **'What DesKilo never does'**
  String get consentNotTitle;

  /// No description provided for @consentNotBody.
  ///
  /// In en, this message translates to:
  /// **'No tracking, no analytics, no advertising, no sale or sharing of data. Push notifications carry no content — only \"you have a new message\"; the app itself writes the text. The F-Droid build has no Google services at all.'**
  String get consentNotBody;

  /// No description provided for @consentWhoTitle.
  ///
  /// In en, this message translates to:
  /// **'Who can see what'**
  String get consentWhoTitle;

  /// No description provided for @consentWhoBody.
  ///
  /// In en, this message translates to:
  /// **'Access follows roles and is enforced on the server: bookings are visible to the workspace (the floor plan shows occupancy); messages only to the people in the conversation, whatever their role; your finances and your commercial agreement only to you, the owners and the admins holding the matching permission. Settings → Privacy & data names the people and lists who actually looked.'**
  String get consentWhoBody;

  /// No description provided for @consentControllerTitle.
  ///
  /// In en, this message translates to:
  /// **'Who is responsible'**
  String get consentControllerTitle;

  /// No description provided for @consentControllerBody.
  ///
  /// In en, this message translates to:
  /// **'Each workspace is operated by its owner — your community — who decides members, prices and payment providers. The app is open source (0BSD) and published by Florian Dittgen (Germany); the backend is Supabase in the EU. Online payments go through the provider the owner enabled (PayPal, Stripe, Mollie, Wero) under that provider\'s terms.'**
  String get consentControllerBody;

  /// No description provided for @consentRetentionTitle.
  ///
  /// In en, this message translates to:
  /// **'How long'**
  String get consentRetentionTitle;

  /// No description provided for @consentRetentionBody.
  ///
  /// In en, this message translates to:
  /// **'As long as you are a member. When you leave and erase, your profile and messages go; accounting records (invoices, payments) stay for the legal retention period, by identifier and not by name.'**
  String get consentRetentionBody;

  /// No description provided for @consentRightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your rights'**
  String get consentRightsTitle;

  /// No description provided for @consentRightsBody.
  ///
  /// In en, this message translates to:
  /// **'Access, rectification, export (art. 20), erasure (art. 17) and objection — each is a button in Settings → Privacy & data. For anything else: fdittgen@gmail.com. You may withdraw this consent by leaving the workspace and erasing your data at any time.'**
  String get consentRightsBody;

  /// No description provided for @consentReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Read it again anytime'**
  String get consentReviewTitle;

  /// No description provided for @consentReviewBody.
  ///
  /// In en, this message translates to:
  /// **'This text stays available in Settings → Privacy & data, in the in-app help (Privacy) and in the project wiki. A change of the text asks for your acceptance again.'**
  String get consentReviewBody;

  /// No description provided for @consentCheckbox.
  ///
  /// In en, this message translates to:
  /// **'I have read this and I accept how DesKilo handles my data.'**
  String get consentCheckbox;

  /// No description provided for @consentAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept and continue'**
  String get consentAccept;

  /// No description provided for @consentVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get consentVersion;

  /// No description provided for @consentAcceptedOn.
  ///
  /// In en, this message translates to:
  /// **'Accepted on {date} ({version})'**
  String consentAcceptedOn(String date, String version);

  /// No description provided for @consentReadInHelp.
  ///
  /// In en, this message translates to:
  /// **'Read in the help'**
  String get consentReadInHelp;

  /// No description provided for @consentReadOnWiki.
  ///
  /// In en, this message translates to:
  /// **'Read on the wiki'**
  String get consentReadOnWiki;

  /// No description provided for @consentReviewHint.
  ///
  /// In en, this message translates to:
  /// **'The text you accepted, with the date — read it again anytime.'**
  String get consentReviewHint;

  /// No description provided for @backendServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get backendServerTitle;

  /// No description provided for @backendServerDefault.
  ///
  /// In en, this message translates to:
  /// **'The app\'s own server ({host})'**
  String backendServerDefault(Object host);

  /// No description provided for @backendServerCustom.
  ///
  /// In en, this message translates to:
  /// **'Your own server ({host})'**
  String backendServerCustom(Object host);

  /// No description provided for @backendServerHint.
  ///
  /// In en, this message translates to:
  /// **'By default this app uses its own server. If your community runs its own Supabase project, enter it here — the app then stores everything there.'**
  String get backendServerHint;

  /// No description provided for @backendUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Project URL'**
  String get backendUrlLabel;

  /// No description provided for @backendKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Publishable key'**
  String get backendKeyLabel;

  /// No description provided for @backendServerRestartHint.
  ///
  /// In en, this message translates to:
  /// **'The app signs you out and applies the change on the next start.'**
  String get backendServerRestartHint;

  /// No description provided for @backendServerReset.
  ///
  /// In en, this message translates to:
  /// **'Use the app\'s server'**
  String get backendServerReset;

  /// No description provided for @backendServerSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved. Close and reopen the app to use the new server.'**
  String get backendServerSaved;

  /// No description provided for @backendErrorUrlEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter the project URL.'**
  String get backendErrorUrlEmpty;

  /// No description provided for @backendErrorUrlNotHttps.
  ///
  /// In en, this message translates to:
  /// **'The URL must start with https://.'**
  String get backendErrorUrlNotHttps;

  /// No description provided for @backendErrorUrlNoHost.
  ///
  /// In en, this message translates to:
  /// **'That is not a complete address.'**
  String get backendErrorUrlNoHost;

  /// No description provided for @backendErrorKeyEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter the publishable key.'**
  String get backendErrorKeyEmpty;

  /// No description provided for @backendErrorKeyNotSupabase.
  ///
  /// In en, this message translates to:
  /// **'That is not a Supabase publishable key (sb_publishable_…).'**
  String get backendErrorKeyNotSupabase;

  /// No description provided for @backendCurrentTitle.
  ///
  /// In en, this message translates to:
  /// **'This device uses'**
  String get backendCurrentTitle;

  /// No description provided for @backendHowTitle.
  ///
  /// In en, this message translates to:
  /// **'Use your own server'**
  String get backendHowTitle;

  /// No description provided for @backendStep1.
  ///
  /// In en, this message translates to:
  /// **'Create a project at supabase.com (the free tier is enough to start).'**
  String get backendStep1;

  /// No description provided for @backendStep2.
  ///
  /// In en, this message translates to:
  /// **'Install the app\'s schema: run the SQL files in supabase/migrations from the source repository, in order.'**
  String get backendStep2;

  /// No description provided for @backendStep3.
  ///
  /// In en, this message translates to:
  /// **'In the Supabase dashboard, open Project Settings → API keys and copy the Project URL and the publishable key.'**
  String get backendStep3;

  /// No description provided for @backendStep4.
  ///
  /// In en, this message translates to:
  /// **'Paste them below, test the connection, and save. Members join the same instance by scanning the QR above.'**
  String get backendStep4;

  /// No description provided for @backendScan.
  ///
  /// In en, this message translates to:
  /// **'Scan a server QR'**
  String get backendScan;

  /// No description provided for @backendScanNothing.
  ///
  /// In en, this message translates to:
  /// **'That QR is not a DesKilo server code.'**
  String get backendScanNothing;

  /// No description provided for @backendShare.
  ///
  /// In en, this message translates to:
  /// **'Share this server'**
  String get backendShare;

  /// No description provided for @backendShareHint.
  ///
  /// In en, this message translates to:
  /// **'Members scan this in Settings → Server to point their app at the same instance.'**
  String get backendShareHint;

  /// No description provided for @backendPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get backendPaste;

  /// No description provided for @backendTest.
  ///
  /// In en, this message translates to:
  /// **'Test the connection'**
  String get backendTest;

  /// No description provided for @backendTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get backendTesting;

  /// No description provided for @backendTestOk.
  ///
  /// In en, this message translates to:
  /// **'Reached it — the app\'s schema is there.'**
  String get backendTestOk;

  /// No description provided for @backendTestUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach that address. Check the URL and your network.'**
  String get backendTestUnreachable;

  /// No description provided for @backendTestBadKey.
  ///
  /// In en, this message translates to:
  /// **'Reached it, but the key was refused. Copy the publishable key again from Project Settings → API keys.'**
  String get backendTestBadKey;

  /// No description provided for @backendTestSchemaMissing.
  ///
  /// In en, this message translates to:
  /// **'Reached it, but the DesKilo tables are missing — run the migrations from supabase/migrations on that project first.'**
  String get backendTestSchemaMissing;

  /// No description provided for @backendCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get backendCopyLink;

  /// No description provided for @profilesDefault.
  ///
  /// In en, this message translates to:
  /// **'Default at startup'**
  String get profilesDefault;

  /// No description provided for @profilesMakeDefault.
  ///
  /// In en, this message translates to:
  /// **'Use as default at startup'**
  String get profilesMakeDefault;

  /// Event-type label for owner-initiated admin promotions/demotions (0035): feed + validation card
  ///
  /// In en, this message translates to:
  /// **'Role change'**
  String get eventTypeRoleChange;

  /// Feed line of a role-change event that grants admin
  ///
  /// In en, this message translates to:
  /// **'{actor} promotes a member to admin'**
  String eventRolePromote(String actor);

  /// Feed line of a role-change event that removes admin
  ///
  /// In en, this message translates to:
  /// **'{actor} demotes an admin to member'**
  String eventRoleDemote(String actor);

  /// Owner action promoting a member to admin (0035)
  ///
  /// In en, this message translates to:
  /// **'Make admin'**
  String get memberMakeAdmin;

  /// Owner action demoting an admin to a regular member (0035)
  ///
  /// In en, this message translates to:
  /// **'Make regular member'**
  String get memberMakeMember;

  /// Snackbar after an owner requested a role change (0035)
  ///
  /// In en, this message translates to:
  /// **'Role change sent for validation.'**
  String get memberRoleChangeRequested;

  /// Event-type label for quota-extension requests (0031): feed filter chip + validation policy card
  ///
  /// In en, this message translates to:
  /// **'Extra half-days'**
  String get eventTypeQuota;

  /// Feed line of a quota-extension request event
  ///
  /// In en, this message translates to:
  /// **'{actor} requests {halfDays} extra half-days for {period}'**
  String eventQuotaRequested(String actor, int halfDays, String period);

  /// Booking error when assert_member_quota (0031) rejects a reservation beyond the subscription entitlement
  ///
  /// In en, this message translates to:
  /// **'Monthly half-day quota reached — request extra half-days from the Money tab.'**
  String get quotaExceededError;

  /// Money-tab button opening the quota-extension request sheet
  ///
  /// In en, this message translates to:
  /// **'Request extra half-days'**
  String get quotaRequestButton;

  /// Title of the quota-extension request sheet
  ///
  /// In en, this message translates to:
  /// **'Request extra half-days'**
  String get quotaRequestTitle;

  /// Explainer in the quota-extension request sheet
  ///
  /// In en, this message translates to:
  /// **'Your reservations are capped by your subscription. Extra half-days for {period} apply once validated.'**
  String quotaRequestExplainer(String period);

  /// Label of the half-day count input in the request sheet
  ///
  /// In en, this message translates to:
  /// **'Number of half-days'**
  String get quotaRequestCountLabel;

  /// Snackbar after a quota-extension request was submitted
  ///
  /// In en, this message translates to:
  /// **'Request sent — waiting for validation.'**
  String get quotaRequestPending;

  /// Tooltip of the members-screen button opening the simultaneous-reservations cap dialog (0044)
  ///
  /// In en, this message translates to:
  /// **'Reservation limit'**
  String get memberReservationLimitTooltip;

  /// Title of the reservation-limit picker dialog
  ///
  /// In en, this message translates to:
  /// **'Reservation limit'**
  String get memberReservationLimitLabel;

  /// Explainer in the reservation-limit dialog
  ///
  /// In en, this message translates to:
  /// **'How many open reservations this member may hold at the same time.'**
  String get memberReservationLimitExplainer;

  /// Chip lifting the cap (null limit)
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get memberReservationLimitNone;

  /// Label of the custom limit input
  ///
  /// In en, this message translates to:
  /// **'Custom (1–100)'**
  String get memberReservationLimitCustom;

  /// Subtitle chip on a member row whose reservation cap is set
  ///
  /// In en, this message translates to:
  /// **'max {n}'**
  String memberReservationLimitChip(int n);

  /// Booking error when the enforce_reservation_limit trigger (0044) rejects a reservation beyond the member's cap
  ///
  /// In en, this message translates to:
  /// **'Reservation limit reached — you already hold the maximum number of open reservations.'**
  String get reservationLimitError;

  /// Member sheet action: pause an active membership (formerly a hidden long-press)
  ///
  /// In en, this message translates to:
  /// **'Pause membership'**
  String get memberPause;

  /// Member sheet action: reactivate a paused membership
  ///
  /// In en, this message translates to:
  /// **'Reactivate membership'**
  String get memberReactivate;

  /// Member notes (#456)
  ///
  /// In en, this message translates to:
  /// **'Send notification'**
  String get memberNotifyAction;

  /// Member notes (#456)
  ///
  /// In en, this message translates to:
  /// **'Notify all admins'**
  String get memberNotifyAllAdmins;

  /// Member notes (#456)
  ///
  /// In en, this message translates to:
  /// **'all admins'**
  String get memberAllAdmins;

  /// Member notes (#456)
  ///
  /// In en, this message translates to:
  /// **'Notify {name}'**
  String memberNoteTitle(String name);

  /// Member notes (#456)
  ///
  /// In en, this message translates to:
  /// **'Your message'**
  String get memberNoteHint;

  /// Member notes (#456)
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get memberNoteSend;

  /// Member notes (#456)
  ///
  /// In en, this message translates to:
  /// **'Notification sent.'**
  String get memberNoteSent;

  /// Member notes (#456)
  ///
  /// In en, this message translates to:
  /// **'Message from {name}'**
  String memberNoteReceived(String name);

  /// Member-notes inbox on the Events screen (#460)
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get eventsMessagesHeader;

  /// Member-notes inbox on the Events screen (#460)
  ///
  /// In en, this message translates to:
  /// **'To {name}'**
  String memberNoteTo(String name);

  /// Member-notes inbox on the Events screen (#460)
  ///
  /// In en, this message translates to:
  /// **'To all admins'**
  String get memberNoteToAllAdmins;

  /// Snack after swipe-deleting a note (#467)
  ///
  /// In en, this message translates to:
  /// **'Message deleted.'**
  String get memberNoteDeleted;

  /// #628 - member sheet action and dialog title for the per-member overlap permission
  ///
  /// In en, this message translates to:
  /// **'Simultaneous reservations'**
  String get memberSimultaneousLimitLabel;

  /// #628 - explainer inside the per-member simultaneous-reservations dialog
  ///
  /// In en, this message translates to:
  /// **'How many bookings this member may hold over the same period. Unset follows the workspace default.'**
  String get memberSimultaneousLimitExplainer;

  /// #628 - chip clearing the per-member override so the workspace default applies
  ///
  /// In en, this message translates to:
  /// **'Workspace default'**
  String get memberSimultaneousLimitDefault;

  /// #628 - subtitle chip on a member row with an explicit simultaneous allowance
  ///
  /// In en, this message translates to:
  /// **'{n} at once'**
  String memberSimultaneousLimitChip(int n);

  /// Designer card title for the positioned layout of one report kind (#875)
  ///
  /// In en, this message translates to:
  /// **'Positioned layout (XML)'**
  String get reportLayoutTitle;

  /// Explains export/edit/check/import and that a layout wins over the bands (#875)
  ///
  /// In en, this message translates to:
  /// **'A layout states where every element sits, in mm, cm, px or %. Export it, edit it, check it with `dart run tool/report.dart check`, import it back. When a layout exists it is what prints; remove it and the bands print again.'**
  String get reportLayoutSubtitle;

  /// Chip: this document is drawn by its positioned layout (#875)
  ///
  /// In en, this message translates to:
  /// **'Layout active'**
  String get reportLayoutActive;

  /// Chip: this document is drawn by its bands (#875)
  ///
  /// In en, this message translates to:
  /// **'Bands'**
  String get reportLayoutBands;

  /// Button: export the layout as XML (#875)
  ///
  /// In en, this message translates to:
  /// **'Export XML'**
  String get reportLayoutExport;

  /// Button: import a layout XML (#875)
  ///
  /// In en, this message translates to:
  /// **'Import XML'**
  String get reportLayoutImport;

  /// Button: open the page-true preview of the layout (#875)
  ///
  /// In en, this message translates to:
  /// **'Page preview'**
  String get reportLayoutPreview;

  /// Button: remove the layout so the bands print again (#875)
  ///
  /// In en, this message translates to:
  /// **'Remove layout (use bands)'**
  String get reportLayoutRemove;

  /// Snack after a successful import; save is still required (#875)
  ///
  /// In en, this message translates to:
  /// **'Layout imported. Save to keep it.'**
  String get reportLayoutImported;

  /// File-picker type label for layout files (#875)
  ///
  /// In en, this message translates to:
  /// **'XML'**
  String get reportLayoutFileTypeLabel;

  /// Features screen name for the #875 positioned report layouts flag
  ///
  /// In en, this message translates to:
  /// **'Positioned report layouts'**
  String get featureReportLayouts;

  /// Features screen description for the #875 positioned report layouts flag
  ///
  /// In en, this message translates to:
  /// **'Design a report by stating where each element sits, in mm, cm, px or %; the PDF prints exactly that. A document with a layout uses it, the others keep their bands.'**
  String get featureReportLayoutsDesc;

  /// Reserve hub view segment: month availability calendar (#7)
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get reserveMonthView;

  /// Free-desks-of-total label in a month calendar cell (#7)
  ///
  /// In en, this message translates to:
  /// **'{free}/{total}'**
  String monthFreeCount(int free, int total);

  /// Generic repetition label for series bookings whose pattern predates 0034
  ///
  /// In en, this message translates to:
  /// **'Recurring booking'**
  String get reservationRecurring;

  /// Detail-sheet action opening the granularity-aware window edit (0033)
  ///
  /// In en, this message translates to:
  /// **'Edit times'**
  String get reservationEditTimes;

  /// Snackbar after an own reservation's window was edited (0033)
  ///
  /// In en, this message translates to:
  /// **'Reservation updated.'**
  String get reservationUpdatedSnack;

  /// Snackbar after an own reservation was cancelled from the detail sheet
  ///
  /// In en, this message translates to:
  /// **'Reservation cancelled.'**
  String get reservationCancelledSnack;

  /// Reserve hub view segment showing the selected day's per-seat timeline (#208)
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get reserveDayView;

  /// Reserve hub view segment paging one day timeline per day, synced with the date strip (#208)
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get reserveWeekView;

  /// Reserve hub window chip selecting the canonical 00:00–24:00 window under half-day granularity (#208)
  ///
  /// In en, this message translates to:
  /// **'Full day'**
  String get reserveFullDayChip;

  /// Tooltip of the calendar icon at the end of the Reserve hub's date strip, opening a date picker for days beyond the pills (#208)
  ///
  /// In en, this message translates to:
  /// **'Choose a date'**
  String get reservePickDateTooltip;

  /// Snackbar when creating a reservation from the Reserve hub fails for a generic reason (#208)
  ///
  /// In en, this message translates to:
  /// **'Could not reserve — the seat may have just been taken.'**
  String get reserveBookingFailed;

  /// No description provided for @spaceScanNfcHint.
  ///
  /// In en, this message translates to:
  /// **'…or hold the phone to a chair\'s NFC tag.'**
  String get spaceScanNfcHint;

  /// No description provided for @spaceScanUnknownTag.
  ///
  /// In en, this message translates to:
  /// **'This tag is not linked to any chair.'**
  String get spaceScanUnknownTag;

  /// #663 - check-in confirmation without a space name
  ///
  /// In en, this message translates to:
  /// **'Checked in until {until}.'**
  String bookingCheckedInUntil(String until);

  /// #663 - check-in confirmation naming the space
  ///
  /// In en, this message translates to:
  /// **'Checked in at {space} until {until}.'**
  String bookingCheckedInAtUntil(String space, String until);

  /// #663 - reservation confirmation without a space name
  ///
  /// In en, this message translates to:
  /// **'Reserved: {when}.'**
  String bookingReservedWhen(String when);

  /// #663 - reservation confirmation naming the space
  ///
  /// In en, this message translates to:
  /// **'Reserved {space}: {when}.'**
  String bookingReservedSpaceWhen(String space, String when);

  /// No description provided for @bookingHorizonError.
  ///
  /// In en, this message translates to:
  /// **'Too far ahead — bookings are open {days} days in advance.'**
  String bookingHorizonError(int days);

  /// No description provided for @bookingTooShortError.
  ///
  /// In en, this message translates to:
  /// **'Too short — a booking lasts at least {minutes} minutes.'**
  String bookingTooShortError(int minutes);

  /// No description provided for @bookingTooLongError.
  ///
  /// In en, this message translates to:
  /// **'Too long — a booking lasts at most {minutes} minutes.'**
  String bookingTooLongError(int minutes);

  /// No description provided for @legendFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get legendFree;

  /// No description provided for @legendReserved.
  ///
  /// In en, this message translates to:
  /// **'Reserved'**
  String get legendReserved;

  /// No description provided for @legendOccupied.
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get legendOccupied;

  /// No description provided for @legendMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get legendMine;

  /// No description provided for @legendBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get legendBlocked;

  /// No description provided for @legendClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed day'**
  String get legendClosed;

  /// No description provided for @reserveClosedShort.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get reserveClosedShort;

  /// No description provided for @planCheckOutFor.
  ///
  /// In en, this message translates to:
  /// **'Check out {name}'**
  String planCheckOutFor(String name);

  /// No description provided for @scanCameraWebUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera scanning is not available in the browser — type the code, or hold an NFC tag to the device (Chrome on Android).'**
  String get scanCameraWebUnavailable;

  /// No description provided for @bookingGateBlocked.
  ///
  /// In en, this message translates to:
  /// **'Not bookable as chosen'**
  String get bookingGateBlocked;

  /// App-bar title of the owner service-catalog editor and its settings tile
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get servicesTitle;

  /// Empty state of the service-catalog editor
  ///
  /// In en, this message translates to:
  /// **'No services yet.'**
  String get servicesEmpty;

  /// FAB tooltip and sheet title when creating a service
  ///
  /// In en, this message translates to:
  /// **'New service'**
  String get servicesNew;

  /// Sheet title when editing an existing service
  ///
  /// In en, this message translates to:
  /// **'Edit service'**
  String get servicesEdit;

  /// Label of the service name field
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get servicesName;

  /// Label of the service price field (major currency units)
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get servicesPrice;

  /// Trailing badge on deactivated services in the catalog list
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get servicesInactive;

  /// Label of the activate/deactivate switch in the edit sheet
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get servicesActive;

  /// No description provided for @authContinueWith.
  ///
  /// In en, this message translates to:
  /// **'or continue with'**
  String get authContinueWith;

  /// No description provided for @authSocialUnavailable.
  ///
  /// In en, this message translates to:
  /// **'{provider} sign-in is not available yet — the server has not enabled it.'**
  String authSocialUnavailable(String provider);

  /// No description provided for @linkedAccountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Linked accounts'**
  String get linkedAccountsTitle;

  /// No description provided for @linkedAccountsIntro.
  ///
  /// In en, this message translates to:
  /// **'Sign into this account with any of these. Add Google, Microsoft, Apple, or Facebook to sign in without a password.'**
  String get linkedAccountsIntro;

  /// No description provided for @linkedAccountsLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get linkedAccountsLink;

  /// No description provided for @linkedAccountsUnlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get linkedAccountsUnlink;

  /// No description provided for @linkedAccountsLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get linkedAccountsLinked;

  /// No description provided for @linkedAccountsLinkStarted.
  ///
  /// In en, this message translates to:
  /// **'Continue in the browser to finish linking.'**
  String get linkedAccountsLinkStarted;

  /// Title of the space-QR scanner sheet and tooltip of the hub scan button
  ///
  /// In en, this message translates to:
  /// **'Scan a space code'**
  String get spaceScanTitle;

  /// Explainer in the space scanner sheet
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the card of a seat, desk, office or level — or type its code.'**
  String get spaceScanHint;

  /// Label of the typed space-code input
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get spaceScanField;

  /// Inline error when the scanned/typed payload is foreign or belongs to another workspace
  ///
  /// In en, this message translates to:
  /// **'Not a space code of this workspace.'**
  String get spaceScanInvalid;

  /// Error when a stale card references a deleted desk/office/level
  ///
  /// In en, this message translates to:
  /// **'This code does not match any space here anymore.'**
  String get spaceScanUnknown;

  /// Subtitle of an occupied seat row in the space sheet
  ///
  /// In en, this message translates to:
  /// **'Taken'**
  String get spaceSeatTaken;

  /// Space sheet explainer when the office/level is not bookable or the feature is off
  ///
  /// In en, this message translates to:
  /// **'This space is not set up for whole-space reservations.'**
  String get spaceNotBookable;

  /// Workspace-settings tile printing the per-space QR sheet
  ///
  /// In en, this message translates to:
  /// **'Space QR codes (PDF)'**
  String get spaceCodesTitle;

  /// Subtitle of the space-QR-codes tile
  ///
  /// In en, this message translates to:
  /// **'One printable QR card per seat, desk, office and level — members scan to reserve or check in.'**
  String get spaceCodesDesc;

  /// Kind label on a desk's printed QR card
  ///
  /// In en, this message translates to:
  /// **'Desk'**
  String get spaceKindDesk;

  /// Kind label on an office's printed QR card
  ///
  /// In en, this message translates to:
  /// **'Office'**
  String get spaceKindOffice;

  /// Kind label on a level's printed QR card
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get spaceKindLevel;

  /// Kind label on a workstation's printed QR card
  ///
  /// In en, this message translates to:
  /// **'Seat'**
  String get spaceKindSeat;

  /// Space sheet: the viewer already holds the reservation — the button below checks in
  ///
  /// In en, this message translates to:
  /// **'Reserved by you for this slot.'**
  String get spaceYoursNow;

  /// No description provided for @spaceCardSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Card size'**
  String get spaceCardSizeLabel;

  /// No description provided for @spaceQrSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'QR code size'**
  String get spaceQrSizeLabel;

  /// No description provided for @spaceCardSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get spaceCardSizeSmall;

  /// No description provided for @spaceCardSizeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get spaceCardSizeMedium;

  /// No description provided for @spaceCardSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get spaceCardSizeLarge;

  /// No description provided for @spaceCardInfoLabel.
  ///
  /// In en, this message translates to:
  /// **'Information on the card'**
  String get spaceCardInfoLabel;

  /// No description provided for @spaceCardInfoWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get spaceCardInfoWorkspace;

  /// Action opening the conversation with the member whose reservation blocks the tapped/scanned space (#622)
  ///
  /// In en, this message translates to:
  /// **'Message {name}'**
  String spaceMessageReserver(String name);

  /// #670 - whole-space sheet
  ///
  /// In en, this message translates to:
  /// **'You are checked in here for this slot.'**
  String get spaceYoursCheckedIn;

  /// #670 - whole-space sheet
  ///
  /// In en, this message translates to:
  /// **'You already hold this space for that period.'**
  String get spaceBlockedByYou;

  /// #670 - whole-space sheet
  ///
  /// In en, this message translates to:
  /// **'Manage my booking'**
  String get spaceManageMyBooking;

  /// Settings entry and dialog title for the in-app theme selection
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeTitle;

  /// Theme option that follows the device light/dark setting instead of an override
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get themeSystem;

  /// Theme option forcing the light appearance
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Theme option forcing the dark appearance
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// #833 - title of the usage face
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get usageTitle;

  /// #833 - no usage records this month
  ///
  /// In en, this message translates to:
  /// **'No usage this month.'**
  String get usageEmpty;

  /// #833 - the reserved window
  ///
  /// In en, this message translates to:
  /// **'Booked'**
  String get usageBooked;

  /// #833 - time actually checked in
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get usagePresent;

  /// #833 - the time that bills
  ///
  /// In en, this message translates to:
  /// **'Billed'**
  String get usageBilled;

  /// #833 - nobody checked in
  ///
  /// In en, this message translates to:
  /// **'Nobody checked in — the booking bills in full'**
  String get usageNoShow;

  /// #833 - checked out before the booking ended
  ///
  /// In en, this message translates to:
  /// **'Left early'**
  String get usageLeftEarly;

  /// #833 - an accepted early-departure correction
  ///
  /// In en, this message translates to:
  /// **'Corrected'**
  String get usageCorrected;

  /// #833 - what the billed time was before a correction
  ///
  /// In en, this message translates to:
  /// **'was {before}'**
  String usageWas(String before);

  /// #833 - action asking for the actual time to bill
  ///
  /// In en, this message translates to:
  /// **'Bill the time I was here'**
  String get usageAsk;

  /// #833 - what asking does and who decides
  ///
  /// In en, this message translates to:
  /// **'You booked {booked} and were here {present}. Ask for the {saved} you did not use to stop billing. Somebody else decides it — never you.'**
  String usageAskExplain(String booked, String present, String saved);

  /// #833 - optional reason on the request
  ///
  /// In en, this message translates to:
  /// **'Why (optional)'**
  String get usageReasonLabel;

  /// #833 - submit the request
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get usageAskSubmit;

  /// #833 - confirmation snack
  ///
  /// In en, this message translates to:
  /// **'Asked. Somebody else decides it.'**
  String get usageAskSubmitted;

  /// #833 - admin action removing a record
  ///
  /// In en, this message translates to:
  /// **'Remove this record'**
  String get usageDelete;

  /// #833 - confirmation snack for a removal
  ///
  /// In en, this message translates to:
  /// **'Removal requested.'**
  String get usageDeleteSubmitted;

  /// #833 - member filter label
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get usageMember;

  /// #833 - member filter: no narrowing
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get usageMemberAll;

  /// Quorum progress on a pending event (#130): accepts so far / accepts required
  ///
  /// In en, this message translates to:
  /// **'{current}/{required} validations'**
  String eventValidations(int current, int required);

  /// Audit-trail row for an accept decision
  ///
  /// In en, this message translates to:
  /// **'Validated by {name} · {when}'**
  String eventValidatedBy(String name, String when);

  /// Audit-trail row for a reject decision
  ///
  /// In en, this message translates to:
  /// **'Declined by {name} · {when}'**
  String eventRejectedBy(String name, String when);

  /// Validator name shown when the timeout sweep decided, not a member
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get eventSystemDecider;

  /// #841 - heading of the ordered decision trail on a document
  ///
  /// In en, this message translates to:
  /// **'Validation trail'**
  String get validationTrailTitle;

  /// #841 - the trail when nothing has been decided yet
  ///
  /// In en, this message translates to:
  /// **'No decision yet.'**
  String get validationTrailNone;

  /// #841 - leader of one entry when the rule asks one validation at a time
  ///
  /// In en, this message translates to:
  /// **'Step {order}'**
  String validationTrailStep(int order);

  /// #841 - how many validations the event still owes
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Awaiting 1 more validation.} other{Awaiting {count} more validations.}}'**
  String validationTrailAwaiting(int count);

  /// #848 - which step of a chained rule is open
  ///
  /// In en, this message translates to:
  /// **'Validation {stage} of {required} requested'**
  String eventValidationStage(int stage, int required);

  /// App-bar title of the owner validation-policy editor and its settings tile (#131)
  ///
  /// In en, this message translates to:
  /// **'Validation rules'**
  String get validationTitle;

  /// Card title of the workspace-wide default validation policy (event types without their own rule inherit it)
  ///
  /// In en, this message translates to:
  /// **'Default policy'**
  String get validationDefaultPolicy;

  /// Card indicator when the event type has no rule of its own and follows the default policy
  ///
  /// In en, this message translates to:
  /// **'Inherits default'**
  String get validationInherited;

  /// Card indicator when a stored rule of its own governs the card (default card or event type)
  ///
  /// In en, this message translates to:
  /// **'Customized'**
  String get validationCustomized;

  /// Label of the 1–10 stepper for how many accepts confirm a pending event; also prefixes the count in the card summary
  ///
  /// In en, this message translates to:
  /// **'Required validations'**
  String get validationRequiredCount;

  /// Switch label: whether admins may validate at all (off = owner only)
  ///
  /// In en, this message translates to:
  /// **'Admins may validate'**
  String get validationAdminsMay;

  /// Shown when admins may not validate: switch subtitle in the editor and card summary
  ///
  /// In en, this message translates to:
  /// **'Owner only'**
  String get validationOwnerOnly;

  /// Picker chip and card summary: every admin is an eligible validator
  ///
  /// In en, this message translates to:
  /// **'All admins'**
  String get validationAllAdmins;

  /// Card summary when only selected admins may validate; the count follows in parentheses
  ///
  /// In en, this message translates to:
  /// **'Specific admins'**
  String get validationSpecificAdmins;

  /// Switch label: one of the accepts must come from an owner
  ///
  /// In en, this message translates to:
  /// **'Owner must always validate'**
  String get validationOwnerRequired;

  /// Save-blocking error when the required count exceeds what owners + eligible admins (+ the subject) could ever provide
  ///
  /// In en, this message translates to:
  /// **'Not enough eligible validators.'**
  String get validationNotEnough;

  /// Snackbar after a policy row was stored successfully
  ///
  /// In en, this message translates to:
  /// **'Validation rule saved.'**
  String get validationSaved;

  /// #629 - switch letting an owner auto-validate their own booking deletion
  ///
  /// In en, this message translates to:
  /// **'Owners delete without validation'**
  String get validationAutoValidateOwner;

  /// #629 - switch letting an admin auto-validate their own booking deletion
  ///
  /// In en, this message translates to:
  /// **'Admins delete without validation'**
  String get validationAutoValidateAdmin;

  /// #629 - subtitle under the auto-validation switches
  ///
  /// In en, this message translates to:
  /// **'Their own deletion request settles itself and stays marked as auto-validated.'**
  String get validationAutoValidateDesc;

  /// #840 - banner title on the validation rules screen
  ///
  /// In en, this message translates to:
  /// **'Nobody validates their own'**
  String get validationNoSelfTitle;

  /// #840 - the invariant, stated where the rules are set
  ///
  /// In en, this message translates to:
  /// **'Whoever creates an event never validates it. It waits for someone else, or expires undecided.'**
  String get validationNoSelfDesc;

  /// #840 - summary chip when the owner exception is off
  ///
  /// In en, this message translates to:
  /// **'Never one\'s own'**
  String get validationNoSelfShort;

  /// #840 - switch: the owner may validate their own event
  ///
  /// In en, this message translates to:
  /// **'The owner may validate their own'**
  String get validationOwnerSelf;

  /// #840 - subtitle under that switch
  ///
  /// In en, this message translates to:
  /// **'The single exception, and the owner\'s alone: an admin never validates their own act.'**
  String get validationOwnerSelfDesc;

  /// #840 - summary chip when the owner exception is on
  ///
  /// In en, this message translates to:
  /// **'Owner may validate their own'**
  String get validationOwnerSelfShort;

  /// #840 - switch: ask for the validations one at a time
  ///
  /// In en, this message translates to:
  /// **'One after another'**
  String get validationSequential;

  /// #840 - subtitle under that switch
  ///
  /// In en, this message translates to:
  /// **'The next validation is asked for once the previous one passed, and the trail numbers each step.'**
  String get validationSequentialDesc;

  /// VAT settings screen title
  ///
  /// In en, this message translates to:
  /// **'VAT'**
  String get vatTitle;

  /// Explains that prices are VAT-inclusive and the tax is extracted
  ///
  /// In en, this message translates to:
  /// **'Prices in DesKilo include VAT. Adding rates changes nothing about what members pay — the tax is extracted from the price you already charge and shown on the invoice.'**
  String get vatIntro;

  /// Shown when the workspace regime is not VAT-registered
  ///
  /// In en, this message translates to:
  /// **'This workspace is not declared VAT-registered, so invoices show no VAT. Change that under Legal identity.'**
  String get vatRegimeHint;

  /// No VAT rate configured yet
  ///
  /// In en, this message translates to:
  /// **'No rate yet — invoices show no VAT.'**
  String get vatEmpty;

  /// Button seeding the country's usual rates
  ///
  /// In en, this message translates to:
  /// **'Use the usual rates'**
  String get vatSeed;

  /// Adds an empty rate row
  ///
  /// In en, this message translates to:
  /// **'Add a rate'**
  String get vatAddRate;

  /// Rate name field ('Standard')
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get vatRateLabelField;

  /// Rate percentage field
  ///
  /// In en, this message translates to:
  /// **'Rate %'**
  String get vatRatePercentField;

  /// Tooltip of the default-rate radio
  ///
  /// In en, this message translates to:
  /// **'Default rate — used by subscriptions and by anything without its own rate'**
  String get vatRateDefaultTooltip;

  /// Tooltip of the remove-rate button
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get vatRateRemoveTooltip;

  /// Confirmation after saving the rates
  ///
  /// In en, this message translates to:
  /// **'VAT rates saved.'**
  String get vatSaved;

  /// Validation: exactly one default is required
  ///
  /// In en, this message translates to:
  /// **'Mark exactly one rate as the default.'**
  String get vatNeedsDefault;

  /// Validation: a rate needs a name and a percentage
  ///
  /// In en, this message translates to:
  /// **'Every rate needs a name and a percentage between 0 and 99.99.'**
  String get vatRateIncomplete;

  /// Tile leading to the VAT rate editor
  ///
  /// In en, this message translates to:
  /// **'VAT rates'**
  String get vatRatesTile;

  /// FEC account for collected VAT
  ///
  /// In en, this message translates to:
  /// **'VAT account'**
  String get vatAccountField;

  /// Explains the VAT account and its default
  ///
  /// In en, this message translates to:
  /// **'Where the accounting export books collected VAT. Empty = 445710.'**
  String get vatAccountHint;

  /// VAT rate picker in the service and package editors
  ///
  /// In en, this message translates to:
  /// **'VAT rate'**
  String get vatServiceRate;

  /// Picker entry meaning the workspace default rate
  ///
  /// In en, this message translates to:
  /// **'Workspace default'**
  String get vatServiceRateDefault;

  /// Invoice PDF: the net (tax-exclusive) subtotal
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get vatPdfNet;

  /// Invoice PDF: the VAT caption, followed by the rate
  ///
  /// In en, this message translates to:
  /// **'VAT'**
  String get vatPdfVat;

  /// FEC export: label of the collected-VAT account
  ///
  /// In en, this message translates to:
  /// **'Collected VAT'**
  String get fecAccountVat;

  /// Explains that a referenced rate is deactivated, not deleted
  ///
  /// In en, this message translates to:
  /// **'A rate still used by an invoice or a service is kept, deactivated.'**
  String get vatKeptRate;

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

  /// Owner screen + settings entry: workspace ID with QR (#88)
  ///
  /// In en, this message translates to:
  /// **'Workspace ID & QR'**
  String get workspaceCodeTitle;

  /// No description provided for @workspaceCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Workspace ID'**
  String get workspaceCodeLabel;

  /// No description provided for @workspaceCodeHint.
  ///
  /// In en, this message translates to:
  /// **'4–20 letters or digits, unique'**
  String get workspaceCodeHint;

  /// No description provided for @workspaceCodeEdit.
  ///
  /// In en, this message translates to:
  /// **'Change workspace ID'**
  String get workspaceCodeEdit;

  /// No description provided for @workspaceCodeRejected.
  ///
  /// In en, this message translates to:
  /// **'That ID was rejected — it must be 4–20 letters or digits and not already taken.'**
  String get workspaceCodeRejected;

  /// No description provided for @workspaceCodeExplainer.
  ///
  /// In en, this message translates to:
  /// **'Coworkers scan this QR code — or type the ID — to join this workspace.'**
  String get workspaceCodeExplainer;

  /// No description provided for @workspaceCodeCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy ID'**
  String get workspaceCodeCopy;

  /// No description provided for @workspaceCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get workspaceCodeCopied;

  /// Segment label: invite QR/code that joins as a plain member
  ///
  /// In en, this message translates to:
  /// **'Member invite'**
  String get inviteRoleMember;

  /// Segment label: invite QR/code that joins as an admin
  ///
  /// In en, this message translates to:
  /// **'Admin invite'**
  String get inviteRoleAdmin;

  /// Explainer under the admin invite QR
  ///
  /// In en, this message translates to:
  /// **'This code is single-use: it admits ONE person as an admin, then expires. Give it only to the person it is meant for.'**
  String get inviteAdminExplainer;

  /// No description provided for @inviteAdminNewCode.
  ///
  /// In en, this message translates to:
  /// **'New admin code'**
  String get inviteAdminNewCode;

  /// Footnote on the invite screen: owner role is never invitable
  ///
  /// In en, this message translates to:
  /// **'There is no owner invite — only an owner can grant ownership, in Members & plans.'**
  String get inviteOwnerNote;

  /// App-bar title of the QR scanner screen
  ///
  /// In en, this message translates to:
  /// **'Scan workspace QR'**
  String get scanJoinTitle;

  /// Join-mode button opening the QR scanner
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get onboardingScanButton;

  /// Join-QR scanner: helper line under the camera (#572)
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the invitation QR — the code is taken over and joined automatically.'**
  String get scanJoinHelp;

  /// Join-QR scanner: the QR decoded but is not an invitation (#791)
  ///
  /// In en, this message translates to:
  /// **'That QR is not a DesKilo invitation — scan the one from the invitation message.'**
  String get scanJoinNotAnInvite;

  /// Button exporting the workspace QR as a PNG via the share sheet (#112)
  ///
  /// In en, this message translates to:
  /// **'Share as PNG'**
  String get workspaceCodeSharePng;

  /// Owner settings entry + screen title for editing the workspace country/currency/time zone (#153).
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get workspaceSettingsTitle;

  /// Snackbar after the workspace locale settings were persisted (#153).
  ///
  /// In en, this message translates to:
  /// **'Workspace saved.'**
  String get workspaceSettingsSaved;

  /// Helper under the currency field on the workspace settings screen (#153).
  ///
  /// In en, this message translates to:
  /// **'Defaults from the country — override if your community bills in another currency.'**
  String get workspaceSettingsCurrencyHelper;

  /// Section title: owner editor (workspace settings) + the how-to-pay card on an unpaid statement (#155).
  ///
  /// In en, this message translates to:
  /// **'Payment instructions'**
  String get paymentInstructionsTitle;

  /// Helper under the payment-instructions section of the workspace settings screen (#155).
  ///
  /// In en, this message translates to:
  /// **'Shown to members on an unpaid statement. Leave empty to show nothing.'**
  String get paymentInstructionsHelper;

  /// Label of the PayPal.me field in the workspace settings (#155). PayPal.me is a brand name.
  ///
  /// In en, this message translates to:
  /// **'PayPal.me link or handle'**
  String get paymentInstructionsPaypalLabel;

  /// Label of the reference-hint field (settings) and row (statement card) (#155).
  ///
  /// In en, this message translates to:
  /// **'Payment reference hint'**
  String get paymentInstructionsReferenceLabel;

  /// Row title for the IBAN on the how-to-pay card — the acronym is identical in every locale (#155).
  ///
  /// In en, this message translates to:
  /// **'IBAN'**
  String get paymentInstructionsIbanTitle;

  /// Snackbar after tapping the IBAN row copied it to the clipboard (#155).
  ///
  /// In en, this message translates to:
  /// **'IBAN copied.'**
  String get paymentInstructionsIbanCopied;

  /// Label of the Wero field in the workspace settings — the phone number the workspace receives Wero payments on (#192). Wero is a brand name.
  ///
  /// In en, this message translates to:
  /// **'Wero phone number'**
  String get paymentInstructionsWeroLabel;

  /// Label of the Lydia field in the workspace settings (#192). Lydia is a brand name.
  ///
  /// In en, this message translates to:
  /// **'Lydia phone number or username'**
  String get paymentInstructionsLydiaLabel;

  /// Label of the Wise field in the workspace settings (#192). Wise and Wisetag are brand names.
  ///
  /// In en, this message translates to:
  /// **'Wisetag or Wise payment link'**
  String get paymentInstructionsWiseLabel;

  /// Snackbar after tapping a Wero/Lydia/Wise row copied its value to the clipboard (#192).
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard.'**
  String get paymentInstructionsValueCopied;

  /// Section title of the WhatsApp-group block on the workspace settings screen (#231). WhatsApp is a brand name.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp group'**
  String get workspaceWhatsappGroupTitle;

  /// Helper under the WhatsApp-group section of the workspace settings screen (#231); the chat.whatsapp.com URL is a fixed technical shape.
  ///
  /// In en, this message translates to:
  /// **'Shown to members so they can join the community\'s WhatsApp group. Paste the group\'s invite link (https://chat.whatsapp.com/…). Leave empty to show nothing.'**
  String get workspaceWhatsappGroupHelper;

  /// Label of the WhatsApp-group invite-link field in the workspace settings (#231).
  ///
  /// In en, this message translates to:
  /// **'WhatsApp group link'**
  String get workspaceWhatsappGroupLabel;

  /// Validation error when the entered group link does not start with https://chat.whatsapp.com/ (#231).
  ///
  /// In en, this message translates to:
  /// **'Must be a chat.whatsapp.com invite link'**
  String get workspaceWhatsappGroupInvalid;

  /// Member status label: an active member (complements memberStatusPaused / memberStatusExited).
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get memberStatusActive;

  /// Owner settings entry: export a complete human-readable PDF snapshot of the workspace configuration.
  ///
  /// In en, this message translates to:
  /// **'Export configuration (PDF)'**
  String get workspaceConfigPdfExport;

  /// Subtitle of the configuration-PDF export entry, contrasting it with the members-free XML export.
  ///
  /// In en, this message translates to:
  /// **'Complete snapshot: settings, all members and the floor plan.'**
  String get workspaceConfigPdfExportSubtitle;

  /// Title printed at the top of the configuration PDF.
  ///
  /// In en, this message translates to:
  /// **'Workspace configuration'**
  String get workspaceConfigPdfTitle;

  /// Sub-header of the configuration PDF stating the export date.
  ///
  /// In en, this message translates to:
  /// **'Generated on {date}'**
  String workspaceConfigPdfGeneratedOn(String date);

  /// Configuration PDF section: workspace locale and booking settings.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get workspaceConfigOverview;

  /// Configuration PDF section: the full member roster with roles and statuses.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get workspaceConfigMembersSection;

  /// Configuration PDF section: the workspace's enabled feature flags.
  ///
  /// In en, this message translates to:
  /// **'Enabled features'**
  String get workspaceConfigFeatures;

  /// Configuration PDF section: open weekdays and closure days.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get workspaceConfigAvailability;

  /// Configuration PDF section: levels, rooms, desks and seats.
  ///
  /// In en, this message translates to:
  /// **'Floor plan'**
  String get workspaceConfigFloorPlan;

  /// Configuration PDF overview line: how bookings are timed.
  ///
  /// In en, this message translates to:
  /// **'Booking granularity'**
  String get workspaceConfigGranularity;

  /// Configuration PDF members table: name column header.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get workspaceConfigColName;

  /// Configuration PDF members table: role column header.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get workspaceConfigColRole;

  /// Configuration PDF members table: status column header.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get workspaceConfigColStatus;

  /// Configuration PDF availability line: the weekdays the workspace is open.
  ///
  /// In en, this message translates to:
  /// **'Open days'**
  String get workspaceConfigOpenDays;

  /// Configuration PDF availability line: the configured closure days.
  ///
  /// In en, this message translates to:
  /// **'Closures'**
  String get workspaceConfigClosures;

  /// Configuration PDF floor plan: marker next to a room that can be booked as a whole.
  ///
  /// In en, this message translates to:
  /// **'bookable as a whole'**
  String get workspaceConfigBookableWhole;

  /// Configuration PDF floor plan: prefix of a desk's seat list.
  ///
  /// In en, this message translates to:
  /// **'Seats'**
  String get workspaceConfigSeats;

  /// Configuration PDF floor plan: placeholder for a level with no rooms.
  ///
  /// In en, this message translates to:
  /// **'No rooms'**
  String get workspaceConfigEmptyLevel;

  /// Configuration PDF: placeholder for an empty section (no members, no features, no closures).
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get workspaceConfigNone;

  /// Workspace settings section: how see-through desks are drawn (0040).
  ///
  /// In en, this message translates to:
  /// **'Desk transparency'**
  String get workspaceDeskTransparencyTitle;

  /// Helper under the desk-transparency slider explaining its effect.
  ///
  /// In en, this message translates to:
  /// **'Lower the desk opacity so a level\'s background photo shows through the tables.'**
  String get workspaceDeskTransparencyHelper;

  /// Live value label of the desk-opacity slider.
  ///
  /// In en, this message translates to:
  /// **'Opacity: {percent}%'**
  String workspaceDeskOpacityValue(int percent);

  /// Section header for irreversible owner-only actions in workspace settings.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get workspaceDangerZone;

  /// Owner settings entry: wipe all transactions and the floor plan, keeping settings and members (0039).
  ///
  /// In en, this message translates to:
  /// **'Reset workspace'**
  String get workspaceResetTitle;

  /// Subtitle of the reset-workspace entry summarizing what is removed and kept.
  ///
  /// In en, this message translates to:
  /// **'Delete all bookings, money and the floor plan. Keeps settings and members.'**
  String get workspaceResetSubtitle;

  /// Title of the destructive reset confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Reset this workspace?'**
  String get workspaceResetDialogTitle;

  /// Body of the reset confirmation dialog explaining exactly what is deleted vs kept, and that it is irreversible.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes every reservation, all money and ledger entries, the activity feed, and the entire floor plan — floors, rooms, tables, seats and images. Workspace settings, fee bands, availability, features, catalogs and members are kept. This cannot be undone.'**
  String get workspaceResetWarning;

  /// The exact phrase the owner must type to unlock the reset button. Keep it short and hard to type by accident.
  ///
  /// In en, this message translates to:
  /// **'I agree'**
  String get workspaceResetConfirmPhrase;

  /// Label of the confirmation text field, telling the owner which phrase to type.
  ///
  /// In en, this message translates to:
  /// **'Type \"{phrase}\" to confirm'**
  String workspaceResetConfirmLabel(String phrase);

  /// Destructive confirm button in the reset dialog; enabled only once the phrase matches.
  ///
  /// In en, this message translates to:
  /// **'Reset workspace'**
  String get workspaceResetConfirmButton;

  /// Success snackbar after the workspace has been reset.
  ///
  /// In en, this message translates to:
  /// **'Workspace reset.'**
  String get workspaceResetDone;

  /// Settings tile (#395): download the whole workspace as an Excel workbook.
  ///
  /// In en, this message translates to:
  /// **'Export data (Excel)'**
  String get workspaceExcelExport;

  /// Subtitle under the Excel export tile (#395).
  ///
  /// In en, this message translates to:
  /// **'Every dataset in one workbook: bookings, payments, invoices, members and the floor plan — a tab each.'**
  String get workspaceExcelExportSubtitle;

  /// Finance/settings UX + workspace language (#486)
  ///
  /// In en, this message translates to:
  /// **'Workspace language'**
  String get workspaceLanguageLabel;

  /// Finance/settings UX + workspace language (#486)
  ///
  /// In en, this message translates to:
  /// **'Invitations are written in this language by default.'**
  String get workspaceLanguageHelper;

  /// Finance/settings UX + workspace language (#486)
  ///
  /// In en, this message translates to:
  /// **'Sender\'s app language'**
  String get workspaceLanguageUnset;

  /// Finance/settings UX + workspace language (#486)
  ///
  /// In en, this message translates to:
  /// **'Payments & billing'**
  String get workspacePaymentsBillingTitle;

  /// Finance/settings UX + workspace language (#486)
  ///
  /// In en, this message translates to:
  /// **'IBAN, PayPal, Wero, Lydia, Wise and the payment reference'**
  String get paymentMethodsSubtitle;

  /// Workspace document library (#500)
  ///
  /// In en, this message translates to:
  /// **'Document library'**
  String get featureDocuments;

  /// Workspace document library (#500)
  ///
  /// In en, this message translates to:
  /// **'The workspace document library: statutes, guides, financial statements, minutes — linked from any drive, visible per role.'**
  String get featureDocumentsDesc;

  /// Workspace document library (#500)
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documentsTitle;

  /// Workspace document library (#500)
  ///
  /// In en, this message translates to:
  /// **'Add a document'**
  String get documentsAdd;

  /// Workspace document library (#500)
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get documentsTitleLabel;

  /// Workspace document library (#500)
  ///
  /// In en, this message translates to:
  /// **'Link (https://…)'**
  String get documentsUrlLabel;

  /// Workspace document library (#500)
  ///
  /// In en, this message translates to:
  /// **'Paste the share link from your drive — access rights stay managed there.'**
  String get documentsUrlHelper;

  /// Workspace document library (#500)
  ///
  /// In en, this message translates to:
  /// **'Stored on'**
  String get documentsProviderLabel;

  /// Workspace document library (#500)
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get documentsCategoryLabel;

  /// Workspace document library (#500)
  ///
  /// In en, this message translates to:
  /// **'Visible to'**
  String get documentsRoleLabel;

  /// Workspace document library (#500)
  ///
  /// In en, this message translates to:
  /// **'Every member'**
  String get documentsRoleMember;

  /// Workspace document library (#500)
  ///
  /// In en, this message translates to:
  /// **'Admins and owners'**
  String get documentsRoleAdmin;

  /// Workspace document library (#500)
  ///
  /// In en, this message translates to:
  /// **'Owners only'**
  String get documentsRoleOwner;

  /// Workspace document library (#500)
  ///
  /// In en, this message translates to:
  /// **'Statutes & legal'**
  String get documentsCategoryStatutes;

  /// Workspace document library (#500)
  ///
  /// In en, this message translates to:
  /// **'Guides & manuals'**
  String get documentsCategoryGuides;

  /// Workspace document library (#500)
  ///
  /// In en, this message translates to:
  /// **'Financial statements'**
  String get documentsCategoryFinance;

  /// Workspace document library (#500)
  ///
  /// In en, this message translates to:
  /// **'Meeting minutes'**
  String get documentsCategoryMinutes;

  /// Workspace document library (#500)
  ///
  /// In en, this message translates to:
  /// **'Other documents'**
  String get documentsCategoryOther;

  /// Workspace document library (#500)
  ///
  /// In en, this message translates to:
  /// **'No document yet. Link your statutes, guides and statements from any drive.'**
  String get documentsEmpty;

  /// Workspace document library (#500)
  ///
  /// In en, this message translates to:
  /// **'Remove document?'**
  String get documentsDelete;

  /// Workspace document library (#500)
  ///
  /// In en, this message translates to:
  /// **'A document needs a title and an https:// link.'**
  String get documentsInvalid;

  /// Feature name (#513)
  ///
  /// In en, this message translates to:
  /// **'Role management'**
  String get featureRoleManagement;

  /// Feature description (#513)
  ///
  /// In en, this message translates to:
  /// **'The central role→permission matrix: the owner decides which role holds which permission; everyone else reads their own. Off, the defaults simply apply.'**
  String get featureRoleManagementDesc;

  /// Roles screen title (#513)
  ///
  /// In en, this message translates to:
  /// **'Role management'**
  String get rolesTitle;

  /// Roles screen intro for editors (#513)
  ///
  /// In en, this message translates to:
  /// **'The owner always holds every permission. Decide here what the other roles may do — a co-owner can hold less than an owner.'**
  String get rolesIntroEditor;

  /// Roles screen intro for non-editors (#513)
  ///
  /// In en, this message translates to:
  /// **'Read-only: these are the permissions each role holds. Your role is highlighted.'**
  String get rolesIntroReadOnly;

  /// Chip on the reader's own role card (#513)
  ///
  /// In en, this message translates to:
  /// **'Your role'**
  String get rolesYourRole;

  /// Role label (#513)
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get roleOwner;

  /// Role label (#513)
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// Role label (#513)
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get roleMember;

  /// Permission label (#513)
  ///
  /// In en, this message translates to:
  /// **'Manage roles & permissions'**
  String get permManageRoles;

  /// Permission label (#513)
  ///
  /// In en, this message translates to:
  /// **'Manage members'**
  String get permManageMembers;

  /// Permission label (#513)
  ///
  /// In en, this message translates to:
  /// **'Configure validation policies'**
  String get permManageValidation;

  /// Permission label (#513)
  ///
  /// In en, this message translates to:
  /// **'Edit workspace settings'**
  String get permWorkspaceSettings;

  /// Permission label (#513)
  ///
  /// In en, this message translates to:
  /// **'Issue invoices & match payments'**
  String get permIssueInvoices;

  /// Permission label (#513)
  ///
  /// In en, this message translates to:
  /// **'View workspace finances'**
  String get permViewFinances;

  /// Permission label (#513)
  ///
  /// In en, this message translates to:
  /// **'Manage the document library'**
  String get permManageDocuments;

  /// Permission label (#513)
  ///
  /// In en, this message translates to:
  /// **'Manage services & packages'**
  String get permManageServices;

  /// Permission label (#513)
  ///
  /// In en, this message translates to:
  /// **'Approve expenses'**
  String get permApproveExpenses;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Region & formats'**
  String get regionalFormatsTitle;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Numbers & dates'**
  String get regionalFormatLocale;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Follows the app language ({locale})'**
  String regionalFormatLocaleAuto(String locale);

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get regionalFollowLanguage;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Clock'**
  String get regionalClock;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get regionalClockAuto;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Show times in my time zone'**
  String get regionalDeviceZone;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Off: times show in the workspace\'s zone, the one bookings are made in. On: your device\'s, labelled where it differs.'**
  String get regionalDeviceZoneHint;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Pick a time zone from the list'**
  String get workspaceTimezoneUnknown;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Cyprus'**
  String get countryNameCY;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Estonia'**
  String get countryNameEE;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Finland'**
  String get countryNameFI;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Greece'**
  String get countryNameGR;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Croatia'**
  String get countryNameHR;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Ireland'**
  String get countryNameIE;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Lithuania'**
  String get countryNameLT;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Latvia'**
  String get countryNameLV;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Malta'**
  String get countryNameMT;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Slovenia'**
  String get countryNameSI;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Slovakia'**
  String get countryNameSK;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Bulgaria'**
  String get countryNameBG;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Czechia'**
  String get countryNameCZ;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Denmark'**
  String get countryNameDK;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Hungary'**
  String get countryNameHU;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Poland'**
  String get countryNamePL;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Romania'**
  String get countryNameRO;

  /// #711 - globalization
  ///
  /// In en, this message translates to:
  /// **'Sweden'**
  String get countryNameSE;

  /// #711 - clock segment
  ///
  /// In en, this message translates to:
  /// **'24h'**
  String get regionalClock24h;

  /// #711 - clock segment
  ///
  /// In en, this message translates to:
  /// **'12h'**
  String get regionalClock12h;

  /// #713 - region name in the format picker
  ///
  /// In en, this message translates to:
  /// **'Mexico'**
  String get countryNameMX;

  /// #713 - region name in the format picker
  ///
  /// In en, this message translates to:
  /// **'Australia'**
  String get countryNameAU;

  /// #713 - region name in the format picker
  ///
  /// In en, this message translates to:
  /// **'Japan'**
  String get countryNameJP;

  /// #713 - language name in the format picker
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageNameDE;

  /// #713 - language name in the format picker
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageNameEN;

  /// #713 - language name in the format picker
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageNameES;

  /// #713 - language name in the format picker
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageNameFR;

  /// #713 - language name in the format picker
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get languageNameIT;

  /// #713 - language name in the format picker
  ///
  /// In en, this message translates to:
  /// **'Dutch'**
  String get languageNameNL;

  /// #713 - language name in the format picker
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get languageNamePT;

  /// #713 - language name in the format picker
  ///
  /// In en, this message translates to:
  /// **'Polish'**
  String get languageNamePL;

  /// #713 - language name in the format picker
  ///
  /// In en, this message translates to:
  /// **'Swedish'**
  String get languageNameSV;

  /// #713 - language name in the format picker
  ///
  /// In en, this message translates to:
  /// **'Danish'**
  String get languageNameDA;

  /// #713 - language name in the format picker
  ///
  /// In en, this message translates to:
  /// **'Norwegian'**
  String get languageNameNB;

  /// #713 - language name in the format picker
  ///
  /// In en, this message translates to:
  /// **'Finnish'**
  String get languageNameFI;

  /// #713 - language name in the format picker
  ///
  /// In en, this message translates to:
  /// **'Czech'**
  String get languageNameCS;

  /// #713 - language name in the format picker
  ///
  /// In en, this message translates to:
  /// **'Hungarian'**
  String get languageNameHU;

  /// #713 - language name in the format picker
  ///
  /// In en, this message translates to:
  /// **'Romanian'**
  String get languageNameRO;

  /// #713 - language name in the format picker
  ///
  /// In en, this message translates to:
  /// **'Greek'**
  String get languageNameEL;

  /// #713 - language name in the format picker
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get languageNameJA;

  /// #713 - region name in the format picker
  ///
  /// In en, this message translates to:
  /// **'Canada'**
  String get countryNameCA;

  /// #713 - region name in the format picker
  ///
  /// In en, this message translates to:
  /// **'Norway'**
  String get countryNameNO;

  /// No description provided for @permViewNegotiations.
  ///
  /// In en, this message translates to:
  /// **'View commercial agreements'**
  String get permViewNegotiations;

  /// No description provided for @permManageNegotiations.
  ///
  /// In en, this message translates to:
  /// **'Manage commercial agreements'**
  String get permManageNegotiations;

  /// Owner settings tile exporting the workspace settings + floor plan as a versioned XML file via the share sheet (#164)
  ///
  /// In en, this message translates to:
  /// **'Export workspace (XML)'**
  String get workspaceXmlExport;

  /// Subtitle under the XML export tile explaining what the file contains and what it deliberately omits (#164)
  ///
  /// In en, this message translates to:
  /// **'Settings and floor plan as a shareable file. No members, bookings or money data.'**
  String get workspaceXmlExportSubtitle;

  /// Owner settings tile starting the XML import flow: file pick, preview, destructive confirm (#165)
  ///
  /// In en, this message translates to:
  /// **'Import workspace (XML)'**
  String get workspaceXmlImport;

  /// Subtitle under the XML import tile warning that the current floor plan is replaced (#165)
  ///
  /// In en, this message translates to:
  /// **'Restore settings and floor plan from an exported file. Replaces the current floor plan.'**
  String get workspaceXmlImportSubtitle;

  /// File-type filter label in the platform file picker. The acronym is identical in every locale; the key exists so the parity gate covers the whole set (#165)
  ///
  /// In en, this message translates to:
  /// **'XML'**
  String get workspaceXmlFileTypeLabel;

  /// Title of the import preview dialog shown before anything is applied (#165)
  ///
  /// In en, this message translates to:
  /// **'Replace floor plan?'**
  String get workspaceXmlImportPreviewTitle;

  /// Summary line in the import preview dialog counting what the picked file contains (#165)
  ///
  /// In en, this message translates to:
  /// **'Levels: {levels} · Offices: {offices} · Desks: {desks} · Seats: {seats}'**
  String workspaceXmlImportPreviewCounts(
    int levels,
    int offices,
    int desks,
    int seats,
  );

  /// Second summary line in the import preview dialog counting the accessory catalog entries the picked file carries (schema v2, #180); 0 for a v1 file
  ///
  /// In en, this message translates to:
  /// **'Accessories: {count}'**
  String workspaceXmlImportPreviewAccessories(int count);

  /// Destructive-styled warning in the import preview dialog (#165)
  ///
  /// In en, this message translates to:
  /// **'The current floor plan will be deleted and replaced, and the workspace settings will be overwritten. This cannot be undone.'**
  String get workspaceXmlImportPreviewWarning;

  /// Destructive confirm button of the import preview dialog (#165)
  ///
  /// In en, this message translates to:
  /// **'Replace and import'**
  String get workspaceXmlImportConfirm;

  /// Snackbar after a successful XML import (#165)
  ///
  /// In en, this message translates to:
  /// **'Workspace imported.'**
  String get workspaceXmlImportSuccess;

  /// Snackbar when the picked file is not well-formed XML at all (WorkspaceXmlError.malformed, #165)
  ///
  /// In en, this message translates to:
  /// **'The file is not readable XML.'**
  String get workspaceXmlErrorMalformed;

  /// Snackbar when the XML root element is not deskilo-workspace (WorkspaceXmlError.wrongRoot, #165)
  ///
  /// In en, this message translates to:
  /// **'This is not a DesKilo workspace file.'**
  String get workspaceXmlErrorWrongRoot;

  /// Snackbar when the file's schema version is newer than this app understands (WorkspaceXmlError.unsupportedVersion, #165)
  ///
  /// In en, this message translates to:
  /// **'The file was exported by a newer version of DesKilo and cannot be imported.'**
  String get workspaceXmlErrorUnsupportedVersion;

  /// Snackbar when a required XML element is missing (WorkspaceXmlError.missingElement, #165)
  ///
  /// In en, this message translates to:
  /// **'The file is incomplete — a required section is missing.'**
  String get workspaceXmlErrorMissingElement;

  /// Snackbar when a required XML attribute is missing (WorkspaceXmlError.missingAttribute, #165)
  ///
  /// In en, this message translates to:
  /// **'The file is incomplete — a required value is missing.'**
  String get workspaceXmlErrorMissingAttribute;

  /// Snackbar when an XML attribute value fails validation (WorkspaceXmlError.invalidValue, #165)
  ///
  /// In en, this message translates to:
  /// **'The file contains an invalid value and cannot be imported.'**
  String get workspaceXmlErrorInvalidValue;

  /// Snackbar when the parsed plan fails the editor's placement rules client-side (#165)
  ///
  /// In en, this message translates to:
  /// **'The floor plan in the file is invalid: rooms, desks or seats overlap or extend outside their parent.'**
  String get workspaceXmlErrorInvalidPlan;

  /// Snackbar when the import RPC refuses because reservation history references the seats that would be deleted (#165)
  ///
  /// In en, this message translates to:
  /// **'This workspace already has reservations, so its floor plan cannot be replaced. Imports are only possible before the first booking.'**
  String get workspaceXmlImportReservationsError;
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
