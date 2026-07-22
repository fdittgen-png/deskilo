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
  /// **'Half days: bookings cover the morning (until 13:00), the afternoon (from 13:00) or the whole day.'**
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

  /// Settings toggle enabling the local diagnostics screen
  ///
  /// In en, this message translates to:
  /// **'Developer mode'**
  String get developerMode;

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
  /// **'{minutes} min'**
  String directoryLastSeenMinutes(int minutes);

  /// Directory offline chip: compact relative last-seen, under a day
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String directoryLastSeenHours(int hours);

  /// Directory offline chip: compact relative last-seen, a day or more
  ///
  /// In en, this message translates to:
  /// **'{days} d'**
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

  /// Feature switch: UnifiedPush delivery of confirmations
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
  /// **'Level reservations'**
  String get featureLevelBooking;

  /// No description provided for @featureLevelBookingDesc.
  ///
  /// In en, this message translates to:
  /// **'Reserve a whole floor as one booking, priced per half-day. Grant members the right per member.'**
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

  /// Default invitation message; firstName is '' or ' Name'
  ///
  /// In en, this message translates to:
  /// **'Hi{firstName}! You\'re invited to join our coworking space \"{workspaceName}\" on DesKilo.\n\n1. Download the app:\n{downloadUrl}\n\n2. Open it, create your account (e-mail + password) and sign in.\n\n3. Choose \"Join a workspace\" and enter the workspace ID:\n{workspaceId}\n(or scan the invite QR on site — {inviteLink})\n\nSee you soon at {workspaceName}!'**
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
  /// **'May reserve a whole level'**
  String get levelPermissionAllowed;

  /// No description provided for @levelPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'May not reserve a whole level'**
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
  /// **'You are not allowed to reserve a whole level.'**
  String get levelNotAllowed;

  /// No description provided for @levelConflict.
  ///
  /// In en, this message translates to:
  /// **'The level has reservations in that period.'**
  String get levelConflict;

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
  /// **'Whoever scans this QR code — or types this code — joins as an admin. Share it only with people who should manage this workspace.'**
  String get inviteAdminExplainer;

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
