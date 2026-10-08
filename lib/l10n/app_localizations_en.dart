// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get a11yClearDate => 'Clear the date';

  @override
  String get a11yDecrease => 'Decrease';

  @override
  String get a11yFinishEditing => 'Finish editing';

  @override
  String get a11yIncrease => 'Increase';

  @override
  String get a11yMoveDown => 'Move down';

  @override
  String get a11yMoveUp => 'Move up';

  @override
  String get a11yRecentre => 'Fit the plan to the screen';

  @override
  String get a11ySeatBlocked => 'not available';

  @override
  String get a11ySeatFree => 'free';

  @override
  String get a11ySeatMine => 'your seat';

  @override
  String get a11ySeatOccupied => 'occupied';

  @override
  String get a11ySeatReserved => 'reserved';

  @override
  String get a11yZoomIn => 'Zoom in';

  @override
  String get a11yZoomOut => 'Zoom out';

  @override
  String get aboutAttribution =>
      'Based on DesKilo by Florian DITTGEN — https://github.com/fdittgen-png/deskilo';

  @override
  String get aboutAttributionNote =>
      'This credit must stay visible in every copy and modified version.';

  @override
  String get aboutOpenSource => 'Free software (AGPL-3.0)';

  @override
  String get aboutOpenSourceDesc => 'Source code on GitHub';

  @override
  String get aboutPrivacy => 'Privacy policy';

  @override
  String get aboutReportBug => 'Report a bug / suggest a feature';

  @override
  String get aboutSupportBody =>
      'This app is free, open source and ad-free. If you find it useful, support the developer.';

  @override
  String get aboutSupportTitle => 'Support this project';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get accessKindNegotiations => 'Price negotiations';

  @override
  String get accessKindProfile => 'your profile';

  @override
  String get accessLogEmpty =>
      'Nobody has looked at your finances or messages.';

  @override
  String accessLogRow(String actor, String category, String subject) {
    return '$actor read $category of $subject';
  }

  @override
  String get accessLogTitle => 'Who accessed your data';

  @override
  String get accessNobodyElse => 'nobody else';

  @override
  String get accessRuleEvents => 'You, the member who acted, and the admins.';

  @override
  String accessRuleFinances(String people) {
    return 'You, and those with the finance permission: $people.';
  }

  @override
  String accessRuleManagedProfile(String people) {
    return 'While this profile was managed for you: $people. Every time one of them opened or changed it is on the record below.';
  }

  @override
  String get accessRuleMessages =>
      'Only the people in the conversation — no role can read a conversation it is not part of.';

  @override
  String accessRuleNegotiations(String people) {
    return 'You, the owners and the finance admins: $people. Every read by someone else is on the record below.';
  }

  @override
  String get accessRuleReminders => 'Only you.';

  @override
  String get accessRuleReservations =>
      'Every member of the workspace — the floor plan shows occupancy to everyone.';

  @override
  String get accessoriesActive => 'Active';

  @override
  String get accessoriesEdit => 'Edit accessory';

  @override
  String get accessoriesEmpty => 'No accessories yet.';

  @override
  String get accessoriesInactive => 'Inactive';

  @override
  String get accessoriesName => 'Name';

  @override
  String get accessoriesNew => 'New accessory';

  @override
  String get accessoriesNoSupplement => 'No supplement';

  @override
  String accessoriesPerHalfDay(String amount) {
    return '$amount / half-day';
  }

  @override
  String get accessoriesSupplement => 'Supplement per half-day';

  @override
  String get accessoriesTitle => 'Accessories';

  @override
  String get accountActivityEmpty => 'No records to display.';

  @override
  String get accountActivityFailed =>
      'Could not load your financial history. Tap to retry.';

  @override
  String get accountActivityScope =>
      'All your profiles on this server, including previous memberships. Currencies are shown separately.';

  @override
  String get accountActivityTitle => 'My consumption and payments';

  @override
  String get accountCardTitle => 'Your account';

  @override
  String get accountCredit => 'Credit on account';

  @override
  String get accountImputationHint =>
      'Your credit can settle open invoices — the workspace applies it when matching payments.';

  @override
  String get accountInvoiceIssued => 'Invoice issued';

  @override
  String get accountInvoiceRegrouped => 'Included in a settlement invoice';

  @override
  String get accountInvoiceVoided => 'Invoice voided';

  @override
  String get accountNet => 'Net position';

  @override
  String accountOpenPartial(String period, String paid) {
    return '$period · $paid paid';
  }

  @override
  String get accountPaymentAsk => 'Choose at checkout';

  @override
  String get accountPaymentConfirmed => 'Payment confirmed';

  @override
  String get accountPaymentPreference => 'Preferred online payment';

  @override
  String get accountPaymentsTitle => 'Payments';

  @override
  String get accountRefundDue => 'Refund due from the workspace';

  @override
  String get accountUsageCorrected => 'Corrected billable usage';

  @override
  String accountUsageMinutes(int minutes) {
    return '$minutes minutes';
  }

  @override
  String get accountingExportDevelopment =>
      'Development workspace: the file is marked DEV and is not the real books.';

  @override
  String get addressCountryLabel => 'Country';

  @override
  String get addressNone => 'No address';

  @override
  String get addressSaved => 'Address saved';

  @override
  String get addressTitle => 'Address';

  @override
  String get addressVatIdLabel => 'VAT number (if you invoice as a business)';

  @override
  String get addressWindowCountry => 'Follow the country';

  @override
  String get addressWindowLeft => 'Left (DIN 5008)';

  @override
  String get addressWindowOff => 'No window';

  @override
  String get addressWindowRight => 'Right (French)';

  @override
  String get addressWindowSubtitle =>
      'Where the recipient is printed so it shows through a window envelope. The address field is 85 × 45 mm, 45 mm from the top of the sheet.';

  @override
  String get addressWindowTitle => 'Address window';

  @override
  String get agreementExtraHalfDay => 'Extra half-day';

  @override
  String get amenityDock => 'Docking station';

  @override
  String get amenityErgonomicChair => 'Ergonomic chair';

  @override
  String get amenityMonitor => 'Monitor';

  @override
  String get amenityStandingDesk => 'Standing desk';

  @override
  String get amenityWindow => 'Window seat';

  @override
  String get appTitle => 'DesKilo';

  @override
  String get applicationAcceptedVote => 'Approved this request';

  @override
  String get applicationApproved => 'Approved';

  @override
  String get applicationDecisionComment => 'Comment visible to the applicant';

  @override
  String get applicationDiscussionHint =>
      'Your requests and reviewer discussions remain available, even if a request is refused.';

  @override
  String get applicationNoMessages => 'No messages yet.';

  @override
  String get applicationPending => 'Awaiting approval';

  @override
  String get applicationRefused => 'Refused';

  @override
  String get applicationRefusedVote => 'Refused this request';

  @override
  String get applicationReplyFailed =>
      'Your message was not sent. Your draft is kept; please try again.';

  @override
  String get applicationsEmpty => 'No workspace requests.';

  @override
  String get applicationsLoadFailed =>
      'Could not load your workspace requests. Please try again.';

  @override
  String get applicationsTitle => 'Workspace requests';

  @override
  String get assistantPrefix => 'Assistant';

  @override
  String get assistantSetupActorConfigurer =>
      'Who: someone who manages this workspace\'s configuration';

  @override
  String get assistantSetupActorDatabaseAdministrator =>
      'Who: a database administrator';

  @override
  String get assistantSetupActorInstanceOperator =>
      'Who: the instance owner or a delegate';

  @override
  String get assistantSetupActorIntegrations =>
      'Who: someone who manages this workspace\'s integrations';

  @override
  String get assistantSetupActorYou => 'Who: you';

  @override
  String get assistantSetupAllDone =>
      'Everything is set up for this workspace.';

  @override
  String get assistantSetupApply => 'Apply';

  @override
  String get assistantSetupConnectHowTo =>
      '1. In your assistant, add a custom connector with this URL.\n2. Sign in with your DesKilo account when asked.\n3. Approve this workspace and the operations you allow.';

  @override
  String get assistantSetupCopied => 'Connector URL copied.';

  @override
  String get assistantSetupCopyUrl => 'Copy connector URL';

  @override
  String get assistantSetupCustomise => 'Customise';

  @override
  String get assistantSetupFailed =>
      'Could not save. Nothing changed; try again.';

  @override
  String assistantSetupInstanceNames(String names) {
    return 'Answering for this database: $names.';
  }

  @override
  String get assistantSetupInstanceNobody =>
      'Nobody answers for this database yet.';

  @override
  String get assistantSetupInstanceYou =>
      'You answer for this database: switch assistants on from the instance tools.';

  @override
  String get assistantSetupIntro =>
      'What assistants need to work in this workspace, in order. Each step says who takes it.';

  @override
  String get assistantSetupLinkIdentity => 'Confirm my identity';

  @override
  String assistantSetupNextTodo(String step) {
    return 'Next: $step.';
  }

  @override
  String assistantSetupNextWaiting(String step, String actor) {
    return 'Next: $step. $actor.';
  }

  @override
  String get assistantSetupNoConnector =>
      'This app runs without a server, so there is no connector URL.';

  @override
  String get assistantSetupNoWorkspace => 'Select a workspace first.';

  @override
  String get assistantSetupPreviewAdds => 'Added';

  @override
  String get assistantSetupPreviewNone =>
      'No change: the workspace already offers exactly this set.';

  @override
  String get assistantSetupPreviewNote =>
      'Only a member\'s own records and the availability reads. Assistants already connected get new operations only after each person approves again.';

  @override
  String get assistantSetupPreviewOwn =>
      'Assistants see only each member\'s own records.';

  @override
  String get assistantSetupPreviewRemoves => 'Removed';

  @override
  String get assistantSetupPreviewTitle => 'Recommended set';

  @override
  String get assistantSetupReasonConnect =>
      'Add the connector in your assistant, sign in, and approve this workspace.';

  @override
  String get assistantSetupReasonEligibility =>
      'This database\'s administrators approve each person once, for every workspace on it.';

  @override
  String get assistantSetupReasonIdentity =>
      'An assistant acts as you, so this database must know it is you.';

  @override
  String get assistantSetupReasonInstallation =>
      'The instance owner or a delegate switches assistants on for every workspace on this database.';

  @override
  String get assistantSetupReasonPolicy =>
      'Nothing is offered to assistants until someone chooses the operations.';

  @override
  String get assistantSetupReasonWorkspace =>
      'While it is off, the workspace refuses every assistant call.';

  @override
  String get assistantSetupRecommended => 'Use the recommended set';

  @override
  String get assistantSetupRequest => 'Ask for access';

  @override
  String get assistantSetupReview => 'Review requests';

  @override
  String get assistantSetupSaved => 'Saved.';

  @override
  String get assistantSetupStale =>
      'Someone changed the offer meanwhile. Review it and try again.';

  @override
  String get assistantSetupStateBlocked => 'After the steps above';

  @override
  String get assistantSetupStateDone => 'Done';

  @override
  String get assistantSetupStateTodo => 'To do';

  @override
  String get assistantSetupStateUnavailable => 'Could not be asked';

  @override
  String get assistantSetupStateWaiting => 'Waiting';

  @override
  String get assistantSetupStepConnect => 'Connect your assistant';

  @override
  String get assistantSetupStepEligibility => 'Ask for your assistant access';

  @override
  String get assistantSetupStepIdentity => 'Link your identity';

  @override
  String get assistantSetupStepInstallation =>
      'Assistants switched on for this database';

  @override
  String get assistantSetupStepPolicy => 'Choose what assistants may do';

  @override
  String get assistantSetupStepWorkspace =>
      'Turn assistants on for this workspace';

  @override
  String get assistantSetupTitle => 'Assistant setup';

  @override
  String get assistantSetupTurnOn => 'Turn on';

  @override
  String get authAlreadyRegistered =>
      'This address cannot be used to create an account. Sign in or reset your password instead.';

  @override
  String get authConnectServer => 'Connect an organisation\'s server';

  @override
  String get authContinueWith => 'or continue with';

  @override
  String get authDisplayNameLabel => 'Display name';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authEmailNotConfirmed =>
      'Confirm your e-mail address first: open the message we sent you, then sign in.';

  @override
  String get authFieldRequired => 'Required';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authGenericError =>
      'Authentication failed. Check your credentials and try again.';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authJoinByInvitation => 'Join by invitation';

  @override
  String get authJoinHint =>
      'Create your account or sign in first — you\'ll paste your invitation right after.';

  @override
  String authLinkAlreadyUsed(String provider) {
    return 'This $provider identity is already linked to another account.';
  }

  @override
  String authLinkFailed(String provider, String code) {
    return 'Linking $provider did not work ($code). Try again; if it keeps failing, tell the server\'s administrator this code.';
  }

  @override
  String get authLinkManualDisabled =>
      'Linking accounts is switched off on this server. Its administrator must turn on “Allow manual linking” in the authentication settings.';

  @override
  String get authNetworkError =>
      'Could not reach the server. Check your connection and try again.';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordTooShort => 'At least 8 characters';

  @override
  String get authProviderDisabled =>
      'This sign-in method is switched off on this server.';

  @override
  String get authRateLimited =>
      'Too many attempts. Wait a moment, then try again.';

  @override
  String get authRecoveryNotSaved =>
      'Your code was accepted, but the new password was not saved. Try saving it again.';

  @override
  String get authRecoveryRetryUpdate => 'Save the new password again';

  @override
  String get authRecoverySessionLost =>
      'That code is no longer valid here. Request a new one.';

  @override
  String get authResetCodeLabel => 'Code from the email';

  @override
  String get authResetCodeSent => 'Code sent — check your email.';

  @override
  String get authResetDone => 'Password updated — you are signed in.';

  @override
  String get authResetExplainer =>
      'We\'ll email you a one-time code. Use it here to set a new password.';

  @override
  String get authResetInvalidCode => 'That code is invalid or expired.';

  @override
  String get authResetNewPasswordLabel => 'New password';

  @override
  String get authResetSendCode => 'Send code';

  @override
  String get authResetSubmit => 'Set new password';

  @override
  String get authResetTitle => 'Reset password';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authSignInButton => 'Sign in';

  @override
  String get authSignInTitle => 'Sign in';

  @override
  String get authSignOut => 'Sign out';

  @override
  String get authSignUpButton => 'Create account';

  @override
  String get authSignUpTitle => 'Create account';

  @override
  String authSocialUnavailable(String provider) {
    return '$provider sign-in is not available yet — the server has not enabled it.';
  }

  @override
  String get authToggleToSignIn => 'Already have an account? Sign in';

  @override
  String get authToggleToSignUp => 'New here? Create an account';

  @override
  String get authVerifyBackToSignIn => 'Back to sign in';

  @override
  String authVerifyBody(String email) {
    return 'We sent a confirmation link to $email. Open it on this device to finish creating your account.';
  }

  @override
  String get authVerifyChangeEmail => 'Use another address';

  @override
  String get authVerifyHint =>
      'Nothing yet? Look in the spam folder, or send it again.';

  @override
  String get authVerifyResend => 'Send the e-mail again';

  @override
  String get authVerifyResendWait => 'You can send it again in a minute.';

  @override
  String get authVerifyResent => 'Sent again.';

  @override
  String get authVerifyTitle => 'Check your e-mail';

  @override
  String get authWeakPassword => 'Choose a stronger password.';

  @override
  String get availabilityAddClosure => 'Add closure day';

  @override
  String get availabilityClosureDays => 'Closure days';

  @override
  String get availabilityClosureReason => 'Reason (optional)';

  @override
  String get availabilityFullDayHours => 'Hours billed as a full day';

  @override
  String get availabilityGranularity15 => '15-minute slots';

  @override
  String get availabilityGranularity30 => '30-minute slots';

  @override
  String get availabilityGranularity5 => '5-minute slots';

  @override
  String get availabilityGranularity60 => '1-hour slots';

  @override
  String get availabilityGranularityDescription =>
      'Half days: bookings cover the morning, the afternoon or the whole working day — the windows follow the configured working hours.';

  @override
  String get availabilityGranularityFlexible => 'Free time period';

  @override
  String get availabilityGranularityFullDay => 'Full days only';

  @override
  String get availabilityGranularityHalfDay =>
      'Half days (morning & afternoon)';

  @override
  String get availabilityGranularityHours =>
      'Real hours (exact from–to, half/full days as shortcuts)';

  @override
  String get availabilityGranularityTitle => 'Booking granularity';

  @override
  String get availabilityHalfBoundary => 'Half-day boundary';

  @override
  String get availabilityHalfDayHours => 'Hours billed as a half day';

  @override
  String availabilityHourOption(int count) {
    return '$count h';
  }

  @override
  String get availabilityLastOpenDay => 'At least one weekday must stay open.';

  @override
  String get availabilityNoClosures => 'No closure days.';

  @override
  String get availabilityOpenWeekdays => 'Open weekdays';

  @override
  String get availabilityPoliciesTitle => 'Booking policies';

  @override
  String get availabilityTitle => 'Availability';

  @override
  String get availabilityWorkEnd => 'Day ends';

  @override
  String get availabilityWorkHoursDescription =>
      'The half-day and full-day windows everywhere — reservations, check-in and invoicing — follow these hours.';

  @override
  String get availabilityWorkHoursInvalid =>
      'The day must run start < half-day boundary < end.';

  @override
  String get availabilityWorkHoursTitle => 'Working hours';

  @override
  String get availabilityWorkStart => 'Day starts';

  @override
  String get backendCopyLink => 'Copy';

  @override
  String get backendCurrentTitle => 'This device uses';

  @override
  String get backendDescriptorInvalid =>
      'That is not a valid DesKilo server code.';

  @override
  String get backendDescriptorLabel => 'Server code';

  @override
  String backendDescriptorNamed(String label) {
    return 'Named \"$label\" by whoever shared it — not verified.';
  }

  @override
  String backendDestination(String host) {
    return 'Destination: $host';
  }

  @override
  String get backendErrorKeyConnectionString =>
      'That is a database connection string. It never leaves the server — paste the project\'s publishable key here.';

  @override
  String get backendErrorKeyEmpty => 'Enter the publishable key.';

  @override
  String get backendErrorKeyNotSupabase =>
      'That is not a Supabase publishable key (sb_publishable_…).';

  @override
  String get backendErrorKeyPersonalToken =>
      'That is a personal access token. It stays with its owner — paste the project\'s publishable key here.';

  @override
  String get backendErrorKeySecret =>
      'That is a secret key, not a publishable one. Never share it: rotate it in Project Settings → API keys, then paste the publishable key here.';

  @override
  String get backendErrorKeyUserToken =>
      'That is a session or identity token, not a project key. Paste the project\'s publishable key here.';

  @override
  String get backendErrorUrlEmpty => 'Enter the project URL.';

  @override
  String get backendErrorUrlNoHost => 'That is not a complete address.';

  @override
  String get backendErrorUrlNotCanonical =>
      'Use only the project\'s address (https://host), without a path, a query or credentials.';

  @override
  String get backendErrorUrlNotHttps => 'The URL must start with https://.';

  @override
  String get backendFacetNo => 'no';

  @override
  String get backendFacetUnknown => 'unknown';

  @override
  String get backendFacetYes => 'yes';

  @override
  String backendFacets(
    String reachable,
    String key,
    String schema,
    String version,
  ) {
    return 'Reached: $reachable · Key accepted: $key · Schema: $schema · Version: $version';
  }

  @override
  String get backendFullCheckHint =>
      'Paste a personal access token for this check. It is used for this check only and never stored.';

  @override
  String get backendFullCheckTitle => 'Run a full check';

  @override
  String get backendFullCheckUseToken => 'Use this token';

  @override
  String get backendHowTitle => 'Use your own server';

  @override
  String get backendKeyLabel => 'Publishable key';

  @override
  String backendLastOk(String time) {
    return 'Last successful test: $time';
  }

  @override
  String get backendModeConnect => 'Connect an existing organization';

  @override
  String get backendModeConnectHint =>
      'Scan or paste the server code your organization gave you. You never need an administrator key.';

  @override
  String get backendModeDefault => 'Use DesKilo\'s service';

  @override
  String get backendModeDefaultHint =>
      'DesKilo\'s own service needs no setup. Members of an organization that runs its own server use its code instead.';

  @override
  String get backendModeOperator => 'Set up a server (operators)';

  @override
  String get backendOpenDashboard => 'Open in Supabase';

  @override
  String get backendOwnServer => 'Your own server';

  @override
  String get backendOwnership =>
      'Your Supabase organization owns it. DesKilo keeps no access to it.';

  @override
  String get backendOwnershipOther =>
      'Whoever runs this server owns it. DesKilo keeps no access to it.';

  @override
  String get backendPaste => 'Paste';

  @override
  String backendPendingBody(String active, String saved) {
    return 'This session still runs on $active. $saved takes over when you close and reopen the app.';
  }

  @override
  String get backendPendingTitle => 'Saved for the next start';

  @override
  String get backendPendingUndo => 'Undo';

  @override
  String get backendPendingUndone => 'Undone — the previous server is back.';

  @override
  String backendProjectRef(String ref) {
    return 'Your Supabase project $ref';
  }

  @override
  String get backendResetDeviceOnly =>
      'This changes this device only and never touches your Supabase project.';

  @override
  String get backendSaveNeedsTest =>
      'Test the connection first. Only a verified server can be saved.';

  @override
  String get backendScan => 'Scan a server QR';

  @override
  String get backendScanNothing => 'That QR is not a DesKilo server code.';

  @override
  String backendServerCustom(Object host) {
    return 'Your own server ($host)';
  }

  @override
  String backendServerDefault(Object host) {
    return 'The app\'s own server ($host)';
  }

  @override
  String get backendServerHint =>
      'By default this app uses its own server. If your community runs its own Supabase project, enter it here — the app then stores everything there.';

  @override
  String get backendServerInUse => 'In use on this device';

  @override
  String get backendServerReset => 'Use the app\'s server';

  @override
  String get backendServerRestartHint =>
      'The app signs you out and applies the change on the next start.';

  @override
  String get backendServerSaved =>
      'Saved. Close and reopen the app to use the new server.';

  @override
  String get backendServerTitle => 'Server';

  @override
  String get backendShare => 'Share this server';

  @override
  String get backendShareHint =>
      'Members scan this in Settings → Server to point their app at the same instance.';

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
  String get backendTest => 'Test the connection';

  @override
  String get backendTestAhead =>
      'Reached it. Its schema is newer than this app — it works, and a newer app is available.';

  @override
  String get backendTestAttention =>
      'Reached it, but the answer could not be classified. Check the server before using it.';

  @override
  String get backendTestBadKey =>
      'Reached it, but the key was refused. Copy the publishable key again from Project Settings → API keys.';

  @override
  String get backendTestBehind =>
      'Reached it, but its DesKilo schema is older than this app needs. Update the server before using it.';

  @override
  String get backendTestOk => 'Reached it — the app\'s schema is there.';

  @override
  String get backendTestSchemaMissing =>
      'Reached it, but the DesKilo tables are missing — run the migrations from supabase/migrations on that project first.';

  @override
  String get backendTestUnreachable =>
      'Could not reach that address. Check the URL and your network.';

  @override
  String get backendTesting => 'Testing…';

  @override
  String get backendUrlLabel => 'Project URL';

  @override
  String get backendVersionAhead =>
      'The server is newer than this app — update the app when you can';

  @override
  String backendVersionBehind(int version) {
    return 'Needs an update: this app needs schema $version';
  }

  @override
  String get backendVersionBehindHow =>
      'Its owner updates it with the setup wizard or `dart run tool/instance.dart install`, which applies only what is missing.';

  @override
  String backendVersionCurrent(int version) {
    return 'Up to date (schema $version)';
  }

  @override
  String get backendVersionShortAhead => 'newer';

  @override
  String get backendVersionShortBehind => 'older';

  @override
  String get backendVersionShortCurrent => 'current';

  @override
  String get backendVersionUnknown =>
      'The version could not be checked right now';

  @override
  String get badgeAuthEnabledHint =>
      'Off by default: a badge that checks you in does not log you in until you say so.';

  @override
  String get badgeAuthEnabledLabel => 'Signs me in';

  @override
  String get badgeAuthNeedsPin =>
      'Set a sign-in PIN first — a badge alone must never be enough.';

  @override
  String get badgeCardAlreadyRegistered => 'That card is already registered.';

  @override
  String get badgeCardRegistered => 'Card registered.';

  @override
  String get badgeDefaultLabel => 'Badge';

  @override
  String get badgeDeleteConfirm => 'Delete this revoked badge for good?';

  @override
  String get badgeIssue => 'New badge';

  @override
  String badgeIssuedOn(String date) {
    return 'Issued $date';
  }

  @override
  String get badgeNone => 'No badges yet.';

  @override
  String get badgePinChangeAction => 'Change PIN';

  @override
  String get badgePinClearAction => 'Remove PIN';

  @override
  String get badgePinCleared =>
      'PIN removed. Your badges no longer sign you in.';

  @override
  String get badgePinConfirmLabel => 'Repeat it';

  @override
  String get badgePinExplain =>
      'Your PIN lets you sign in by scanning your badge instead of typing your e-mail. Only you can set it, and nobody — not even an owner — can read it back.';

  @override
  String get badgePinMismatch => 'The two entries do not match.';

  @override
  String get badgePinNewLabel => 'New PIN';

  @override
  String get badgePinNotSet => 'No PIN yet';

  @override
  String get badgePinSaveFailed =>
      'Could not reach the server. Your PIN was not changed — try again.';

  @override
  String get badgePinSaved => 'PIN saved.';

  @override
  String get badgePinSectionTitle => 'My PIN';

  @override
  String get badgePinSet => 'PIN set';

  @override
  String get badgePinSetAction => 'Set a PIN';

  @override
  String badgePinTooShort(int min) {
    return 'Use at least $min digits.';
  }

  @override
  String get badgeRegisterCard => 'Register card';

  @override
  String get badgeRevoke => 'Revoke';

  @override
  String get badgeRevoked => 'Revoked';

  @override
  String get badgeSavePdf => 'Save as PDF';

  @override
  String get badgeSignInButton => 'Sign in';

  @override
  String get badgeSignInEntry => 'Sign in with a badge';

  @override
  String badgeSignInHello(String name) {
    return 'Hello $name';
  }

  @override
  String get badgeSignInLocked =>
      'Too many attempts. Wait a few minutes, or sign in with your e-mail.';

  @override
  String get badgeSignInNoReader =>
      'No badge reader is available on this device.';

  @override
  String get badgeSignInPinLabel => 'Your PIN';

  @override
  String get badgeSignInRefused =>
      'That did not work. Check the badge and the PIN, or sign in with your e-mail.';

  @override
  String get badgeSignInRetry => 'Try again';

  @override
  String get badgeSignInTapPrompt => 'Hold your badge against the phone.';

  @override
  String get badgeSignInTitle => 'Sign in with your badge';

  @override
  String get badgeSignInUnavailable =>
      'Badge sign-in is not reachable right now. Sign in with your e-mail instead.';

  @override
  String get badgeSignInUseEmail => 'Use my e-mail instead';

  @override
  String get badgeTapCardHint =>
      'Hold the RFID/NFC card to the back of the device.';

  @override
  String get badgeTapCardTitle => 'Register a card';

  @override
  String get badgeTokenOnce => 'Save this QR now — it is shown only once.';

  @override
  String get baseRoleNote =>
      'Everyone has exactly one base role: User, Administrator, Co-owner or Owner. Other roles add to it; none takes anything away.';

  @override
  String get baseRoleUser => 'User';

  @override
  String get biAreaCapacity => 'Space and capacity';

  @override
  String get biAreaFinance => 'Finance';

  @override
  String get biAreaOperations => 'Operations';

  @override
  String get biAreaOverview => 'Overview';

  @override
  String get biAreaPeople => 'People and business';

  @override
  String get biAreaPlanning => 'Planning';

  @override
  String get biAreaSaved => 'Saved analyses';

  @override
  String get biAreaTreasury => 'Treasury';

  @override
  String get biBookingBasis =>
      'Reserved capacity measures bookings, not actual attendance.';

  @override
  String get biCardDown => 'Move down';

  @override
  String get biCardUp => 'Move up';

  @override
  String get biCards => 'Analyses shown';

  @override
  String biCardsUnavailable(String count) {
    return '$count analyses of this view are not available to you and are left out.';
  }

  @override
  String biChangePoints(String value) {
    return '$value pp';
  }

  @override
  String get biCollectionCentre => 'of what was invoiced';

  @override
  String get biCollectionCollected => 'Collected';

  @override
  String get biCollectionNoComposition =>
      'The amounts collected here include earlier invoices, so they are not a part of this period\'s invoiced total.';

  @override
  String get biCollectionOutstanding => 'Still to collect';

  @override
  String get biColumnChange => 'Change';

  @override
  String get biColumnValue => 'Value';

  @override
  String get biCompare => 'Compare with';

  @override
  String get biCompareCustom => 'A period I choose';

  @override
  String get biCompareNone => 'Nothing';

  @override
  String get biComparePrevious => 'The period before';

  @override
  String get biComparePreviousYear => 'The same period a year before';

  @override
  String get biCompareTitle => 'Compared with the past';

  @override
  String biComparedLine(String period, String value, String change) {
    return '$period: $value ($change)';
  }

  @override
  String biComparedNotRecorded(String period, String since) {
    return '$period was not recorded (history begins $since); there is no comparison.';
  }

  @override
  String biComparedPartial(String period) {
    return '$period is only partly recorded.';
  }

  @override
  String get biComparisonUnqualified =>
      'Change unavailable: one period has partial or out-of-date data.';

  @override
  String get biCompositionTitle => 'What it is made of';

  @override
  String biComputedWorkspaceTime(String date) {
    return 'Computed $date · workspace time';
  }

  @override
  String get biCurrentBasis =>
      'The whole period is included. Comparison with a completed period is not like-for-like.';

  @override
  String get biDataNotApplicable => 'No applicable capacity';

  @override
  String get biDataNotRecorded => 'Not recorded';

  @override
  String get biDataPartial => 'Partial data';

  @override
  String get biDataStale => 'Out of date';

  @override
  String get biDataUnavailable => 'Unavailable';

  @override
  String get biDeltaNone => 'No comparison yet';

  @override
  String get biDimensionLevel => 'Level';

  @override
  String get biEvolutionTitle => 'Evolution';

  @override
  String get biExportPdf => 'Export as PDF';

  @override
  String get biExposureDiffers =>
      'The two periods do not offer the same base; the ratio accounts for it, the raw figures do not compare directly.';

  @override
  String get biFinanceCollected => 'Collected';

  @override
  String biFinanceCollectedBasis(String count) {
    return 'From $count payments matched to invoices';
  }

  @override
  String get biFinanceCollectedDefinition =>
      'Payments matched to invoices, by the month of the match on the workspace clock.';

  @override
  String get biFinanceCollectedZero => 'Measured: nothing was collected.';

  @override
  String biFinanceComputed(String date) {
    return 'Computed $date';
  }

  @override
  String get biFinanceCurrencyMix =>
      'This period holds amounts in another currency; amounts in different currencies are not added, so none is shown.';

  @override
  String get biFinanceInvoiced => 'Invoiced';

  @override
  String biFinanceInvoicedBasis(String count, String credit) {
    return 'From $count invoices; credit notes $credit, shown apart';
  }

  @override
  String get biFinanceInvoicedDefinition =>
      'Invoices of these months, voided ones and settlements left out (a settlement regroups invoices already counted); positive totals only.';

  @override
  String get biFinanceInvoicedZero => 'Measured: nothing was invoiced.';

  @override
  String biFinanceLastChange(String date) {
    return 'Last change to the source: $date';
  }

  @override
  String get biFinanceNotExact =>
      'An amount is too large to show exactly, so it is not shown.';

  @override
  String get biFinanceNotProfit =>
      'Not a profit: no cost is in this figure, and the two figures are not subtracted from each other.';

  @override
  String get biFinancePartial =>
      'The period is not over: these figures will still change.';

  @override
  String get biFinanceSameAsReport =>
      'The same rules as the workspace status report, computed once on the server.';

  @override
  String get biForbidden => 'You may not read this analysis in this workspace.';

  @override
  String get biFutureBasis =>
      'Existing bookings and current opening rules; not a demand forecast or guaranteed usage.';

  @override
  String get biGrain => 'Period length';

  @override
  String get biGrainMonth => 'Month';

  @override
  String get biGrainQuarter => 'Quarter';

  @override
  String get biGrainYear => 'Year';

  @override
  String get biGroupBy => 'Group by';

  @override
  String get biGroupNone => 'No grouping';

  @override
  String get biInvalidAddress =>
      'This address asks for an analysis that does not exist; nothing was read.';

  @override
  String get biKindCurrent => 'Now';

  @override
  String get biKindPrevious => 'Previous period';

  @override
  String get biKindYearAgo => 'Same period last year';

  @override
  String biNarrativeDown(String label, String change) {
    return 'Lower than $label ($change).';
  }

  @override
  String biNarrativeFlat(String label) {
    return 'About the same as $label.';
  }

  @override
  String biNarrativeUp(String label, String change) {
    return 'Higher than $label ($change).';
  }

  @override
  String get biNoDataLabel => 'no data';

  @override
  String get biNotOffered => 'not offered by the analyses shown';

  @override
  String get biOnPace => 'on pace';

  @override
  String get biOpenSource => 'Open the source';

  @override
  String get biPastBasis =>
      'Recomputed from records available now, not a snapshot of what was known then.';

  @override
  String get biPdfEstimateNote =>
      'Dashed lines and shaded bands are estimates from past periods, not measurements.';

  @override
  String get biPdfFailed => 'The PDF could not be made.';

  @override
  String biPdfProduced(String date) {
    return 'Produced on $date';
  }

  @override
  String get biPdfTitle => 'Business analytics';

  @override
  String biProjectionBasis(int count) {
    return 'A straight line through the last $count complete periods, carried forward. The shaded band is the likely range. An estimate, not a promise.';
  }

  @override
  String get biProjectionLabel => 'Estimate';

  @override
  String biProjectionNotEnough(int have, int need) {
    return 'Not enough history to project yet: $have complete periods so far, $need needed.';
  }

  @override
  String get biProjectionTitle => 'Where it is heading';

  @override
  String get biProvisionalNote =>
      'Provisional: the period is not over, so this change is an estimate.';

  @override
  String biQuarter(String quarter, String year) {
    return 'Q$quarter $year';
  }

  @override
  String get biRecordedFuture => 'Future period · bookings on record';

  @override
  String get biRecordedPast => 'Past period · current records';

  @override
  String get biRecordedPresent => 'Current period · includes future dates';

  @override
  String get biRefresh => 'Refresh data';

  @override
  String biRefusedBudget(String count) {
    return 'There are more than $count groups; choose no grouping.';
  }

  @override
  String get biRefusedComparison =>
      'This analysis cannot make that comparison.';

  @override
  String get biRefusedGrain =>
      'This analysis is not offered for that period length.';

  @override
  String get biRefusedGrouping => 'This analysis cannot be grouped that way.';

  @override
  String get biRemainder => 'Not in a current group';

  @override
  String get biReset => 'Show the standard view';

  @override
  String biRunRate(String value) {
    return 'At the pace so far, this period would end at about $value.';
  }

  @override
  String get biRunningLabel => 'running';

  @override
  String get biSeatCentre => 'of all seat time';

  @override
  String get biSeatClosed => 'Outside opening hours';

  @override
  String get biSeatFree => 'Free during opening hours';

  @override
  String biSeatHoursBlocked(String hours) {
    return '$hours blocked seat-hours';
  }

  @override
  String biSeatHoursFree(String hours) {
    return '$hours unreserved seat-hours';
  }

  @override
  String get biSeatReserved => 'Reserved';

  @override
  String get biShareByLevel => 'Reserved time by level';

  @override
  String get biSort => 'Order';

  @override
  String get biSortAscending => 'Lowest first';

  @override
  String get biSortDescending => 'Highest first';

  @override
  String get biSortNatural => 'As listed';

  @override
  String get biSortUngrouped => 'Order (groups only)';

  @override
  String get biSourceRestricted =>
      'The source records are shown only to those who manage them.';

  @override
  String get biTitle => 'Business analytics';

  @override
  String get biTotal => 'Total';

  @override
  String get biUnavailable => 'This analysis could not be computed.';

  @override
  String get biViewChart => 'Chart';

  @override
  String get biViewClearMyDefault => 'Stop opening my default view';

  @override
  String get biViewClearTeamDefault => 'Clear the team’s default';

  @override
  String biViewCopyName(String name) {
    return '$name (copy)';
  }

  @override
  String get biViewDashboard => 'Dashboard';

  @override
  String get biViewDelete => 'Delete';

  @override
  String biViewDeleteConfirm(String name) {
    return 'Delete the view “$name”?';
  }

  @override
  String get biViewDuplicate => 'Duplicate as my view';

  @override
  String get biViewForbidden => 'You may not change this view.';

  @override
  String get biViewInvalid => 'This name or view cannot be saved.';

  @override
  String get biViewMakeMyDefault => 'Open this view by default';

  @override
  String get biViewMakeTeamDefault => 'Make it the team’s default';

  @override
  String get biViewModified => 'changed since it was opened';

  @override
  String get biViewName => 'Name';

  @override
  String get biViewNameTaken => 'A view with this name already exists.';

  @override
  String biViewPeriodFixed(String period) {
    return 'Always $period';
  }

  @override
  String get biViewPeriodMoves => 'The period moves with the day it is opened';

  @override
  String get biViewRename => 'Rename…';

  @override
  String get biViewSave => 'Save';

  @override
  String get biViewSaveAs => 'Save as a new view…';

  @override
  String get biViewScopePrivate => 'Only me';

  @override
  String get biViewScopeTeam => 'The team';

  @override
  String get biViewStale =>
      'Someone saved this view since you opened it. The list was read again; try once more.';

  @override
  String get biViewStandard => 'Standard view';

  @override
  String get biViewTable => 'Table';

  @override
  String get biViewUnreadable =>
      'This view cannot be opened here: it was saved in a form this version does not read, or none of its analyses is available to you.';

  @override
  String get biViews => 'Views';

  @override
  String get biViewsMine => 'My views';

  @override
  String get biViewsTeam => 'Team views';

  @override
  String get biVsPrevious => 'vs previous period';

  @override
  String get biVsYearAgo => 'vs last year';

  @override
  String get billAccessorySupplements => 'Accessory supplements';

  @override
  String get billBalance => 'Balance';

  @override
  String billCreditNoteCard(String number) {
    return 'Credit note $number';
  }

  @override
  String get billCreditNoteDue =>
      'The workspace owes you this amount — nothing to pay on your side.';

  @override
  String get billCreditNoteRefunded =>
      'The workspace refunded you this amount.';

  @override
  String billEntitlement(int used, int included, int openDays) {
    return '$used of $included half-days billed ($openDays days open)';
  }

  @override
  String billInvoiceCard(String number) {
    return 'Invoice $number';
  }

  @override
  String get billInvoicePaid => 'Paid so far';

  @override
  String get billInvoiceRemaining => 'Remaining to pay';

  @override
  String get billInvoiceTotal => 'Invoice total';

  @override
  String get billOpenPositions => 'Open positions';

  @override
  String get billOutstanding => 'Outstanding';

  @override
  String billOverage(int extra) {
    return '$extra extra half-days';
  }

  @override
  String get billPackages => 'Day packages';

  @override
  String billParticipation(int pct) {
    return 'Participation $pct%';
  }

  @override
  String billParticipationMonth(String month, int pct) {
    return '$month $pct%';
  }

  @override
  String get billPaymentsCredits => 'Payments & credits';

  @override
  String get billPdfExport => 'Export bill as PDF';

  @override
  String get billPdfTitle => 'Monthly bill';

  @override
  String get billPendingBadge => 'pending validation';

  @override
  String get billServices => 'Consumed services';

  @override
  String get billServicesTotal => 'Services total';

  @override
  String get billSettled => 'Settled';

  @override
  String billSubscription(int pct) {
    return 'Subscription $pct%';
  }

  @override
  String billSubscriptionMonth(String month, int pct) {
    return 'Subscription $month $pct%';
  }

  @override
  String get billingAddBand => 'Add band';

  @override
  String get billingAddLevel => 'Add level';

  @override
  String get billingAddPackage => 'Add package';

  @override
  String get billingAdvanceDays => 'Days before the month starts';

  @override
  String get billingAllowCustom => 'Allow negotiated custom value';

  @override
  String get billingBandFee => 'Monthly fee';

  @override
  String billingBandFrom(int from) {
    return 'from $from%';
  }

  @override
  String get billingBandOverage => 'Overage';

  @override
  String get billingBandTo => 'To %';

  @override
  String get billingBandsInvalid => 'Bands must increase and end at 100%.';

  @override
  String get billingFeeBands => 'Fee bands';

  @override
  String get billingLevelValue => 'Level (1–100)';

  @override
  String get billingLevels => 'Subscription levels';

  @override
  String get billingNewPackage => 'New package';

  @override
  String get billingPackageDays => 'Days';

  @override
  String get billingPackageName => 'Name';

  @override
  String get billingPackagePrice => 'Price';

  @override
  String billingPackageSummary(int days, String price) {
    return '$days days · $price';
  }

  @override
  String get billingPackages => 'Day packages';

  @override
  String get billingPackagesHint =>
      'Members on the package plan buy these when their days run out.';

  @override
  String billingPricesVatHint(String rate) {
    return 'Prices are gross — VAT $rate (the workspace default rate) is included.';
  }

  @override
  String get billingRemoveBand => 'Remove band';

  @override
  String get billingRulesSaved => 'Invoice schedule saved.';

  @override
  String get billingRulesSubtitle =>
      'When subscription and end-of-month invoices go out';

  @override
  String get billingRulesTitle => 'Invoice schedule';

  @override
  String get billingSaved => 'Saved.';

  @override
  String get billingSubscriptionAuto => 'Issue automatically';

  @override
  String get billingSubscriptionOff =>
      'Switch on “Subscription invoices” in Features to use this.';

  @override
  String get billingSubscriptionSection => 'Subscription, in advance';

  @override
  String billingSubscriptionWhen(String day, String month) {
    return 'Issued on $day for $month';
  }

  @override
  String billingTariffVatHint(String rate) {
    return 'Prices are gross — VAT $rate (the tariff rate) is included.';
  }

  @override
  String get billingTitle => 'Billing';

  @override
  String get billingUsageAuto => 'Issue automatically';

  @override
  String get billingUsageOff =>
      'Switch on “End-of-month invoices” in Features to use this.';

  @override
  String get billingUsageSection => 'The month just finished';

  @override
  String get billingUsageWhenZero => 'Also when there is nothing to pay';

  @override
  String get billingUsageWhenZeroHint =>
      'Sends a document reading zero, as confirmation that the subscription covered the whole month.';

  @override
  String get blockPersonAction => 'Block this person';

  @override
  String blockPersonConfirm(String name) {
    return 'Block $name? Neither of you will see or reach the other. You can undo this in Me.';
  }

  @override
  String get blockPersonDone => 'Blocked.';

  @override
  String get blockedPeopleEmpty => 'You have not blocked anyone.';

  @override
  String get blockedPeopleHint =>
      'A blocked person cannot see you or write to you, and you cannot see or reach them.';

  @override
  String get blockedPeopleTitle => 'Blocked people';

  @override
  String get bookAccountCode => 'Account code';

  @override
  String get bookAccountName => 'Account name';

  @override
  String get bookAccountPosting => 'Takes postings';

  @override
  String get bookAuthorityExternal => 'External system';

  @override
  String get bookAuthorityLocal => 'DesKilo is the book';

  @override
  String get bookAuthorityPre => 'Pre-accounting';

  @override
  String get bookBasisAccrual => 'Accrual basis';

  @override
  String get bookBasisCash => 'Cash basis';

  @override
  String get bookChartSuggest => 'Add the suggested accounts to review';

  @override
  String bookChartTitle(String site) {
    return 'Chart of accounts · $site';
  }

  @override
  String get bookCurrency => 'Functional currency';

  @override
  String bookEffectiveFrom(String date) {
    return 'Takes effect from $date';
  }

  @override
  String get bookExternalSystem => 'Authoritative system';

  @override
  String bookFiscalPreview(String label, String start, String end) {
    return 'Fiscal year $label: $start – $end';
  }

  @override
  String get bookFiscalStart => 'Fiscal year starts on';

  @override
  String get bookIssuer => 'Issuer';

  @override
  String get bookMappingsTitle => 'Which account each entry books to';

  @override
  String get bookProblemCurrency =>
      'This currency has no reviewed number of decimals.';

  @override
  String get bookProblemExternal =>
      'Name the external system that keeps the official books.';

  @override
  String get bookProblemFiscal =>
      'A fiscal year starts on a day every year has (never 29 February).';

  @override
  String bookProblemUnmapped(String roles) {
    return 'Map these accounts before a local book starts: $roles.';
  }

  @override
  String get bookRoleBank => 'Bank';

  @override
  String get bookRoleCustomers => 'Customers (receivable)';

  @override
  String get bookRoleExpenses => 'Expenses';

  @override
  String get bookRoleRevenue => 'Revenue';

  @override
  String get bookRoleVatOutput => 'Output VAT';

  @override
  String get bookSaveFailed =>
      'The book was not saved. Check the connection and try again.';

  @override
  String get bookSaved => 'Book saved';

  @override
  String get bookSheetTitle => 'Accounting book';

  @override
  String get bookStale =>
      'Someone saved this book since you opened it. Close and reopen to see their version.';

  @override
  String get bookTileEmpty =>
      'No book set: DesKilo keeps member balances and invoices (pre-accounting).';

  @override
  String get bookTypeAsset => 'Asset';

  @override
  String get bookTypeEquity => 'Equity';

  @override
  String get bookTypeExpense => 'Expense';

  @override
  String get bookTypeIncome => 'Income';

  @override
  String get bookTypeLiability => 'Liability';

  @override
  String bookingCheckedInAtUntil(String space, String until) {
    return 'Checked in at $space until $until.';
  }

  @override
  String get bookingCheckedInElsewhere =>
      'You are checked in elsewhere — check out there first.';

  @override
  String bookingCheckedInUntil(String until) {
    return 'Checked in until $until.';
  }

  @override
  String get bookingGateBlocked => 'Not bookable as chosen';

  @override
  String bookingHorizonError(int days) {
    return 'Too far ahead — bookings are open $days days in advance.';
  }

  @override
  String get bookingMembershipPaused =>
      'Your membership is paused — an administrator reactivates it in Members.';

  @override
  String get bookingModeCheckInNow => 'Check in now';

  @override
  String get bookingMoreOptions => 'More options';

  @override
  String get bookingNoLongerCheckedIn =>
      'This reservation is no longer checked in — it was checked out or closed in the meantime.';

  @override
  String get bookingNotAMember =>
      'You are no longer a member of this space — ask an administrator for an invitation.';

  @override
  String get bookingOnePlace =>
      'You already have a booking in that period — one place at a time.';

  @override
  String get bookingOpenDetails => 'Details';

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
  String get bookingOverlapsAnother =>
      'The seat is already booked during part of this time.';

  @override
  String get bookingPastError => 'This booking lies entirely in the past.';

  @override
  String bookingRecordedPastSpaceWhen(String space, String when) {
    return 'Recorded $space: $when. That period is already over, so it is kept as a past visit.';
  }

  @override
  String bookingRecordedPastWhen(String when) {
    return 'Recorded: $when. That period is already over, so it is kept as a past visit.';
  }

  @override
  String get bookingRecoveryBanner =>
      'A booking request of yours is still unanswered.';

  @override
  String get bookingRecoveryBannerAction => 'Check';

  @override
  String get bookingRecoveryCheck => 'Check outcome';

  @override
  String get bookingRecoveryCommitted =>
      'The booking exists — exactly one, from your original request.';

  @override
  String get bookingRecoveryDiscard => 'Let it go';

  @override
  String get bookingRecoveryInProgress =>
      'The server is still working on this request. Check again in a moment.';

  @override
  String get bookingRecoveryNotCommitted =>
      'Nothing was booked for this request. You can resume it as it was, or let it go.';

  @override
  String get bookingRecoveryNotSaved =>
      'This device could not save your booking request, so nothing was sent. Free some space or try again.';

  @override
  String get bookingRecoveryResume => 'Resume the same request';

  @override
  String get bookingRecoveryResumed =>
      'Resumed: your original request was booked once.';

  @override
  String get bookingRecoverySpaceFallback => 'The space you chose';

  @override
  String get bookingRecoveryTitle => 'Your booking request';

  @override
  String get bookingRecoveryUnavailable =>
      'The server could not be asked. Nothing was changed; try again.';

  @override
  String get bookingRecoveryUnknown =>
      'The connection dropped after your request was sent. The booking may or may not exist — check before booking again.';

  @override
  String get bookingRecoveryUnresolved =>
      'The server no longer keeps a record of this request, so it cannot say. Check your bookings before booking again.';

  @override
  String get bookingRecoveryView => 'View the booking';

  @override
  String bookingRecoveryWindow(String space, String from, String to) {
    return '$space · $from – $to';
  }

  @override
  String bookingReservedSpaceWhen(String space, String when) {
    return 'Reserved $space: $when.';
  }

  @override
  String bookingReservedWhen(String when) {
    return 'Reserved: $when.';
  }

  @override
  String get bookingSameDayError =>
      'A booking ends on the day it starts — book the next day separately.';

  @override
  String get bookingSpaceChainTaken =>
      'This space, or a space it belongs to, is already reserved in that period.';

  @override
  String bookingTooLongError(int minutes) {
    return 'Too long — a booking lasts at most $minutes minutes.';
  }

  @override
  String bookingTooShortError(int minutes) {
    return 'Too short — a booking lasts at least $minutes minutes.';
  }

  @override
  String get bookingWalkUpTodayError => 'A walk-up check-in must start today.';

  @override
  String get bootFailedBody =>
      'The server or this device\'s secure storage did not answer. Nothing was changed. Close the app and open it again; if it keeps happening, check the network.';

  @override
  String get bootFailedTitle => 'DesKilo could not start';

  @override
  String get bootSlowBody =>
      'It keeps trying. If nothing happens, close the app and open it again.';

  @override
  String get bootSlowTitle => 'Starting is taking longer than usual';

  @override
  String brandColorRefused(String color, String pair) {
    return 'The colour $color was not applied: $pair would be unreadable.';
  }

  @override
  String get buyPackageButton => 'Buy a package';

  @override
  String buyPackageDays(int days) {
    return '$days days';
  }

  @override
  String get buyPackageDone => 'Days added — enjoy the extra time.';

  @override
  String get buyPackageNone => 'No packages are available yet.';

  @override
  String get buyPackageTitle => 'Buy a package';

  @override
  String calendarAgendaEmpty(int days) {
    return 'Nothing planned in the next $days days.';
  }

  @override
  String calendarAgendaRange(int days) {
    return 'Next $days days';
  }

  @override
  String get calendarAllLevels => 'All levels';

  @override
  String get calendarCancelFollowing => 'Cancel this and following';

  @override
  String get calendarCancelOccurrence => 'Cancel this occurrence';

  @override
  String get calendarClosedDay => 'Closed';

  @override
  String calendarClosedDayReason(String reason) {
    return 'Closed — $reason';
  }

  @override
  String get calendarDay => 'Day';

  @override
  String get calendarDayEmpty => 'Nothing on this day.';

  @override
  String calendarDueTitle(String number) {
    return 'Payment due · $number';
  }

  @override
  String get calendarEventActionApproved => 'approved';

  @override
  String get calendarEventActionCancelled => 'cancelled';

  @override
  String get calendarEventActionCreated => 'created';

  @override
  String get calendarEventActionModified => 'changed';

  @override
  String get calendarEventActionRefused => 'refused';

  @override
  String get calendarEventActionRejected => 'rejected';

  @override
  String get calendarEventActionSubmitted => 'submitted';

  @override
  String get calendarEventActionValidated => 'validated';

  @override
  String get calendarEventStatusExpired => 'expired';

  @override
  String get calendarEventStatusPending => 'awaiting confirmation';

  @override
  String get calendarEventStatusRejected => 'rejected';

  @override
  String calendarEventTitle(String label) {
    return 'Alert: $label';
  }

  @override
  String get calendarEveryoneTab => 'Everyone';

  @override
  String get calendarGroupActivity => 'Alerts & messages';

  @override
  String get calendarGroupBookings => 'Bookings & presence';

  @override
  String get calendarGroupMoney => 'Money';

  @override
  String calendarItemCount(int count) {
    return '$count items';
  }

  @override
  String get calendarKindCheckIn => 'Check-ins';

  @override
  String get calendarKindCheckOut => 'Check-outs';

  @override
  String get calendarKindConsumption => 'Consumption';

  @override
  String get calendarKindDue => 'Payments due';

  @override
  String get calendarKindEvent => 'Alerts';

  @override
  String get calendarKindInvoice => 'Invoices';

  @override
  String get calendarKindMessage => 'Messages';

  @override
  String get calendarKindPayment => 'Payments';

  @override
  String get calendarKindReminder => 'Reminders';

  @override
  String get calendarKindReservation => 'Bookings';

  @override
  String get calendarKindScheduled => 'Scheduled expenses';

  @override
  String get calendarKindValidation => 'Validations';

  @override
  String calendarLevelCollapsed(String level) {
    return '$level, collapsed';
  }

  @override
  String calendarLevelExpanded(String level) {
    return '$level, expanded';
  }

  @override
  String get calendarListView => 'List view';

  @override
  String calendarLockedKinds(String kinds) {
    return 'Not visible to you for this member: $kinds';
  }

  @override
  String get calendarMemberMe => 'Me';

  @override
  String get calendarMineTab => 'Mine';

  @override
  String get calendarNext => 'Next';

  @override
  String get calendarNextMonth => 'Next month';

  @override
  String get calendarNoReservations => 'No reservations on this day.';

  @override
  String get calendarNothingHere => 'Nothing on these dates.';

  @override
  String get calendarPrevious => 'Previous';

  @override
  String get calendarPreviousMonth => 'Previous month';

  @override
  String get calendarRange => 'Range';

  @override
  String get calendarReservationActions => 'Reservation actions';

  @override
  String calendarScheduledTitle(String name) {
    return 'Scheduled expense · $name';
  }

  @override
  String get calendarShowOnPlan => 'Show on plan';

  @override
  String get calendarTimelineAllEmpty =>
      'No reservations on any level for this day.';

  @override
  String get calendarTimelineEmpty =>
      'No reservations on this level for this day.';

  @override
  String get calendarTimelineView => 'Timeline view';

  @override
  String get calendarToday => 'Today';

  @override
  String get calendarTomorrow => 'Tomorrow';

  @override
  String calendarValidationRefused(String what) {
    return 'Refused: $what';
  }

  @override
  String calendarValidationValidated(String what) {
    return 'Validated: $what';
  }

  @override
  String get calendarViewAgenda => 'Agenda';

  @override
  String get calendarViewAlerts => 'Alerts';

  @override
  String get calendarViewMonth => 'Month';

  @override
  String get calendarViewWeek => 'Week';

  @override
  String get calendarWeekEmpty => 'Nothing this week.';

  @override
  String get calendarWhoCanSee => 'Who can see this';

  @override
  String get calendarYesterday => 'Yesterday';

  @override
  String get capabilityBrowserPrefer => 'Prefer';

  @override
  String get capabilityBrowserRequire => 'Require';

  @override
  String get capabilityBrowserTitle => 'Browse capabilities';

  @override
  String get capabilityCreditPacks => 'Credit packs';

  @override
  String get capabilityCustomMemberForm => 'Custom membership form';

  @override
  String get capabilityMultiApproval => 'Two or more approvals';

  @override
  String get capabilityOpeningHours => 'Opening hours';

  @override
  String get capabilityPayAsYouGo => 'Pay as you go';

  @override
  String get capabilityRefundApprovals => 'Two approvals for refunds';

  @override
  String get capabilityStateConditional => 'On only if its prerequisites are';

  @override
  String get capabilityStateDisabled => 'Off';

  @override
  String get capabilityStateEnabled => 'On';

  @override
  String get capabilityStateIncompatible => 'Cannot apply here';

  @override
  String get capabilityStateLocalInput => 'Needs a local value first';

  @override
  String get capabilityStateUnknown => 'Unknown';

  @override
  String get capabilityStateUnspecified => 'Not set by this template';

  @override
  String get capabilitySubscriptionPlans => 'Subscription plans';

  @override
  String capacityKpiAsOf(String time) {
    return 'Computed $time';
  }

  @override
  String get capacityKpiDefinition =>
      'Reserved seat-hours inside the opening hours, divided by offered seat-hours: every seat times the opening hours of the open days, minus closure days and seat blocks. A whole desk, room or level counts each of its seats once; cancelled bookings do not count.';

  @override
  String get capacityKpiExplain => 'How is this computed?';

  @override
  String get capacityKpiForbidden =>
      'You may not read the capacity figures of this workspace.';

  @override
  String capacityKpiHistory(String date) {
    return 'History recorded since $date';
  }

  @override
  String capacityKpiHistorySince(String date) {
    return 'Counted from $date, when this workspace’s history began; earlier time is not known and not counted.';
  }

  @override
  String get capacityKpiKnownZero => 'Measured: nothing was reserved.';

  @override
  String capacityKpiNotRecorded(String date) {
    return 'This period lies before the workspace’s history began on $date; there is nothing recorded to count.';
  }

  @override
  String capacityKpiOutside(String hours) {
    return 'Reserved outside the offered hours: $hours seat-hours, not in the ratio';
  }

  @override
  String capacityKpiOverlap(String hours) {
    return 'Claimed twice at the same time: $hours seat-hours, counted once';
  }

  @override
  String capacityKpiPhysical(String hours) {
    return 'Physical capacity: $hours seat-hours';
  }

  @override
  String capacityKpiRatio(String reserved, String offered) {
    return '$reserved of $offered seat-hours reserved';
  }

  @override
  String get capacityKpiRetry => 'Try again';

  @override
  String capacityKpiRooms(String count, String reserved, String offered) {
    return 'Rooms without seats: $count, $reserved of $offered room-hours reserved';
  }

  @override
  String get capacityKpiRoomsToday =>
      'Rooms without seats are read as they are today.';

  @override
  String get capacityKpiTitle => 'Seat utilisation';

  @override
  String get capacityKpiUnattributed =>
      'Some reservations in this period point to a place that no longer exists; they are not counted.';

  @override
  String get capacityKpiUnavailable =>
      'The seat utilisation could not be computed.';

  @override
  String get capacityKpiUndefined =>
      'No seat time was offered in this period, so there is no utilisation to show.';

  @override
  String get captureRecordingHidden =>
      'Hidden while your screen is recorded or mirrored.';

  @override
  String get captureWebNotice =>
      'Your browser cannot block screenshots of this conversation.';

  @override
  String get carnetAdd => 'Add carnet';

  @override
  String carnetBalance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count half-days left',
      one: '1 half-day left',
      zero: 'No half-days left',
    );
    return '$_temp0';
  }

  @override
  String get carnetHalfDays => 'Half-days';

  @override
  String get carnetName => 'Name';

  @override
  String get carnetPrice => 'Price';

  @override
  String get carnetSell => 'Sell a carnet';

  @override
  String get carnetSold => 'Carnet sold — charged once on this month\'s bill.';

  @override
  String carnetSummary(int halfDays, String price) {
    return '$halfDays half-days · $price';
  }

  @override
  String get carnetValidity => 'Valid for (months, empty = never expires)';

  @override
  String get carnetsEmpty => 'No carnet yet.';

  @override
  String get carnetsTitle => 'Carnets';

  @override
  String get coOwnerAction => 'Co-ownership';

  @override
  String get coOwnerActivate => 'Promote to owner now';

  @override
  String get coOwnerActive =>
      'Active co-owner — owner permissions now, automatic succession';

  @override
  String get coOwnerNone => 'No co-ownership';

  @override
  String get coOwnerPassive =>
      'Successor — becomes owner when activated or when the owner leaves';

  @override
  String coloursApplied(String hex) {
    return '$hex applied. The app derives its themes from it.';
  }

  @override
  String get coloursDark => 'Dark';

  @override
  String get coloursHexHint =>
      'Six hexadecimal digits. Leave empty for the product colours.';

  @override
  String get coloursHexLabel => 'Colour';

  @override
  String get coloursIntro =>
      'One colour, and the app derives its light and dark themes from it. Everything else keeps the product palette.';

  @override
  String get coloursLight => 'Light';

  @override
  String coloursMalformed(String text) {
    return '$text is not a colour: write it as #RRGGBB.';
  }

  @override
  String get coloursNeverTheirs =>
      'The DesKilo mark, the colours of the seat states and the production banner are the product’s, in every space.';

  @override
  String get coloursPreview => 'What it looks like';

  @override
  String coloursRefused(String pair) {
    return 'Refused: $pair would be unreadable with this colour.';
  }

  @override
  String get coloursReset => 'Product colours';

  @override
  String get coloursResetDone => 'The product colours are back.';

  @override
  String get coloursRooms => 'Room colours';

  @override
  String get coloursRoomsAdd => 'Add a colour';

  @override
  String coloursRoomsOwn(int n) {
    return '$n of your own colours, in order.';
  }

  @override
  String get coloursRoomsProduct =>
      'The product palette. Add a colour to use your own.';

  @override
  String coloursRoomsSaved(int n) {
    return '$n room colours saved.';
  }

  @override
  String get coloursSaveFailed =>
      'The colour could not be saved. Nothing changed.';

  @override
  String get coloursTitle => 'Colours';

  @override
  String coloursTooMany(int most) {
    return 'The plan paints at most $most room colours.';
  }

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonDone => 'Done';

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSaveFailed => 'Could not save the file.';

  @override
  String commonSavedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String get commonShare => 'Share';

  @override
  String get commonStart => 'Start';

  @override
  String get compareAdd => 'Add to comparison';

  @override
  String get compareAll => 'All settings';

  @override
  String compareCount(String shown, String total) {
    return '$shown of $total settings';
  }

  @override
  String get compareCurrencies => 'Different currencies: not comparable';

  @override
  String get compareDefault => 'Default';

  @override
  String get compareDifferences => 'Differences';

  @override
  String get compareEmpty => 'Empty';

  @override
  String get compareExport => 'Export to Excel';

  @override
  String get compareExported => 'Workbook saved.';

  @override
  String get compareInherits => 'Keeps the space\'s own';

  @override
  String compareLimit(String count) {
    return 'Up to $count templates can be compared. Remove one first.';
  }

  @override
  String get compareLocal => 'Set locally';

  @override
  String get compareMissing => 'Not in this template';

  @override
  String get compareNo => 'No';

  @override
  String get compareNotCarried => 'Not carried';

  @override
  String get compareNothing => 'No setting differs.';

  @override
  String compareOpen(String count) {
    return 'Compare ($count)';
  }

  @override
  String get compareRemove => 'Remove from comparison';

  @override
  String get compareSearch => 'Find a setting';

  @override
  String get compareTitle => 'Compare templates';

  @override
  String get compareUnavailable =>
      'These templates could not be read to compare them. Nothing is claimed either way.';

  @override
  String get compareUnknown => 'Unknown';

  @override
  String get compareYes => 'Yes';

  @override
  String get composerAttach => 'Attach a reference';

  @override
  String composerCharsLeft(int count) {
    return '$count characters left';
  }

  @override
  String get composerDraftKept => 'Draft kept';

  @override
  String get composerMention => 'Mention someone';

  @override
  String get connectionCancelled =>
      'The account changed meanwhile, so this answer was discarded.';

  @override
  String get connectionChangedIdentity =>
      'This server is no longer the one you connected. Its actions are paused until you verify it again.';

  @override
  String get connectionChecking => 'Checking…';

  @override
  String get connectionCurrentServer =>
      'This is the server this app already uses.';

  @override
  String get connectionDenied =>
      'This server refused the account. Check the sign-in details, or disconnect it.';

  @override
  String get connectionExpired =>
      'Your sign-in to this server has ended. Sign in to this server again.';

  @override
  String get connectionInvalidEndpoint =>
      'This address or key is not a valid server.';

  @override
  String get connectionMalformed =>
      'This server answered something this app cannot read.';

  @override
  String get connectionNotConnected =>
      'This server is not connected on this device.';

  @override
  String get connectionRetry => 'Try again';

  @override
  String get connectionSessionNotSaved =>
      'The action was done, but this device could not save the server\'s sign-in. You may be asked to sign in again.';

  @override
  String get connectionSignInAgain => 'Sign in again';

  @override
  String get connectionUnavailable =>
      'This server is not answering right now. Your other servers are not affected.';

  @override
  String get connectionUnknownOutcome =>
      'The connection dropped after the request was sent. It may have been applied: check before trying again.';

  @override
  String get connectionUnsupported =>
      'This server\'s version cannot be connected from this app. Update the app, or ask the server\'s operator to update the server.';

  @override
  String get connectionUsable => 'Connected';

  @override
  String get connectionVerifyAgain => 'Verify again';

  @override
  String get consentAccept => 'Accept and continue';

  @override
  String consentAcceptedOn(String date, String version) {
    return 'Accepted on $date ($version)';
  }

  @override
  String get consentCheckbox =>
      'I have read this and I accept how DesKilo handles my data.';

  @override
  String get consentControllerBody =>
      'Each workspace is operated by its owner — your community — who decides members, prices and payment providers. The app is free software (AGPL-3.0-or-later) and published by Florian Dittgen (Germany); the backend is Supabase in the EU. Online payments go through the provider the owner enabled (PayPal, Stripe, Mollie, Wero) under that provider\'s terms.';

  @override
  String get consentControllerTitle => 'Who is responsible';

  @override
  String get consentIntro =>
      'Before you use DesKilo, here is what the app does with your data, who can see it and what you can do about it. Two minutes; it is all there is.';

  @override
  String get consentNotBody =>
      'No tracking, no analytics, no advertising, no sale or sharing of data. Push notifications carry no content — only \"you have a new message\"; the app itself writes the text. The F-Droid build has no Google services at all.';

  @override
  String get consentNotTitle => 'What DesKilo never does';

  @override
  String get consentReadInHelp => 'Read in the help';

  @override
  String get consentReadOnWiki => 'Read on the wiki';

  @override
  String get consentRetentionBody =>
      'As long as you are a member. When you leave and erase, your profile and messages go; accounting records (invoices, payments) stay for the legal retention period, by identifier and not by name.';

  @override
  String get consentRetentionTitle => 'How long';

  @override
  String get consentReviewBody =>
      'This text stays available in Settings → Privacy & data, in the in-app help (Privacy) and in the project wiki. A change of the text asks for your acceptance again.';

  @override
  String get consentReviewHint =>
      'The text you accepted, with the date — read it again anytime.';

  @override
  String get consentReviewTitle => 'Read it again anytime';

  @override
  String get consentRightsBody =>
      'Access, rectification, export (art. 20), erasure (art. 17) and objection — each is a button in Settings → Privacy & data. For anything else: fdittgen@gmail.com. You may withdraw this consent by leaving the workspace and erasing your data at any time.';

  @override
  String get consentRightsTitle => 'Your rights';

  @override
  String get consentTitle => 'Your data, your rights';

  @override
  String get consentUnavailable =>
      'Your account could not be loaded, so there is nothing to accept yet.';

  @override
  String get consentVersion => 'Version';

  @override
  String get consentWhatBody =>
      'Your account (e-mail, display name, hashed password), your profile as you fill it (photo, status, address, WhatsApp number — each optional), and what you do in a workspace: reservations and check-ins, messages, expenses and consumptions, your subscription, invoices and payments. Everything is stored in the EU (Supabase, eu-central-1).';

  @override
  String get consentWhatTitle => 'What DesKilo processes';

  @override
  String get consentWhoBody =>
      'Access follows roles and is enforced on the server: bookings are visible to the workspace (the floor plan shows occupancy); messages only to the people in the conversation, whatever their role; your finances and your commercial agreement only to you, the owners and the admins holding the matching permission. Settings → Privacy & data names the people and lists who actually looked.';

  @override
  String get consentWhoTitle => 'Who can see what';

  @override
  String get consumptionAdd => 'Add consumption';

  @override
  String consumptionAddForMember(String name) {
    return 'Add service for $name';
  }

  @override
  String get consumptionNoServices => 'No active services to record.';

  @override
  String get consumptionPeriodLabel => 'Billing period (YYYY-MM)';

  @override
  String get consumptionQuantity => 'Quantity';

  @override
  String get consumptionRecorded =>
      'Consumption recorded — waiting for confirmation.';

  @override
  String get consumptionRefusedInactive =>
      'This service is no longer offered. Nothing was recorded.';

  @override
  String get consumptionRefusedPeriod =>
      'The billing period must be a month (YYYY-MM). Nothing was recorded.';

  @override
  String get consumptionRefusedQuantity =>
      'The quantity must be between 1 and 999. Nothing was recorded.';

  @override
  String get consumptionRefusedStock =>
      'Not enough left in stock. Nothing was recorded.';

  @override
  String get consumptionService => 'Service';

  @override
  String get conversationAddPeople => 'Add people';

  @override
  String get conversationAdmin => 'Admin';

  @override
  String get conversationArchive => 'Archive';

  @override
  String get conversationArchived => 'Conversation archived.';

  @override
  String get conversationEmpty => 'No messages yet — say hello!';

  @override
  String get conversationGroup => 'Group';

  @override
  String get conversationGroupInfo => 'Group';

  @override
  String get conversationLeave => 'Leave group';

  @override
  String get conversationLeaveConfirm =>
      'Leave this group? You stop receiving its messages; what you already sent stays.';

  @override
  String get conversationLeft => 'Left';

  @override
  String get conversationLoadEarlier => 'Load earlier messages';

  @override
  String get conversationMarkUnread => 'Mark as unread';

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
  String get conversationMute => 'Mute notifications';

  @override
  String get conversationMutedBadge => 'Muted';

  @override
  String get conversationPin => 'Pin to top';

  @override
  String get conversationRemove => 'Remove';

  @override
  String get conversationSeeProfile => 'See profile';

  @override
  String get conversationToday => 'Today';

  @override
  String get conversationUnarchive => 'Restore from archive';

  @override
  String get conversationUnknownMember => 'Member';

  @override
  String get conversationUnmute => 'Unmute';

  @override
  String get conversationUnpin => 'Unpin';

  @override
  String get conversationYesterday => 'Yesterday';

  @override
  String get conversationYou => 'You';

  @override
  String get countryNameAT => 'Austria';

  @override
  String get countryNameAU => 'Australia';

  @override
  String get countryNameBE => 'Belgium';

  @override
  String get countryNameBG => 'Bulgaria';

  @override
  String get countryNameCA => 'Canada';

  @override
  String get countryNameCH => 'Switzerland';

  @override
  String get countryNameCY => 'Cyprus';

  @override
  String get countryNameCZ => 'Czechia';

  @override
  String get countryNameDE => 'Germany';

  @override
  String get countryNameDK => 'Denmark';

  @override
  String get countryNameEE => 'Estonia';

  @override
  String get countryNameES => 'Spain';

  @override
  String get countryNameFI => 'Finland';

  @override
  String get countryNameFR => 'France';

  @override
  String get countryNameGB => 'United Kingdom';

  @override
  String get countryNameGR => 'Greece';

  @override
  String get countryNameHR => 'Croatia';

  @override
  String get countryNameHU => 'Hungary';

  @override
  String get countryNameIE => 'Ireland';

  @override
  String get countryNameIT => 'Italy';

  @override
  String get countryNameJP => 'Japan';

  @override
  String get countryNameLT => 'Lithuania';

  @override
  String get countryNameLU => 'Luxembourg';

  @override
  String get countryNameLV => 'Latvia';

  @override
  String get countryNameMT => 'Malta';

  @override
  String get countryNameMX => 'Mexico';

  @override
  String get countryNameNL => 'Netherlands';

  @override
  String get countryNameNO => 'Norway';

  @override
  String get countryNamePL => 'Poland';

  @override
  String get countryNamePT => 'Portugal';

  @override
  String get countryNameRO => 'Romania';

  @override
  String get countryNameSE => 'Sweden';

  @override
  String get countryNameSI => 'Slovenia';

  @override
  String get countryNameSK => 'Slovakia';

  @override
  String get countryNameUS => 'United States';

  @override
  String get courtesyHint =>
      'Printed before your name on documents. \"None\" prints the name alone.';

  @override
  String get courtesyHintManaged =>
      'Printed before their name on documents. \"None\" prints the name alone.';

  @override
  String get courtesyLabel => 'Form of address';

  @override
  String get courtesyMr => 'Mr';

  @override
  String get courtesyMrs => 'Ms';

  @override
  String get courtesyNone => 'None';

  @override
  String get customerCapacityBusiness => 'Business';

  @override
  String get customerCapacityConsumer => 'Consumer';

  @override
  String get customerCapacityExplainer =>
      'Whether this customer acts for a trade or business (a company, a sole trader, an association acting as one) or as a private consumer. It decides which payment clauses an invoice prints; a VAT number alone does not decide it. Not stated: the workspace default applies.';

  @override
  String get customerCapacityLabel => 'Customer capacity';

  @override
  String get customerCapacityNotStated => 'Not stated';

  @override
  String get customerCapacitySaveError =>
      'The customer capacity was not saved.';

  @override
  String get datevAccountsIntro =>
      'Your accountant gives you the consultant and client numbers. DATEV refuses a file whose numbers do not match — which is what keeps it out of the wrong company’s books.';

  @override
  String get datevAccountsTitle => 'DATEV export';

  @override
  String get datevClientNumber => 'Mandantennummer';

  @override
  String get datevConsultantNumber => 'Beraternummer';

  @override
  String get decisionSurfaceEmpty => 'Nothing needs you';

  @override
  String get decisionSurfaceEmptyDetail => 'Everything is answered.';

  @override
  String get defaultPeriodNone => 'No preference (full day)';

  @override
  String get defaultPeriodTitle => 'Default booking period';

  @override
  String get demoEntryAction => 'Explore the demo workspace';

  @override
  String get demoEntryBody =>
      'Everything in it is made up: the people, the bookings and the bills are invented for the demonstration. Nothing you do here reaches a real workspace, nothing leaves this device, and no account is needed. Reset puts it back whenever you like.';

  @override
  String get demoEntryStart => 'Start exploring';

  @override
  String get demoEntryTitle => 'A workspace to look around';

  @override
  String get demoPersonaAdmin => 'An administrator';

  @override
  String get demoPersonaMember => 'A member';

  @override
  String get demoPersonaOwner => 'The owner';

  @override
  String get demoSessionBadge => 'Demo';

  @override
  String get demoSessionBadgeHint =>
      'You are exploring a demonstration space. Nothing here leaves this device.';

  @override
  String get demoSessionLeave => 'Leave the demo';

  @override
  String get demoSessionReset => 'Reset the demo';

  @override
  String get demoSessionResetDone => 'The demo is back as it started.';

  @override
  String get demoSessionViewAs => 'View as';

  @override
  String get deployEntityAccessories => 'Accessories';

  @override
  String get deployEntityBookingRules => 'Booking rules';

  @override
  String get deployEntityBranding => 'Colours';

  @override
  String get deployEntityClosureDays => 'Closure days';

  @override
  String get deployEntityCreditProducts => 'Prepaid carnets on sale';

  @override
  String get deployEntityDocumentDesign => 'Document designs';

  @override
  String get deployEntityDocumentLinks => 'Document links';

  @override
  String get deployEntityFeatures => 'Features';

  @override
  String get deployEntityFieldDefinitions => 'Questions the space asks';

  @override
  String get deployEntityFloorPlan => 'Floor plans (levels, places, images)';

  @override
  String get deployEntityIdentity => 'Identity & legal';

  @override
  String get deployEntityInvitations => 'Invitation templates';

  @override
  String get deployEntityPackages => 'Packages';

  @override
  String get deployEntityPaymentInstructions => 'Payment instructions';

  @override
  String get deployEntityReminders => 'Reminder rules';

  @override
  String get deployEntityRoles => 'Role matrix';

  @override
  String get deployEntityServices => 'Services';

  @override
  String get deployEntitySites => 'Sites';

  @override
  String get deployEntityTariffs => 'Tariffs';

  @override
  String get deployEntityValidationRules => 'Validation rules';

  @override
  String get deployEntityVat => 'VAT';

  @override
  String get deployEntityWorkspaceRoles => 'Roles the space defines';

  @override
  String get deploymentConfirm => 'Deploy';

  @override
  String get deploymentConfirmBody =>
      'What this workspace holds for the ticked entities is replaced by the twin\'s. The journal keeps the way back.';

  @override
  String get deploymentConfirmTitleDev => 'Deploy into this DEV?';

  @override
  String get deploymentConfirmTitleProd => 'Deploy into this PROD?';

  @override
  String get deploymentDirectionToDev => 'To development';

  @override
  String get deploymentDirectionToProd => 'To production';

  @override
  String get deploymentDone => 'Deployed. The journal has it.';

  @override
  String get deploymentFlowFromDev => 'From DEV';

  @override
  String get deploymentFlowFromProd => 'From PROD';

  @override
  String get deploymentFlowToDev => 'To DEV';

  @override
  String get deploymentFlowToProd => 'To PROD';

  @override
  String get deploymentIntroFromDev =>
      'You stand on the production side. What you tick below is pulled from the development twin into this workspace, after a preview.';

  @override
  String get deploymentIntroFromProd =>
      'You stand on the development side. What you tick below is pulled from the production twin into this workspace, after a preview.';

  @override
  String get deploymentIntroToDev =>
      'You stand on the production side. What you tick below is deployed to the development twin, after a preview of what changes.';

  @override
  String get deploymentIntroToProd =>
      'You stand on the development side. What you tick below is deployed to the production twin, after a preview of what changes.';

  @override
  String get deploymentJournal => 'Journal';

  @override
  String get deploymentJournalEmpty => 'Nothing deployed yet.';

  @override
  String get deploymentKindConfiguration => 'Configuration';

  @override
  String get deploymentKindMasterData => 'Master data';

  @override
  String get deploymentKindReports => 'Reports';

  @override
  String get deploymentNeedsDevPermission =>
      'Deploying to development needs the \"Deploy to development\" permission.';

  @override
  String get deploymentNeedsProdPermission =>
      'Deploying to production needs the \"Deploy to production\" permission.';

  @override
  String get deploymentNoChange => 'No change';

  @override
  String get deploymentNoTwin =>
      'This workspace has no twin you are a member of.';

  @override
  String get deploymentNothingToDo =>
      'The two sides already agree on these entities.';

  @override
  String get deploymentPreviewToDev => 'What changes on the development side';

  @override
  String get deploymentPreviewToProd => 'What changes on the production side';

  @override
  String get deploymentPullFromDev => 'Pull from DEV…';

  @override
  String get deploymentPullFromProd => 'Pull from PROD…';

  @override
  String get deploymentRequires => 'needs';

  @override
  String get deploymentRollback => 'Roll back';

  @override
  String get deploymentRolledBack => 'Rolled back.';

  @override
  String get deploymentRolledBackLabel => 'rolled back';

  @override
  String get deploymentTitle => 'Deployment';

  @override
  String get deploymentToDev => 'Deploy to DEV…';

  @override
  String get deploymentToProd => 'Deploy to PROD…';

  @override
  String get deskDetail => 'Whole desk';

  @override
  String get deskSupplementLabel => 'Desk reservations';

  @override
  String get developerClear => 'Clear trace';

  @override
  String get developerEmpty => 'No trace entries yet.';

  @override
  String get developerExport => 'Export trace';

  @override
  String get developerExportReservations => 'Export reservations';

  @override
  String get developerExportReservationsHint =>
      'Every booking and check-in — past, present and future, every state — as CSV, for analysis and debugging.';

  @override
  String get developerExportReservationsOwnHint =>
      'Your own bookings and check-ins, every state, as CSV — exporting the whole workspace needs the data-export permission.';

  @override
  String get developerFilterAll => 'All';

  @override
  String get developerFilterErrors => 'Errors';

  @override
  String get developerFilterWarnings => 'Warnings+';

  @override
  String get developerMode => 'Developer mode';

  @override
  String get developerModeWorkspaceHint =>
      'Applies to every member of this workspace.';

  @override
  String get developerTitle => 'Developer';

  @override
  String get developmentBanner =>
      'Development workspace — nothing here is real';

  @override
  String get developmentWatermark => 'DEVELOPMENT';

  @override
  String get directoryApproximate => 'Approximate address location';

  @override
  String get directoryCheckedIn => 'Checked in';

  @override
  String directoryCheckedInSeat(String seat) {
    return 'Checked in · $seat';
  }

  @override
  String get directoryClose => 'Close';

  @override
  String get directoryEmpty => 'No members yet.';

  @override
  String directoryLastSeenDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Seen $days days ago',
      one: 'Seen 1 day ago',
    );
    return '$_temp0';
  }

  @override
  String directoryLastSeenHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Seen $hours hours ago',
      one: 'Seen 1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String directoryLastSeenMinutes(int minutes) {
    return 'Seen $minutes min ago';
  }

  @override
  String get directoryLocate => 'Locate on map';

  @override
  String get directoryLocating => 'Locating the public address…';

  @override
  String get directoryLocationMissing =>
      'Location unavailable. The owner can publish precise map coordinates.';

  @override
  String get directoryNoUpcoming => 'No upcoming reservations';

  @override
  String get directoryOnline => 'Online';

  @override
  String get directoryOpenGroup => 'Open WhatsApp group';

  @override
  String get directoryReservationsHeading => 'Reservations';

  @override
  String get directoryReservedNow => 'Reserved now';

  @override
  String directoryReservedNowSeat(String seat) {
    return 'Reserved now · $seat';
  }

  @override
  String get directoryReservedToday => 'Reserved today';

  @override
  String get directoryTitle => 'Members';

  @override
  String get directoryWhatsapp => 'Chat on WhatsApp';

  @override
  String get documentsAdd => 'Add a document';

  @override
  String get documentsCategoryFinance => 'Financial statements';

  @override
  String get documentsCategoryGuides => 'Guides & manuals';

  @override
  String get documentsCategoryLabel => 'Category';

  @override
  String get documentsCategoryMinutes => 'Meeting minutes';

  @override
  String get documentsCategoryOther => 'Other documents';

  @override
  String get documentsCategoryStatutes => 'Statutes & legal';

  @override
  String get documentsDelete => 'Remove document?';

  @override
  String get documentsEmpty =>
      'No document yet. Link your statutes, guides and statements from any drive.';

  @override
  String get documentsInvalid =>
      'A document needs a title and an https:// link.';

  @override
  String get documentsProviderLabel => 'Stored on';

  @override
  String get documentsRoleAdmin => 'Admins and owners';

  @override
  String get documentsRoleLabel => 'Visible to';

  @override
  String get documentsRoleMember => 'Every member';

  @override
  String get documentsRoleOwner => 'Owners only';

  @override
  String get documentsTitle => 'Documents';

  @override
  String get documentsTitleLabel => 'Title';

  @override
  String get documentsUrlHelper =>
      'Paste the share link from your drive — access rights stay managed there.';

  @override
  String get documentsUrlLabel => 'Link (https://…)';

  @override
  String get dunningAutomatic => 'Automatic reminders';

  @override
  String get dunningAutomaticHint =>
      'Once a day, invoices past their recorded payment term get their next reminder level by themselves — for the amount still outstanding, never while a payment is pending or the invoice is on hold. Invoices without a recorded term are left to you. Off: you send each reminder yourself.';

  @override
  String get dunningBetweenDays => 'Days between reminders';

  @override
  String dunningDueChip(int level) {
    return 'Reminder $level due';
  }

  @override
  String get dunningFirstAfterDays => 'Days until the first reminder';

  @override
  String get dunningLevels => 'Number of reminder levels';

  @override
  String get dunningSaved => 'Reminder rules saved.';

  @override
  String get dunningSettingsTitle => 'Reminder rules';

  @override
  String get eInvoiceGapBuyerLegalIdAdvisable =>
      'The buyer\'s SIREN is missing. A French platform routes by it: enter it on the member\'s profile before transmitting. Not a refusal — the file is valid without it.';

  @override
  String get eInvoiceGapMissingBuyerLegalId =>
      'The buyer is a French business without a SIREN — fill in its legal id on the member\'s profile.';

  @override
  String get eInvoiceGapMixedNotSubjectLines =>
      'A not-subject line (a refundable deposit) sits beside taxed lines — EN 16931 refuses the mix; issue the deposit on its own document.';

  @override
  String get editorAccessoriesLabel => 'Accessories';

  @override
  String get editorAddLevel => 'Add level';

  @override
  String get editorAmenitiesLabel => 'Amenities';

  @override
  String get editorBackgroundImage => 'Background image';

  @override
  String get editorBackgroundRemove => 'Remove background image';

  @override
  String get editorBackgroundReplace => 'Replace background image';

  @override
  String get editorBackgroundSet => 'Set background image';

  @override
  String get editorBlockedLabel => 'Blocked (maintenance)';

  @override
  String get editorBookableAsWhole => 'Bookable as a whole';

  @override
  String get editorBookableAsWholeHint =>
      'Somebody can reserve it entire, with everything inside it.';

  @override
  String get editorCanvasSemantics => 'Floor plan drawing area';

  @override
  String get editorChairLabel => 'Chair type';

  @override
  String get editorDeleteElementConfirm =>
      'Delete this element? Anything placed on it is removed too.';

  @override
  String get editorDeleteElementConfirmAudit =>
      'Delete this element? Anything placed on it is removed too. Bookings that reference it keep a text snapshot for audits; open bookings are cancelled.';

  @override
  String get editorDeleteLevelConfirm =>
      'Delete this level? All offices, desks and seats on it are removed.';

  @override
  String get editorDeleteLevelConfirmAudit =>
      'Delete this level? All offices, desks and seats on it are removed. Bookings that reference them keep a text snapshot for audits; open bookings are cancelled.';

  @override
  String get editorDeskFull => 'No room left on this desk.';

  @override
  String get editorDeskNameDefault => 'Desk';

  @override
  String get editorDeskNameLabel => 'Desk name';

  @override
  String get editorDeskProperties => 'Desk';

  @override
  String get editorDuplicate => 'Duplicate';

  @override
  String get editorEmptyFloorAction => 'Draw the first room';

  @override
  String get editorEmptyFloorBody =>
      'Everything sits inside a room: draw one, put desks in it, then seats on the desks.';

  @override
  String get editorEmptyFloorTitle => 'This floor is empty';

  @override
  String get editorHintDesk => 'Drag inside an office to draw a desk';

  @override
  String get editorHintImage => 'Tap where the image should go';

  @override
  String get editorHintOffice => 'Drag to draw an office';

  @override
  String get editorHintSeat => 'Tap a desk to add a seat';

  @override
  String get editorLevelActions => 'Level actions';

  @override
  String get editorLevelBookableOff => 'Not bookable as a whole';

  @override
  String get editorLevelBookableOn => 'Bookable as a whole';

  @override
  String get editorLevelNameLabel => 'Level name';

  @override
  String get editorMediaSaving => 'Saving the image…';

  @override
  String get editorMediaWriteFailed =>
      'The image could not be confirmed as saved. Trying again never adds it twice.';

  @override
  String get editorNewOffice => 'New office';

  @override
  String get editorNoAccessories =>
      'No accessories yet — add them in Settings → Accessories.';

  @override
  String get editorNoAccessoriesAction => 'No accessories yet — set them up';

  @override
  String get editorNoLevels =>
      'No levels yet. Add the first floor of your workspace.';

  @override
  String get editorOfficeNameDefault => 'Office';

  @override
  String get editorOfficeNameLabel => 'Office name';

  @override
  String get editorOfficeProperties => 'Office';

  @override
  String get editorOpenTooltip => 'Edit workspace';

  @override
  String get editorOrientationHint => 'Which way the chair faces on the plan.';

  @override
  String get editorOrientationLabel => 'Sitting direction';

  @override
  String get editorPlacementOutside => 'Must be fully inside an office.';

  @override
  String get editorPlacementOverlap => 'Overlaps an existing element.';

  @override
  String get editorProperties => 'Properties';

  @override
  String get editorRenameLevel => 'Rename';

  @override
  String get editorSeatNameDefault => 'Seat';

  @override
  String get editorSeatNameLabel => 'Seat name';

  @override
  String get editorSeatNfcDuplicate =>
      'This tag is already linked to another chair.';

  @override
  String get editorSeatNfcHelp => 'Tag uid in hex — leave empty for no tag.';

  @override
  String get editorSeatNfcLabel => 'NFC/RFID tag';

  @override
  String get editorSeatNfcRead => 'Read a tag now';

  @override
  String get editorSeatNfcReadFailed => 'Could not start the tag reader.';

  @override
  String get editorSeatNoDesk => 'Seats can only be placed on a desk.';

  @override
  String get editorSeatProperties => 'Seat';

  @override
  String get editorTitle => 'Workspace editor';

  @override
  String get editorToolDesk => 'Desk';

  @override
  String get editorToolErase => 'Erase';

  @override
  String get editorToolImage => 'Image';

  @override
  String get editorToolOffice => 'Office';

  @override
  String get editorToolSeat => 'Seat';

  @override
  String get editorToolSelect => 'Select';

  @override
  String get einvoiceConfigClear => 'Remove the platform';

  @override
  String get einvoiceConfigCleared => 'Platform removed.';

  @override
  String get einvoiceConfigEndpoint => 'Upload URL';

  @override
  String get einvoiceConfigField => 'File field name (default file)';

  @override
  String get einvoiceConfigHeader => 'Auth header (default Authorization)';

  @override
  String get einvoiceConfigIntro =>
      'Where DesKilo posts your invoices. Any platform that accepts an upload with a token works — a plateforme agréée, a Peppol access point, a national platform. The token is stored server-side and never comes back out.';

  @override
  String get einvoiceConfigSaved => 'Platform saved.';

  @override
  String get einvoiceConfigTitle => 'E-invoicing platform';

  @override
  String get einvoiceConfigToken => 'Token or credential';

  @override
  String get einvoiceConfigTokenSet =>
      'A token is stored (type a new one to replace it).';

  @override
  String get einvoiceConfigUnavailable =>
      'The platform settings could not be loaded. Check your connection and try again.';

  @override
  String get einvoiceCustomerSectionHelp =>
      'Where invoices go for the customer: their Peppol access point, portal or agreed upload API — separate from the government platform.';

  @override
  String get einvoiceCustomerSectionTitle => 'Customer delivery service';

  @override
  String get einvoiceDevEndpoint => 'Dev upload URL';

  @override
  String get einvoiceDevToken => 'Dev token or credential';

  @override
  String get einvoiceEnvDev => 'Dev (test platform)';

  @override
  String get einvoiceEnvProd => 'Production';

  @override
  String get einvoiceEnvProdHint => 'The real submission.';

  @override
  String get einvoiceEnvTestHint => 'A rehearsal — logged as a test send.';

  @override
  String get einvoiceEnvTitle => 'Send to which platform?';

  @override
  String get einvoiceEnvUat => 'UAT (test platform)';

  @override
  String get einvoiceTestEnvsHelp =>
      'Separate endpoints and tokens for rehearsals. The choice appears at send time only while developer mode is on.';

  @override
  String get einvoiceTestEnvsTitle => 'Test environments (UAT / Dev)';

  @override
  String get einvoiceUatEndpoint => 'UAT upload URL';

  @override
  String get einvoiceUatToken => 'UAT token or credential';

  @override
  String get emblemChoose => 'Choose an image';

  @override
  String get emblemFailed => 'The emblem could not be saved. Nothing changed.';

  @override
  String get emblemHint =>
      'A small image shown beneath the app’s own name in the menu. It is redrawn at most 512 pixels wide and stored without the file’s metadata.';

  @override
  String get emblemNotAnImage => 'That file is not an image.';

  @override
  String get emblemRemove => 'Remove';

  @override
  String get emblemRemoved => 'Emblem removed.';

  @override
  String get emblemSaved => 'Emblem saved.';

  @override
  String get emblemTitle => 'Emblem';

  @override
  String get emblemTooHeavy =>
      'That image is too heavy for a mark shown at 28 pixels.';

  @override
  String get entitlementBlockedFull =>
      'You\'ve used all your days this month. Ask an admin for more or request extra half-days below.';

  @override
  String entitlementDaysLeft(String left) {
    return '$left days left';
  }

  @override
  String entitlementDaysUsed(String used, String total) {
    return '$used of $total days used';
  }

  @override
  String get entitlementPackageFull =>
      'You\'ve used all your days this month. Buy a package to keep booking.';

  @override
  String entitlementPaygRate(String rate) {
    return 'Extra days beyond your plan bill at $rate each.';
  }

  @override
  String get entitlementTitle => 'This month';

  @override
  String get environmentDev => 'Development — for trying things out';

  @override
  String get environmentHint =>
      'A development workspace says so on every screen and watermarks every document. Declare it production only when the invoices leaving it are genuinely owed.';

  @override
  String get environmentLabel => 'Workspace type';

  @override
  String get environmentPairsCreateTwin => 'Create its twin';

  @override
  String get environmentPairsCreateTwinDesc =>
      'A development and a production workspace with the same name; the configuration is copied once.';

  @override
  String get environmentPairsPairedDev => 'Paired with its development twin';

  @override
  String get environmentPairsPairedProd => 'Paired with its production twin';

  @override
  String get environmentPairsTwinCreated => 'The twin is created.';

  @override
  String get environmentProd => 'Production — the invoices are owed';

  @override
  String get environmentProdConfirmAction => 'Declare production';

  @override
  String get environmentProdConfirmBody =>
      'The banner goes away and documents lose their watermark. Invoices already issued do not change: they keep the watermark they carried when they were issued.';

  @override
  String get environmentProdConfirmTitle =>
      'Declare this workspace production?';

  @override
  String get environmentSaved => 'Workspace type saved.';

  @override
  String get erasurePreviewKept => 'Kept, and why';

  @override
  String get erasurePreviewOutside => 'Outside this installation';

  @override
  String get erasurePreviewRemoved => 'Removed';

  @override
  String get erasurePreviewTitle => 'What erasing does here';

  @override
  String get erasureStoreAccounts =>
      'Invoices and ledger — accounting evidence, kept for the statutory period; issued documents are not rewritten';

  @override
  String get erasureStoreAnswers => 'Your answers to the space\'s questions';

  @override
  String get erasureStoreBackups =>
      'The operator\'s backups — expire on their rotation';

  @override
  String get erasureStoreDeviceCaches =>
      'Copies on your devices — cleared when you sign out of each';

  @override
  String get erasureStoreHeldAnswers =>
      'Answers under a retention hold the space documented';

  @override
  String get erasureStoreMembership =>
      'The membership row — links the records kept; pseudonymous, not anonymous';

  @override
  String get erasureStoreMessages => 'Messages you sent';

  @override
  String get erasureStoreOpenBookings => 'Open bookings — cancelled';

  @override
  String get erasureStoreOtherInstallations =>
      'Another DesKilo installation is a separate controller — ask it directly';

  @override
  String get erasureStorePastBookings =>
      'Past bookings — the space\'s occupancy record';

  @override
  String get erasureStoreProfile =>
      'Your profile (when this is your last space)';

  @override
  String get errorOffline =>
      'No connection — nothing was sent. Try again when you are back online.';

  @override
  String get eventAccept => 'Accept';

  @override
  String get eventAutoValidated => 'Auto-validated';

  @override
  String eventExpenseDeviation(Object reason, Object scheduled) {
    return 'validated $scheduled — $reason';
  }

  @override
  String eventExpenseRepartitionLine(
    String actor,
    String title,
    String amount,
    int count,
  ) {
    return '$actor distributes “$title” — $amount over $count members';
  }

  @override
  String eventExpenseScheduleLine(Object actor, Object amount, Object title) {
    return '$actor schedules “$title” — $amount recurring';
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
  String eventInvoicePaid(String number, String amount) {
    return 'Invoice $number paid — $amount';
  }

  @override
  String eventInvoiceReminderLine(String number, int level, String amount) {
    return 'Reminder $level: invoice $number — $amount still due';
  }

  @override
  String eventInvoiceWriteoffLine(String actor, String number, String amount) {
    return '$actor asks to cancel the remainder of $number — $amount';
  }

  @override
  String eventPaymentSubmitted(String actor, String amount) {
    return '$actor recorded a payment of $amount';
  }

  @override
  String eventPaymentTermsChangeLine(String actor, String terms) {
    return '$actor asks to set payment conditions: $terms';
  }

  @override
  String eventPriceNegotiationItems(int count) {
    return '$count items';
  }

  @override
  String eventPriceNegotiationLine(String actor, String member, String terms) {
    return '$actor proposes a deal for $member: $terms';
  }

  @override
  String eventQuotaRequested(String actor, int halfDays, String period) {
    return '$actor requests $halfDays extra half-days for $period';
  }

  @override
  String get eventReject => 'Decline';

  @override
  String eventRejectedBy(String name, String when) {
    return 'Declined by $name · $when';
  }

  @override
  String eventReservationCancelled(String actor, String target) {
    return '$actor cancelled the booking of $target';
  }

  @override
  String eventReservationCreated(String actor, String target) {
    return '$actor booked $target';
  }

  @override
  String get eventReservationDeleteCheckedIn => 'checked in';

  @override
  String eventReservationDeleteLine(String actor, String date, String state) {
    return '$actor asks to delete the booking of $date ($state)';
  }

  @override
  String get eventReservationDeleteUnused => 'never used';

  @override
  String eventReservationModified(String actor, String target) {
    return '$actor changed the booking of $target';
  }

  @override
  String eventRoleDemote(String actor) {
    return '$actor asks to take back the Administrator role';
  }

  @override
  String eventRoleGiven(String actor, String role, String member) {
    return '$actor gives the role $role to $member';
  }

  @override
  String eventRolePromote(String actor) {
    return '$actor asks to give the Administrator role';
  }

  @override
  String eventRoleTakenBack(String actor, String role, String member) {
    return '$actor takes back the role $role from $member';
  }

  @override
  String eventServiceChargeTitle(String name, int quantity, String amount) {
    return '$name ×$quantity — $amount';
  }

  @override
  String get eventSystemDecider => 'System';

  @override
  String get eventTypeAdjustment => 'Adjustment';

  @override
  String get eventTypeExpense => 'Expense';

  @override
  String get eventTypeExpenseRepartition => 'Shared expense';

  @override
  String get eventTypeExpenseSchedule => 'Scheduled expense';

  @override
  String get eventTypeInvoiceIssue => 'Invoice issue';

  @override
  String get eventTypeInvoicePayment => 'Invoice payment';

  @override
  String get eventTypeInvoiceReminder => 'Payment reminder';

  @override
  String get eventTypeInvoiceVoid => 'Invoice cancellation';

  @override
  String get eventTypeInvoiceWriteoff => 'Outstanding write-off';

  @override
  String get eventTypeMatrixChange => 'Permission matrix change';

  @override
  String get eventTypeMemberJoin => 'New member';

  @override
  String get eventTypeMemberStatusChange => 'Membership change';

  @override
  String get eventTypePayment => 'Payment';

  @override
  String get eventTypePaymentTermsChange => 'Payment conditions';

  @override
  String get eventTypePriceNegotiation => 'Price negotiation';

  @override
  String get eventTypeQuota => 'Extra half-days';

  @override
  String get eventTypeRefund => 'Refund';

  @override
  String get eventTypeReservation => 'Reservation';

  @override
  String get eventTypeReservationDelete => 'Booking deletion';

  @override
  String get eventTypeRoleChange => 'Role change';

  @override
  String get eventTypeServiceCharge => 'Service';

  @override
  String get eventTypeSpaceReservation => 'Whole-space reservations';

  @override
  String get eventTypeSubscriptionChange => 'Subscription change';

  @override
  String get eventTypeUnknown => 'Activity';

  @override
  String get eventTypeUsageCorrection => 'Early departure';

  @override
  String get eventTypeUsageRecordDelete => 'Usage record removal';

  @override
  String eventUsageCorrectionLine(String actor, String from, String to) {
    return '$actor asks to be billed $to instead of $from';
  }

  @override
  String eventUsageRecordDeleteLine(String actor, String space) {
    return '$actor asks to remove a usage record ($space)';
  }

  @override
  String eventValidatedBy(String name, String when) {
    return 'Validated by $name · $when';
  }

  @override
  String eventValidationStage(int stage, int required) {
    return 'Validation $stage of $required requested';
  }

  @override
  String eventValidations(int current, int required) {
    return '$current/$required validations';
  }

  @override
  String get eventsEmpty => 'No events yet.';

  @override
  String get eventsFilterAll => 'All';

  @override
  String get eventsMessagesHeader => 'Messages';

  @override
  String get eventsPendingHeader => 'Waiting for your confirmation';

  @override
  String get expenseCategoryCoffee => 'Coffee & kitchen';

  @override
  String get expenseCategoryEquipment => 'Equipment';

  @override
  String get expenseCategoryOther => 'Other';

  @override
  String get expenseCategorySupplies => 'Supplies';

  @override
  String get expenseInvalidAmount => 'Enter an amount above zero.';

  @override
  String get expenseInvalidSupplyQuantity => 'Enter at least one unit.';

  @override
  String get expenseInvalidUnitPrice =>
      'Enter a valid unit price, or leave it empty.';

  @override
  String get expenseMissingSupplyName => 'Name the new item.';

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
  String get expenseSupplyToggle => 'This is a supply for the space';

  @override
  String get expenseSupplyUnitPrice => 'Unit price (what a consumption costs)';

  @override
  String get expenseSupplyUnitPriceHint =>
      'Prefilled from amount ÷ quantity; round up if you like.';

  @override
  String get exportClaimExchange =>
      'For your accountant to import and review — not a filing.';

  @override
  String get exportClaimRegulatory => 'The format your tax authority asks for.';

  @override
  String get exportClaimSubset =>
      'Invoices and payments only; no general ledger. The file says so in its header.';

  @override
  String get exportNoCompleteBooks =>
      'Rebuilt from invoices and payments — DesKilo keeps no double-entry ledger, so this is not your complete books. Your accountant completes it.';

  @override
  String get exportUncertifiedSoftware =>
      'Built to the published spec, but DesKilo is not certified software in this country — check with your accountant whether that is required of you.';

  @override
  String get featureAccessorySupplements => 'Accessory supplements';

  @override
  String get featureAccessorySupplementsDesc =>
      'Bill priced seat accessories per booked half-day. Applies to bookings from activation on.';

  @override
  String get featureAccountingBookDesc =>
      'Who keeps the official books of each issuer: Deskilo as pre-accounting, a local book, or an external accounting system that stays authoritative. Each issuer states its currency, fiscal year and accounting basis. Off: member balances and invoices work as before.';

  @override
  String get featureAccountingBookTitle => 'Accounting book';

  @override
  String get featureAdminInvoicing => 'Admins issue invoices';

  @override
  String get featureAdminInvoicingDesc =>
      'Admins issue invoices too. The owner always can.';

  @override
  String get featureAdminLevelAssign => 'Admins can assign levels';

  @override
  String get featureAdminLevelAssignDesc =>
      'Admins assign level reservations to members. The owner always can.';

  @override
  String get featureAdminSeatBlocking => 'Admins can block seats';

  @override
  String get featureAdminSeatBlockingDesc =>
      'Admins mark seats not reservable for maintenance. The owner always can.';

  @override
  String featureAlsoEnabled(String features) {
    return 'Also switched on: $features';
  }

  @override
  String featureAlsoEnables(String features) {
    return 'Switching this on also enables $features';
  }

  @override
  String get featureAutoCheckInOut => 'Auto check-in/out at day end';

  @override
  String get featureAutoCheckInOutDesc =>
      'Reservations never checked in or out complete themselves once their time has passed.';

  @override
  String get featureBadgeSignInDesc =>
      'Members can sign in by scanning their badge and entering their PIN, instead of typing an e-mail on a shared tablet. Each member sets their own PIN and arms their own badge.';

  @override
  String get featureBadgeSignInTitle => 'Sign in with a badge';

  @override
  String get featureBookForOthers => 'Book for others';

  @override
  String get featureBookForOthersDesc =>
      'Admins and owners book seats for other members.';

  @override
  String get featureBookingGateDesc =>
      'Every booking surface — plan, day, week and month views, the booking sheet, the kiosk, a QR or NFC scan — checks the availability parameters before offering a window and names the reason when it cannot; closed days draw as closed in every view, a legend names the seat states, and admins may check members out where the policy allows.';

  @override
  String get featureBookingGateTitle => 'Booking gate';

  @override
  String get featureBookingPoliciesDesc =>
      'Owner-configurable booking behavior: past bookings, minute bookings outside the working hours, and check-out by admins.';

  @override
  String get featureBookingPoliciesTitle => 'Booking policies';

  @override
  String get featureCalendarFileExportDesc =>
      'Lets a member save one of their own bookings as a standard calendar file (.ics) for the calendar they already use. The file carries the time, the booked space and the workspace name only — no amount, no name, no note, no link — and it is a snapshot: a later change to the booking does not update a file already saved. Nothing is written to any calendar and nothing syncs. Off hides the button.';

  @override
  String get featureCalendarFileExportTitle => 'Calendar file of a booking';

  @override
  String get featureCalendarHubDesc =>
      'The calendar shows everything dated — bookings, check-ins, alerts, messages, invoices, payments, consumption, reminders — for a day or a range, each row opening its source. Off: reservations only.';

  @override
  String get featureCalendarHubTitle => 'Calendar hub';

  @override
  String get featureCalendarTab => 'Calendar tab';

  @override
  String get featureCalendarTabDesc =>
      'Monthly overview of bookings and closed days.';

  @override
  String get featureCalendarValidationsDesc =>
      'Every decision taken on an event appears on the calendar at the moment it was taken, not at the moment of the event: who validated or refused what, and when. Tapping one opens its trail. Off: the calendar carries no decisions.';

  @override
  String get featureCalendarValidationsTitle => 'Validations on the calendar';

  @override
  String get featureCalendarViewsDesc =>
      'The Calendar tab as agenda, week and month: per-day markers by kind, closed days drawn as closed, Today / Tomorrow headers, payment due dates and scheduled expenses in the feed. Off: the plain day-or-range selector over the feed.';

  @override
  String get featureCalendarViewsTitle => 'Calendar views';

  @override
  String get featureCapacityKpiDesc =>
      'Shows owners and reservation managers how much of the offered seat time was reserved in a month, with how it is computed and what the figure cannot know.';

  @override
  String get featureCapacityKpiTitle => 'Seat utilisation';

  @override
  String get featureCaptureProtectionDesc =>
      'Message screens refuse screenshots and screen recording where the device allows it, hide their content while the screen is recorded, and announce a screenshot in the conversation where it can only be detected. A browser cannot block screenshots; there the thread is blurred when the tab loses focus.';

  @override
  String get featureCaptureProtectionTitle => 'Screen capture protection';

  @override
  String get featureCarnetsDesc =>
      'Sell carnets of half-days that are spent across months when a member books beyond their subscription, charged once at the sale.';

  @override
  String get featureCarnetsTitle => 'Carnets';

  @override
  String get featureChangeUnconfirmed =>
      'The change was sent, but the features could not be reloaded to confirm it. Reopen the screen to see what is set.';

  @override
  String get featureChangedMeanwhile =>
      'The features changed meanwhile, so nothing was written. Check the list and switch again.';

  @override
  String get featureCoOwner => 'Co-owners';

  @override
  String get featureCoOwnerDesc =>
      'Appoint co-owners: owner permissions now (active) or succession-in-waiting (passive).';

  @override
  String get featureConfigurationTransfer => 'Configuration in the space file';

  @override
  String get featureConfigurationTransferDesc =>
      'The space file (XML) carries the whole configuration — tariffs, legal identity, booking and validation rules, roles, document designs, sites, closure days — and importing it applies it, even on a space that already has bookings. Off: the file carries settings and floor plan only.';

  @override
  String get featureCustomFieldsDesc =>
      'The workspace may ask its own questions inside the identity form — a committee role, a joining date, an emergency contact. The answers belong to the membership, so a question asked here never follows somebody elsewhere.';

  @override
  String get featureCustomFieldsTitle => 'Questions this space asks';

  @override
  String get featureCustomRolesDesc =>
      'The workspace may define roles of its own — a treasurer, a secretary — each adding permissions on top of a member\'s role. They never take a permission away, and an owner always keeps every one.';

  @override
  String get featureCustomRolesTitle => 'Roles this space defines';

  @override
  String get featureDataAccessLogDesc =>
      'Members see who looked at their finances and when (written by the server, never skippable). Off hides the row; the log is still kept.';

  @override
  String get featureDataAccessLogTitle => 'Data access log';

  @override
  String get featureDataExport => 'Data export (Excel)';

  @override
  String get featureDataExportDesc =>
      'Download all workspace data as an Excel workbook.';

  @override
  String get featureDecisionSurfaceDesc =>
      'One place that answers \"does anything need me?\", ranked by what the delay costs — money that leaves first, then somebody waiting on an answer. A line appears only when a person must decide or act; a number nobody can act on stays on the screen that owns it.';

  @override
  String get featureDecisionSurfaceTitle => 'What needs you';

  @override
  String get featureDeletionRequests => 'Booking deletion requests';

  @override
  String get featureDeletionRequestsDesc =>
      'Members may REQUEST deletion of a past or checked-in booking; an owner/admin validates. Off, such bookings cannot be deleted at all.';

  @override
  String get featureDemoMode => 'The demo workspace';

  @override
  String get featureDemoModeDesc =>
      'An invented workspace anyone can open from the sign-in screen, with its own people, bookings and bills. Nothing done in it reaches a real workspace or leaves the device, and no account is needed. Off: the offer does not appear.';

  @override
  String get featureDeployments => 'Deployments';

  @override
  String get featureDeploymentsDesc =>
      'Configuration and master data deployed between the two sides of a pair, entity by entity, with a preview of what changes and a journal that can roll back. Off: the twins are edited by hand, each on its own.';

  @override
  String get featureDetailChange => 'Change it among the switches';

  @override
  String featureDetailGrantsPermission(String permission) {
    return 'Grants administrators the permission \"$permission\".';
  }

  @override
  String featureDetailHeldBack(String feature) {
    return 'Switched on, but held back: it needs $feature, which is off.';
  }

  @override
  String get featureDetailKey => 'Technical key';

  @override
  String get featureDetailNone => 'Nothing.';

  @override
  String get featureDetailOff => 'Switched off.';

  @override
  String get featureDetailOn => 'Switched on.';

  @override
  String featureDetailOnNeededBy(String names) {
    return 'Switched on, and needed by $names.';
  }

  @override
  String get featureDetailProvides => 'Provides';

  @override
  String get featureDetailRequires => 'Requires';

  @override
  String get featureDetailTechnical => 'Technical details';

  @override
  String get featureDetailUsedBy => 'Used by';

  @override
  String get featureDocuments => 'Document library';

  @override
  String get featureDocumentsDesc =>
      'The workspace document library: statutes, guides, financial statements, minutes — linked from any drive, visible per role.';

  @override
  String get featureDunning => 'Payment reminders';

  @override
  String get featureDunningDesc =>
      'Configurable reminder levels and delays, a reminder letter per level, and “Reminder due” flags on late invoices. Sending stays a manual tap unless Automatic payment reminders is on.';

  @override
  String get featureEinvoiceCustomerDeliveryDesc =>
      'A second sending channel beside the government platform: post the issued invoice straight to the customer\'s own e-invoicing service.';

  @override
  String get featureEinvoiceCustomerDeliveryTitle =>
      'E-invoice delivery to customers';

  @override
  String get featureEnvironmentPairs => 'Environment pairs';

  @override
  String get featureEnvironmentPairsDesc =>
      'A workspace and its twin — the development and the production side — as one couple: one card in Profiles with a switch, and the twin created on demand with the configuration copied. Off: two unrelated entries.';

  @override
  String get featureEventsTab => 'Events tab';

  @override
  String get featureEventsTabDesc => 'Activity feed and pending confirmations.';

  @override
  String get featureExpenseRepartitionDesc =>
      'A shared expense (a cleaning bill, an internet upgrade, a broken chair) split over the members — equal shares, pro rata of the subscription, pro rata of usage, or a key per member — with every share previewed before it is booked. The shares land as charge lines on the next usage invoice; a reversal books credit notes. Through the validation rules. Off: no distribution.';

  @override
  String get featureExpenseRepartitionTitle => 'Shared expenses';

  @override
  String get featureExpenseRepartitionWizard => 'Repartition wizard';

  @override
  String get featureExpenseRepartitionWizardDesc =>
      'A guided repartition: a shared cost proposed over the members by subscription share, each share adjustable, and the adjusted rule remembered for next month. Off: the one-expense repartition sheet only.';

  @override
  String get featureFinanceFacesDesc =>
      'The Finances tab reads as four faces — Statement, Payments, Invoices, Documents — under one month chooser, each with its own help. Off: a single column.';

  @override
  String get featureFinanceFacesTitle => 'Finances in four faces';

  @override
  String get featureFormHelpHintsDesc =>
      'A dismissible tip carousel on every main screen, and a small ? beside every parameter and entry field — one tap opens the guide at the right section. Restorable from Settings.';

  @override
  String get featureFormHelpHintsTitle => 'Help hints';

  @override
  String get featureGuestParticipationDesc =>
      'Lets a person who is not a member ask to visit this space, and someone who manages reservations admit or decline them. A visit creates no membership, subscription or role. Off: nobody asks or is admitted here.';

  @override
  String get featureGuestParticipationTitle => 'Guest visits';

  @override
  String get featureHeldBack =>
      'Waiting on the feature above — switch that on and this one works again.';

  @override
  String get featureHolidayImportDesc =>
      'An owner imports the public holidays of the country, and of one region, from an open-data source, deselects the days the space stays open and imports the rest as closure days. Invoiced months are skipped and named.';

  @override
  String get featureHolidayImportTitle => 'Import public holidays';

  @override
  String get featureInstanceWizard => 'Instance wizard';

  @override
  String get featureInstanceWizardDesc =>
      'On the Server screen, a wizard that creates a new Supabase project, installs the app\'s schema, deploys its functions and points this device at it — one access token, no terminal. Off: the manual steps only.';

  @override
  String get featureIntakeStoppedNote =>
      'Off: nothing new starts; what is already open can still be answered and closed.';

  @override
  String get featureIntakeUnconfirmedNote =>
      'Off: nothing new starts. This server could not confirm that what is already open stays answerable, so do not count on it.';

  @override
  String get featureInvoiceAddressWindow => 'Envelope address window';

  @override
  String get featureInvoiceAddressWindowDesc =>
      'Place the recipient where a window envelope shows it, so a printed invoice can be folded and posted. The side follows the country and can be overridden.';

  @override
  String get featureInvoiceJourneyDesc =>
      'Every invoice shows where it stands — Issued, Payment, Confirmation, Closed — and whose move it is: the member pays, an admin confirms the declared payment, the issuer matches it, the validators decide. The issuers\' hub adds a stage strip with live counts and a How-it-works explainer.';

  @override
  String get featureInvoiceJourneyTitle => 'The journey of an invoice';

  @override
  String get featureInvoicePdfTemplate => 'Invoice PDF template';

  @override
  String get featureInvoicePdfTemplateDesc =>
      'Owner-written intro and footer text on the invoice PDF. Never touches the e-invoice XML.';

  @override
  String get featureInvoiceSettlementDesc =>
      'Several of a member\'s open invoices can be regrouped into one they pay. The originals stay in the archive, traceable position by position, and stop being chased separately.';

  @override
  String get featureInvoiceSettlementTitle => 'Regroup invoices';

  @override
  String get featureInvoicing => 'Invoices';

  @override
  String get featureInvoicingDesc =>
      'Immutable, signed invoices in an archive — download or share as PDF.';

  @override
  String get featureInvoicingWizardDesc =>
      'One guided month-close process for the finance person: a start-of-month run for the subscriptions paid ahead and an end-of-month run for usage and extra charges — review, issue in one batch, send, remind what is due, register and validate payments, match them to invoices, regroup, write off or refund, and a summary with whose move is left. Off: the separate screens.';

  @override
  String get featureInvoicingWizardTitle => 'Invoicing wizard';

  @override
  String get featureKioskMemberPhotosDesc =>
      'The kiosk receipt shows the member\'s profile photo — the visual wrong-badge check.';

  @override
  String get featureKioskMemberPhotosTitle => 'Member photos at the kiosk';

  @override
  String get featureKioskMode => 'Kiosk mode';

  @override
  String get featureKioskModeDesc =>
      'Wall-tablet accounts locked to the live plan; members act through badges.';

  @override
  String get featureLess => 'Less';

  @override
  String get featureLetterStandard => 'Letter standard for every document';

  @override
  String get featureLetterStandardDesc =>
      'Invoices, proformas, statements, agreements, payments and consumption reports and reminders without a design print as standard letters: letterhead, recipient in the envelope window, body from 90 mm, a fixed footer.';

  @override
  String get featureLevelBooking => 'Desk, office & level reservations';

  @override
  String get featureLevelBookingDesc =>
      'Reserve a whole desk, office or floor as one booking, priced per half-day. Grant the right per member.';

  @override
  String get featureLifecycleActive => 'Active';

  @override
  String get featureLifecycleDeprecated => 'Deprecated';

  @override
  String get featureLifecycleRetired => 'Retired';

  @override
  String get featureManagedProfileAccess => 'Who administers a profile';

  @override
  String get featureManagedProfileAccessDesc =>
      'Each managed profile says who may administer it — by role, by named people, or both. Off: every owner and admin may, as before. The identity itself is protected either way, and every read is written down for the person who takes the profile over.';

  @override
  String get featureManagedProfiles => 'Managed profiles';

  @override
  String get featureManagedProfilesDesc =>
      'Admins create members who have no account yet, book and invoice for them, and hand the profile over with a personal code the person redeems when they join.';

  @override
  String get featureMaturityAlpha => 'Alpha';

  @override
  String get featureMaturityBeta => 'Beta';

  @override
  String get featureMaturityFilterAll => 'All stages';

  @override
  String get featureMaturityFilterLabel => 'Maturity';

  @override
  String featureMaturitySemantics(String maturity, String lifecycle) {
    return 'Maturity $maturity, $lifecycle';
  }

  @override
  String get featureMaturityStable => 'Stable';

  @override
  String get featureMaturityUnreviewed => 'Unreviewed';

  @override
  String get featureMcpAccessDesc =>
      'Makes the MCP interface available to this workspace, so an AI assistant can be connected to DesKilo. Availability only: switching it on grants nobody anything. Each person still needs a grant the owner configures and the instance administrator approves, and every operation keeps answering to the permissions and rules the app already applies. Off hides the MCP entry points and refuses calls; existing grants stay visible and revocable.';

  @override
  String get featureMcpAccessTitle => 'MCP interface';

  @override
  String get featureMemberAccountMenuDesc =>
      'A member who administers nothing meets My account instead of Settings — the same screen, which already shows them only their own account, membership and preferences, under the name that says so. Anyone whose role grants administration keeps Settings and everything it opens. This renames an entry; it grants and withdraws nothing.';

  @override
  String get featureMemberAccountMenuTitle => 'Members see My account';

  @override
  String get featureMemberDataExportDesc =>
      'Every member can export their data as one file (GDPR art. 20) and leave the workspace with their personal data cleared (art. 17) from Settings → Privacy & data.';

  @override
  String get featureMemberDataExportTitle => 'Export & erasure';

  @override
  String get featureMemberEnvironmentsDesc =>
      'When you invite somebody, choose whether they also reach the production space. They join the test space either way, and the role still has to allow production access.';

  @override
  String get featureMemberEnvironmentsTitle =>
      'Choose the environments a person is activated on';

  @override
  String get featureMemberGettingStartedDesc =>
      'After joining or creating a workspace, a member sees one compact card on the Reserve hub: which workspace they are in, and one suggested next step — choose a time to book, view their membership, or open the help — only where the features and their permissions allow it. Not now hides it; Settings can show it again. It never books, pays or approves anything. For whoever configures the space, the settings also show how far it is from a first booking, section by section. Off hides the card and that checklist and changes nothing else.';

  @override
  String get featureMemberGettingStartedTitle => 'Get started card';

  @override
  String get featureMemberNotifications => 'Member notifications';

  @override
  String get featureMemberNotificationsDesc =>
      'Messaging between members: private and group conversations, read receipts, links to a reservation or a space; admins can notify all admins, owner included.';

  @override
  String get featureMemberOriginDesc =>
      'A discreet line on a member saying how their membership began: founded the space, joined by invitation, or had the profile created for them. It is not a status.';

  @override
  String get featureMemberOriginTitle => 'How each member got here';

  @override
  String get featureMemberPageDesc =>
      'One page per member: photo and presence, when they were last seen, what they have booked and what comes next, quick actions to message, WhatsApp or e-mail them, contact and money cards, and for admins every setting grouped by topic with its current value. Off: the profile sheet and the Members & plans action sheet.';

  @override
  String get featureMemberPageTitle => 'Member page';

  @override
  String get featureMemberPaymentTerms => 'Payment conditions per member';

  @override
  String get featureMemberPaymentTermsDesc =>
      'The workspace sets the default payment conditions; a member may have their own, visible to them, changed only through a validated request by an authorised admin.';

  @override
  String get featureMemberReports => 'Member reports';

  @override
  String get featureMemberReportsDesc =>
      'The financial agreement and the monthly payments report — self-service for members, sendable per member.';

  @override
  String get featureMembersDirectory => 'Members directory';

  @override
  String get featureMembersDirectoryDesc =>
      'The community tab: who is here, statuses, presence.';

  @override
  String get featureMessageForwardingDesc =>
      'A message can be forwarded into another conversation the forwarder takes part in. The copy names where it came from and who wrote it, the original conversation is told who forwarded it and where, and an author can lock a message against forwarding. Off refuses forwards out of this space.';

  @override
  String get featureMessageForwardingTitle => 'Message forwarding';

  @override
  String get featureMessageGesturesDesc =>
      'Swipe a message right to quote it in your reply; swipe left to take your own message back while nobody has read it yet, after a confirmation. Off: messages are deleted by holding them.';

  @override
  String get featureMessageGesturesTitle => 'Swipe to quote or take back';

  @override
  String get featureMessageMentionsDesc =>
      'In a group, a person can be mentioned by name. Only people in the conversation can be mentioned, and the person mentioned is notified even when they have muted it. Off, a name typed after @ is plain text and notifies nobody.';

  @override
  String get featureMessageMentionsTitle => 'Mentions in groups';

  @override
  String get featureMessagesHubDesc =>
      'One inbox bar (All / Unread / Archived and search), pin, mute, archive and mark-unread on a thread, the conversation as a full page with date separators, an attach menu and a kept draft in the composer, a person opened with one tap. Off: the two-bar inbox and the sheet thread.';

  @override
  String get featureMessagesHubTitle => 'Messages, reworked';

  @override
  String get featureMoneyTab => 'Money tab';

  @override
  String get featureMoneyTabDesc => 'Monthly bills, payments and expenses.';

  @override
  String get featureMore => 'More';

  @override
  String get featureMultiSite => 'Sites';

  @override
  String get featureMultiSiteDesc =>
      'Several addresses: levels are grouped by site, each site has its own address and registration, each member a home site, and documents name the site they concern. Off: one address for the whole workspace.';

  @override
  String get featureNavigationStyle => 'Navigation choice';

  @override
  String get featureNavigationStyleDesc =>
      'Each member picks in their settings how the app navigates: the classic bottom bar with the round Reserve button, or the menu the web uses. Off: every device keeps its platform\'s default.';

  @override
  String get featureNfcBadges => 'RFID / NFC badges';

  @override
  String get featureNfcBadgesDesc =>
      'Members check in at a kiosk by tapping an RFID/NFC card. Needs an Android device with NFC.';

  @override
  String get featureNfcSeatTagsDesc =>
      'A physical NFC/RFID tag on a chair resolves to its seat like the printed QR card; owners fill the tag field by tapping the chip.';

  @override
  String get featureNfcSeatTagsTitle => 'NFC/RFID chair tags';

  @override
  String get featureNotificationGroupingDesc =>
      'Members may fold the notification feed into groups by type, day or member; tapping the group symbol returns to the flat list.';

  @override
  String get featureNotificationGroupingTitle => 'Notification feed grouping';

  @override
  String get featureNumberSequences => 'Number sequences';

  @override
  String get featureNumberSequencesDesc =>
      'How each journal numbers its documents — prefix, year or month, digits, when the counter restarts — one screen for every series. Numbers are drawn in the database, gapless, whether this is on or off; on, the owner can change the format for what comes next.';

  @override
  String get featureOnlinePayments => 'Online payments';

  @override
  String get featureOnlinePaymentsDesc =>
      'Let members pay their bill online (PayPal). Needs the payment provider configured on the server.';

  @override
  String featureOptInAlsoOn(int count, String features) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Also switched on, because they are needed ($count): $features',
      one: 'Also switched on, because it is needed: $features',
    );
    return '$_temp0';
  }

  @override
  String featureOptInBody(String features) {
    return 'Not yet reviewed as stable: $features. It may change and has known limits. Switch on only if this space accepts that.';
  }

  @override
  String get featureOptInConfirm => 'Switch on';

  @override
  String featureOptInStage(String feature, String stage) {
    return '$feature: $stage';
  }

  @override
  String get featureOptInTitle => 'Switch on an experimental feature?';

  @override
  String get featurePaymentRemindersDesc =>
      'Open invoices past the configured term get their reminder levels automatically — an alert in the member\'s feed and a push, once a day. Off: reminders stay a manual action.';

  @override
  String get featurePaymentRemindersTitle => 'Automatic payment reminders';

  @override
  String get featurePdfExport => 'PDF export';

  @override
  String get featurePdfExportDesc => 'Export the monthly bill as a PDF.';

  @override
  String get featurePersonalInfo => 'Personal information';

  @override
  String get featurePersonalInfoDesc =>
      'Members enter their name, postal address, phone, e-mail and legal ids in Settings; invoices and letters print them in the standard postal block.';

  @override
  String get featurePlaceFeedbackDesc =>
      'Members mark seats, desks, offices and levels as favourites and rate them from 0 to 5 stars. A favourite is the member\'s own; a rating shows its average and how many gave one, never who. An assistant can list the favourites, book one, and record a rating. Off hides the hearts and stars and refuses the writes; nothing else follows it.';

  @override
  String get featurePlaceFeedbackTitle => 'Favourites and ratings';

  @override
  String get featurePlanMemberPhotosDesc =>
      'Occupied seats on the Plan tab and Reserve hub show the occupant\'s profile photo instead of the initial.';

  @override
  String get featurePlanMemberPhotosTitle => 'Member photos on the plan';

  @override
  String get featurePlanObjectDeleteDesc =>
      'Owners may delete levels, offices, desks and seats even when past reservations reference them — the bookings keep a text snapshot for audits and reports.';

  @override
  String get featurePlanObjectDeleteTitle => 'Delete spaces with history';

  @override
  String get featurePriceNegotiationsDesc =>
      'The tariff is the default; a member can hold their own conditions — monthly fee, overage rate, discount on supplements, unit prices per service and package, the occupation percentage — proposed by whoever holds Manage commercial agreements and validated by the rules. Seen by the member, the owners and the holders of View commercial agreements; every read is logged.';

  @override
  String get featurePriceNegotiationsTitle => 'Price negotiations';

  @override
  String get featurePublicHolidaysDesc =>
      'An owner picks a year and sees the public holidays that would become closure days, then confirms. Re-running a year adds nothing, and a month that already carries an invoice is skipped and named — generating holidays never changes a bill that was already issued.';

  @override
  String get featurePublicHolidaysTitle => 'Public holidays';

  @override
  String get featurePublicListings => 'Public workspace listing';

  @override
  String get featurePublicListingsDesc =>
      'Publish only the workspace details and plans you choose, with visible owners and optional administrator contacts.';

  @override
  String get featurePushNotifications => 'Push notifications';

  @override
  String get featurePushNotificationsDesc =>
      'Deliver pending confirmations to members\' devices.';

  @override
  String get featureQrBadgesDesc =>
      'Printable QR badge cards for the kiosk, beside the NFC/RFID cards.';

  @override
  String get featureQrBadgesTitle => 'QR badges';

  @override
  String get featureRecordingPrivacyDesc =>
      'For filming or photographing this workspace. Every name, e-mail, telephone number, address and photograph is replaced by an invented person before it reaches the screen, while the plan, the bookings and the figures stay the real ones. A banner says so on every screen, and the identity forms refuse to save until it is off.';

  @override
  String get featureRecordingPrivacyTitle => 'Filming mode';

  @override
  String get featureRegionalFormatsDesc =>
      'Members choose how numbers, dates, the clock and the time zone are shown to them. Off: everyone reads in the app language\'s home region, 24-hour, workspace time.';

  @override
  String get featureRegionalFormatsTitle => 'Region & formats';

  @override
  String get featureReportDesignExchangeDesc =>
      'Every report design can be written out as one self-describing file and read back in. The file carries the design plus what its fields mean, the markup it accepts and the placeholders that exist, so a person or a tool can edit it outside the app and hand it back. A file for another report, or from a newer version, is refused with the reason. Off: designs are only editable in the designer.';

  @override
  String get featureReportDesignExchangeTitle =>
      'Export and import report designs';

  @override
  String get featureReportDesignerDesc =>
      'The report editor as a full-screen designer: elements edited in place in their real typography, drag to reorder, an insert palette, a searchable field picker, undo and redo, image size and alignment, a discard guard, presets and reset behind a confirmation, the template error spelled out, design and preview side by side on a wide screen. Off: the editor sheet.';

  @override
  String get featureReportDesignerTitle => 'Report designer';

  @override
  String get featureReportLayouts => 'Positioned report layouts';

  @override
  String get featureReportLayoutsDesc =>
      'Design a report by stating where each element sits, in mm, cm, px or %; the PDF prints exactly that. A document with a layout uses it, the others keep their bands.';

  @override
  String get featureReportTexts => 'Report texts';

  @override
  String get featureReportTextsDesc =>
      'The owner writes texts (a greeting, a note, a legal paragraph) per language and places them in any report as text.key — wording changes without touching the design.';

  @override
  String featureRequires(String feature) {
    return 'Requires $feature';
  }

  @override
  String get featureRichMessageRefsDesc =>
      'A message can point at an alert, at the validation trail behind one, and at an invoice, a payment or a refund — each one a link that opens what it names. Every reference picker filters as you type. Off: only reservations and spaces can be referenced.';

  @override
  String get featureRichMessageRefsTitle => 'References in messages';

  @override
  String get featureRoleAssignmentDesc =>
      'Shows a Roles section on each member\'s page to give or take back a role, the members holding each role, and lets every member see what they can do here.';

  @override
  String get featureRoleAssignmentTitle => 'Giving roles';

  @override
  String get featureRoleManagement => 'Role management';

  @override
  String get featureRoleManagementDesc =>
      'The central role→permission matrix: the owner decides which role holds which permission; everyone else reads their own. Off, the defaults simply apply.';

  @override
  String get featureScheduledExpensesDesc =>
      'Recurring expenses (internet, phone, electricity): any member schedules one with its rule (every X days/weeks/months/years, X times or until a date); the schedule is validated once, and every due date is presented to the member — the validated amount counts immediately, a different amount explains itself and passes the expense validation.';

  @override
  String get featureScheduledExpensesTitle => 'Scheduled expenses';

  @override
  String get featureSeatDayTimeline => 'Seat day timeline';

  @override
  String get featureSeatDayTimelineDesc =>
      'A seat booked for part of the day is drawn part-filled on the plan, and a seat several people share opens a timeline of the day: who has it, when, and which stretches are still free.';

  @override
  String get featureSeriesBooking => 'Series booking';

  @override
  String get featureSeriesBookingDesc =>
      'Repeat a reservation daily, weekly or on weekdays.';

  @override
  String get featureServices => 'Services';

  @override
  String get featureServicesDesc => 'Service catalog and consumption tracking.';

  @override
  String get featureSettlementFoldDesc =>
      'Invoices regrouped into one disappear from the lists as peers and nest under the regrouping invoice, which carries all their lines. On a regrouped invoice every operation is off; the one thing left is its PDF, stamped with the number it was regrouped in. Off: the regrouped invoices stay listed beside the regrouping one.';

  @override
  String get featureSettlementFoldTitle => 'Regrouped invoices fold';

  @override
  String get featureSingleRoomLevelNamesDesc =>
      'When a level holds only one room, the booking views name the level instead of the room — “2nd floor · Table 3”, not “Room 1 · Table 3”. Adding a second room brings both names back; the plan editor always shows the rooms.';

  @override
  String get featureSingleRoomLevelNamesTitle =>
      'Name a single-room level by the level';

  @override
  String get featureSiteDocuments => 'Sites on documents';

  @override
  String get featureSiteDocumentsDesc =>
      'Documents name the site they concern: the member\'s home site\'s address and registration as the seller, and the other sites the month stood at in the details. Off: the workspace address on every document.';

  @override
  String get featureSpaceInquiriesDesc =>
      'A signed-in person who finds the published page can write to the hosts: the owners, and the administrators who chose to be public contacts. The hosts are named before anyone writes, and only that person and the hosts read the conversation. Off removes the button and the Inquiries view, so nobody starts a new inquiry; open ones stay in the hosts\' inbox to answer and close.';

  @override
  String get featureSpaceInquiriesTitle => 'Write to the hosts';

  @override
  String get featureSpaceQrCodes => 'Space QR codes';

  @override
  String get featureSpaceQrCodesDesc =>
      'Printable QR cards per seat, desk, office and level — scan to reserve or check in.';

  @override
  String get featureSubscriptionInvoicesDesc =>
      'The membership fee is invoiced before the month it pays for, on a date you choose. Off: the fee stays on the whole-month invoice.';

  @override
  String get featureSubscriptionInvoicesTitle => 'Subscription invoices';

  @override
  String get featureSupplyExpensesDesc =>
      'An expense can be a supply for the space (coffee capsules, vacuum bags…): once validated it restocks or creates a consumable service with a unit price, and consumptions count the stock down.';

  @override
  String get featureSupplyExpensesTitle => 'Supplies from expenses';

  @override
  String get featureSurfaceCalendarHint =>
      'What is happening, by day and by month.';

  @override
  String get featureSurfaceDocumentsHint =>
      'The files the space keeps and shares.';

  @override
  String get featureSurfaceEverywhere => 'The whole app';

  @override
  String get featureSurfaceEverywhereHint =>
      'Changes how the app behaves, wherever you are in it.';

  @override
  String get featureSurfaceKioskHint =>
      'The tablet at the door, badges and scanning.';

  @override
  String get featureSurfaceMembersHint =>
      'Who is in the space, their profiles and their roles.';

  @override
  String get featureSurfaceMessagesHint =>
      'Conversations, alerts and what reaches a phone.';

  @override
  String get featureSurfaceMoneyHint =>
      'Statements, payments, invoices and what they are made of.';

  @override
  String get featureSurfaceReports => 'Documents you print';

  @override
  String get featureSurfaceReportsHint =>
      'Invoices, statements and letters, and how they look on paper.';

  @override
  String get featureSurfaceReserveHint =>
      'Booking a seat, the floor plan, check-in.';

  @override
  String get featureSurfaceSettingsHint => 'How the space itself is set up.';

  @override
  String get featureTaskRecorderDesc =>
      'Lets a person record the steps of a task on this workspace\'s screens, on their own device, review them and export a file without any value they typed. Nothing is uploaded. Off: nobody records here.';

  @override
  String get featureTaskRecorderTitle => 'Task recorder';

  @override
  String get featureTierCore => 'Core';

  @override
  String get featureTierCoreDesc =>
      'What every space needs. On from the first day.';

  @override
  String get featureTierPlatform => 'Platform';

  @override
  String get featureTierPlatformDesc =>
      'Asked for, never assumed. Switch on what this space actually runs.';

  @override
  String get featureUiAnimationsDesc =>
      'Smooth transitions and state animations across the app. Off means every change is instant; the device\'s reduced-motion setting always wins.';

  @override
  String get featureUiAnimationsTitle => 'Interface animations';

  @override
  String get featureUniqueMonogramsDesc =>
      'An avatar without a photo shows initials that belong to one member: first and family initial, a further letter when two members would clash, numbers only as a last resort. Off: the first letter alone, repeated across everyone who shares it.';

  @override
  String get featureUniqueMonogramsTitle => 'Distinct avatar initials';

  @override
  String get featureUsageInvoicesDesc =>
      'Once a month is over, what it actually cost beyond the subscription — overage, accessories, services — is invoiced separately. Off: those stay on the whole-month invoice.';

  @override
  String get featureUsageInvoicesTitle => 'End-of-month invoices';

  @override
  String get featureUsageRecordsDesc =>
      'Every counted booking leaves a record: the window booked, the time actually present, and what of it bills. A booking nobody checked into bills in full. A member who left early can ask for the unused time to stop billing, and somebody else decides it — never them. Off: no records and no correction.';

  @override
  String get featureUsageRecordsTitle => 'Usage records';

  @override
  String get featureUsageReport => 'Consumption report';

  @override
  String get featureUsageReportDesc =>
      'At month end a member receives what their participation paid for, what they actually consumed and what is left or exceeded — from the usage records, as a letter.';

  @override
  String get featureValidationChainDesc =>
      'A validation rule can ask for its validations one after another, each step requested once the previous passed, and can let the owner — never an admin — validate their own act. Off: every validation is asked at once and nobody validates their own event.';

  @override
  String get featureValidationChainTitle => 'Chained validations';

  @override
  String get featureValidationScopesDesc =>
      'Each validation rule names who validates: the admins, listed persons of any role, or every member — plus how many. Off: owner and admins as before.';

  @override
  String get featureValidationScopesTitle => 'Validators by role or person';

  @override
  String get featureVatCounterparty => 'VAT by counterparty';

  @override
  String get featureVatCounterpartyDesc =>
      'Who the buyer is for VAT, set on each member: domestic VAT, reverse charge, outside the EU, or exempt with a printed reason. Off: the automatic rule only.';

  @override
  String get featureVatDeclarationsDesc =>
      'Generate the periodic VAT return from issued invoices, map it to the official form and transmit or export it.';

  @override
  String get featureVatDeclarationsTitle => 'VAT declarations';

  @override
  String get featureVatGroups => 'VAT groups';

  @override
  String get featureVatGroupsDesc =>
      'Each VAT rate carries the fiscal group of what it taxes — standard, intermediate, reduced, super-reduced, zero, exempt, not subject, refundable deposit, excise-bearing — with the category and the exemption reason the group implies. Off: bare percentages.';

  @override
  String get featureVatManagementDesc =>
      'The VAT rate editor and the rate pickers on services, packs, accessories and the tariff. Off hides the configuration; stored rates keep applying.';

  @override
  String get featureVatManagementTitle => 'VAT management';

  @override
  String get featureVatRateHistory => 'VAT rate versions';

  @override
  String get featureVatRateHistoryDesc =>
      'A rate is a family of dated versions: a change by law adds the new value from its date, the old value stays on every supply before it, and nothing is re-pointed. Off: one value per rate.';

  @override
  String get featureVatReport => 'VAT report';

  @override
  String get featureVatReportDesc =>
      'Every taxable position of a month or period — document, customer, net, rate, VAT, gross, category — with subtotals per rate, as a letter and as a CSV for the accountant.';

  @override
  String get featureWhatsappIntegration => 'WhatsApp integration';

  @override
  String get featureWhatsappIntegrationDesc =>
      'Members share their WhatsApp number on their profile; one tap on a member opens a chat with it; the community group link in the directory. No server-side WhatsApp integration.';

  @override
  String get featureWorkingHours => 'Working hours';

  @override
  String get featureWorkingHoursDesc =>
      'Configure the working day and offer exact-hours booking; off keeps the 8:00–17:00 defaults.';

  @override
  String get featureWorkspaceBrandingDesc =>
      'The workspace chooses a brand colour the app derives its light and dark themes from, and the fill colours of its rooms. A colour that would make the app unreadable is refused with the reason; the product\'s own palette stays the default.';

  @override
  String get featureWorkspaceBrandingTitle => 'Workspace colours';

  @override
  String get featureWorkspaceLibraryDesc =>
      'Save this space\'s floor plan and how it works as a template, choose who may see it, invite people by e-mail, and start from what others offer.';

  @override
  String get featureWorkspaceLibraryTitle => 'Workspace library';

  @override
  String get featureWorkspaceStatus => 'Workspace status';

  @override
  String get featureWorkspaceStatusDesc =>
      'What the workspace invoiced, collected, reimbursed and shared out over a range of months, member by member — on screen for owners and admins, and as a printable report. Off: no status view.';

  @override
  String get featureWorkspaceVocabularyDesc =>
      'The workspace may rename a small, approved set of product words — a seat, the legend labels, the tabs — per language. Everything else keeps the product\'s own wording, and a workspace that renames nothing looks exactly as it did before.';

  @override
  String get featureWorkspaceVocabularyTitle => 'Workspace vocabulary';

  @override
  String get featuresFilterChanged => 'Changed';

  @override
  String get featuresNoMatch => 'No feature matches that.';

  @override
  String get featuresSearchLabel => 'Search features';

  @override
  String get featuresTitle => 'Features';

  @override
  String get featuresViewProcesses => 'Processes';

  @override
  String get featuresViewSwitches => 'Switches';

  @override
  String get fecAccountBank => 'Bank';

  @override
  String get fecAccountCustomers => 'Customers';

  @override
  String get fecAccountExpenses => 'Expenses';

  @override
  String get fecAccountRevenue => 'Revenue';

  @override
  String get fecAccountVat => 'Collected VAT';

  @override
  String get fecAccountsIntro =>
      'A FEC is made of accounting entries, so it needs account numbers. These are the French chart defaults — change them to your accountant\'s.';

  @override
  String get fecAccountsTitle => 'Accounts to book';

  @override
  String get fecMissingSiren =>
      'The FEC is named after your registration number — fill it in under Legal identity first.';

  @override
  String get federationActionExistingAccount =>
      'Sign in to my existing account';

  @override
  String get federationActionReviewServer => 'Review server';

  @override
  String get federationCancel => 'Cancel';

  @override
  String get federationClose => 'Close';

  @override
  String get federationContinue => 'Continue with Deskilo';

  @override
  String federationDetailAuthority(String host) {
    return 'Identity authority: $host';
  }

  @override
  String federationDetailServer(String host) {
    return 'Server: $host';
  }

  @override
  String get federationDetails => 'Technical details';

  @override
  String get federationFailureBrowser =>
      'The browser could not be opened. Check that a browser is available, then try again.';

  @override
  String get federationFailureExpired =>
      'This sign-in took too long and has expired. Start it again.';

  @override
  String get federationFailureIncompatible =>
      'This server does not accept this Deskilo sign-in. Check the server address, or ask its administrator.';

  @override
  String get federationFailureNetwork =>
      'The server could not be reached, so the sign-in was not completed. Check your connection, then try again.';

  @override
  String get federationFailureProviderMissing =>
      'Deskilo sign-in is not set up on this server. Ask its administrator to enable it.';

  @override
  String get federationFailureRefused =>
      'The sign-in was cancelled or refused in the browser. Nothing changed; you can try again.';

  @override
  String get federationFailureUnlinked =>
      'This Deskilo account matches an account here that is not linked to it yet. Sign in to that account, then link Deskilo under Linked accounts. Nothing is merged until the server confirms it.';

  @override
  String get federationFailureWrongAccount =>
      'Your browser signed in with a different Deskilo account. Switch accounts in the browser, then try again.';

  @override
  String federationPurpose(String server) {
    return 'Your browser confirms your Deskilo account, then brings you back to $server. Your memberships and history here stay as they are.';
  }

  @override
  String get federationRetry => 'Try again';

  @override
  String get federationStageCompleting => 'Completing sign-in…';

  @override
  String get federationStageOpening => 'Opening sign-in…';

  @override
  String get federationStageWaiting => 'Waiting for sign-in in your browser…';

  @override
  String get fieldProblemNotAChoice => 'Please pick from the list.';

  @override
  String get fieldProblemNotADate => 'A date, please.';

  @override
  String get fieldProblemNotANumber => 'A number, please.';

  @override
  String get fieldProblemNotAPhone => 'That is not a telephone number.';

  @override
  String get fieldProblemNotAUrl => 'That is not a web address.';

  @override
  String get fieldProblemNotAnEmail => 'That is not an e-mail address.';

  @override
  String get fieldProblemNotWhole => 'A whole number, please.';

  @override
  String get fieldProblemRequired => 'Please answer this.';

  @override
  String fieldProblemTooEarly(String date) {
    return 'Not before $date.';
  }

  @override
  String fieldProblemTooLarge(String max) {
    return 'At most $max.';
  }

  @override
  String fieldProblemTooLate(String date) {
    return 'Not after $date.';
  }

  @override
  String fieldProblemTooLong(int count) {
    return 'At most $count characters.';
  }

  @override
  String fieldProblemTooShort(int count) {
    return 'At least $count characters.';
  }

  @override
  String fieldProblemTooSmall(String min) {
    return 'At least $min.';
  }

  @override
  String get financesAllSpaces => 'All spaces';

  @override
  String get financesAutomatic => 'automatic';

  @override
  String get financesAwaitingValidation => 'Payment being validated';

  @override
  String get financesDevSection =>
      'Development spaces — test data, not counted above';

  @override
  String financesDueOn(String date) {
    return 'Due $date';
  }

  @override
  String get financesFullHistory => 'Full history, usage and other servers';

  @override
  String financesLinkAction(String space) {
    return 'Open for $space';
  }

  @override
  String get financesLinkBody =>
      'Your invoices, reminders and payments from every space are together in Me › Finances.';

  @override
  String get financesLinkTitle => 'Your documents live in Me';

  @override
  String get financesNoReminders => 'No reminder received.';

  @override
  String get financesNothingOwed => 'Nothing to pay — you are up to date.';

  @override
  String get financesNothingPaid => 'No settled invoice yet.';

  @override
  String get financesOutstanding => 'Outstanding';

  @override
  String financesOverdueCount(int count) {
    return '$count overdue';
  }

  @override
  String financesOverdueSince(String date) {
    return 'Overdue since $date';
  }

  @override
  String get financesPaid => 'Paid';

  @override
  String get financesPartlyPaid => 'Partly paid';

  @override
  String get financesPayments => 'Payments';

  @override
  String financesRemindedTimes(int count) {
    return 'Reminded ×$count';
  }

  @override
  String financesReminderLevel(int level) {
    return 'Reminder $level';
  }

  @override
  String get financesReminders => 'Reminders';

  @override
  String get financesStateClosed => 'Closed';

  @override
  String get financesStatePaid => 'Paid';

  @override
  String get financesStateRefunded => 'Refunded';

  @override
  String get financesTitle => 'Finances';

  @override
  String get financesToPay => 'To pay';

  @override
  String get gettingStartedActionChooseDay => 'Choose another day';

  @override
  String get gettingStartedActionChooseTime => 'Choose a time to book';

  @override
  String get gettingStartedActionFinishSetup => 'Finish setting up';

  @override
  String get gettingStartedActionHelp => 'Help for this workspace';

  @override
  String get gettingStartedActionMembership => 'View my membership';

  @override
  String gettingStartedAllowance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You may hold $count bookings at a time.',
      one: 'You may hold one booking at a time.',
    );
    return '$_temp0';
  }

  @override
  String get gettingStartedAvailabilityUnknown =>
      'Availability could not be loaded. The help explains how booking works here.';

  @override
  String gettingStartedBooked(String id, String state) {
    return 'Your booking $id is $state. Your membership shows what else is included.';
  }

  @override
  String get gettingStartedClosedToday =>
      'The workspace is closed on the selected day. Choose another day to see what is free.';

  @override
  String get gettingStartedEnvDev => 'Development workspace';

  @override
  String get gettingStartedEnvProd => 'Production workspace';

  @override
  String get gettingStartedMembershipUnknown =>
      'Your membership could not be loaded right now. The help explains how this workspace works.';

  @override
  String get gettingStartedNoSpaces =>
      'Nothing can be booked here yet. Your membership shows what your access includes.';

  @override
  String get gettingStartedNotNow => 'Not now';

  @override
  String get gettingStartedReadyToBook =>
      'The workspace is open on this day. Pick a time and a space on the plan — nothing is booked until you confirm.';

  @override
  String get gettingStartedReopen => 'Get started';

  @override
  String get gettingStartedSemantics => 'Get started: one suggested next step';

  @override
  String gettingStartedSetupIncomplete(String step) {
    return 'Before anyone can book here: $step.';
  }

  @override
  String get gettingStartedStandingAdmin => 'You are an administrator here.';

  @override
  String get gettingStartedStandingMember => 'You are a member here.';

  @override
  String get gettingStartedStandingOwner =>
      'You are an owner of this workspace.';

  @override
  String get gettingStartedStateCancelled => 'cancelled';

  @override
  String get gettingStartedStateCheckedIn => 'checked in';

  @override
  String get gettingStartedStateCompleted => 'completed';

  @override
  String get gettingStartedStateReleased => 'released';

  @override
  String get gettingStartedStateReserved => 'reserved';

  @override
  String gettingStartedTitle(String workspace) {
    return 'Get started in $workspace';
  }

  @override
  String get groupAnnounceOnly => 'Only admins can post';

  @override
  String get groupAnnounceOnlyHint => 'Everyone reads; only admins write.';

  @override
  String get groupCreate => 'Create group';

  @override
  String get groupDescription => 'Description';

  @override
  String get groupDescriptionAdd => 'Add a description';

  @override
  String get groupDescriptionTitle => 'Group description';

  @override
  String get groupMakeAdmin => 'Make admin';

  @override
  String get groupName => 'Group name';

  @override
  String get groupNeedsPeople => 'Add at least one person.';

  @override
  String get groupNew => 'New group';

  @override
  String get groupNewTitle => 'New group';

  @override
  String get groupPeople => 'People in the group';

  @override
  String get groupPickPeople => 'Add people';

  @override
  String get groupPostingClosed => 'Only admins can post in this group.';

  @override
  String get groupRemoveAdmin => 'Remove admin';

  @override
  String get groupRename => 'Rename group';

  @override
  String get groupRenameTitle => 'Group name';

  @override
  String get guideActionConfirmBooking =>
      'confirm the booking and wait for the answer';

  @override
  String get guideActionOpenReserve => 'open Reserve';

  @override
  String get guideActionSelectDate => 'choose the day';

  @override
  String get guideActionSelectPeriod => 'choose the period';

  @override
  String get guideActionSelectResource =>
      'choose a place on the plan or in the list';

  @override
  String get guideBookingRefusedRecovery =>
      'The booking was refused (the place is taken or a rule forbids it). Choose another place or period, then confirm again.';

  @override
  String get guideBuiltinBooking => 'Book a place';

  @override
  String get guideBuiltinBookingIntro =>
      'This guide shows how to book a place: choose the day and the period, pick a place, then confirm. Nothing is booked until you confirm.';

  @override
  String get guideHostBack => 'Back';

  @override
  String get guideHostBlocked =>
      'Resolve the message on screen first; the guide waits.';

  @override
  String get guideHostClose => 'Close';

  @override
  String get guideHostCommand => 'Confirm, then wait for the result.';

  @override
  String get guideHostCompleted => 'Guide completed.';

  @override
  String guideHostDoAction(String action) {
    return 'Next: $action.';
  }

  @override
  String get guideHostDone => 'Done';

  @override
  String get guideHostFillField =>
      'Fill in the highlighted field, then leave it.';

  @override
  String guideHostFillLabel(String label) {
    return 'Fill in “$label”, then leave the field.';
  }

  @override
  String get guideHostGoToPage => 'Go to page';

  @override
  String get guideHostInstruction => 'Read this, then mark it done.';

  @override
  String get guideHostManual => 'Do this step yourself, then mark it done.';

  @override
  String guideHostManualProtected(String category) {
    return 'This part happens on a protected screen ($category). Do it yourself, then mark it done.';
  }

  @override
  String get guideHostMinimize => 'Minimise the guide';

  @override
  String get guideHostNotOnScreen =>
      'This control is not on this screen. Go to the screen of the previous step, or check the guide.';

  @override
  String guideHostOpenLabel(String label) {
    return 'Open “$label”.';
  }

  @override
  String get guideHostOpenScreen => 'Open the next screen.';

  @override
  String get guideHostPausedFeature =>
      'Paused: the task recorder is turned off in this workspace.';

  @override
  String get guideHostPausedScope =>
      'Paused: the account or workspace changed. The guide continues only where it started.';

  @override
  String get guideHostRecovery =>
      'That was refused. Follow these steps, then try again.';

  @override
  String guideHostRestore(int current, int total) {
    return 'Show the guide (step $current of $total)';
  }

  @override
  String get guideHostResume => 'Resume';

  @override
  String get guideHostShowMe => 'Show me';

  @override
  String get guideHostSkip => 'Skip';

  @override
  String get guideHostStatusAcknowledged => 'Acknowledged';

  @override
  String get guideHostStatusDone => 'Done';

  @override
  String get guideHostStatusPending => 'To do';

  @override
  String get guideHostStatusSkipped => 'Skipped';

  @override
  String get guideHostStatusWaiting => 'Waiting';

  @override
  String guideHostStepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get guideHostSteps => 'All steps';

  @override
  String get guideHostStop => 'Stop the guide';

  @override
  String get guideHostStopped => 'Guide stopped. Nothing was undone.';

  @override
  String get guideHostTapControl => 'Tap the highlighted control.';

  @override
  String guideHostTapLabel(String label) {
    return 'Tap “$label”.';
  }

  @override
  String get guideHostTitle => 'Guided task';

  @override
  String get guideHostUncertain =>
      'The answer did not arrive. Check whether it happened before trying again.';

  @override
  String get guideHostWaiting => 'Waiting for the result…';

  @override
  String get guideStart => 'Start the guide';

  @override
  String get guideStartNotRunnable =>
      'This guide names steps this version of the app does not know; it can be read, not followed.';

  @override
  String get guideStartRefused =>
      'This guide cannot start here: sign in and turn the task recorder on in this workspace.';

  @override
  String handoffAmountOutOfRange(String number) {
    return '$number: a total too large to carry exactly';
  }

  @override
  String get handoffBlocked =>
      'This file cannot be handed over until the source is corrected.';

  @override
  String get handoffChanged =>
      'The invoices changed while you were reviewing. Export again to see the current books.';

  @override
  String handoffDuplicate(String number) {
    return '$number: appears twice in the source';
  }

  @override
  String handoffExcludedSettlements(String count) {
    return '$count settlement summary(ies) left out: their invoices are already listed';
  }

  @override
  String handoffIncluded(String count) {
    return '$count document(s) in the file';
  }

  @override
  String get handoffIssued => 'Issued';

  @override
  String handoffMissingCurrency(String number) {
    return '$number: no currency';
  }

  @override
  String handoffOrphanMatch(String key) {
    return 'A payment ($key) belongs to no document of this export';
  }

  @override
  String handoffOverpaid(String number) {
    return '$number: paid more than it charges';
  }

  @override
  String handoffPayments(String confirmed, String pending) {
    return 'Paid: $confirmed confirmed, $pending pending';
  }

  @override
  String handoffRowMismatch(String detail) {
    return 'The file rows do not match the documents ($detail)';
  }

  @override
  String get handoffSave => 'Save file and report';

  @override
  String get handoffTitle => 'Before you save';

  @override
  String handoffUnsupportedCurrency(String number) {
    return '$number: its currency has no reviewed number of decimals';
  }

  @override
  String get handoffVoided => 'Voided';

  @override
  String get helpContents => 'Contents';

  @override
  String get helpDotTooltip => 'Open the guide';

  @override
  String get helpGuidedTasks => 'Guided tasks';

  @override
  String get helpHintAvailability =>
      'Set the open weekdays and working hours, and add closure days nobody can book.';

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
  String get helpHintAvailabilityTopic => 'Availability';

  @override
  String get helpHintBadges =>
      'Issue a printable QR badge or register an NFC card; revoke lost badges any time.';

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
  String get helpHintBadgesTopic => 'NFC badges';

  @override
  String get helpHintCalendar =>
      'Pick a day or a range: everything dated that you may see, in one list, each row opening its source.';

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
  String get helpHintCalendarTip5 =>
      'The shield shows who can see each kind, and who actually looked at your finances.';

  @override
  String get helpHintCalendarTip5Topic => 'Privacy';

  @override
  String get helpHintCalendarTopic => 'Calendar';

  @override
  String get helpHintDismiss => 'Dismiss hint';

  @override
  String get helpHintEditor =>
      'Draw rooms and desks, stamp seats onto them — tap a seat twice to edit its properties.';

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
  String get helpHintEditorTopic => 'space editor';

  @override
  String get helpHintEvents =>
      'Everything that happened, in one feed. Decisions waiting for you sit on top; the chips filter the rest.';

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
  String get helpHintEventsTopic => 'confirmations';

  @override
  String get helpHintFeatures =>
      'Switch workspace functionality on or off — every member\'s app follows immediately.';

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
  String get helpHintFeaturesTopic => 'Features';

  @override
  String get helpHintLearnMore => 'Learn more';

  @override
  String get helpHintMembers =>
      'Invite members, set their plan percentage and role, and manage their badges.';

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
  String get helpHintMembersTipNegotiation =>
      'A member\'s own prices: open their sheet → Price negotiation, set the fee, overage or discount you agreed, and the rule\'s validators confirm it.';

  @override
  String get helpHintMembersTipNegotiationTopic => 'Price negotiations';

  @override
  String get helpHintMembersTopic => 'Members & plans';

  @override
  String get helpHintMessages =>
      'Every conversation in one list, newest first. Tap the pencil to write to someone or start a group.';

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
  String get helpHintMessagesTopic => 'Messages';

  @override
  String get helpHintMoney =>
      'Your monthly bill: browse months with the arrows; pay, export or share from here.';

  @override
  String get helpHintMoneyDocuments =>
      'Your paperwork: your conditions, the payments report, the month\'s statement as PDF, the document library.';

  @override
  String get helpHintMoneyDocumentsTip3 =>
      'My conditions is your standing financial agreement — plan, rate, extras — rendered as a document you can keep.';

  @override
  String get helpHintMoneyDocumentsTopic => 'The Documents face';

  @override
  String get helpHintMoneyInvoices =>
      'Your invoices: what is open and when it is due, every invoice issued to you with its status, one tap to the detail and to paying it.';

  @override
  String get helpHintMoneyInvoicesTip2 =>
      'Past the workspace\'s payment term an open invoice reads overdue here, and the reminder levels the owner configured arrive by themselves — in your feed and as a push.';

  @override
  String get helpHintMoneyInvoicesTip2Topic => 'Automatic payment reminders';

  @override
  String get helpHintMoneyInvoicesTopic => 'The Invoices face';

  @override
  String get helpHintMoneyPayments =>
      'Settle and ask: the balance, how to pay it or pay online, record a payment — and submit an expense, request half-days or add a consumption.';

  @override
  String get helpHintMoneyPaymentsTip2 =>
      'Record a payment with the date the money moved and the month it settles — the other side confirms it.';

  @override
  String get helpHintMoneyPaymentsTip3 =>
      'Pay online settles what is owed right away; the instructions card shows the manual way with the reference to quote.';

  @override
  String get helpHintMoneyPaymentsTip3Topic => 'online payments';

  @override
  String get helpHintMoneyPaymentsTipSupply =>
      'Bought capsules or vacuum bags for the space? Submit the expense as a supply: validated, it goes on the shelf as a consumable that others pay for, and you are reimbursed.';

  @override
  String get helpHintMoneyPaymentsTipSupplyTopic => 'Services and Accessories';

  @override
  String get helpHintMoneyPaymentsTopic => 'The Payments face';

  @override
  String get helpHintMoneyStatement =>
      'The month as it stands: your account, days used and left, subscription, services, packages, open positions, credits and the balance. Browse months with the arrows.';

  @override
  String get helpHintMoneyStatementTip2 =>
      'A booked morning counts as half a day; days outside the opening hours follow the workspace\'s outside-hours policy.';

  @override
  String get helpHintMoneyStatementTip2Topic => 'How booking behaves';

  @override
  String get helpHintMoneyStatementTip3 =>
      'Out of days? Request extra half-days, buy a package, or keep booking pay-as-you-go — whichever your plan allows.';

  @override
  String get helpHintMoneyStatementTipNegotiation =>
      'Negotiated a deal? The card shows your prices beside the tariff, since when, and who can see them — the owners and finance admins, every read on the record.';

  @override
  String get helpHintMoneyStatementTipNegotiationTopic => 'Price negotiations';

  @override
  String get helpHintMoneyStatementTopic => 'The Statement face';

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
  String get helpHintMoneyTopic => 'Money';

  @override
  String get helpHintNextTip => 'Next tip';

  @override
  String get helpHintPlan =>
      'The live floor plan: tap a free seat to book it, tap your own booking to check in.';

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
  String get helpHintPlanTopic => 'floor plan';

  @override
  String get helpHintPrevTip => 'Previous tip';

  @override
  String get helpHintPrivacy =>
      'See who can read your data and who did, export everything as one file, or leave with your personal data erased.';

  @override
  String get helpHintPrivacyTip2 =>
      'Messages are readable only by the people in the conversation, whatever their role; money only by you and the finance permission.';

  @override
  String get helpHintPrivacyTip3 =>
      'Every read of your finances by someone else is logged by the server — the log cannot be skipped or edited.';

  @override
  String get helpHintPrivacyTopic => 'Privacy';

  @override
  String get helpHintReserve =>
      'Pick a day and time window, then tap a free seat to book it.';

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
  String get helpHintReserveTopic => 'Reserve hub';

  @override
  String get helpHintRestoreTitle => 'Show help hints again';

  @override
  String get helpHintRestored => 'Help hints will be shown again.';

  @override
  String get helpHintValidation =>
      'Decide which actions need confirmation, who confirms, and how many approvals it takes.';

  @override
  String get helpHintValidationTip2 =>
      'One card per event type, each inheriting from the default rule until you edit it — payments, expenses, role changes and more.';

  @override
  String get helpHintValidationTip3 =>
      'Nobody ever validates their own event, and unanswered requests expire after 7 days — nothing is granted silently.';

  @override
  String get helpHintValidationTipScopes =>
      'Who validates is the rule\'s scope: the admins, listed persons of any role, or every member — and how many. The owner always may; nobody validates their own event.';

  @override
  String get helpHintValidationTipScopesTopic => 'Role management';

  @override
  String get helpHintValidationTopic => 'confirmations';

  @override
  String get helpHintWorkspace =>
      'Country, currency, language and billing details — documents and taxes follow these settings.';

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
  String get helpHintWorkspaceTopic => 'Workspace settings';

  @override
  String get helpTitle => 'Help';

  @override
  String get helpTopicAccounting => 'Accounting exports';

  @override
  String get helpTopicBilling => 'Billing';

  @override
  String get helpTopicBookingLimits => 'Booking limits';

  @override
  String get helpTopicBookingPolicies => 'Booking policies';

  @override
  String get helpTopicDeployment => 'Deploying';

  @override
  String get helpTopicDocumentLibrary => 'document library';

  @override
  String get helpTopicEinvoice => 'e-invoice';

  @override
  String get helpTopicEnvironments => 'Environments';

  @override
  String get helpTopicInstances => 'Instances';

  @override
  String get helpTopicKiosk => 'Kiosk mode';

  @override
  String get helpTopicLegalIdentity => 'Legal identity';

  @override
  String get helpTopicReadiness => 'readiness gate';

  @override
  String get helpTopicReportEditor => 'report editor';

  @override
  String get helpTopicReportLayout => 'Positioned layouts';

  @override
  String get helpTopicScheduledExpenses => 'Scheduled expenses';

  @override
  String get helpTopicServer => 'your own server';

  @override
  String get helpTopicSettings => 'Settings & profile';

  @override
  String get helpTopicTrace => 'The trace';

  @override
  String get helpTopicVat => 'VAT';

  @override
  String get helpTopicWindowEnvelope => 'The window-envelope contract';

  @override
  String get helpTopicWorkingHours => 'Working hours';

  @override
  String get helpTopicWorkspaceId => 'Workspace ID';

  @override
  String get holidayAllSaints => 'All Saints\' Day';

  @override
  String get holidayArmistice => 'Armistice 1918';

  @override
  String get holidayAscension => 'Ascension';

  @override
  String get holidayAssumption => 'Assumption';

  @override
  String get holidayBoxingDay => 'Boxing Day';

  @override
  String get holidayChristmas => 'Christmas Day';

  @override
  String get holidayEasterMonday => 'Easter Monday';

  @override
  String get holidayGermanUnity => 'German Unity Day';

  @override
  String get holidayGoodFriday => 'Good Friday';

  @override
  String get holidayImportAction => 'Import public holidays (open data)';

  @override
  String holidayImportConfirm(int count) {
    return 'Import $count closure days';
  }

  @override
  String get holidayImportFailed =>
      'The holidays could not be checked or imported. Nothing was changed.';

  @override
  String get holidayImportNationwide => 'Nationwide holidays only';

  @override
  String get holidayImportRegion => 'Region';

  @override
  String get holidayImportRetry => 'Try again';

  @override
  String holidayImportSource(String source) {
    return 'Source: $source';
  }

  @override
  String get holidayImportUnavailable =>
      'The holiday source cannot be reached right now. Try again later, or use “Add public holidays”.';

  @override
  String get holidayLabourDay => 'Labour Day';

  @override
  String get holidayNationalDay => 'Bastille Day';

  @override
  String get holidayNewYear => 'New Year\'s Day';

  @override
  String get holidayVictory1945 => 'Victory 1945';

  @override
  String get holidayWhitMonday => 'Whit Monday';

  @override
  String get identityConnectBrowser => 'The browser could not be opened.';

  @override
  String identityConnectConfirmApply(String name) {
    return 'Send your membership request to $name?';
  }

  @override
  String get identityConnectConfirmApplyBody =>
      'You are connected now. The space reviews your request; nothing else is shared.';

  @override
  String get identityConnectContinue => 'Continue with Deskilo';

  @override
  String get identityConnectCurrentServer =>
      'This is the server you are already signed in to.';

  @override
  String get identityConnectDifferentAuthority =>
      'This server accepts a different identity provider.';

  @override
  String identityConnectDone(String host) {
    return 'Connected to $host.';
  }

  @override
  String get identityConnectExistingAccount =>
      'Use an account I already have on this server';

  @override
  String get identityConnectExpired =>
      'The sign-in took too long. Start again.';

  @override
  String identityConnectExplain(String host) {
    return '$host will know it is you, through your Deskilo identity. Connecting does not make you a member, give you a role or connect an assistant: the space still decides any request.';
  }

  @override
  String get identityConnectNetwork => 'The server did not answer. Try again.';

  @override
  String get identityConnectNoDeskiloSignIn =>
      'This server does not offer sign-in with Deskilo.';

  @override
  String get identityConnectNoSharedIdentity =>
      'Your account here has no Deskilo identity another server could accept.';

  @override
  String identityConnectNotSaved(String host) {
    return '$host accepted you, but this device could not keep the connection. Nothing was sent. Try again.';
  }

  @override
  String get identityConnectRefused =>
      'The connection was not completed. Nothing was sent.';

  @override
  String get identityConnectRetry => 'Try again';

  @override
  String get identityConnectSend => 'Send request';

  @override
  String get identityConnectServerUnsupported =>
      'This server cannot be connected from this version of the app.';

  @override
  String identityConnectTitle(String host) {
    return 'Connect to $host';
  }

  @override
  String get identityConnectUnavailable => 'This server did not answer.';

  @override
  String get identityConnectUnlinked =>
      'An account on that server already uses this identity or e-mail without being linked to it. Use that account instead.';

  @override
  String get identityConnectWaiting =>
      'Finish signing in in your browser, then come back here.';

  @override
  String get identityConnectWrongAccount =>
      'The browser signed in as someone else. Nothing was connected.';

  @override
  String identityConsentAsks(String host) {
    return 'Use your Deskilo identity to sign in to $host.';
  }

  @override
  String get identityConsentCompleting => 'Saving your choice…';

  @override
  String get identityConsentPurpose =>
      'Workspace and assistant access are approved separately.';

  @override
  String get identityConsentReturnFailed => 'Could not open the destination.';

  @override
  String get identityConsentReturning => 'Returning to sign-in…';

  @override
  String get identityConsentTitle => 'Continue with Deskilo';

  @override
  String get identityConsentUnavailable =>
      'This sign-in request is unavailable. Return to the destination and start again.';

  @override
  String get inboxAlertsTab => 'Alerts';

  @override
  String get inboxChatsTab => 'Chats';

  @override
  String get inboxFilterAll => 'All';

  @override
  String get inboxFilterArchived => 'Archived';

  @override
  String get inboxFilterUnread => 'Unread';

  @override
  String get inboxMessengerDoor => 'Open my messenger';

  @override
  String get inboxNoArchived => 'No archived conversations.';

  @override
  String get inboxNoUnread => 'Nothing unread — you are up to date.';

  @override
  String get inboxRetry => 'Try again';

  @override
  String get instanceAccessTitle => 'Assistant access';

  @override
  String instanceAccessUntil(String date) {
    return 'Until $date';
  }

  @override
  String get instanceAccountIntro =>
      'Create a free account at supabase.com, then make a personal access token (Account → Access Tokens) and paste it here. The wizard uses it to create and set up the project; it is never stored.';

  @override
  String get instanceAdminsHelp =>
      'They decide who may use assistants. Only people who confirmed their identity for assistants can be chosen.';

  @override
  String get instanceAdminsTitle => 'Database administrators';

  @override
  String get instanceApplySignIn => 'Apply the sign-in settings';

  @override
  String get instanceApprove => 'Approve';

  @override
  String instanceAttentionForeign(String tables) {
    return 'Its public schema holds tables DesKilo does not create ($tables). Installing there is refused; use an empty project.';
  }

  @override
  String get instanceAttentionNotHealthy =>
      'Supabase does not report the project as healthy. Wait until it is, or restore it in the dashboard.';

  @override
  String get instanceAttentionOtherTooling =>
      'Its migrations were recorded by other tooling, so where DesKilo would resume cannot be read. Use an empty project.';

  @override
  String instanceAttentionPostgres(int found, int supported) {
    return 'It runs Postgres $found; DesKilo is built for Postgres $supported.';
  }

  @override
  String get instanceAttentionUnrecorded =>
      'DesKilo tables are there but no migration was recorded. Record what it has with `dart run tool/instance.dart record` first.';

  @override
  String get instanceBlock => 'Block';

  @override
  String get instanceBlockerNoAdmin => 'a database administrator';

  @override
  String get instanceBlockers => 'Still missing:';

  @override
  String get instanceCheckToken => 'Check the token';

  @override
  String get instanceChooseAnother => 'Choose another project';

  @override
  String get instanceClaimBody =>
      'You created this instance and no owner has been set. Taking ownership makes you the person who answers for it.';

  @override
  String get instanceClaimButton => 'Take ownership';

  @override
  String get instanceClaimDone => 'You are now the instance owner.';

  @override
  String get instanceClaimFailed => 'Ownership could not be taken.';

  @override
  String get instanceClaimTitle => 'Take ownership';

  @override
  String get instanceClientApproved => 'Approved';

  @override
  String get instanceClientBlocked => 'Blocked';

  @override
  String get instanceClientWaiting => 'Waiting for approval';

  @override
  String get instanceClientsHelp =>
      'An assistant registers itself the first time someone connects it; it works only once approved here.';

  @override
  String get instanceClientsTitle => 'Assistant clients';

  @override
  String get instanceConfirmSecondFactor => 'Confirm with my authenticator';

  @override
  String get instanceCreateButton => 'Create a new instance';

  @override
  String get instanceCreateProject => 'Create the project';

  @override
  String get instanceDatabasePassword =>
      'Database password, chosen for you — copy it somewhere safe; the app never needs it again.';

  @override
  String get instanceDelegateAdd => 'Delegate the role';

  @override
  String get instanceDelegateAlreadyOwner =>
      'The owner does not need a delegation.';

  @override
  String get instanceDelegateFieldLabel => 'E-mail address of an account';

  @override
  String get instanceDelegateNoAccount =>
      'No account uses this e-mail address.';

  @override
  String get instanceDelegateUnavailable => 'This server cannot delegate yet.';

  @override
  String get instanceDelegateUnchanged => 'This person already is a delegate.';

  @override
  String get instanceDelegateUnconfirmed =>
      'This account has not confirmed its e-mail address yet.';

  @override
  String get instanceDelegateWithdraw => 'Withdraw the delegation';

  @override
  String get instanceDelegateWithdrawBody =>
      'They lose access to the installation-wide setup immediately.';

  @override
  String get instanceDelegateWithdrawConfirm => 'Withdraw';

  @override
  String get instanceDelegateWithdrawTitle => 'Withdraw this delegation?';

  @override
  String get instanceDelegated => 'Delegated.';

  @override
  String get instanceDelegatesHelp =>
      'A delegate can run the installation-wide setup for assistants. Delegates cannot delegate further and see no other workspace.';

  @override
  String get instanceDelegatesNone => 'No delegates.';

  @override
  String get instanceDelegatesTitle => 'Delegates';

  @override
  String get instanceDelegationWithdrawn => 'Delegation withdrawn.';

  @override
  String instanceDeployFunctions(int count) {
    return 'Deploy the functions: payments, e-invoices, push, badges ($count).';
  }

  @override
  String get instanceDoctorAttention => 'Attention required';

  @override
  String get instanceDoctorIntro =>
      'Before this device uses it, the security check must pass: an alarm keeps the button off until it is fixed.';

  @override
  String instanceDoctorPassed(int count) {
    return '$count checks passed';
  }

  @override
  String get instanceDoctorProtected => 'Protected';

  @override
  String get instanceDoctorRun => 'Run the security check';

  @override
  String get instanceDoctorRunAgain => 'Check again';

  @override
  String get instanceDoneIntro =>
      'The instance is ready. Use it on this device, then share the server QR from the Server screen so members join the same one.';

  @override
  String get instanceEndpointTitle => 'Assistant endpoint';

  @override
  String get instanceFamilyChatgpt => 'ChatGPT';

  @override
  String get instanceFamilyClaude => 'Claude';

  @override
  String get instanceFamilyLoopback => 'Desktop or command-line assistant';

  @override
  String get instanceGrant => 'Approve access';

  @override
  String get instanceGrantDays => 'Choose between 1 and 30 days.';

  @override
  String instanceGrantDaysLabel(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'For $_temp0';
  }

  @override
  String get instanceGrantHelp =>
      'While no other database administrator exists, you approve access yourself — yours included — for up to 30 days, with a reason. Each approval is recorded.';

  @override
  String get instanceGrantNeedsGoogle =>
      'Approving access needs this session to be signed in with Google.';

  @override
  String get instanceGrantNoIdentity =>
      'That person has not confirmed their identity yet.';

  @override
  String get instanceGrantOtherAdmin =>
      'A database administrator decides access here; ask them.';

  @override
  String get instanceGrantReason => 'Reason';

  @override
  String get instanceGrantReasonNeeded =>
      'Write why this access is approved (up to 500 characters).';

  @override
  String instanceGrantTitle(String name) {
    return 'Approve assistant access for $name';
  }

  @override
  String instanceInstallSchema(int count) {
    return 'Install the schema: every migration of the app, in order ($count).';
  }

  @override
  String get instanceIntro =>
      'Switches for every workspace of this installation. Only the instance operator sees this page; every change needs your second factor and is recorded.';

  @override
  String get instanceLoopbackHelp =>
      'Claude Code, Cursor, VS Code and other assistants that run on a person\'s own computer. Each person still approves their own connection.';

  @override
  String get instanceLoopbackTitle =>
      'Allow desktop and command-line assistants';

  @override
  String get instanceMakeAdmin => 'Make administrator';

  @override
  String get instanceNoCandidates =>
      'Nobody else has confirmed their identity yet.';

  @override
  String get instanceNotOperator =>
      'Only the instance operator manages the installation\'s assistants.';

  @override
  String instanceNoticeClientWaiting(String name) {
    return '$name is waiting for your approval.';
  }

  @override
  String instanceNoticeOperatorGrant(String name) {
    return 'The operator approved assistant access for $name.';
  }

  @override
  String instanceNoticeSelfGrant(String name) {
    return '$name approved their own assistant access.';
  }

  @override
  String get instanceNoticesMarkRead => 'Mark as read';

  @override
  String get instanceOperatorApproved => 'Approved by the operator';

  @override
  String get instanceOrganisationLabel => 'Organisation';

  @override
  String get instanceOwnerClaimIntro =>
      'Who owns this instance? Enter the e-mail you will sign up with on it. After you confirm that address, claim the ownership from Settings → Instance owner.';

  @override
  String get instanceOwnerClaimLabel => 'Owner e-mail';

  @override
  String get instanceOwnerCopied => 'E-mail address copied.';

  @override
  String get instanceOwnerCopyEmail => 'Copy e-mail address';

  @override
  String get instanceOwnerHelp =>
      'This installation is shared by all its workspaces. The instance owner answers for it: contact them about anything that concerns the whole installation, such as assistants.';

  @override
  String get instanceOwnerNone => 'No instance owner is set yet.';

  @override
  String get instanceOwnerTitle => 'Instance owner';

  @override
  String get instanceProbeCheck => 'Check the server';

  @override
  String get instanceProbeDeployed =>
      'The assistant endpoint answers as it should.';

  @override
  String get instanceProbeMismatch =>
      'The endpoint answers with another address than the one assistants are given.';

  @override
  String get instanceProbeMissing => 'The server has not been checked yet.';

  @override
  String get instanceProbeNotDeployed =>
      'The assistant endpoint is not deployed on this server yet.';

  @override
  String get instanceProbePending => 'Checking the server…';

  @override
  String get instanceProbeStale =>
      'The last check is more than 15 minutes old. Check again before turning assistants on.';

  @override
  String get instanceProbeUnavailable =>
      'The server could not be reached. Try again in a moment.';

  @override
  String instanceProgress(int done, int total, String current) {
    return '$done / $total · $current';
  }

  @override
  String get instanceProjectName => 'Project name';

  @override
  String instanceProjectReady(String ref) {
    return 'Project ready: $ref';
  }

  @override
  String instanceProjectStatus(String status) {
    return 'Project status: $status';
  }

  @override
  String get instanceReadyAttention =>
      'This project needs attention — nothing was installed.';

  @override
  String instanceReadyCurrent(int version) {
    return 'DesKilo version $version is installed and current: the schema needs nothing.';
  }

  @override
  String get instanceReadyInstall =>
      'The project is empty: everything will be installed.';

  @override
  String instanceReadyResume(int pending) {
    return 'A DesKilo install stopped part-way: $pending migrations remain and only those will run.';
  }

  @override
  String instanceReadyUpgrade(int version, int pending) {
    return 'DesKilo version $version is installed: only the $pending missing migrations will run.';
  }

  @override
  String get instanceRegion => 'Region (the nearest to the space)';

  @override
  String get instanceRemoveAdmin => 'Remove';

  @override
  String get instanceRetry => 'Retry from where it stopped';

  @override
  String get instanceRevokeToken =>
      'You can revoke the access token now: DesKilo kept no copy.';

  @override
  String get instanceRuntimeOff => 'Off';

  @override
  String get instanceRuntimeOn => 'On';

  @override
  String get instanceRuntimeTitle => 'Assistants on this installation';

  @override
  String get instanceSecondFactorNeeded =>
      'Changes here need your second factor on this session.';

  @override
  String get instanceSelfApproved => 'Self-approved by operator';

  @override
  String get instanceSignInExplain =>
      'Sign-in settings: e-mail confirmation on (a sign-up must click the link in its mail), and the app\'s links allowed for password resets and magic links.';

  @override
  String get instanceStepAccount => 'Account';

  @override
  String get instanceStepDone => 'Done';

  @override
  String instanceStepFailed(String item, String message) {
    return 'Stopped at $item: $message';
  }

  @override
  String get instanceStepFunctions => 'Functions';

  @override
  String get instanceStepProject => 'Project';

  @override
  String get instanceStepSchema => 'Schema';

  @override
  String get instanceStepSignIn => 'Sign-in';

  @override
  String get instanceTitle => 'Installation: assistants';

  @override
  String get instanceTokenLabel => 'Personal access token';

  @override
  String get instanceTokenReach =>
      'A personal access token reaches your whole Supabase account for as long as it lives. The wizard holds it in memory only and tells you when you can revoke it.';

  @override
  String get instanceTokenRefused =>
      'Supabase refused the token. Create one at Account → Access Tokens and paste it whole.';

  @override
  String get instanceTurnOff => 'Turn off';

  @override
  String get instanceTurnOn => 'Turn on for every workspace';

  @override
  String get instanceTurnOnConfirm =>
      'Assistants become usable in every workspace that offers them. You can turn them off again at any time.';

  @override
  String get instanceTurnOnNeedsProbe =>
      'The assistant endpoint is not confirmed. Check the server first.';

  @override
  String get instanceUseExisting => 'Or use an existing project:';

  @override
  String get instanceUseHere => 'Use this instance on this device';

  @override
  String get instanceWizardTitle => 'Create a new instance';

  @override
  String get instanceYou => 'you';

  @override
  String get instanceYouAreDelegate =>
      'You are a delegate of the instance owner.';

  @override
  String get instanceYouAreOwner => 'You are the instance owner.';

  @override
  String invitationAlreadyMember(String workspace) {
    return 'You are already a member of $workspace.';
  }

  @override
  String get invitationApprovalRequired =>
      'An administrator approves new members before the workspace opens.';

  @override
  String get invitationApprovalUnknown =>
      'Whether an administrator must approve is not known.';

  @override
  String get invitationBadServer =>
      'The server in this invitation is not valid. Ask for a new invitation.';

  @override
  String get invitationChangeAccount => 'Change account';

  @override
  String get invitationCheckAnother => 'Use another invitation';

  @override
  String get invitationCheckFailed =>
      'The invitation could not be checked — status not updated. Nothing was changed; try again.';

  @override
  String get invitationContinue => 'Continue to this workspace';

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
  String get invitationEnvironmentProduction => 'Production workspace';

  @override
  String get invitationEnvironmentTest => 'Test workspace';

  @override
  String get invitationExpired =>
      'This invitation has expired. Ask the person who sent it for a new one.';

  @override
  String invitationInvalid(String host) {
    return 'No workspace on $host knows this invitation. Check it, or ask the organizer for their server link.';
  }

  @override
  String get invitationJoinButton => 'Join workspace';

  @override
  String get invitationJoinUnconfirmed =>
      'The result could not be confirmed. Join again to check — the invitation is not used twice.';

  @override
  String invitationJoiningAs(String account) {
    return 'Joining as $account';
  }

  @override
  String get invitationNewerVersion =>
      'This invitation was made by a newer version of DesKilo. Update the app, then open it again.';

  @override
  String invitationOtherServer(String host) {
    return 'This invitation is for another server: $host.';
  }

  @override
  String get invitationPasteButton => 'Paste';

  @override
  String invitationPaused(String workspace) {
    return 'Your membership in $workspace is paused. Only an administrator there can resume it.';
  }

  @override
  String get invitationReviewButton => 'Review invitation';

  @override
  String get invitationReviewTitle => 'Check before you join';

  @override
  String get invitationRevoked =>
      'This workspace code was replaced. Ask the person who sent it for the current one.';

  @override
  String get invitationRoleAdmin => 'Offered role: administrator';

  @override
  String get invitationRoleMember => 'Offered role: member';

  @override
  String get invitationRoleUnknown => 'Offered role: not known yet';

  @override
  String invitationServerLabel(String label) {
    return 'Named “$label” by whoever shared it';
  }

  @override
  String invitationServerRow(String host) {
    return 'Server: $host';
  }

  @override
  String get invitationTemplateHelp =>
      'Sent when you invite someone via WhatsApp, SMS, or share. Leave empty to use the built-in message in the chosen language. Available tags:';

  @override
  String get invitationTemplateHint =>
      'Custom invitation message using the tags above…';

  @override
  String get invitationTemplateLanguage => 'Message language';

  @override
  String get invitationTemplateTitle => 'Invitation message';

  @override
  String invitationThisDevice(String host) {
    return 'This device uses $host. An invitation is only checked on its own server.';
  }

  @override
  String get invitationUnknownAnswer =>
      'The server gave an answer this version of the app cannot read. Nothing was changed.';

  @override
  String get invitationUseServer => 'Use this server';

  @override
  String get invitationWrongAccount =>
      'This invitation was already used by another account. If it was meant for you, sign in with that account.';

  @override
  String get inviteAdminExplainer =>
      'This code is single-use: it admits ONE person as an admin, then expires. Give it only to the person it is meant for.';

  @override
  String get inviteAdminNewCode => 'New administrator code';

  @override
  String get inviteAlsoProdSubtitle =>
      'They join the test space either way. The role still has to allow production access.';

  @override
  String get inviteAlsoProdTitle => 'Also give access to production';

  @override
  String get inviteCreateFailed =>
      'Could not create the invitation. Check your connection and try again.';

  @override
  String get inviteFirstNameLabel => 'First name (optional)';

  @override
  String get inviteLanguageLabel => 'Message language';

  @override
  String get inviteLastNameLabel => 'Last name (optional)';

  @override
  String get inviteOwnerNote =>
      'There is no owner invite — only an owner can grant ownership, in Members & plans.';

  @override
  String get invitePhoneLabel => 'Phone (optional, with country code)';

  @override
  String get inviteRoleAdmin => 'Administrator invite';

  @override
  String get inviteRoleMember => 'Member invite';

  @override
  String get inviteRolesHint =>
      'Given when they join, once their membership is active.';

  @override
  String get inviteRolesTitle => 'Roles on arrival';

  @override
  String get inviteSectionTitle => 'Invite someone';

  @override
  String get inviteSendFailed =>
      'Could not open the app for sending. The message was copied instead.';

  @override
  String get inviteViaShare => 'Share…';

  @override
  String get inviteViaSms => 'SMS';

  @override
  String get inviteViaWhatsapp => 'WhatsApp';

  @override
  String get invoiceAccountingExport => 'Accounting export';

  @override
  String get invoiceAccountingExportEmpty =>
      'Nothing to export for this period.';

  @override
  String get invoiceAllCaughtUp => 'All caught up — nothing to invoice.';

  @override
  String get invoiceAlreadyInvoiced =>
      'This month is already invoiced for this member.';

  @override
  String invoiceAnnexSummary(int movements, int checkIns) {
    return 'Annex: $movements movements, $checkIns check-ins';
  }

  @override
  String get invoiceBalance => 'Balance due';

  @override
  String get invoiceBuyerReference => 'Service code';

  @override
  String get invoiceBuyerReferenceHint =>
      'Public-sector buyer (Chorus Pro): the code service exécutant.';

  @override
  String invoiceCountShown(int count) {
    return '$count invoices';
  }

  @override
  String get invoiceCreate => 'New invoice';

  @override
  String get invoiceDetailedToggle =>
      'Include the detailed annex (check-ins, services, payments)';

  @override
  String get invoiceDownload => 'Download PDF';

  @override
  String get invoiceEInvoiceAction => 'E-invoice (XML)';

  @override
  String get invoiceEInvoiceBlockedTitle =>
      'A validator would reject this file:';

  @override
  String invoiceEInvoiceBusinessRoute(String channel, String format) {
    return 'Business customers: send it through $channel as $format.';
  }

  @override
  String get invoiceEInvoiceDownload => 'Download e-invoice (XML)';

  @override
  String get invoiceEInvoiceExplain =>
      'The machine-readable EN 16931 invoice — the file tax administrations and business customers ask for.';

  @override
  String get invoiceEInvoiceFixIdentity => 'Complete the legal identity';

  @override
  String invoiceEInvoiceFormatMismatch(String channel, String format) {
    return '$channel only accepts $format: this EN 16931 file serves Peppol, public buyers and foreign customers — your platform or accountant converts the rest.';
  }

  @override
  String get invoiceEInvoiceIncompleteTitle =>
      'Valid, but the strict national profiles also want:';

  @override
  String invoiceEInvoicePublicRoute(String channel) {
    return 'Public-sector customers: $channel.';
  }

  @override
  String get invoiceEInvoiceReady => 'Ready — this file satisfies EN 16931.';

  @override
  String get invoiceEInvoiceShare => 'Share e-invoice (XML)';

  @override
  String get invoiceEInvoiceStaleIdentity =>
      'Your legal identity is complete now, but this invoice was signed before it and keeps what it was issued with. Mark it erroneous and issue a replacement to carry the new identity.';

  @override
  String get invoiceEInvoiceTransportAccredited =>
      'An accredited platform carries the invoice and reports it to the tax administration for you.';

  @override
  String get invoiceEInvoiceTransportBilateral =>
      'No channel is imposed: e-mail, a portal or Peppol — whatever you agree with the customer.';

  @override
  String get invoiceEInvoiceTransportClearance =>
      'The national platform receives the invoice first and hands it on — sending it straight to the customer is not an option.';

  @override
  String get invoiceEInvoiceTransportPeppol =>
      'An access point delivers it to the customer — no government platform in between.';

  @override
  String get invoiceEssentialsRefused =>
      'The invoice was not issued: required details are missing.';

  @override
  String get invoiceExportAccountantCsv => 'Accounting CSV';

  @override
  String get invoiceExportAuditTrail => 'Audit trail';

  @override
  String get invoiceExportBundle => 'Year archive (zip)';

  @override
  String get invoiceExportChoose => 'Export for accounting';

  @override
  String get invoiceExportDatev => 'DATEV (Buchungsstapel)';

  @override
  String get invoiceExportFec => 'FEC (France, required in an audit)';

  @override
  String get invoiceExportSafT => 'SAF-T (XML, international)';

  @override
  String get invoiceExportSafTPt => 'SAF-T (Portugal)';

  @override
  String get invoiceExportSage => 'Sage 50 (audit trail)';

  @override
  String get invoiceFacturXDownload => 'Download Factur-X (PDF)';

  @override
  String get invoiceFacturXExplain =>
      'One file: the invoice a human reads, with the machine-readable XML inside it. This is what most platforms expect.';

  @override
  String get invoiceFacturXShare => 'Share Factur-X (PDF)';

  @override
  String get invoiceFilterAllMembers => 'All members';

  @override
  String get invoiceFilterAllMonths => 'All months';

  @override
  String get invoiceFilterClear => 'Clear filters';

  @override
  String get invoiceFilterMonthLabel => 'Month';

  @override
  String get invoiceFilterNoMatch => 'No invoice matches these filters.';

  @override
  String get invoiceGapBuyerVatIdFormat =>
      'The customer\'s VAT number does not have its country\'s shape — check it.';

  @override
  String get invoiceGapCreditNoteWithPayments =>
      'This credit note also nets payments, which an EN 16931 credit note cannot state. Issue the credit on its own document.';

  @override
  String get invoiceGapMissingBuyerCountry =>
      'The customer\'s country is missing.';

  @override
  String get invoiceGapMissingBuyerVatId =>
      'The customer\'s VAT number is missing — a reverse-charged invoice must name it.';

  @override
  String get invoiceGapMissingExemptionReason =>
      'The reason for not charging VAT is missing.';

  @override
  String get invoiceGapMissingLegalId =>
      'The company registration number is missing (SIREN, HRB, CIF…) — nothing identifies you on the invoice.';

  @override
  String get invoiceGapMissingSellerCity => 'the city of the workspace address';

  @override
  String get invoiceGapMissingSellerCountry =>
      'The workspace country is missing.';

  @override
  String get invoiceGapMissingSellerPostalCode =>
      'the post code of the workspace address';

  @override
  String get invoiceGapMissingVatId =>
      'The VAT number is missing — an exempt seller must state one.';

  @override
  String get invoiceGapNoChargeLines =>
      'This invoice has no charge line — its month was fully covered by payments, so there is no invoice to send.';

  @override
  String get invoiceGapPublicSectorRefs =>
      'Bound for a public-sector platform with no engagement number and no service code — Chorus Pro refuses most deposits without one.';

  @override
  String get invoiceGapVatNotSupported =>
      'The workspace charges VAT but this invoice carries no rate — add your VAT rates, then issue it again.';

  @override
  String invoiceHeldNote(String reason) {
    return 'Reminders on hold: $reason';
  }

  @override
  String get invoiceHoldAction => 'Hold reminders';

  @override
  String get invoiceHoldConfirm => 'Hold';

  @override
  String get invoiceHoldExplain =>
      'No reminder is sent for this invoice, by hand or automatically, until the hold is released.';

  @override
  String get invoiceHoldFailed =>
      'The reminder hold could not be changed. Please try again.';

  @override
  String get invoiceHoldNote => 'Note (optional)';

  @override
  String get invoiceHoldPlaced => 'Reminders are on hold for this invoice.';

  @override
  String get invoiceHoldReasonDispute => 'The member disputes it';

  @override
  String get invoiceHoldReasonIdentity => 'Wrong person or identity error';

  @override
  String get invoiceHoldReasonInsolvency => 'Insolvency proceedings';

  @override
  String get invoiceHoldReasonOther => 'Another reason';

  @override
  String get invoiceHoldReleaseAction => 'Release the reminder hold';

  @override
  String get invoiceHoldReleased => 'Reminders can resume for this invoice.';

  @override
  String get invoiceHoldTitle => 'Why hold the reminders?';

  @override
  String get invoiceIntegrityAltered => 'Altered since issue';

  @override
  String get invoiceIntegrityUnverifiable => 'Issued before integrity checks';

  @override
  String get invoiceIntegrityVerified => 'Integrity verified';

  @override
  String get invoiceIssue => 'Issue invoice';

  @override
  String get invoiceIssueAll => 'Invoice all';

  @override
  String invoiceIssueAllConfirm(int count, String month, String total) {
    return 'Issue $count invoices for $month, $total in total? An issued invoice can no longer be edited — a mistake is corrected with a replacement.';
  }

  @override
  String get invoiceIssueOne => 'Issue';

  @override
  String get invoiceIssued => 'Invoice issued.';

  @override
  String invoiceIssuedCount(int count) {
    return '$count invoices issued.';
  }

  @override
  String invoiceIssuedPartial(int issued, int failed) {
    return '$issued issued, $failed failed.';
  }

  @override
  String get invoiceKindFull => 'Whole month';

  @override
  String get invoiceKindSettlement => 'Regrouped invoices';

  @override
  String get invoiceKindSubscription => 'Subscription, in advance';

  @override
  String get invoiceKindUsage => 'The month\'s extras';

  @override
  String get invoiceLegalAssociationReasonHint =>
      'e.g. \"TVA non applicable, art. 293 B du CGI\" — or \"Exonération de TVA, art. 261, 7-1° du CGI\" for services to members';

  @override
  String get invoiceLegalCustomerCapacityField => 'Default customer capacity';

  @override
  String get invoiceLegalCustomerCapacityHint =>
      'Decides which payment clauses an invoice prints. The statutory late-penalty, recovery-indemnity and discount defaults apply only to business customers, and a consumer never receives the recovery indemnity. A member\'s own capacity wins over this default. Every invoice keeps the clauses it was issued with.';

  @override
  String get invoiceLegalEscompteDefault => 'No discount for early payment.';

  @override
  String get invoiceLegalEscompteField => 'Early-payment discount';

  @override
  String get invoiceLegalFormField => 'Legal form & capital';

  @override
  String get invoiceLegalFormHint => 'e.g. SARL au capital de 7 500 €';

  @override
  String get invoiceLegalFormHintAssociation => 'e.g. Association loi 1901';

  @override
  String get invoiceLegalInsuranceField => 'Professional insurance';

  @override
  String get invoiceLegalIntro =>
      'The statutory lines printed on invoices and reminders. The payment clauses fall back to legal defaults when left empty.';

  @override
  String get invoiceLegalKindAssociation => 'Association (non-profit)';

  @override
  String get invoiceLegalKindCompany => 'Company / business';

  @override
  String get invoiceLegalKindField => 'Organization type';

  @override
  String get invoiceLegalLatePenaltyDefault =>
      'Late-payment penalty: three times the statutory interest rate.';

  @override
  String get invoiceLegalLatePenaltyField => 'Late-payment penalty';

  @override
  String get invoiceLegalPaymentTermsDefault => 'Payment on receipt.';

  @override
  String get invoiceLegalPaymentTermsField => 'Payment terms';

  @override
  String get invoiceLegalRecoveryDefault =>
      'Fixed recovery indemnity for collection costs: €40.';

  @override
  String get invoiceLegalRecoveryField => 'Recovery indemnity';

  @override
  String get invoiceLegalRegistrationField => 'Trade register';

  @override
  String get invoiceLegalRegistrationHint =>
      'e.g. RCS Saint-Brieuc 680 357 910';

  @override
  String get invoiceLegalRegistrationHintAssociation =>
      'e.g. RNA W123456789 · SIRET if assigned';

  @override
  String get invoiceLegalSection => 'Invoice mentions';

  @override
  String get invoiceLegalSpecialField => 'Special mentions';

  @override
  String get invoiceLineAdjustment => 'Adjustment';

  @override
  String get invoiceMatchAction => 'Mark as paid';

  @override
  String get invoiceMatchCreditNote => 'Create a credit note for the excess';

  @override
  String get invoiceMatchForce => 'Accept anyway (note why)';

  @override
  String get invoiceMatchNoPayments =>
      'No registered payment to match — record or confirm it first.';

  @override
  String get invoiceMatchNoteLabel => 'Note';

  @override
  String get invoiceMatchNoteRequired => 'A note is required.';

  @override
  String invoiceMatchOver(String excess) {
    return 'The member paid $excess more.';
  }

  @override
  String get invoiceMatchPendingBadge => 'Awaiting validation';

  @override
  String get invoiceMatchPickPayment => 'Select the registered payment';

  @override
  String invoiceMatchSummary(String amount, String date) {
    return 'Paid $amount on $date';
  }

  @override
  String invoiceMatchUnder(String missing) {
    return 'The member paid $missing less — accepting requires a note.';
  }

  @override
  String get invoiceMatched => 'Invoice matched.';

  @override
  String get invoiceMatchedBadge => 'Paid';

  @override
  String get invoiceMaturityReview =>
      'No agreed payment term was recorded for this invoice: reminders are not sent automatically until you review it.';

  @override
  String get invoiceMemberLabel => 'Member';

  @override
  String get invoiceMissingBuyerAddress =>
      'The member\'s postal address (a business customer needs one)';

  @override
  String get invoiceMissingBuyerName => 'The member\'s name or company';

  @override
  String get invoiceMissingBuyerVatId =>
      'The member\'s VAT number (needed for reverse charge)';

  @override
  String get invoiceMissingExemptionReason =>
      'The legal basis for the VAT exemption';

  @override
  String get invoiceMissingSellerAddress =>
      'The workspace\'s postal address (street or city)';

  @override
  String get invoiceMissingSellerCountry =>
      'The workspace country must be France or Germany for issuing here — other countries are issued outside the app';

  @override
  String get invoiceMissingSellerVatId =>
      'The workspace\'s VAT identification number';

  @override
  String get invoiceMissingTitle => 'Complete these details before issuing';

  @override
  String get invoiceMissingVatNotRegistered =>
      'No VAT on any line: the workspace does not charge VAT, but a rate is set on the subscription or an accessory';

  @override
  String get invoiceMissingVatRate =>
      'A VAT rate in force for the workspace\'s default rate (it would bill 0 %)';

  @override
  String get invoiceMissingVatZeroLine =>
      'A VAT rate for every charge: a charge is billed at 0 % with no export, exemption or reverse charge explaining it';

  @override
  String get invoiceNoOpen => 'No open invoices.';

  @override
  String get invoiceNothingToInvoice =>
      'Nothing tracked for this month — nothing to invoice.';

  @override
  String invoiceOpenAge(int days) {
    return '$days days';
  }

  @override
  String get invoicePdfActivity => 'Bookings & payments';

  @override
  String get invoicePdfAnnex => 'Annex — details';

  @override
  String get invoicePdfAttendance => 'Check-ins';

  @override
  String get invoicePdfBilledTo => 'Billed to';

  @override
  String get invoicePdfBuyerReference => 'Service reference';

  @override
  String get invoicePdfCharges => 'Charges';

  @override
  String get invoicePdfCopy => 'Copy';

  @override
  String get invoicePdfCreditNote => 'Credit note';

  @override
  String get invoicePdfDescription => 'Description';

  @override
  String get invoicePdfDueOn => 'Due on';

  @override
  String get invoicePdfIssuedBy => 'Issued by';

  @override
  String get invoicePdfIssuedOn => 'Issued on';

  @override
  String get invoicePdfPage => 'Page';

  @override
  String get invoicePdfPayments => 'Payments';

  @override
  String get invoicePdfProforma => 'Proforma';

  @override
  String get invoicePdfPurchaseOrder => 'Order reference';

  @override
  String get invoicePdfReplaces => 'Replaces';

  @override
  String get invoicePdfReserved => 'reserved';

  @override
  String invoicePdfSettledIn(String number) {
    return 'Regrouped in $number';
  }

  @override
  String get invoicePdfSignature => 'Digital signature (SHA-256)';

  @override
  String get invoicePdfTitle => 'Invoice';

  @override
  String get invoicePdfVoided => 'ERRONEOUS — voided on';

  @override
  String get invoicePickMember =>
      'Pick a member to see what their month tracked.';

  @override
  String get invoiceProformaAction => 'Proforma invoice';

  @override
  String get invoiceProformaNothing =>
      'Nothing tracked for this month — no proforma to send.';

  @override
  String get invoiceProformaShared => 'Proforma shared.';

  @override
  String get invoicePublicBuyer => 'Public-sector buyer (Chorus Pro)';

  @override
  String get invoicePurchaseOrder => 'Engagement number';

  @override
  String get invoicePurchaseOrderHint =>
      'Public-sector buyer (Chorus Pro): the numéro d\'engagement.';

  @override
  String get invoiceRefundButton => 'Record the refund';

  @override
  String invoiceRefundExplain(String amount) {
    return 'This credit note means the WORKSPACE owes the member $amount. Record that the refund was paid out — the amount is booked against the member\'s balance and the document closes as Refunded.';
  }

  @override
  String get invoiceRefundLabel => 'To refund';

  @override
  String get invoiceRefunded => 'Refund recorded.';

  @override
  String get invoiceRegisterAllYears => 'All years';

  @override
  String get invoiceRegisterAmount => 'Amount';

  @override
  String get invoiceRegisterDate => 'Date';

  @override
  String get invoiceRegisterName => 'Name';

  @override
  String get invoiceRegisterTitle => 'Invoice register';

  @override
  String get invoiceRegisterTotal => 'Total';

  @override
  String get invoiceRegisterYear => 'Year';

  @override
  String get invoiceRemainingLabel => 'Remaining';

  @override
  String get invoiceRemindAction => 'Send a reminder';

  @override
  String get invoiceReminded => 'Reminder recorded.';

  @override
  String invoiceRemindedBadge(int count) {
    return 'Reminded ×$count';
  }

  @override
  String invoiceRemindedLast(String date) {
    return 'last reminder $date';
  }

  @override
  String invoiceReminderMessage(String number, String amount) {
    return 'Friendly reminder: invoice $number — balance due $amount.';
  }

  @override
  String get invoiceReminderNotSent =>
      'Nothing was sent, so nothing was recorded.';

  @override
  String get invoiceReplaceAction => 'Issue replacement';

  @override
  String invoiceReplacedBy(String number) {
    return 'Replaced by $number';
  }

  @override
  String get invoiceRunningMonth =>
      'This month is still running — its positions can still change, and a month can only be invoiced once.';

  @override
  String get invoiceSendAccepted => 'Sent — the platform accepted it.';

  @override
  String invoiceSendAcceptedTest(String env) {
    return 'Test send accepted ($env).';
  }

  @override
  String get invoiceSendAction => 'Send to the government platform';

  @override
  String get invoiceSendCustomerAccepted =>
      'Sent — the customer\'s service accepted it.';

  @override
  String get invoiceSendCustomerAction => 'Send to the customer\'s service';

  @override
  String get invoiceSendRejected => 'The platform refused it.';

  @override
  String get invoiceSendStatusAccepted => 'accepted';

  @override
  String get invoiceSendStatusFailed => 'not delivered';

  @override
  String get invoiceSendStatusRejected => 'rejected';

  @override
  String invoiceSentOn(String date, String status) {
    return 'Sent $date · $status';
  }

  @override
  String get invoiceSentTestChip => 'test';

  @override
  String get invoiceShare => 'Share PDF';

  @override
  String get invoiceShowCancelled => 'Show cancelled';

  @override
  String get invoiceSortByMember => 'By member';

  @override
  String get invoiceSortByMonth => 'By month';

  @override
  String get invoiceSortNewest => 'Newest first';

  @override
  String get invoiceSortTooltip => 'Sort';

  @override
  String get invoiceStatusOpen => 'Open';

  @override
  String get invoiceStatusPartiallyPaid => 'Partially paid';

  @override
  String get invoiceStatusRefunded => 'Refunded';

  @override
  String get invoiceStatusRemainderCancelled =>
      'Partially paid · remainder cancelled';

  @override
  String invoiceSummaryOpen(int count, String amount) {
    return '$count open · $amount outstanding';
  }

  @override
  String invoiceSummaryToInvoice(int count) {
    return '$count to invoice';
  }

  @override
  String invoiceSummaryToRefund(int count, String amount) {
    return '$count to refund · $amount';
  }

  @override
  String get invoiceTabArchive => 'Archive';

  @override
  String get invoiceTabOpen => 'Open';

  @override
  String get invoiceTabToInvoice => 'To invoice';

  @override
  String get invoiceTemplateBodyLabel => 'Body band (the invoice lines)';

  @override
  String get invoiceTemplateDocInvoice => 'Invoice';

  @override
  String invoiceTemplateDocReminder(int level) {
    return 'Reminder $level';
  }

  @override
  String get invoiceTemplateDocStatement => 'Statement';

  @override
  String get invoiceTemplateDownload => 'Download PDF';

  @override
  String get invoiceTemplateFooterLabel =>
      'Footer (under the totals — payment terms, legal mentions)';

  @override
  String get invoiceTemplateHeaderLabel => 'Header band';

  @override
  String get invoiceTemplateHint =>
      'Three report bands rendered on the PDF — the e-invoice XML is never touched. Liquid conditions and loops, then line markup:';

  @override
  String get invoiceTemplateIntroLabel => 'Intro (above the billed-to block)';

  @override
  String get invoiceTemplateNoPreview =>
      'Issue an invoice first — the preview renders your newest one.';

  @override
  String get invoiceTemplatePresets => 'Templates';

  @override
  String get invoiceTemplatePreview => 'Preview';

  @override
  String get invoiceTemplateQuickPreview => 'Quick preview';

  @override
  String get invoiceTemplateReset => 'Reset to default';

  @override
  String get invoiceTemplateSaved => 'Invoice template saved.';

  @override
  String get invoiceTemplateShare => 'Share PDF';

  @override
  String get invoiceTemplateTitle => 'Invoice PDF template';

  @override
  String get invoiceVoidAction => 'Mark erroneous';

  @override
  String invoiceVoidConfirm(String number) {
    return 'Mark invoice $number as erroneous? This cannot be undone.';
  }

  @override
  String get invoiceVoided => 'Invoice marked as erroneous.';

  @override
  String get invoiceVoidedChip => 'Erroneous';

  @override
  String get invoiceWizardAction => 'Month-close wizard';

  @override
  String get invoiceWriteoffButton => 'Cancel outstanding amount';

  @override
  String get invoiceWriteoffExplain =>
      'The unpaid remainder of this invoice will be cancelled and the invoice archived as partially paid — once the validators confirm. Until then it stays open and owed.';

  @override
  String get invoiceWriteoffRequested =>
      'Write-off requested — awaiting validation.';

  @override
  String get invoicesEmpty => 'No invoices yet.';

  @override
  String get invoicesManage => 'Manage invoices';

  @override
  String get invoicesTitle => 'Invoices';

  @override
  String get invoicingBanner =>
      'You are issuing and chasing invoices for the whole workspace. Your own invoices and payments are in Me › Finances.';

  @override
  String get invoicingHubTitle => 'Invoicing';

  @override
  String get invoicingMyFinances => 'My finances';

  @override
  String get invoicingTools => 'Invoicing tools';

  @override
  String journeyClosedPaid(String date) {
    return 'Paid on $date — closed';
  }

  @override
  String journeyClosedRefunded(String date) {
    return 'Refunded on $date — closed';
  }

  @override
  String journeyClosedRemainder(String date) {
    return 'Closed — remainder cancelled on $date';
  }

  @override
  String journeyClosedReplaced(String number) {
    return 'Cancelled — replaced by $number';
  }

  @override
  String get journeyClosedSettled =>
      'Regrouped into another invoice — that one is owed and chased';

  @override
  String get journeyHowButton => 'How it works';

  @override
  String get journeyHowClosedMember =>
      'The month reads settled and the invoice stays readable forever: quick view, PDF, share.';

  @override
  String get journeyHowClosedWorkspace =>
      'Paid, remainder cancelled or refunded: the invoice moves to the archive. A wrong invoice is marked erroneous and replaced — before payment, never after.';

  @override
  String get journeyHowConfirmationMember =>
      'Nothing to do — unless the workspace recorded the payment for them: then they confirm it in Events.';

  @override
  String get journeyHowConfirmationWorkspace =>
      'Another admin confirms the declared payment; the issuer then matches the registered payment to the invoice (Mark as paid) — a validation rule may hand the match to the validators. Paid more? A credit note. Paid less? Partially paid, the rest owed until paid or written off.';

  @override
  String get journeyHowIntro =>
      'Four steps, the same for every invoice. Each one says whose move it is.';

  @override
  String get journeyHowIssuedMember =>
      'Finds it on the Invoices face: positions, balance, due date.';

  @override
  String get journeyHowIssuedWorkspace =>
      'Issues the invoice from the month\'s tracked data — numbered, signed, immutable — and shares the PDF or sends the e-invoice.';

  @override
  String get journeyHowMemberLabel => 'Member';

  @override
  String get journeyHowPaymentMember =>
      'Pays online (settled at once) or by transfer, then records the payment so the workspace knows.';

  @override
  String get journeyHowPaymentWorkspace =>
      'Waits for the money. Past the term it sends the reminder levels it configured — by hand or automatically.';

  @override
  String get journeyHowTitle => 'How invoicing works';

  @override
  String get journeyHowWorkspaceLabel => 'Workspace';

  @override
  String journeyIssuerAdminConfirms(String name, String amount) {
    return '$name declared a payment of $amount — another admin confirms it in Events';
  }

  @override
  String journeyIssuerMatches(String amount) {
    return 'A payment of $amount is registered — match it to this invoice';
  }

  @override
  String journeyIssuerMemberConfirms(String name, String amount) {
    return 'A payment of $amount was recorded — $name confirms it in Events';
  }

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
  String journeyIssuerRefunds(String name, String amount) {
    return 'Credit note — refund $amount to $name and record it';
  }

  @override
  String get journeyIssuerReplaces => 'Cancelled — issue the replacement';

  @override
  String journeyMemberConfirms(String amount) {
    return 'Your move: confirm the payment of $amount recorded for you, in Events';
  }

  @override
  String journeyMemberDeclared(String amount) {
    return 'You declared $amount — the workspace is confirming it';
  }

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
  String journeyMemberRefund(String amount) {
    return 'The workspace owes you $amount — nothing to pay';
  }

  @override
  String journeyMemberRegistered(String amount) {
    return 'Your payment of $amount is registered — the workspace matches it to this invoice';
  }

  @override
  String get journeyMemberReplaces => 'Cancelled — a replacement follows';

  @override
  String get journeyMemberValidators => 'Payment matched — awaiting validation';

  @override
  String get journeyMemberWriteoff =>
      'The workspace asked to cancel the remainder — awaiting validation';

  @override
  String journeyOutstanding(String amount) {
    return '$amount outstanding';
  }

  @override
  String journeyOverdueCount(int count) {
    return '$count overdue';
  }

  @override
  String get journeyPrimaryConfirmInEvents => 'Open Events';

  @override
  String journeyPrimaryRemind(int level) {
    return 'Send reminder $level';
  }

  @override
  String get journeyStageClosed => 'Closed';

  @override
  String get journeyStageCollect => 'To collect';

  @override
  String get journeyStageConfirm => 'To confirm';

  @override
  String get journeyStageIssue => 'To issue';

  @override
  String get journeyStageStripLabel =>
      'The invoicing process: issue, collect, confirm, close';

  @override
  String get journeyStepClosed => 'Closed';

  @override
  String get journeyStepConfirmation => 'Confirmation';

  @override
  String get journeyStepIssued => 'Issued';

  @override
  String get journeyStepPayment => 'Payment';

  @override
  String get journeyTimelineTitle => 'Timeline';

  @override
  String get journeyValidatorsMatch =>
      'Payment matched — awaiting the validators\' decision';

  @override
  String get journeyValidatorsWriteoff =>
      'Write-off of the remainder requested — awaiting the validators';

  @override
  String get kioskBadgeConfirm => 'Confirm';

  @override
  String get kioskBadgeFieldLabel => 'Badge code';

  @override
  String get kioskBadgeHint => 'Scan your badge QR, or type its code.';

  @override
  String get kioskBadgeHintNfc =>
      'Tap your card, scan your QR, or type its code.';

  @override
  String get kioskBadgeRejected => 'Badge not recognized.';

  @override
  String kioskBasis(String granularity, String hours) {
    return 'Rule: $granularity · today $hours';
  }

  @override
  String kioskBlockedContactHint(String name) {
    return 'Held by $name — you can message them from the app on your phone.';
  }

  @override
  String get kioskCheckIn => 'Check in';

  @override
  String get kioskCheckInRightAway => 'Check in right away';

  @override
  String get kioskCheckInRightAwayHint =>
      'You\'re here — the reservation starts checked in.';

  @override
  String get kioskCheckOut => 'Check out';

  @override
  String get kioskClosedToday =>
      'The workspace is closed today — check-in and reservations are not possible.';

  @override
  String get kioskConfirmAction => 'Confirm';

  @override
  String get kioskDone => 'Done — you\'re all set.';

  @override
  String get kioskGateBody =>
      'This account is set up as the workspace kiosk. In kiosk mode the tablet only shows the floor plan for badge check-in — nothing else can be opened. To leave kiosk mode, restart the tablet.';

  @override
  String get kioskGateReject => 'Not now — open the app normally';

  @override
  String get kioskGateStart => 'Start kiosk mode';

  @override
  String get kioskGateTitle => 'Start kiosk mode?';

  @override
  String get kioskLevelButton => 'This level';

  @override
  String get kioskNfcFailed =>
      'The RFID reader did not start — restart the app and try again.';

  @override
  String get kioskNfcOff =>
      'NFC is turned off in this tablet\'s Android settings — turn it on to read RFID cards.';

  @override
  String get kioskNfcUnsupported =>
      'This tablet has no NFC reader — scan the QR badge instead.';

  @override
  String get kioskNotCheckedIn =>
      'No active check-in found — the plan may have just updated.';

  @override
  String get kioskPeriodCheckInHint =>
      'Until when will you stay? Checking in starts now.';

  @override
  String get kioskPeriodReserveHint => 'Pick the period — today only.';

  @override
  String get kioskPresentBadge => 'Present your badge';

  @override
  String get kioskPresentBadgeNext => 'Present the badge';

  @override
  String get kioskRejectAction => 'Reject';

  @override
  String get kioskReserve => 'Reserve';

  @override
  String get kioskReserveAndCheckIn => 'Reserve & check in';

  @override
  String get kioskRestOfDay => 'Rest of the day';

  @override
  String get kioskRevertDesc =>
      'This profile is set up as the workspace kiosk. Revert it to a regular member to stop the kiosk question at start.';

  @override
  String get kioskRevertDone => 'This profile is a regular member again.';

  @override
  String get kioskRevertTitle => 'Kiosk device';

  @override
  String get kioskScanQr => 'Scan the QR badge';

  @override
  String get kioskTapHint => 'Tap a seat to check in';

  @override
  String get languageNameCS => 'Czech';

  @override
  String get languageNameDA => 'Danish';

  @override
  String get languageNameDE => 'German';

  @override
  String get languageNameEL => 'Greek';

  @override
  String get languageNameEN => 'English';

  @override
  String get languageNameES => 'Spanish';

  @override
  String get languageNameFI => 'Finnish';

  @override
  String get languageNameFR => 'French';

  @override
  String get languageNameHU => 'Hungarian';

  @override
  String get languageNameIT => 'Italian';

  @override
  String get languageNameJA => 'Japanese';

  @override
  String get languageNameNB => 'Norwegian';

  @override
  String get languageNameNL => 'Dutch';

  @override
  String get languageNamePL => 'Polish';

  @override
  String get languageNamePT => 'Portuguese';

  @override
  String get languageNameRO => 'Romanian';

  @override
  String get languageNameSV => 'Swedish';

  @override
  String get languageSystemDefault => 'System default';

  @override
  String get languageTitle => 'Language';

  @override
  String get ledgerCategoryAdjustment => 'Adjustment';

  @override
  String get ledgerCategoryExpense => 'Expense reimbursement';

  @override
  String get ledgerCategoryOverage => 'Overage';

  @override
  String get ledgerCategoryPayment => 'Payment';

  @override
  String get ledgerCategoryService => 'Service';

  @override
  String get ledgerCategorySubscription => 'Subscription';

  @override
  String get legalIdentityAssociationRegime =>
      'A non-profit association with no trading activity is not subject to VAT: choose \"Outside the scope of VAT\", not \"Exempt\". The exempt scheme requires a VAT number you do not have, and the e-invoice would be rejected. Outside the scope, your registration number identifies the association.';

  @override
  String get legalIdentityCity => 'City';

  @override
  String get legalIdentityExemptionReason => 'Why no VAT is charged';

  @override
  String get legalIdentityIntro =>
      'What an EN 16931 e-invoice must state about you. Invoices already issued keep the identity they were signed with.';

  @override
  String get legalIdentityLegalId => 'Company registration number';

  @override
  String get legalIdentityPostalCode => 'Post code';

  @override
  String get legalIdentityRegime => 'VAT regime';

  @override
  String get legalIdentityRegimeExempt => 'VAT-exempt (small-business scheme)';

  @override
  String get legalIdentityRegimeHint =>
      'The regime decides which number the norm requires: a registration number outside the scope of VAT, a VAT number when exempt.';

  @override
  String get legalIdentityRegimeNotSubject => 'Outside the scope of VAT';

  @override
  String get legalIdentityRegimeVatRegistered => 'VAT-registered (charges VAT)';

  @override
  String get legalIdentitySaved => 'Legal identity saved.';

  @override
  String get legalIdentityStreet => 'Street';

  @override
  String get legalIdentitySubtitle =>
      'VAT regime, registration numbers and the workspace\'s default payment conditions';

  @override
  String get legalIdentityTitle => 'Legal identity & e-invoicing';

  @override
  String get legalIdentityVatId => 'VAT number';

  @override
  String get legalIdentityVatWarning =>
      'This workspace charges VAT but no rate is set up: invoices show no tax and the XML export stays disabled until you add one.';

  @override
  String get legendBlocked => 'Blocked';

  @override
  String get legendClosed => 'Closed day';

  @override
  String get legendFree => 'Free';

  @override
  String get legendMine => 'Mine';

  @override
  String get legendOccupied => 'Checked in';

  @override
  String get legendProfileFull => 'Every state';

  @override
  String get legendProfileFullDesc =>
      'Free · Reserved · Checked in · Mine · Blocked — you can see who has arrived.';

  @override
  String get legendProfileSimple => 'Fewer states';

  @override
  String get legendProfileSimpleDesc =>
      'Free · Reserved · Mine · Unavailable. A booked seat and one somebody has checked into look the same.';

  @override
  String get legendProfileTitle => 'What the plan tells apart';

  @override
  String get legendReserved => 'Reserved';

  @override
  String get legendUnavailable => 'Unavailable';

  @override
  String get levelAssignMember => 'For member';

  @override
  String get levelAssignMyself => 'Myself';

  @override
  String get levelBookableDesc =>
      'The whole floor can be reserved as one booking.';

  @override
  String get levelBookableToggle => 'Bookable as a whole';

  @override
  String get levelConflict => 'The level has reservations in that period.';

  @override
  String get levelDetail => 'Whole level';

  @override
  String get levelFeatureOff =>
      'Office & level reservations are switched off in Features.';

  @override
  String get levelNotAllowed =>
      'You are not allowed to reserve a whole desk, office or level.';

  @override
  String get levelPermissionAllowed =>
      'May reserve a whole desk, office or level';

  @override
  String get levelPermissionDenied =>
      'May not reserve a whole desk, office or level';

  @override
  String get levelPermissionTile => 'Level reservations';

  @override
  String get levelPriceLabel => 'Price per half-day';

  @override
  String get levelReorderStale =>
      'The levels changed meanwhile. Nothing was saved; the current order is shown.';

  @override
  String get levelReserveButton => 'Reserve level';

  @override
  String get levelReserveTitle => 'Reserve the whole level';

  @override
  String get levelSupplementLabel => 'Level reservations';

  @override
  String get libraryApplied => 'Template applied.';

  @override
  String libraryAppliedChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes applied.',
      one: '1 change applied.',
    );
    return '$_temp0';
  }

  @override
  String get libraryApply => 'Apply to this space';

  @override
  String libraryApplyChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Apply $count changes',
      one: 'Apply 1 change',
      zero: 'Nothing selected',
    );
    return '$_temp0';
  }

  @override
  String get libraryApplyConfirmBody =>
      'The floor plan is added or updated by name, and the settings the template carries are merged in. Nothing you already have is removed.';

  @override
  String libraryApplyConfirmTitle(String name) {
    return 'Apply « $name »?';
  }

  @override
  String get libraryCarriesSettings => 'with its settings';

  @override
  String libraryConfirmSensitive(String groups) {
    return 'This changes $groups. Apply?';
  }

  @override
  String libraryCounts(int levels, int desks, int seats) {
    return '$levels levels · $desks desks · $seats seats';
  }

  @override
  String get libraryCustomizedHere => 'Customized here';

  @override
  String get libraryDelete => 'Delete template';

  @override
  String libraryDeleteConfirm(String name) {
    return 'Delete « $name »? People you shared it with lose access.';
  }

  @override
  String get libraryEmpty =>
      'Nothing here yet. Save this space as a template, or wait for someone to share one with you.';

  @override
  String libraryFeatureNeeds(String feature, String prerequisite) {
    return '$feature needs $prerequisite, which stays off: it will not work yet.';
  }

  @override
  String get libraryGroupAppearance => 'Appearance';

  @override
  String get libraryGroupCalendarNavigation => 'Calendar & closures';

  @override
  String get libraryGroupDocumentsOperations => 'Documents & operations';

  @override
  String get libraryGroupForms => 'Forms';

  @override
  String get libraryGroupHoursBooking => 'Hours & booking';

  @override
  String get libraryGroupPricingCredits => 'Prices & credits';

  @override
  String get libraryGroupRolesAccess => 'Roles & access';

  @override
  String get libraryGroupSpace => 'Space & plan';

  @override
  String get libraryGroupUnknown => 'Other — this version cannot apply it';

  @override
  String get libraryGroupWording => 'Wording';

  @override
  String get libraryInvitationTexts => 'Invitation texts';

  @override
  String libraryInvitationTextsHint(String tag) {
    return 'Only texts written with placeholders such as $tag; a text naming your space or its people is refused.';
  }

  @override
  String get libraryInvitationTextsRefused =>
      'An invitation text still names your space or its people. Replace them with placeholders in the invitation settings, or untick invitation texts.';

  @override
  String get libraryNeverDocumentDesign => 'Document designs';

  @override
  String get libraryNeverDocumentLinks => 'Links to your documents';

  @override
  String get libraryNeverIdentity =>
      'Your address, legal identifiers, legal mentions and WhatsApp group';

  @override
  String get libraryNeverInvitations => 'Invitation texts';

  @override
  String get libraryNeverPayment => 'Bank details';

  @override
  String get libraryNeverPublished => 'Never published';

  @override
  String get libraryNeverSites => 'Sites and their addresses';

  @override
  String get libraryNotSupported => 'This template cannot be applied here.';

  @override
  String get libraryNothingToApply =>
      'Everything this template carries is already here.';

  @override
  String get libraryPartial =>
      'Part of this template cannot be applied here and is left out.';

  @override
  String libraryPlanNames(String names) {
    return 'These names go with the plan: $names';
  }

  @override
  String get libraryPreviewChanges => 'Preview changes';

  @override
  String get libraryPreviewFailed =>
      'The changes could not be previewed. Nothing was applied.';

  @override
  String libraryPreviewTitle(String name) {
    return 'What « $name » would change';
  }

  @override
  String libraryProcessOff(String feature) {
    return '$feature off';
  }

  @override
  String libraryProcessOn(String feature) {
    return '$feature on';
  }

  @override
  String get libraryProcessTechnical => 'Technical';

  @override
  String get libraryPublishGroups => 'What travels';

  @override
  String get libraryPublishNothing => 'Choose at least one group.';

  @override
  String get libraryReasonFeeSchedule =>
      'Your fee schedule would be replaced as a whole.';

  @override
  String get librarySave => 'Save this space as a template';

  @override
  String get librarySaveDescription => 'Description (optional)';

  @override
  String get librarySaveName => 'Template name';

  @override
  String get librarySaveTags => 'Tags, separated by commas';

  @override
  String get librarySaved => 'Saved to your templates.';

  @override
  String librarySearchCapabilities(String capabilities) {
    return 'Templates set up for: $capabilities';
  }

  @override
  String get librarySearchHint => 'Search templates';

  @override
  String librarySearchSuggestion(String word) {
    return 'Did you mean “$word”?';
  }

  @override
  String get librarySearchUnavailable =>
      'The templates\' settings could not be checked, so none is shown as matching. Try again.';

  @override
  String get libraryShare => 'Share…';

  @override
  String get libraryShareAdd => 'Invite';

  @override
  String get libraryShareEmail => 'E-mail address';

  @override
  String get libraryShareHint =>
      'Invite by e-mail. The invitation works the moment that address signs in — nothing is revealed about whether it already has an account.';

  @override
  String get libraryShareNobody => 'Nobody invited yet.';

  @override
  String libraryShareTitle(String name) {
    return 'Share « $name »';
  }

  @override
  String get libraryStartFrom => 'Start from the library';

  @override
  String get libraryStateAttention => 'Needs attention';

  @override
  String get libraryStateChange => 'Changes what you have';

  @override
  String get libraryStateMatching => 'Already the same';

  @override
  String get libraryStateNew => 'New';

  @override
  String get libraryTitle => 'Workspace library';

  @override
  String get libraryVisibility => 'Who may see it';

  @override
  String get libraryVisibilityBuiltin => 'Built in';

  @override
  String get libraryVisibilityPrivate => 'Only me';

  @override
  String get libraryVisibilityPublic => 'Everyone (the library)';

  @override
  String get libraryVisibilityShared => 'People I invite';

  @override
  String get libraryYours => 'Your templates';

  @override
  String get linkedAccountsIntro =>
      'Sign into this account with any linked identity. The available providers depend on your server.';

  @override
  String get linkedAccountsLink => 'Link';

  @override
  String get linkedAccountsLinkStarted =>
      'Continue in the browser to finish linking.';

  @override
  String get linkedAccountsLinked => 'Linked';

  @override
  String get linkedAccountsTitle => 'Linked accounts';

  @override
  String get linkedAccountsUnlink => 'Unlink';

  @override
  String listCoversSeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seats',
      one: '1 seat',
    );
    return '$_temp0';
  }

  @override
  String listCoversTables(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tables',
      one: '1 table',
    );
    return '$_temp0';
  }

  @override
  String get listWholeReservable => 'Reservable as a whole';

  @override
  String get localGapsTitle => 'To finish setting up this space';

  @override
  String get localNeedsTitle =>
      'You will add these yourself; a template never carries them:';

  @override
  String get localSlotEinvoicePlatform => 'Your e-invoicing platform account';

  @override
  String get localSlotLegalIdentity =>
      'Your legal identity and address (for invoices)';

  @override
  String localSlotNamedValidators(String type) {
    return 'Who validates: $type';
  }

  @override
  String get localSlotOpen => 'Set up';

  @override
  String get localSlotPaymentDetails => 'How members pay you (bank details)';

  @override
  String get localSlotPaymentProvider => 'An online payment provider';

  @override
  String get localSlotRecommended => 'Recommended';

  @override
  String get localSlotSite => 'At least one site';

  @override
  String get managedAccessAdmins => 'Admins';

  @override
  String get managedAccessDefault => 'Every owner and every admin';

  @override
  String get managedAccessHint =>
      'By default: every owner and every admin. Narrow it by role, by person, or both. The owner may always change this rule — otherwise a profile could become unadministrable — but only reaches the data when the rule names them.';

  @override
  String get managedAccessOwners => 'Owners';

  @override
  String get managedAccessPeople => 'Named people';

  @override
  String get managedAccessSaved => 'Rule saved.';

  @override
  String get managedAccessTitle => 'Who may administer this profile';

  @override
  String get managedProfileAdd => 'Add a managed profile';

  @override
  String get managedProfileChip => 'Managed';

  @override
  String get managedProfileCreated => 'Managed profile created';

  @override
  String get managedProfileEdit => 'Edit identity';

  @override
  String get managedProfileHandOver => 'Hand over to the person';

  @override
  String get managedProfileHandOverHint =>
      'Mints a personal code bound to this profile. Whoever redeems it takes the profile over — reservations, invoices, subscription — once you approve the membership.';

  @override
  String get managedProfileIdentityUnavailable =>
      'These details could not be read, so there is nothing to edit yet. Nothing has been changed.';

  @override
  String get managedProfileIntro =>
      'This person has no account yet. You book, invoice and manage for them; hand the profile over when they join.';

  @override
  String get managedProfileRevoke => 'Revoke handover';

  @override
  String get managedProfileRevoked => 'Handover revoked';

  @override
  String get managedProfileSaved => 'Identity saved';

  @override
  String get managedProfileTitle => 'Managed profile';

  @override
  String get mcpApiReference => 'API reference';

  @override
  String get mcpApiReferenceHint =>
      'What an assistant can call, and how it is authorised';

  @override
  String get mcpAssistantsTitle => 'Assistants';

  @override
  String get mcpAssistantsUnavailable =>
      'Your assistant access could not be loaded. Try again later.';

  @override
  String get mcpCancel => 'Cancel';

  @override
  String get mcpConfirmAccept => 'Confirm';

  @override
  String get mcpConfirmApprove => 'Your answer: approve';

  @override
  String mcpConfirmClient(String client) {
    return 'Asked by: $client';
  }

  @override
  String get mcpConfirmConsequence =>
      'Confirming lets the assistant send this exact request once. The workspace\'s own validation rules still apply.';

  @override
  String get mcpConfirmDecline => 'Decline';

  @override
  String get mcpConfirmDeclined => 'Declined. Nothing was done.';

  @override
  String get mcpConfirmDone =>
      'Confirmed. The assistant can now send the request.';

  @override
  String get mcpConfirmExpired =>
      'This request expired. Ask the assistant to send it again.';

  @override
  String mcpConfirmNewShare(String pct) {
    return 'New subscription share: $pct %';
  }

  @override
  String mcpConfirmNewStatus(String status) {
    return 'New status: $status';
  }

  @override
  String get mcpConfirmNotFound => 'There is no such request for you.';

  @override
  String mcpConfirmPeriod(String period) {
    return 'Period: $period';
  }

  @override
  String get mcpConfirmRefuse => 'Your answer: refuse';

  @override
  String get mcpConfirmStale =>
      'This request no longer matches the current data or your access. Nothing was done.';

  @override
  String get mcpConfirmTitle => 'Confirm an assistant request';

  @override
  String get mcpConfirmUnavailable =>
      'This request could not be loaded. Try again from the link.';

  @override
  String mcpConfirmWorkspace(String workspace) {
    return 'Workspace: $workspace';
  }

  @override
  String mcpConnectAccessExpiresIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Approved — $_temp0 left.';
  }

  @override
  String mcpConnectAccessExpiresSoon(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Approved — expires in $_temp0. Ask for approval again once it lapses.';
  }

  @override
  String get mcpConnectAddTitle => 'Add DesKilo to your assistant';

  @override
  String get mcpConnectAddressLabel => 'Your DesKilo address for assistants';

  @override
  String get mcpConnectAllDone =>
      'Everything is ready. Test the connection below.';

  @override
  String get mcpConnectBeforeTitle => 'Before you connect';

  @override
  String get mcpConnectChatgptNote =>
      'Developer mode needs a paid ChatGPT plan (Plus, Pro, Business, Enterprise or Edu).';

  @override
  String get mcpConnectChatgptStep1 =>
      'In ChatGPT, turn on developer mode: Settings → Apps → Advanced settings.';

  @override
  String get mcpConnectChatgptStep2 =>
      'Create an app named DesKilo, paste the address above and choose OAuth as the authentication.';

  @override
  String get mcpConnectChatgptStep3 =>
      'Sign in with Google and pick this workspace and what ChatGPT may do there.';

  @override
  String get mcpConnectClaudeNote =>
      'Claude on the web, Claude Desktop and the Claude mobile app share the same connectors. On a Team or Enterprise plan, an owner of the Claude organisation adds the connector first.';

  @override
  String get mcpConnectClaudeOpen => 'Open Claude connectors';

  @override
  String get mcpConnectClaudeStep1 => 'In Claude, open Settings → Connectors.';

  @override
  String get mcpConnectClaudeStep2 =>
      'Choose \"Add custom connector\", name it DesKilo and paste the address above.';

  @override
  String get mcpConnectClaudeStep3 =>
      'Choose Connect, sign in with Google and pick this workspace and what Claude may do there.';

  @override
  String get mcpConnectCodeStep1 => 'Run this in a terminal:';

  @override
  String get mcpConnectCodeStep2 =>
      'In Claude Code, type /mcp, choose deskilo and then Authenticate. A browser opens to sign in and pick this workspace.';

  @override
  String get mcpConnectCopied => 'Copied.';

  @override
  String get mcpConnectCopyRequest => 'Copy a request to send';

  @override
  String get mcpConnectCursorInstall => 'Add to Cursor';

  @override
  String get mcpConnectCursorStep =>
      'Cursor asks to install DesKilo, then opens a browser to sign in and pick this workspace. Without the button, add this to ~/.cursor/mcp.json:';

  @override
  String get mcpConnectDone => 'Done';

  @override
  String get mcpConnectIntro =>
      'Let Claude, ChatGPT or another assistant check and book things for you in DesKilo. It acts as you, only in the workspaces and for the actions you approve.';

  @override
  String mcpConnectLastCall(String client, String when) {
    return 'Last call: $client, $when.';
  }

  @override
  String get mcpConnectManageHint =>
      'To see what an assistant did or to disconnect it, open Assistants.';

  @override
  String get mcpConnectOpenFailed =>
      'The app could not be opened from here. Use the steps below instead.';

  @override
  String get mcpConnectOpenGuide => 'Open the connection guide';

  @override
  String get mcpConnectOpenInstallation => 'Open the installation console';

  @override
  String get mcpConnectOpenSetup => 'Open assistant setup';

  @override
  String get mcpConnectOperatorRequest =>
      'Hello, could you switch assistants on for our DesKilo server? It is under Settings → Installation: assistants. Thank you.';

  @override
  String get mcpConnectOtherStep1 =>
      'Most clients read a JSON file of servers. Add this entry; the client opens a browser to sign in the first time.';

  @override
  String get mcpConnectOtherStep2 =>
      'A client that only starts local programs can reach DesKilo through mcp-remote (needs Node.js):';

  @override
  String get mcpConnectRoleDenied =>
      'Nothing is offered to your role here. A workspace administrator decides what each role may do.';

  @override
  String get mcpConnectStepAccess => 'Your access to assistants';

  @override
  String get mcpConnectStepConnect => 'DesKilo added to your assistant';

  @override
  String get mcpConnectStepGoogle => 'Google sign-in';

  @override
  String get mcpConnectStepIdentity => 'Your identity on this server';

  @override
  String get mcpConnectStepServer => 'Assistants switched on for this server';

  @override
  String get mcpConnectStepWorkspace => 'This workspace offers assistants';

  @override
  String get mcpConnectSwitchWorkspace => 'Switch to this workspace';

  @override
  String get mcpConnectTabChatgpt => 'ChatGPT';

  @override
  String get mcpConnectTabClaude => 'Claude';

  @override
  String get mcpConnectTabClaudeCode => 'Claude Code';

  @override
  String get mcpConnectTabCursor => 'Cursor';

  @override
  String get mcpConnectTabOther => 'Other';

  @override
  String get mcpConnectTabVscode => 'VS Code';

  @override
  String get mcpConnectTest => 'Test the connection';

  @override
  String get mcpConnectTestAgain => 'Test again';

  @override
  String get mcpConnectTestPrompt =>
      'Using DesKilo, what are my bookings this week?';

  @override
  String mcpConnectTestReached(String client, String when) {
    return 'Connected: $client reached DesKilo, $when.';
  }

  @override
  String get mcpConnectTestTimeout =>
      'No call arrived yet. Check that the connector is added, that you approved this workspace, and that the steps above are done; then test again.';

  @override
  String get mcpConnectTestTitle => 'Check that it works';

  @override
  String get mcpConnectTestWaiting =>
      'Waiting for your assistant to call DesKilo. Ask it:';

  @override
  String get mcpConnectTitle => 'Connect an assistant';

  @override
  String get mcpConnectTodoConnect =>
      'To do — you: follow the steps for your assistant below.';

  @override
  String get mcpConnectTodoYou => 'To do — you.';

  @override
  String get mcpConnectUnavailable => 'Could not be checked right now.';

  @override
  String get mcpConnectVscodeInstall => 'Add to VS Code';

  @override
  String get mcpConnectVscodeStep =>
      'VS Code asks to install DesKilo. Start it from the MCP servers list; a browser opens to sign in and pick this workspace.';

  @override
  String get mcpConnectWaitingDatabaseAdmin =>
      'Waiting for a database administrator to approve your request.';

  @override
  String mcpConnectWaitingOperator(String names) {
    return 'Waiting for the server\'s operator: $names.';
  }

  @override
  String get mcpConnectWaitingOperatorUnknown =>
      'Waiting for the server\'s operator, who is not named yet.';

  @override
  String get mcpConnectWaitingWorkspaceAdmin =>
      'Waiting for a workspace administrator to offer assistants here.';

  @override
  String get mcpConnectWhich => 'Which assistant do you use?';

  @override
  String get mcpConnectWorkspaceSelected => 'Selected workspace';

  @override
  String get mcpConnectWorkspacesHint =>
      'Each workspace decides for itself. When your assistant asks, you choose among the ready ones.';

  @override
  String get mcpConnectWorkspacesTitle => 'Your workspaces';

  @override
  String get mcpConnectWsConnected =>
      'Connected — an assistant may act for you here.';

  @override
  String get mcpConnectWsNotOffered =>
      'Assistants are on, but nothing is offered to your role yet. A workspace administrator decides.';

  @override
  String get mcpConnectWsOff =>
      'Assistants are off in this workspace. A workspace administrator turns them on in Assistant setup.';

  @override
  String get mcpConnectWsReady => 'Ready — choose it when your assistant asks.';

  @override
  String get mcpConnectWsUnknown =>
      'Shown once your access to assistants is approved.';

  @override
  String get mcpConnectedNoWorkspace =>
      'No workspace: this assistant can do nothing here.';

  @override
  String get mcpConnectedNone =>
      'No assistant is connected. Connect one from the assistant itself.';

  @override
  String get mcpConnectedTitle => 'Connected assistants';

  @override
  String get mcpConsentAlready =>
      'This assistant is already connected. Returning to it.';

  @override
  String get mcpConsentApprove => 'Connect';

  @override
  String mcpConsentAsks(String client) {
    return '$client asks to act for you in Deskilo.';
  }

  @override
  String get mcpConsentChoose =>
      'Choose each workspace and what it may do there. Nothing is chosen for you.';

  @override
  String mcpConsentClientBlocked(String name) {
    return 'The operator has blocked $name on this server. It cannot be connected.';
  }

  @override
  String mcpConsentClientWaiting(String name) {
    return '$name is not approved on this server yet. The operator approves each assistant once; then connect again from the assistant.';
  }

  @override
  String get mcpConsentConnected => 'Connected. Returning to the assistant.';

  @override
  String mcpConsentDeciderAsk(String name) {
    return 'Ask $name to decide.';
  }

  @override
  String get mcpConsentDeciderMe =>
      'You decide this yourself, in the installation console.';

  @override
  String get mcpConsentDeciderNobody => 'Nobody answers for this server yet.';

  @override
  String get mcpConsentDenied => 'Refused. The assistant gets nothing.';

  @override
  String get mcpConsentDeny => 'Deny';

  @override
  String get mcpConsentFamilyChatgpt =>
      'Approved for every ChatGPT connection.';

  @override
  String get mcpConsentFamilyClaude => 'Approved for every Claude connection.';

  @override
  String get mcpConsentFamilyLoopback =>
      'Approved for desktop and command-line assistants on this computer.';

  @override
  String get mcpConsentFieldsExplain =>
      'Details it may also see here. Leave them off to keep its answers minimised.';

  @override
  String get mcpConsentNoWorkspace =>
      'None of your workspaces lets assistants in. Nothing can be connected.';

  @override
  String get mcpConsentNotEligible =>
      'This database has not approved assistants for you yet. Ask for approval, then connect again.';

  @override
  String get mcpConsentPartial =>
      'The assistant was approved but the connection is not usable yet. Connect again from the assistant.';

  @override
  String mcpConsentRedirectHost(String host) {
    return 'The answer is sent to $host.';
  }

  @override
  String get mcpConsentRequestEligibility => 'Ask for approval';

  @override
  String get mcpConsentRequested =>
      'Approval requested. A database administrator will review it.';

  @override
  String get mcpConsentTitle => 'Connect an assistant';

  @override
  String get mcpConsentUnavailable =>
      'This connection request could not be loaded. Start again from the assistant.';

  @override
  String get mcpDisclosureMaximumExplain =>
      'The most that owners on this database may let assistants see. It never widens a workspace\'s policy or a person\'s consent.';

  @override
  String get mcpDisclosureMaximumLocked =>
      'Confirm with your second factor to see and change the maximum.';

  @override
  String get mcpDisclosureMaximumRefused =>
      'The maximum was not saved. It needs your second factor.';

  @override
  String get mcpDisclosureMaximumSave => 'Save the maximum';

  @override
  String get mcpDisclosureMaximumSaved => 'Maximum saved.';

  @override
  String get mcpDisclosureNoneAllowed =>
      'This database lets no optional detail be shown to assistants.';

  @override
  String get mcpDisclosurePolicyExplain =>
      'Assistants get minimised answers. Choose the details they may also see here; each person still chooses for themselves.';

  @override
  String get mcpDisclosurePreviewDetailed => 'Detailed answer';

  @override
  String get mcpDisclosurePreviewMinimised => 'Minimised answer';

  @override
  String get mcpDisclosurePreviewNote =>
      'A fictional answer, to show what assistants would see.';

  @override
  String get mcpDisclosureTitle => 'Optional details';

  @override
  String get mcpDisclosureUnlock => 'Confirm';

  @override
  String get mcpDisconnect => 'Disconnect';

  @override
  String get mcpDisconnectBody =>
      'The assistant loses access to every workspace on this database. What it already read is not taken back.';

  @override
  String mcpDisconnectTitle(String client) {
    return 'Disconnect $client?';
  }

  @override
  String get mcpEligibleExpired =>
      'Your approval expired. Ask again to keep using assistants.';

  @override
  String get mcpEligibleNoIdentity =>
      'Your identity is not confirmed for assistants on this database yet.';

  @override
  String get mcpEligibleNot =>
      'This database has not approved assistants for you.';

  @override
  String get mcpEligibleRequested =>
      'You asked for approval. A database administrator will review it.';

  @override
  String get mcpEligibleWithdraw => 'Give up assistant access on this database';

  @override
  String get mcpEligibleYes => 'This database allows you to use assistants.';

  @override
  String get mcpFieldName => 'Names of workspaces and places';

  @override
  String get mcpFieldNameSample => 'Window desk 12';

  @override
  String get mcpGroupFinancial => 'Financial requests';

  @override
  String get mcpGroupMembership => 'Membership requests';

  @override
  String get mcpGroupOwn => 'Own bookings and account';

  @override
  String get mcpGroupValidations => 'Validations';

  @override
  String get mcpIdentityConflict =>
      'Another account already holds this identity here — a database administrator can resolve it.';

  @override
  String get mcpIdentityIneligible =>
      'This account cannot be confirmed yet — confirm your e-mail address or sign in with a provider first.';

  @override
  String get mcpNextAwaitEligibility =>
      'Next: a database administrator decides your request.';

  @override
  String get mcpNextConsent =>
      'Next: connect an assistant from the assistant itself and approve this workspace.';

  @override
  String get mcpNextLinkGoogle =>
      'Assistants use your Google sign-in. Link Google to this account first; without it the account cannot use assistants.';

  @override
  String get mcpNextLinkIdentity =>
      'Next: confirm your identity for assistants on this database — one tap below.';

  @override
  String get mcpNextOwnerExposes =>
      'Next: the workspace owner offers operations to assistants.';

  @override
  String get mcpNextReady =>
      'Ready: a connected assistant may act for you in this workspace, within what you approved.';

  @override
  String get mcpNextRequestEligibility =>
      'Next: you ask this database\'s administrators for approval.';

  @override
  String get mcpNextRoleDenied =>
      'Your role leaves no operation to offer here. The workspace owner decides what each role may do.';

  @override
  String get mcpNextSignInGoogle =>
      'Assistants use your Google sign-in. Sign in with Google to continue.';

  @override
  String get mcpNextUnavailable =>
      'The server could not answer. Nothing is assumed; try again later.';

  @override
  String get mcpOpAvailability => 'See free places';

  @override
  String get mcpOpCancelReservation =>
      'Cancel your bookings that have not started';

  @override
  String get mcpOpCapabilities => 'See what it may do there';

  @override
  String get mcpOpCheckIn => 'Check you in';

  @override
  String get mcpOpCheckOut => 'Check you out';

  @override
  String get mcpOpCreateReservation => 'Book a place for you';

  @override
  String get mcpOpGetPlace => 'Describe a place, and show it when you ask';

  @override
  String get mcpOpGetValidation => 'Read a validation request';

  @override
  String get mcpOpInvoiceIssue => 'Issue an invoice';

  @override
  String get mcpOpInvoiceVoid => 'Void an invoice';

  @override
  String get mcpOpListMyFavorites => 'Your favourite places';

  @override
  String get mcpOpListWorkspaces => 'See which workspaces it may use';

  @override
  String get mcpOpMemberStatus => 'Change a member\'s status';

  @override
  String get mcpOpMyInvoices => 'See your invoices';

  @override
  String get mcpOpMyReservations => 'See your reservations';

  @override
  String get mcpOpMyStatement => 'See your account statement';

  @override
  String get mcpOpPendingValidations => 'See pending validation requests';

  @override
  String get mcpOpRatePlace => 'Rate places';

  @override
  String get mcpOpRefund => 'Refund an invoice';

  @override
  String get mcpOpReservationDeletion =>
      'Ask to delete a booking that has started';

  @override
  String get mcpOpRespond => 'Answer a validation request';

  @override
  String get mcpOpSetFavorite => 'Mark places as favourites';

  @override
  String get mcpOpSubscription => 'Change a member\'s subscription share';

  @override
  String get mcpOpUpdateReservation => 'Change your reservations';

  @override
  String get mcpOverviewTitle => 'Other connected databases';

  @override
  String get mcpOverviewUnavailable => 'Could not be asked right now.';

  @override
  String get mcpPolicyBroadening =>
      'Assistants already connected do not get the added services: each person must add them when they connect again.';

  @override
  String get mcpPolicyCeiling => 'Records an assistant may act on';

  @override
  String get mcpPolicyCeilingOwn => 'Own records only';

  @override
  String get mcpPolicyCeilingWorkspace => 'Workspace-wide';

  @override
  String get mcpPolicyConflict =>
      'This save was refused. Review the current settings and save again.';

  @override
  String get mcpPolicyEnabled => 'Offer assistant services';

  @override
  String get mcpPolicyExplain =>
      'Choose what assistants may do in this workspace. A member still needs this database\'s approval, the matching role, and must choose this workspace when connecting their assistant.';

  @override
  String get mcpPolicyFeatureOff =>
      'Assistants are switched off for this workspace in its features. You can still narrow or switch off the services below.';

  @override
  String get mcpPolicySave => 'Save';

  @override
  String get mcpPolicySaved => 'Saved.';

  @override
  String get mcpPolicyStale =>
      'Someone changed these settings meanwhile. Review the current settings and save again.';

  @override
  String get mcpPolicySwitched =>
      'You switched workspace. Reopen this page to edit the other workspace.';

  @override
  String get mcpPolicyTitle => 'Assistant access';

  @override
  String get mcpPolicyUnavailable =>
      'The assistant settings could not be loaded. Try again later.';

  @override
  String get mcpRefusalClientNotApproved =>
      'This assistant is not approved on this server yet. The operator approves each assistant once; ask them, then connect again from the assistant.';

  @override
  String get mcpRefusalNoIdentity =>
      'Confirm your identity in DesKilo under Assistants first, then connect again from the assistant.';

  @override
  String get mcpRefusalNotEligible =>
      'Your access to assistants is not approved yet. Ask for it in DesKilo under Assistants, then connect again from the assistant.';

  @override
  String get mcpRefusalOfferChanged =>
      'What this workspace offers changed while you were choosing. Connect again from the assistant to see the current offer.';

  @override
  String get mcpRefusalRequestExpired =>
      'This connection request has expired or was already used. Start again from the assistant.';

  @override
  String get mcpRemoveWorkspace => 'Remove this workspace';

  @override
  String get mcpReviewApprove => 'Approve';

  @override
  String get mcpReviewChanged =>
      'This request changed or another administrator decided first. Nothing was done.';

  @override
  String get mcpReviewDone => 'Decision recorded.';

  @override
  String get mcpReviewEmpty => 'No request is waiting.';

  @override
  String get mcpReviewExplain =>
      'Approving lets a person connect assistants on this database, in the workspaces whose owners allow it. It grants no membership or role.';

  @override
  String get mcpReviewNotAdmin =>
      'Only this database\'s administrators review approvals.';

  @override
  String get mcpReviewRefused => 'The decision was refused.';

  @override
  String get mcpReviewReject => 'Reject';

  @override
  String get mcpReviewSecondFactor =>
      'That database needs your second factor on its own session. Nothing was decided.';

  @override
  String get mcpReviewTitle => 'Assistant approvals';

  @override
  String get mcpReviewUnavailable =>
      'The requests could not be loaded. A review needs your second factor; try again.';

  @override
  String get mcpStateAfterPrevious => 'After the step above';

  @override
  String get mcpStateAllowed => 'Allowed';

  @override
  String get mcpStateApproved => 'Approved';

  @override
  String get mcpStateAvailable => 'Reachable';

  @override
  String get mcpStateCurrent => 'Given';

  @override
  String get mcpStateDenied => 'Nothing for your role';

  @override
  String get mcpStateDisabled => 'Nothing offered';

  @override
  String get mcpStateExposed => 'Operations offered';

  @override
  String get mcpStateGoogleMissing => 'Google not linked';

  @override
  String get mcpStateGoogleOtherSession => 'Signed in another way';

  @override
  String get mcpStateGoogleReady => 'Signed in with Google';

  @override
  String get mcpStateIncompatible => 'Incompatible version';

  @override
  String get mcpStateMissing => 'Not given';

  @override
  String get mcpStateNotRequested => 'Not requested';

  @override
  String get mcpStatePending => 'Waiting for a decision';

  @override
  String get mcpStateRevoked => 'Expired or withdrawn';

  @override
  String get mcpStateUnavailable => 'Unknown';

  @override
  String get mcpStateUnlinked => 'Not confirmed';

  @override
  String get mcpStateVerified => 'Verified';

  @override
  String get mcpStatusBackend => 'Server';

  @override
  String get mcpStatusConfirmIdentity => 'Confirm my identity';

  @override
  String get mcpStatusConsent => 'Your consent';

  @override
  String get mcpStatusEligibility => 'Database approval';

  @override
  String get mcpStatusExposure => 'Workspace offer';

  @override
  String get mcpStatusGoogle => 'Google sign-in';

  @override
  String get mcpStatusIdentity => 'Identity for assistants';

  @override
  String get mcpStatusLinkGoogle => 'Link Google';

  @override
  String get mcpStatusOpenLinkedAccounts => 'Open linked accounts';

  @override
  String get mcpStatusRole => 'Your role';

  @override
  String get mcpStatusSignInGoogle => 'Sign in with Google';

  @override
  String get mcpStatusTitle => 'Where you stand here';

  @override
  String get mcpUsageApplied => 'Applied';

  @override
  String mcpUsageLastUsed(String when) {
    return 'Last used $when';
  }

  @override
  String get mcpUsageMineTitle => 'Your assistant use today';

  @override
  String get mcpUsageNone => 'No assistant has used your access yet.';

  @override
  String get mcpUsagePending => 'Awaiting validation';

  @override
  String get mcpUsageRefusals => 'Refused';

  @override
  String get mcpUsageRequests => 'Requests';

  @override
  String get mcpUsageUnavailable => 'Usage could not be loaded.';

  @override
  String get mcpUsageWorkspaceTitle => 'Assistant use, last 30 days';

  @override
  String get meAccountInMe => 'My account is in Me';

  @override
  String get meAccountInMeBody =>
      'Photo, language, theme and sign-ins are yours in every space.';

  @override
  String get meAddressSaveFailed =>
      'Could not save your address. Please try again.';

  @override
  String get meCreateSpace => 'Create a space';

  @override
  String meFinanceGlanceOwed(String amount) {
    return 'To pay: $amount';
  }

  @override
  String get meFindSpace => 'Find a space';

  @override
  String get meGroupAdd => 'New group';

  @override
  String get meGroupDelete => 'Delete group';

  @override
  String get meGroupEmptyFavorites =>
      'Give a space a heart and it waits for you here.';

  @override
  String get meGroupEmptyOwn => 'Move spaces here from their menu.';

  @override
  String get meGroupFavorites => 'Favorites';

  @override
  String get meGroupInstallations => 'Connected installations';

  @override
  String get meGroupMove => 'Move to group…';

  @override
  String get meGroupName => 'Group name';

  @override
  String get meGroupOther => 'Other';

  @override
  String get meGroupProfile => 'My profile';

  @override
  String get meGroupRename => 'Rename';

  @override
  String get meGroupWorkspaces => 'My workspaces';

  @override
  String get meHeaderOwned => 'Your account · it belongs only to you';

  @override
  String get meHomeTitle => 'Home';

  @override
  String get meJoinSpace => 'Join with a code';

  @override
  String get meLeaveAction => 'Leave this space';

  @override
  String get meLeaveBody =>
      'You stop being a member. Your bookings, invoices and messages stay with the space. To also erase your data, use Privacy.';

  @override
  String meLeaveDone(String name) {
    return 'You left $name.';
  }

  @override
  String get meLeaveFailed => 'Could not leave the space. Please try again.';

  @override
  String get meLeaveOwner => 'Owners hand the space over before leaving';

  @override
  String meLeaveSide(String side) {
    return 'Leave $side';
  }

  @override
  String meLeaveTitle(String name) {
    return 'Leave $name?';
  }

  @override
  String meLinkedOpen(String host) {
    return 'Open on $host';
  }

  @override
  String meLinkedOpenBody(String host) {
    return 'This space lives on $host. The app works with one server at a time: opening it switches to that server and asks you to sign in there.';
  }

  @override
  String meLinkedPendingOn(String host) {
    return 'Waiting for approval · $host';
  }

  @override
  String meLinkedUnavailable(String host) {
    return '$host did not answer: this list may be incomplete.';
  }

  @override
  String get meManageSpaces => 'Manage my spaces';

  @override
  String get meMySpaces => 'My spaces';

  @override
  String get meNoSpaceBody =>
      'Find one near you, join with an invitation code, or create your own.';

  @override
  String get meNoSpaceTitle => 'You are not in a space yet';

  @override
  String get meSectionMine => 'My history and data';

  @override
  String get meSortAlphabet => 'A–Z';

  @override
  String get meSortHand => 'My order';

  @override
  String get meSortRating => 'Best rated';

  @override
  String get meSortRecent => 'Recently used';

  @override
  String get meSortTooltip => 'Sort';

  @override
  String get meSpaceException => 'In this space';

  @override
  String get meSpaceLastUsed => 'Last used';

  @override
  String get meSpaceOpen => 'Open';

  @override
  String get meSpacePending => 'Waiting for approval';

  @override
  String get meSpacesNoMatch => 'No space matches.';

  @override
  String get meSpacesSearch => 'Search my spaces';

  @override
  String get meTabDiscover => 'Discover';

  @override
  String get meTabHome => 'Home';

  @override
  String get meTabMe => 'Me';

  @override
  String get meTabMessages => 'Messages';

  @override
  String get meWhereSpacesLive => 'Where my spaces live';

  @override
  String get memberAccountTitle => 'My account';

  @override
  String get memberAllAdmins => 'all admins';

  @override
  String get memberApprove => 'Approve membership';

  @override
  String memberBadgesTitle(String name) {
    return 'Badges — $name';
  }

  @override
  String get memberBadgesTooltip => 'Badges';

  @override
  String get memberCoOwnerChip => 'Co-owner';

  @override
  String get memberCoOwnerPassiveChip => 'Successor';

  @override
  String get memberContactHeading => 'Contact';

  @override
  String get memberHomeSiteDefault => 'Workspace address';

  @override
  String get memberHomeSiteLabel => 'Home site';

  @override
  String memberInvoiceOpen(String amount) {
    return '$amount open';
  }

  @override
  String get memberInvoicePaid => 'Paid';

  @override
  String get memberInvoiceVoided => 'Voided';

  @override
  String get memberInvoicesBanner =>
      'All your invoices and payments, from every workspace, are in Me › Finances.';

  @override
  String get memberKioskLabel => 'Kiosk';

  @override
  String get memberMakeAdmin => 'Give the Administrator role';

  @override
  String get memberMakeKiosk => 'Make kiosk device';

  @override
  String get memberMakeMember => 'Take back the Administrator role';

  @override
  String get memberMessagesAction => 'Messages';

  @override
  String get memberMoneySettled => 'Nothing outstanding.';

  @override
  String get memberMoneyUnavailable =>
      'Money could not be loaded. Pull to refresh.';

  @override
  String get memberMonthInProgress => 'This month';

  @override
  String memberMoreInvoices(int count) {
    return '+$count more';
  }

  @override
  String get memberNoActions =>
      'Only the workspace owner can change this member.';

  @override
  String get memberNoSubscription => 'No subscription';

  @override
  String get memberNoSubscriptionPaygHint =>
      'No subscription is not possible with pay-as-you-go: choose blocked or a package first.';

  @override
  String get memberNoteDelete => 'Delete';

  @override
  String get memberNoteDeleteConfirm =>
      'Delete this message? This cannot be undone.';

  @override
  String get memberNoteDeleteNotMine =>
      'Only the sender can take a message back.';

  @override
  String get memberNoteDeleteRead =>
      'Already read — this message can no longer be taken back.';

  @override
  String get memberNoteDeleted => 'Message deleted.';

  @override
  String get memberNoteHint => 'Your message';

  @override
  String memberNoteReceived(String name) {
    return 'Message from $name';
  }

  @override
  String get memberNoteReply => 'Reply';

  @override
  String get memberNoteSend => 'Send';

  @override
  String get memberNoteSent => 'Notification sent.';

  @override
  String memberNoteTitle(String name) {
    return 'Notify $name';
  }

  @override
  String memberNoteTo(String name) {
    return 'To $name';
  }

  @override
  String get memberNoteToAllAdmins => 'To all admins';

  @override
  String get memberNotifyAction => 'Send notification';

  @override
  String get memberNotifyAllAdmins => 'Notify all admins';

  @override
  String get memberNumberLabel => 'Member no.';

  @override
  String get memberOriginDelegated => 'Profile created by an admin';

  @override
  String get memberOriginFounder => 'Founded this space';

  @override
  String get memberOriginHeading => 'How this membership began';

  @override
  String get memberOriginInvited => 'Joined by invitation';

  @override
  String get memberOveragePolicyLabel => 'When days run out';

  @override
  String get memberOveragePolicyTooltip => 'Over-consumption';

  @override
  String get memberPageAddService => 'Add a service';

  @override
  String memberPageCheckedIn(String seat, String time) {
    return 'Checked in · $seat · since $time';
  }

  @override
  String get memberPageEmailAction => 'E-mail';

  @override
  String get memberPageGroupAccess => 'Badges & access';

  @override
  String get memberPageGroupBilling => 'Billing';

  @override
  String get memberPageGroupBooking => 'Booking rules';

  @override
  String get memberPageGroupMembership => 'Membership';

  @override
  String get memberPageLevelTitle => 'Whole-space bookings';

  @override
  String get memberPageManageHeading => 'Manage';

  @override
  String get memberPageNeverSeen => 'Not seen yet';

  @override
  String memberPageNext(String label) {
    return 'Next: $label';
  }

  @override
  String get memberPageNone => 'None';

  @override
  String get memberPageNowHeading => 'Right now';

  @override
  String memberPageReservedNow(String seat, String time) {
    return 'Reserved now · $seat · until $time';
  }

  @override
  String memberPageSince(String date) {
    return 'Member since $date';
  }

  @override
  String get memberPageStatusActive => 'Active';

  @override
  String memberPageWorkspaceDefaultValue(int count) {
    return 'Workspace default ($count)';
  }

  @override
  String memberPageYou(String name) {
    return '$name (you)';
  }

  @override
  String get memberPause => 'Pause membership';

  @override
  String get memberPayments => 'Payments';

  @override
  String memberPlanShare(String pct) {
    return 'Plan $pct%';
  }

  @override
  String get memberReactivate => 'Reactivate membership';

  @override
  String get memberRejectJoin => 'Reject membership';

  @override
  String memberReservationLimitChip(int n) {
    return 'max $n';
  }

  @override
  String get memberReservationLimitCustom => 'Custom (1–100)';

  @override
  String get memberReservationLimitExplainer =>
      'How many open reservations this member may hold at the same time.';

  @override
  String get memberReservationLimitLabel => 'Reservation limit';

  @override
  String get memberReservationLimitNone => 'No limit';

  @override
  String get memberReservationLimitTooltip => 'Reservation limit';

  @override
  String get memberRoleAdmin => 'Administrator';

  @override
  String get memberRoleChangeRequested => 'Role change sent for validation.';

  @override
  String get memberRoleMember => 'Member';

  @override
  String get memberRoleOwner => 'Owner';

  @override
  String get memberRolesAdd => 'Add a role';

  @override
  String get memberRolesNone => 'No role: everything a member can do.';

  @override
  String get memberRolesTitle => 'Roles';

  @override
  String get memberRolesWhatTheyCanDo => 'What they can do here';

  @override
  String get memberSendAgreement => 'Send the financial agreement';

  @override
  String memberSimultaneousLimitChip(int n) {
    return '$n at once';
  }

  @override
  String get memberSimultaneousLimitDefault => 'Workspace default';

  @override
  String get memberSimultaneousLimitExplainer =>
      'How many bookings this member may hold over the same period. Unset follows the workspace default.';

  @override
  String get memberSimultaneousLimitLabel => 'Simultaneous reservations';

  @override
  String get memberStatusActive => 'Active';

  @override
  String get memberStatusExited => 'Exited';

  @override
  String get memberStatusPaused => 'Paused';

  @override
  String get memberStatusPending => 'Pending';

  @override
  String get memberSubscriptionCustom => 'Custom (1–100)';

  @override
  String get memberSubscriptionLabel => 'Subscription';

  @override
  String get memberUnmakeKiosk => 'Revert kiosk to member';

  @override
  String get memberVatTreatmentExplainer =>
      'Who this member is for VAT: the automatic rule (reverse charge for a business in another EU state), domestic VAT regardless, reverse charge, outside the EU, or an exempt buyer with the reason printed on the invoice.';

  @override
  String get memberVatTreatmentLabel => 'VAT treatment';

  @override
  String get membersInvite => 'Invite a member';

  @override
  String get membersPlanNone => 'No plan';

  @override
  String get membersTitle => 'Members & plans';

  @override
  String get messageInfo => 'Message info';

  @override
  String get messageNotReadYet => 'Not read yet';

  @override
  String get messageReadBy => 'Read by';

  @override
  String get messageRequestsHint =>
      'These people are outside the ones you chose to be reachable by. They are not told what you decide.';

  @override
  String get messageRequestsTitle => 'Message requests';

  @override
  String get messageSearchGroups => 'Groups';

  @override
  String get messageSearchHint => 'People, groups, messages';

  @override
  String get messageSearchMessages => 'Messages';

  @override
  String get messageSearchNothing => 'Nothing matched.';

  @override
  String get messageSearchPeople => 'People';

  @override
  String get messageSearchPrompt => 'Search people, groups and what was said.';

  @override
  String get messageSearchTitle => 'Search';

  @override
  String get messagesEmpty => 'No conversations yet.';

  @override
  String get messagesTitle => 'Messages';

  @override
  String get messengerContextAccount => 'Person to person';

  @override
  String get messengerContextGroup => 'Group';

  @override
  String messengerContextInquiryIn(String space) {
    return 'Inquiry to $space';
  }

  @override
  String messengerContextInquiryOut(String space) {
    return 'Your inquiry to $space';
  }

  @override
  String messengerContextSpace(String space) {
    return 'In $space';
  }

  @override
  String get messengerCopied => 'Copied.';

  @override
  String get messengerCopy => 'Copy text';

  @override
  String get messengerDelete => 'Delete message';

  @override
  String get messengerDeleteConfirm =>
      'Delete this message for everyone in the conversation?';

  @override
  String get messengerDeleted => 'Message deleted.';

  @override
  String get messengerDelivered => 'Delivered';

  @override
  String get messengerEdit => 'Edit';

  @override
  String get messengerEditFailed =>
      'This message could not be edited — the 15 minutes may be over.';

  @override
  String get messengerEditTitle => 'Edit message';

  @override
  String get messengerEditWindow =>
      'A message can be corrected for 15 minutes after it was sent.';

  @override
  String get messengerEdited => 'edited';

  @override
  String messengerEventCaptured(String actor) {
    return 'Screenshot taken by $actor';
  }

  @override
  String messengerEventDeleted(String actor) {
    return 'Deleted by $actor';
  }

  @override
  String messengerEventForwarded(String actor, String target) {
    return 'Forwarded by $actor to $target';
  }

  @override
  String messengerEventForwardedFrom(String actor, String context) {
    return 'Originally written by $actor in $context';
  }

  @override
  String messengerEventForwardedPrivate(String actor) {
    return 'Forwarded by $actor to a personal conversation';
  }

  @override
  String messengerEventOther(String event, String actor) {
    return '$event · $actor';
  }

  @override
  String messengerEventRead(String actor) {
    return 'Read by $actor';
  }

  @override
  String messengerEventSent(String actor) {
    return 'Sent by $actor';
  }

  @override
  String get messengerForward => 'Forward';

  @override
  String get messengerForwardExplain =>
      'Everyone in the original conversation, the author first, is told who forwarded it, when, and where to.';

  @override
  String get messengerForwardLocked =>
      'The author locked this message against forwarding.';

  @override
  String get messengerForwardNoTargets =>
      'No other conversation on this server to forward into.';

  @override
  String get messengerForwardTitle => 'Forward to';

  @override
  String messengerForwarded(String target) {
    return 'Forwarded to $target.';
  }

  @override
  String messengerForwardedFrom(String context, String author) {
    return 'Forwarded from $context · written by $author';
  }

  @override
  String get messengerHistory => 'What happened';

  @override
  String get messengerHistoryEmpty => 'Nothing recorded for this message yet.';

  @override
  String get messengerHostsIntro =>
      'Your message is read by these hosts of the space:';

  @override
  String get messengerHostsNone =>
      'This space has nobody answering messages right now.';

  @override
  String messengerInboxUnavailable(String servers) {
    return 'Not reachable right now: $servers. Their conversations are missing from this list.';
  }

  @override
  String get messengerInquiriesEmpty => 'No inquiries yet.';

  @override
  String get messengerInquiriesTitle => 'Inquiries';

  @override
  String get messengerInquiryClose => 'Close inquiry';

  @override
  String get messengerInquiryClosed => 'Inquiry closed.';

  @override
  String messengerInquiryFrom(String name) {
    return 'From $name';
  }

  @override
  String get messengerInquirySend => 'Send inquiry';

  @override
  String get messengerLock => 'Lock against forwarding';

  @override
  String get messengerMessageActions => 'Message actions';

  @override
  String get messengerNoStarred => 'No starred message yet.';

  @override
  String messengerNoticeCaptured(String actor) {
    return '$actor took a screenshot of this conversation.';
  }

  @override
  String messengerNoticeForwarded(String actor, String target) {
    return '$actor forwarded a message of this conversation to $target.';
  }

  @override
  String messengerNoticeForwardedPrivate(String actor) {
    return '$actor forwarded a message of this conversation to a personal conversation.';
  }

  @override
  String messengerOnServer(String server) {
    return 'on $server';
  }

  @override
  String get messengerRead => 'Read';

  @override
  String get messengerRefusedClosed => 'This inquiry is closed.';

  @override
  String get messengerRefusedForwardingOff =>
      'This space does not allow forwarding its messages.';

  @override
  String get messengerRefusedLimit => 'Too many at once. Please wait a minute.';

  @override
  String get messengerRefusedRequestPending =>
      'Your first message is waiting for an answer.';

  @override
  String get messengerRefusedTooLong =>
      'This message is too long for that conversation.';

  @override
  String get messengerRefusedUnavailable =>
      'This space does not take inquiries right now.';

  @override
  String get messengerStar => 'Star';

  @override
  String get messengerStarred => 'Starred';

  @override
  String get messengerUnlock => 'Allow forwarding';

  @override
  String get messengerUnstar => 'Remove star';

  @override
  String get messengerWriteToHosts => 'Write to the hosts';

  @override
  String get mfaCode => 'Six-digit code';

  @override
  String get mfaEnroll =>
      'Scan this code with an authenticator app, or enter the key, then type the six digits it shows.';

  @override
  String get mfaTitle => 'Confirm with your authenticator';

  @override
  String get mfaVerify => 'Verify';

  @override
  String get mfaWrong => 'That code was not accepted. Try the current one.';

  @override
  String get moneyAmountLabel => 'Amount';

  @override
  String get moneyBalance => 'Balance';

  @override
  String get moneyBaseFee => 'Base subscription';

  @override
  String get moneyCredits => 'Payments & credits';

  @override
  String get moneyDescriptionLabel => 'Description';

  @override
  String get moneyDocumentLibrary => 'Document library';

  @override
  String moneyDueIn(int days) {
    return 'Due in $days days';
  }

  @override
  String get moneyExpenseCategoryLabel => 'Category';

  @override
  String get moneyExpensePending => 'Expense submitted — waiting for approval.';

  @override
  String get moneyFaceDocuments => 'Documents';

  @override
  String get moneyFaceInvoices => 'Invoices';

  @override
  String get moneyFacePayments => 'Payments';

  @override
  String get moneyFaceStatement => 'Statement';

  @override
  String get moneyFaceUsage => 'Usage';

  @override
  String get moneyLedgerEmpty => 'No ledger entries yet.';

  @override
  String get moneyLedgerHeader => 'Ledger';

  @override
  String get moneyMyAgreement => 'My conditions';

  @override
  String get moneyNoInvoicesYet =>
      'No invoice yet — the month is invoiced by the workspace once it closes.';

  @override
  String get moneyNoteLabel => 'Note (optional)';

  @override
  String get moneyNothingOpen => 'Nothing open — you are up to date.';

  @override
  String moneyOpenInvoicesSummary(int count, String amount) {
    return '$count open · $amount due';
  }

  @override
  String get moneyOpenInvoicesTitle => 'Open invoices';

  @override
  String moneyOverage(int count) {
    return 'Overage ($count extra half-days)';
  }

  @override
  String moneyOverdueBanner(int count, String amount) {
    return '$count overdue — $amount to settle';
  }

  @override
  String moneyOverdueBy(int days) {
    return 'Overdue by $days days';
  }

  @override
  String get moneyPayNow => 'Pay now';

  @override
  String get moneyPaymentDateLabel => 'Payment date';

  @override
  String get moneyPaymentPending =>
      'Payment submitted — waiting for confirmation.';

  @override
  String get moneyPaymentPeriodLabel => 'Applies to';

  @override
  String get moneyRecordPayment => 'Record a payment';

  @override
  String moneyRemindedTimes(int count) {
    return 'Reminded ×$count';
  }

  @override
  String get moneySectionDocuments => 'Documents';

  @override
  String get moneySectionPay => 'Pay';

  @override
  String get moneySectionRequests => 'Requests';

  @override
  String get moneyStatementOpen => 'Open';

  @override
  String get moneyStatementPdf => 'This month\'s statement (PDF)';

  @override
  String get moneyStatementSettled => 'Settled';

  @override
  String get moneySubmitExpense => 'Submit an expense';

  @override
  String get moneySubmitPayment => 'Submit for confirmation';

  @override
  String moneySubscriptionPct(int pct) {
    return 'Subscription $pct%';
  }

  @override
  String moneyUsage(int used, int included) {
    return '$used of $included half-days used';
  }

  @override
  String moneyUsageUnlimited(int used) {
    return '$used half-days used';
  }

  @override
  String monthFreeCount(int free, int total) {
    return '$free/$total';
  }

  @override
  String get myBadgeTitle => 'My badge';

  @override
  String get myInvoicesTitle => 'My invoices';

  @override
  String get myVisitsHelp =>
      'Visits you asked for or were admitted to, as a guest. A visit is not a membership.';

  @override
  String get myVisitsTitle => 'My visits';

  @override
  String get navigationClassic =>
      'Classic: the bottom bar and the round button';

  @override
  String get navigationDefault => 'Default for this device';

  @override
  String get navigationMenu => 'Menu: the hamburger, like the web';

  @override
  String get navigationTitle => 'Navigation';

  @override
  String negotiationActiveSince(String month) {
    return 'Your deal applies since $month.';
  }

  @override
  String get negotiationCardTitle => 'My negotiated prices';

  @override
  String get negotiationDefaultColumn => 'Tariff';

  @override
  String get negotiationDiscount => 'Discount on supplements';

  @override
  String get negotiationFee => 'Monthly fee';

  @override
  String get negotiationItems => 'Services and packages';

  @override
  String get negotiationItemsHint =>
      'A unit price for this member; empty keeps the catalogue.';

  @override
  String get negotiationKeepCurrent => 'Keep current';

  @override
  String get negotiationMineColumn => 'Mine';

  @override
  String get negotiationNote => 'Note';

  @override
  String get negotiationOccupation => 'Occupation';

  @override
  String get negotiationOccupationHint =>
      'The share of open days included each month; applied to the member once validated.';

  @override
  String get negotiationOnTariff => 'You are on the workspace tariff.';

  @override
  String get negotiationOverage => 'Overage per half-day';

  @override
  String get negotiationPending => 'A deal is awaiting validation.';

  @override
  String get negotiationPendingBadge => 'awaiting validation';

  @override
  String negotiationPercent(int value) {
    return '$value %';
  }

  @override
  String get negotiationProposeHint =>
      'Leave a field empty to keep the tariff. The deal goes through validation before it applies.';

  @override
  String get negotiationProposeTitle => 'Price negotiation';

  @override
  String get negotiationProposed => 'Deal proposed — waiting for validation.';

  @override
  String get negotiationReadOnly => 'Read only';

  @override
  String get negotiationSubmit => 'Propose for validation';

  @override
  String get negotiationValidFrom => 'Applies from';

  @override
  String get negotiationWhoCanSee => 'Who can see this';

  @override
  String get newConversationGroupSwitch => 'Group';

  @override
  String get newConversationNoMembers => 'Nobody else here yet.';

  @override
  String get newConversationSearch => 'Search members';

  @override
  String get newConversationStart => 'Start chat';

  @override
  String get newConversationTapToOpen =>
      'Tap a person to open the chat; switch on Group to pick several.';

  @override
  String get newConversationTitle => 'New conversation';

  @override
  String get newGroupCreate => 'Create group';

  @override
  String get newGroupName => 'Group name';

  @override
  String get newGroupNameTaken =>
      'A group with that name already exists here. Pick another.';

  @override
  String get newMemberDefaultsConfigured =>
      'What somebody starts with when they join.';

  @override
  String get newMemberDefaultsTitle => 'New members';

  @override
  String get newMemberDefaultsUnavailable =>
      'These could not be read just now. Saving leaves them exactly as they are.';

  @override
  String get newMemberDefaultsUnset =>
      'Nothing chosen — new members start at 100% with bookings blocked once the entitlement is used.';

  @override
  String get newMemberOverageBlocked => 'Blocked once used up';

  @override
  String get newMemberOveragePackage => 'Must buy a package';

  @override
  String get newMemberOveragePayg => 'Pay as you go';

  @override
  String get newMemberSubscription => 'Subscription';

  @override
  String get newMemberSubscriptionLess => 'A smaller subscription';

  @override
  String get newMemberSubscriptionMore => 'A larger subscription';

  @override
  String newMemberSubscriptionValue(int percent) {
    return '$percent%';
  }

  @override
  String get nfcConfigChecking => 'Checking…';

  @override
  String get nfcConfigDeviceOff =>
      'NFC is turned off in this device\'s Android settings — turn it on to read RFID cards.';

  @override
  String get nfcConfigDeviceReady => 'NFC available and enabled';

  @override
  String get nfcConfigDeviceStatus => 'This device';

  @override
  String get nfcConfigDeviceUnavailable =>
      'No NFC here — Android with NFC on is needed (iPads have no NFC). QR badges still work.';

  @override
  String get nfcConfigEnable => 'Enable NFC badge check-in';

  @override
  String get nfcConfigEnableDesc =>
      'Show the card-tap option on kiosks and in the badge manager.';

  @override
  String get nfcConfigIntro =>
      'Members check in at a wall-mounted kiosk by tapping an RFID/NFC card. Register each member\'s card in Members & plans; at the kiosk they tap to reserve or check in.';

  @override
  String get nfcConfigTitle => 'RFID / NFC badges';

  @override
  String get noteRefAlert => 'Alert';

  @override
  String noteRefFilterCount(int shown, int total) {
    return '$shown of $total';
  }

  @override
  String get noteRefFilterEmpty => 'Nothing matches.';

  @override
  String get noteRefFilterLabel => 'Filter';

  @override
  String get noteRefGone => 'This reservation no longer exists.';

  @override
  String get noteRefInvoice => 'Invoice';

  @override
  String get noteRefNoReservations => 'No upcoming reservations to link.';

  @override
  String get noteRefNone => 'Nothing to reference yet.';

  @override
  String get noteRefPayment => 'Payment';

  @override
  String get noteRefPickAlert => 'Which alert?';

  @override
  String get noteRefPickInvoice => 'Which invoice?';

  @override
  String get noteRefPickPayment => 'Which payment?';

  @override
  String get noteRefPickValidation => 'Which validation?';

  @override
  String get noteRefRefund => 'Refund';

  @override
  String get noteRefReservation => 'Link a reservation';

  @override
  String get noteRefSpace => 'Link a space';

  @override
  String get noteRefValidation => 'Validation';

  @override
  String get noteRefWholeLevel => 'whole level';

  @override
  String get notesFilterEmpty => 'No unread messages — all caught up.';

  @override
  String get notesFilterRead => 'Read';

  @override
  String get notesFilterUnread => 'Unread';

  @override
  String get notifCategoryCheckIns => 'Check-ins';

  @override
  String get notifCategoryMembers => 'Members';

  @override
  String get notifCategoryMoney => 'Money';

  @override
  String get notifGroupBy => 'Group by';

  @override
  String get notifGroupByDate => 'Date';

  @override
  String get notifGroupByType => 'Type';

  @override
  String get notifGroupByUser => 'Member';

  @override
  String get notifSortByDate => 'Sort by date';

  @override
  String get notifUngroup => 'Ungroup';

  @override
  String get notificationsSystemOff =>
      'Android is blocking DesKilo notifications';

  @override
  String get notificationsSystemOffHint =>
      'Allow them under system Settings → Apps → DesKilo → Notifications — the icon badge needs them.';

  @override
  String get numberSequenceDateNone => 'None';

  @override
  String get numberSequenceDatePart => 'Date';

  @override
  String get numberSequenceDateRemovalBlocked =>
      'Numbers were already issued with the date. Removing it could repeat one — change the prefix or suffix too.';

  @override
  String get numberSequenceDateYear => 'Year';

  @override
  String get numberSequenceDateYearMonth => 'Year-month';

  @override
  String get numberSequenceDigits => 'Digits';

  @override
  String get numberSequenceGapless => 'Gapless — guaranteed';

  @override
  String get numberSequenceJournalCreditNote => 'Credit notes';

  @override
  String get numberSequenceJournalInvoice => 'Invoices';

  @override
  String get numberSequenceJournalMember => 'Members';

  @override
  String get numberSequenceJournalPayment => 'Payments';

  @override
  String get numberSequenceJournalVatDeclaration => 'VAT declarations';

  @override
  String get numberSequenceNext => 'Next number';

  @override
  String get numberSequencePrefix => 'Prefix';

  @override
  String get numberSequenceReset => 'Restart';

  @override
  String get numberSequenceResetLimited =>
      'A number restarts at most as often as it shows its date — otherwise it would print an earlier number again.';

  @override
  String get numberSequenceResetMonthly => 'Every month';

  @override
  String get numberSequenceResetNever => 'Never';

  @override
  String get numberSequenceResetWasInvalid =>
      'This series restarted more often than it shows its date. Save to keep a restart that cannot repeat a number.';

  @override
  String get numberSequenceResetYearly => 'Every year';

  @override
  String get numberSequenceSaved => 'Sequence saved.';

  @override
  String get numberSequenceSuffix => 'Suffix';

  @override
  String get numberSequencesIntro =>
      'One series per journal, gapless: the number is taken in the database the moment the document is issued, and a document that fails takes nothing. Changing the format never touches a document already issued.';

  @override
  String get numberSequencesSubtitle =>
      'How invoices and credit notes are numbered.';

  @override
  String get numberSequencesTitle => 'Number sequences';

  @override
  String get occurrenceAdded => 'Added to your expenses.';

  @override
  String get occurrenceConfirm => 'Confirm this expense';

  @override
  String get occurrenceReasonLabel => 'Why it differs (required)';

  @override
  String get occurrenceReasonMissing =>
      'A different amount needs an explanation.';

  @override
  String get occurrenceRejected =>
      'The validators rejected it — adjust the amount or the description and resend.';

  @override
  String get occurrenceResend => 'Resend for validation';

  @override
  String occurrenceScheduledAmount(Object amount) {
    return 'Validated: $amount';
  }

  @override
  String get occurrenceSentForValidation =>
      'Sent to the validators — it counts once they confirm.';

  @override
  String get officeSupplementLabel => 'Office reservations';

  @override
  String get onboardingConfirmIntro => 'This is what will be created:';

  @override
  String get onboardingCreateButton => 'Create workspace';

  @override
  String get onboardingCreateTab => 'Create a workspace';

  @override
  String get onboardingCreateWithoutTemplate => 'Create without a template';

  @override
  String get onboardingCurrencyUnknown =>
      'Enter a currency code the app supports, such as EUR';

  @override
  String get onboardingDiscardDraft =>
      'Your entries will be lost. This does not cancel a request already sent.';

  @override
  String get onboardingIntentChanged =>
      'Your earlier request may already have been created. Retry it exactly as it was sent before changing anything.';

  @override
  String get onboardingIntentResumed =>
      'An earlier creation may have gone through. Retry to check the same request.';

  @override
  String get onboardingJoinButton => 'Join';

  @override
  String get onboardingJoinTab => 'Join a workspace';

  @override
  String get onboardingRetryAsSent => 'Retry as sent';

  @override
  String get onboardingScanButton => 'Scan QR code';

  @override
  String get onboardingShapeLabel => 'What to create';

  @override
  String get onboardingShapePair => 'A linked test and real pair';

  @override
  String get onboardingShapeReal => 'One real workspace';

  @override
  String get onboardingShapeRealHint =>
      'For real operation: the invoices it issues are owed.';

  @override
  String get onboardingShapeTest => 'One test workspace';

  @override
  String get onboardingShapeTestHint =>
      'Safe for trying things out: every screen and document says it is a test. No real billing.';

  @override
  String get onboardingStartEmpty => 'Empty space';

  @override
  String get onboardingStartEmptyDesc =>
      'Draw your own plan from a blank canvas.';

  @override
  String get onboardingStartFrom => 'Start from';

  @override
  String get onboardingStepConfirm => 'Confirm';

  @override
  String get onboardingStepName => 'Name';

  @override
  String get onboardingStepWhere => 'Where';

  @override
  String get onboardingSummaryBillingOff =>
      'No real billing: documents are marked as a test.';

  @override
  String get onboardingSummaryBillingOn =>
      'Real billing is possible: its invoices are owed.';

  @override
  String onboardingSummaryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Creates $count workspaces',
      one: 'Creates one workspace',
    );
    return '$_temp0';
  }

  @override
  String onboardingSummaryServer(String host) {
    return 'On the server $host';
  }

  @override
  String onboardingTemplateSetsUp(String groups) {
    return 'Sets up: $groups';
  }

  @override
  String get onboardingTemplatesFailedEmpty =>
      'The templates could not be loaded, so this space would start empty. Go back to try again.';

  @override
  String get onboardingTitle => 'Welcome to DesKilo';

  @override
  String get onboardingUnconfirmed =>
      'The result could not be confirmed. Your entries are kept. Retry to check the same request.';

  @override
  String get onboardingUseSuggested => 'Use the suggested settings';

  @override
  String get onboardingWithTwin => 'Create the development and production pair';

  @override
  String get onboardingWithTwinHint =>
      'Two workspaces with the same name: one to try things out, one that is real. You own both.';

  @override
  String get overagePolicyBlocked => 'Block further booking';

  @override
  String get overagePolicyPackage => 'Require buying a package';

  @override
  String get overagePolicyPayg => 'Charge overage (pay-as-you-go)';

  @override
  String get payConfigConfigured => 'Configured';

  @override
  String get payConfigIntro =>
      'Enter each payment provider you want to offer. Keys are stored securely on the server and never shown again.';

  @override
  String get payConfigNotConfigured => 'Not configured';

  @override
  String get payConfigOpen => 'Configure';

  @override
  String get payConfigRemove => 'Remove';

  @override
  String get payConfigRemoved => 'Removed.';

  @override
  String get payConfigSaved => 'Saved.';

  @override
  String get payConfigSecretSet => 'Set — leave blank to keep';

  @override
  String get payConfigTitle => 'Online payments';

  @override
  String get payFieldApiKey => 'API key';

  @override
  String get payFieldClientId => 'Client ID';

  @override
  String get payFieldEnv => 'Environment';

  @override
  String get payFieldReturnUrl => 'Return URL';

  @override
  String get payFieldSecret => 'Secret';

  @override
  String get payFieldSecretKey => 'Secret key';

  @override
  String get payFieldWebhookId => 'Webhook ID';

  @override
  String get payFieldWebhookSecret => 'Webhook signing secret';

  @override
  String get payOnlineButton => 'Pay online';

  @override
  String get payOnlineChooseTitle => 'Pay online';

  @override
  String get payOnlineDiagHint => 'The server is missing this configuration:';

  @override
  String get payOnlineDiagTitle => 'Online payments — not configured';

  @override
  String payOnlineFailedDetail(
    String reference,
    String amount,
    String provider,
  ) {
    return 'Payment $reference ($amount via $provider) was not completed — nothing was credited; the balance is still owed.';
  }

  @override
  String get payOnlineFailedTitle => 'Online payment failed';

  @override
  String get payOnlineNotConfigured =>
      'Online payments aren\'t set up yet. Ask the workspace owner.';

  @override
  String payOnlinePendingDetail(
    String reference,
    String amount,
    String provider,
  ) {
    return 'Payment $reference ($amount via $provider) has not been confirmed by the provider yet, so the balance still shows what is owed. Quote this reference if it does not settle.';
  }

  @override
  String get payOnlinePendingTitle => 'Online payment pending';

  @override
  String get paymentAccountNumberLabel => 'Account number';

  @override
  String get paymentBankCodeLabel => 'Bank code';

  @override
  String get paymentBankNameLabel => 'Bank name';

  @override
  String get paymentBicLabel => 'BIC / SWIFT';

  @override
  String get paymentCopied => 'Copied.';

  @override
  String get paymentInstructionsHelper =>
      'Shown to members on an unpaid statement. Leave empty to show nothing.';

  @override
  String get paymentInstructionsIbanCopied => 'IBAN copied.';

  @override
  String get paymentInstructionsIbanTitle => 'IBAN';

  @override
  String get paymentInstructionsLydiaLabel => 'Lydia phone number or username';

  @override
  String get paymentInstructionsPaypalLabel => 'PayPal.me link or handle';

  @override
  String get paymentInstructionsReferenceLabel => 'Payment reference hint';

  @override
  String get paymentInstructionsTitle => 'Payment instructions';

  @override
  String get paymentInstructionsValueCopied => 'Copied to clipboard.';

  @override
  String get paymentInstructionsWeroLabel => 'Wero phone number';

  @override
  String get paymentInstructionsWiseLabel => 'Wisetag or Wise payment link';

  @override
  String get paymentMethodBankTransfer => 'Bank transfer';

  @override
  String get paymentMethodCard => 'Card';

  @override
  String get paymentMethodCash => 'Cash';

  @override
  String get paymentMethodLydia => 'Lydia';

  @override
  String get paymentMethodOther => 'Other';

  @override
  String get paymentMethodPaypal => 'PayPal';

  @override
  String get paymentMethodTwint => 'TWINT';

  @override
  String get paymentMethodWero => 'Wero';

  @override
  String get paymentMethodWise => 'Wise';

  @override
  String get paymentMethodsSubtitle =>
      'IBAN, PayPal, Wero, Lydia, Wise and the payment reference';

  @override
  String get paymentProviderMollie => 'Mollie — iDEAL, Bancontact…';

  @override
  String get paymentProviderStripe => 'Credit card (Stripe)';

  @override
  String get paymentProviderWero => 'Wero (via Mollie)';

  @override
  String get paymentRoutingNumberLabel => 'Routing number';

  @override
  String get paymentSortCodeLabel => 'Sort code';

  @override
  String get paymentTermsEdit => 'Request a change';

  @override
  String get paymentTermsFieldEscompte => 'Early-payment discount';

  @override
  String get paymentTermsFieldLatePenalty => 'Late-payment penalty';

  @override
  String get paymentTermsFieldRecovery => 'Recovery indemnity';

  @override
  String get paymentTermsFieldTerms => 'Payment terms';

  @override
  String get paymentTermsInherit => 'the workspace\'s default';

  @override
  String get paymentTermsInherited => 'Workspace default';

  @override
  String get paymentTermsMemberNote =>
      'These conditions are set by the workspace; a change goes through its validation.';

  @override
  String get paymentTermsNone => 'No conditions written yet';

  @override
  String get paymentTermsOverridden => 'Member\'s own';

  @override
  String get paymentTermsReason => 'Reason (optional)';

  @override
  String get paymentTermsRequestHint =>
      'Leave a field empty to keep the workspace\'s wording for it. The change applies once validated.';

  @override
  String get paymentTermsRequestTitle =>
      'Request a change of payment conditions';

  @override
  String get paymentTermsRequested => 'Change requested — pending validation';

  @override
  String get paymentTermsSubmit => 'Submit request';

  @override
  String get paymentTermsTitle => 'Payment conditions';

  @override
  String get paymentTermsUseDefault => 'Use the workspace default again';

  @override
  String get paymentTransitNumberLabel => 'Transit · institution';

  @override
  String get paymentsPendingTag => 'pending validation';

  @override
  String pendingApprovalBody(String workspace) {
    return 'You have joined $workspace. An administrator must approve your membership before you can use the workspace — you will get access as soon as they confirm.';
  }

  @override
  String get pendingApprovalRefresh => 'Check again';

  @override
  String get pendingApprovalTitle => 'Workspace membership awaiting approval';

  @override
  String get pendingAvailable =>
      'While you wait, your other workspaces, your account and the help stay available.';

  @override
  String get pendingHelp => 'Help';

  @override
  String pendingLastChecked(String time) {
    return 'Last checked $time';
  }

  @override
  String get pendingNotUpdated =>
      'Status not updated — the server could not be reached. Your request is unchanged.';

  @override
  String get pendingStillWaiting => 'Still awaiting approval.';

  @override
  String get pendingSwitchWorkspace => 'Switch workspace';

  @override
  String percentValue(int value) {
    return '$value%';
  }

  @override
  String get permAccessProd => 'Enter the production workspace';

  @override
  String get permApproveExpenses => 'Approve expenses';

  @override
  String get permDeployToDev => 'Deploy to development';

  @override
  String get permDeployToProd => 'Deploy to production';

  @override
  String get permDesignDocuments => 'Design the documents';

  @override
  String get permExportData => 'Export accounting and data';

  @override
  String get permIssueInvoices => 'Issue invoices & match payments';

  @override
  String get permMakeReservations => 'Book and use reservations';

  @override
  String get permManageBilling => 'Manage tariffs and billing rules';

  @override
  String get permManageConfiguration => 'Manage the configuration';

  @override
  String get permManageDocuments => 'Manage the document library';

  @override
  String get permManageIntegrations => 'Manage integrations';

  @override
  String get permManageMembers => 'Manage members';

  @override
  String get permManageNegotiations => 'Manage commercial agreements';

  @override
  String get permManageReservations => 'Manage reservations of others';

  @override
  String get permManageRoles => 'Manage roles & permissions';

  @override
  String get permManageServices => 'Manage services & packages';

  @override
  String get permManageSites => 'Manage sites and edit the floor plan';

  @override
  String get permManageValidation => 'Configure validation policies';

  @override
  String get permOperateKiosk => 'Operate the kiosk and badges';

  @override
  String get permPaymentTermsEdit => 'Request payment-condition changes';

  @override
  String get permUseMessages => 'Use the messenger';

  @override
  String get permViewAnalytics => 'Read the workspace figures';

  @override
  String get permViewCalendar => 'See the calendar';

  @override
  String get permViewDirectory => 'See the member directory';

  @override
  String get permViewDocuments => 'See the shared documents';

  @override
  String get permViewFinances => 'View workspace finances';

  @override
  String get permViewMyMoney => 'See their own account and invoices';

  @override
  String get permViewNegotiations => 'View commercial agreements';

  @override
  String get permViewPersonalData => 'Read members\' personal data';

  @override
  String get permWorkspaceSettings => 'Edit workspace settings';

  @override
  String get personalInfoCity => 'City';

  @override
  String get personalInfoCompany => 'Company (optional)';

  @override
  String get personalInfoCountry => 'Country';

  @override
  String get personalInfoEmail => 'E-mail for documents';

  @override
  String get personalInfoFirstName => 'First name';

  @override
  String get personalInfoLastName => 'Family name';

  @override
  String get personalInfoLegalId => 'Company / registration id (optional)';

  @override
  String get personalInfoNone => 'Not filled in yet';

  @override
  String get personalInfoPhone => 'Telephone';

  @override
  String get personalInfoPostalCode => 'Postal code';

  @override
  String get personalInfoPreview => 'On your documents';

  @override
  String get personalInfoSave => 'Save';

  @override
  String get personalInfoSaved => 'Personal information saved';

  @override
  String get personalInfoStreet => 'Street and number';

  @override
  String get personalInfoSubtitle =>
      'Printed on your invoices and letters. Your family name is written in capitals, as on official mail.';

  @override
  String get personalInfoTitle => 'Personal information';

  @override
  String get personalInfoVatId => 'VAT number (optional)';

  @override
  String placeFeedbackAverage(String average, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ratings',
      one: '1 rating',
    );
    return '$average · $_temp0';
  }

  @override
  String get placeFeedbackFailed => 'Could not save. Please try again.';

  @override
  String get placeFeedbackFavorite => 'Add to favourites';

  @override
  String get placeFeedbackNoRating => 'No rating yet';

  @override
  String placeFeedbackStars(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n stars',
      one: '1 star',
    );
    return '$_temp0';
  }

  @override
  String get placeFeedbackUnfavorite => 'Remove from favourites';

  @override
  String get placeFeedbackZero => '0 stars';

  @override
  String get planAccessorySupplementHint => 'Supplements are per half-day.';

  @override
  String get planActiveLabel => 'Active';

  @override
  String get planAfternoonChip => 'Afternoon';

  @override
  String get planAvailabilityLoading => 'Checking the opening days…';

  @override
  String get planBaseFeeLabel => 'Monthly base fee';

  @override
  String get planBookForLabel => 'Book for';

  @override
  String planBookedForPending(String name) {
    return 'Sent to $name for confirmation.';
  }

  @override
  String get planCancelReservationButton => 'Cancel reservation';

  @override
  String planCappedByNext(String time) {
    return 'The seat is reserved from $time.';
  }

  @override
  String get planCheckInButton => 'Check in';

  @override
  String get planCheckInFailed =>
      'Could not check in — the seat may have just been taken.';

  @override
  String planCheckInFor(String name) {
    return 'Check in $name';
  }

  @override
  String get planCheckInNotYetError =>
      'Check-in opens 15 minutes before the start.';

  @override
  String planCheckInOpensAt(String time) {
    return 'Check-in opens at $time';
  }

  @override
  String planCheckInOpensOn(String date) {
    return 'Check-in opens on $date';
  }

  @override
  String get planCheckInOverError =>
      'This reservation is over — check-in is no longer possible.';

  @override
  String get planCheckInTitle => 'Check in';

  @override
  String get planCheckOutButton => 'Check out';

  @override
  String planCheckOutFor(String name) {
    return 'Check out $name';
  }

  @override
  String get planClosedDay => 'Closed on this day';

  @override
  String get planClosedDayError => 'The workspace is closed on that day.';

  @override
  String planClosedDayShowNext(String day) {
    return 'Show $day';
  }

  @override
  String get planDurationLabel => 'Duration';

  @override
  String get planEndBeforeStart => 'End must be after start.';

  @override
  String get planFromLabel => 'From';

  @override
  String get planFullDayChip => 'Day';

  @override
  String get planFullDayError => 'Bookings here cover the full day.';

  @override
  String get planHalfDayError => 'Bookings here are per half day.';

  @override
  String get planIncludedHelper => 'Leave empty for unlimited';

  @override
  String get planIncludedLabel => 'Included half-days';

  @override
  String get planLevelLabel => 'Level';

  @override
  String get planLevelTooltip => 'Level';

  @override
  String get planListViewTooltip => 'List view';

  @override
  String get planMakeNotReservable => 'Make not reservable';

  @override
  String get planMakeReservable => 'Make reservable';

  @override
  String get planMapViewTooltip => 'Plan view';

  @override
  String get planMorningChip => 'Morning';

  @override
  String get planNameLabel => 'Name';

  @override
  String get planNoLevels => 'The workspace has no floor plan yet.';

  @override
  String get planNoSeats => 'This level has no seats yet.';

  @override
  String get planNowButton => 'Now';

  @override
  String planOccupiedBy(String name) {
    return 'Occupied by $name';
  }

  @override
  String get planOverageLabel => 'Price per extra half-day';

  @override
  String planOverruleDone(String name) {
    return 'Reservation removed — $name was notified.';
  }

  @override
  String planOverruleHint(String name) {
    return '$name and all admins will be notified.';
  }

  @override
  String get planOverruleRemove => 'Remove reservation (overrule)';

  @override
  String get planRepeatLabel => 'Repeat';

  @override
  String get planReservationsEmpty => 'No reservations for this day.';

  @override
  String get planReserveButton => 'Reserve';

  @override
  String planReservedBy(String name) {
    return 'Reserved by $name';
  }

  @override
  String get planSeatBlocked => 'This seat is blocked for maintenance.';

  @override
  String get planSendForConfirmation => 'Send for confirmation';

  @override
  String planSlotError(int minutes) {
    return 'Bookings must start and end on the $minutes-minute grid.';
  }

  @override
  String get planStartNow => 'Starts now';

  @override
  String planStartsAt(String time) {
    return 'Starts at $time';
  }

  @override
  String get planStateFree => 'Free';

  @override
  String get planStateYours => 'Yours';

  @override
  String get planToLabel => 'To';

  @override
  String planUntil(String time) {
    return 'until $time';
  }

  @override
  String get planUntilDateLabel => 'Repeat until';

  @override
  String get planUntilLabel => 'Until';

  @override
  String get planYourSeat => 'Your seat';

  @override
  String get plansEditorEdit => 'Edit plan';

  @override
  String get plansEditorInactive => 'Inactive';

  @override
  String get plansEditorNew => 'New plan';

  @override
  String plansEditorPerExtra(String price) {
    return '$price/extra half-day';
  }

  @override
  String plansEditorQuota(int count) {
    return '$count half-days';
  }

  @override
  String get plansEditorTitle => 'Plans';

  @override
  String get plansEditorUnlimited => 'unlimited half-days';

  @override
  String get policyAdminCheckoutDesc =>
      'An admin can end a member\'s running check-in.';

  @override
  String get policyAdminCheckoutTitle => 'Admins may check members out';

  @override
  String get policyAllowPastDesc =>
      'Members may record a booking that already ended (backfill).';

  @override
  String get policyAllowPastTitle => 'Allow past bookings';

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
  String get policyDurationConflict =>
      'The minimum cannot exceed the maximum — no booking would be accepted.';

  @override
  String get policyHorizonDesc =>
      'How many days ahead a booking may start. Beyond it the booking is refused.';

  @override
  String get policyHorizonTitle => 'Advance booking horizon';

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
  String get policyLimitsDesc =>
      'How far ahead a booking may be made, and how short or long it may be. These hold on every granularity.';

  @override
  String get policyLimitsTitle => 'Booking limits';

  @override
  String get policyMaxDurationDesc =>
      'The longest booking accepted. A booking ends on the day it starts, so a full day is the ceiling.';

  @override
  String get policyMaxDurationTitle => 'Maximum duration';

  @override
  String get policyMinDurationDesc =>
      'The shortest booking accepted. It is why arriving at 11:45 for a 12:00 half-day boundary is refused as too short.';

  @override
  String get policyMinDurationTitle => 'Minimum duration';

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
  String get policyOutsideHoursCharged => 'Charged';

  @override
  String get policyOutsideHoursChargedDesc =>
      'Allowed and counted like ordinary usage — except on a day the member already holds a regular booking.';

  @override
  String get policyOutsideHoursDesc =>
      'What may happen outside the working day — one answer, on every granularity. A booking that touches the working hours is an ordinary booking.';

  @override
  String get policyOutsideHoursFree => 'Free';

  @override
  String get policyOutsideHoursFreeDesc =>
      'Allowed, never counted and never charged — pure presence information.';

  @override
  String get policyOutsideHoursOff => 'Off';

  @override
  String get policyOutsideHoursOffDesc =>
      'Nothing outside the hours: no booking ahead, no walk-up, and a booking running past the day end is refused too.';

  @override
  String get policyOutsideHoursTitle => 'Outside the opening hours';

  @override
  String get policyOutsideHoursWalkUp => 'Spontaneous only';

  @override
  String get policyOutsideHoursWalkUpDesc =>
      'Walk-up check-ins stay possible, evening overtime included; booking ahead outside the hours is refused.';

  @override
  String get policySimultaneousDesc =>
      'How many overlapping bookings one member may hold. 1 keeps one place at a time.';

  @override
  String get policySimultaneousTitle => 'Simultaneous reservations per member';

  @override
  String get portalActionFailed =>
      'Could not save this change. Please try again.';

  @override
  String get portalActionNotNegotiated =>
      'This action is not available between this app and that server. Updating the app may help.';

  @override
  String get portalAddress => 'Public address';

  @override
  String get portalAdmin => 'Administrator';

  @override
  String get portalAdminVisible => 'Show me as a public administrator';

  @override
  String get portalAssociation => 'Association';

  @override
  String get portalAvailable => 'Let users find and message my account';

  @override
  String get portalChat => 'Chat';

  @override
  String get portalCompany => 'Company';

  @override
  String get portalConnect => 'Connect a server';

  @override
  String get portalConnectionFailed =>
      'Could not connect. Check this server and your sign-in details.';

  @override
  String get portalConnections => 'Connected servers';

  @override
  String get portalConnectionsHint =>
      'Each server uses its own sign-in. Disconnecting removes its saved access from this account on this device.';

  @override
  String get portalCopyEmail => 'Copy the e-mail';

  @override
  String get portalCustomised => 'Customised';

  @override
  String get portalDescription => 'Description';

  @override
  String get portalDirectoryIncompatible =>
      'Some workspaces need a newer version of the app and are not shown.';

  @override
  String get portalDirectoryUnavailable =>
      'Some directories could not be reached. Results are incomplete.';

  @override
  String get portalDisconnect => 'Disconnect';

  @override
  String get portalDiscover => 'Find a workspace';

  @override
  String get portalEmail => 'Public email';

  @override
  String get portalEmailCode => 'Email sign-in code';

  @override
  String get portalEmailCopied => 'E-mail copied';

  @override
  String get portalEmployed => 'Employed by this workspace';

  @override
  String get portalEmploymentHint =>
      'Employment does not change access or subscriptions. Salary payments are not enabled.';

  @override
  String get portalEnterSpace => 'Enter';

  @override
  String get portalFindPeople => 'Find available people';

  @override
  String get portalFollowsWorkspace => 'From workspace information';

  @override
  String get portalImage => 'Identity image URL';

  @override
  String get portalLatitude => 'Latitude';

  @override
  String get portalList => 'List';

  @override
  String get portalLongitude => 'Longitude';

  @override
  String get portalMap => 'Map';

  @override
  String get portalMessenger => 'Account messenger';

  @override
  String get portalMoreDirectories => 'More directories';

  @override
  String get portalNoLongerPublished =>
      'This workspace is no longer published.';

  @override
  String get portalNoWorkspaces => 'No published workspaces found.';

  @override
  String get portalOpenMe => 'Me: my account and my spaces';

  @override
  String get portalOwner => 'Owner';

  @override
  String get portalPerson => 'Private host';

  @override
  String get portalPhone => 'Public phone';

  @override
  String get portalPlans => 'Plans and prices';

  @override
  String get portalPreview => 'External view';

  @override
  String get portalPublicPlan => 'Public floor plan';

  @override
  String get portalPublication => 'Public workspace page';

  @override
  String get portalPublished => 'Visible in the public directory';

  @override
  String get portalRegisterDirectory => 'Publish a server in the directory';

  @override
  String get portalRequestProfile => 'Request a workspace profile';

  @override
  String get portalRequestSent =>
      'Request sent. The workspace will review your profile.';

  @override
  String get portalResetAll => 'Reset all public data to workspace information';

  @override
  String get portalResetAllBody =>
      'The public values of every field that has workspace information are replaced by it. Fields without a workspace counterpart keep what you typed.';

  @override
  String get portalResetAllConfirm => 'Reset';

  @override
  String get portalSavePreview => 'Save and preview the external view';

  @override
  String get portalSearch => 'Search workspaces';

  @override
  String get portalSendCode => 'Send sign-in code';

  @override
  String get portalSourceUnavailable =>
      'A server is unavailable. This overview is incomplete. Tap to retry.';

  @override
  String get portalThisServer => 'This server';

  @override
  String get portalUseCode => 'Use an email code';

  @override
  String get portalUseWorkspaceInfo => 'Use workspace information';

  @override
  String get portalVisibilityLink => 'Who can find and message me';

  @override
  String get portalVisibilityLinkBody => 'Chosen in Me, under Who sees me.';

  @override
  String get portalWebsite => 'Website';

  @override
  String get preferencesSaveFailed =>
      'Could not save your preferences. Please try again.';

  @override
  String get preferencesScopeHint =>
      'Language, appearance and regional formats. Off: edit my defaults.';

  @override
  String get preferencesUseDefaults => 'Use my defaults';

  @override
  String get preferencesWorkspaceOnly => 'Only for this workspace';

  @override
  String get priceGrossHint =>
      'Gross price — what the member pays; VAT is part of it.';

  @override
  String priceVatIncluded(String rate) {
    return 'incl. VAT $rate';
  }

  @override
  String get privacyErase => 'Leave this workspace and erase my data';

  @override
  String get privacyEraseConfirmButton => 'Erase';

  @override
  String privacyEraseConfirmHint(String phrase) {
    return 'This cannot be undone. Type $phrase to confirm.';
  }

  @override
  String get privacyEraseConfirmPhrase => 'ERASE';

  @override
  String get privacyEraseHint =>
      'Cancels your bookings, blanks your messages, clears your profile. Accounting records stay under the legal retention, by id, not by name (art. 17).';

  @override
  String get privacyEraseOwner =>
      'An owner hands the workspace over first (Members & plans → Co-ownership).';

  @override
  String get privacyErased => 'Your data has been erased.';

  @override
  String get privacyExport => 'Export my data';

  @override
  String get privacyExportHint =>
      'Everything you are the subject of, as one JSON file (art. 20).';

  @override
  String get privacyExportShareText => 'My DesKilo data export';

  @override
  String get privacyIntro =>
      'Your data is never tracked or sold, and is readable only by the roles the rules below name; where it is hosted is in this installation\'s privacy notice. These are your rights under the GDPR — each one is a button.';

  @override
  String privacyNoticeController(String name, String contact) {
    return 'Controller: $name — $contact';
  }

  @override
  String get privacyNoticeEssential =>
      'Needed to run the account and the space';

  @override
  String get privacyNoticeNotRecorded => 'not recorded by the operator';

  @override
  String get privacyNoticeOptional =>
      'Optional — you can use the app without it';

  @override
  String privacyNoticeRegion(String region) {
    return 'Region: $region';
  }

  @override
  String privacyNoticeRights(String contact) {
    return 'Your rights: $contact';
  }

  @override
  String get privacyNoticeRightsRoute => 'Your rights and the contact';

  @override
  String get privacyNoticeTitle => 'Who processes your data';

  @override
  String privacyNoticeTransfer(String mechanism) {
    return 'Transfer safeguard: $mechanism';
  }

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get privacyPushOnDevice => 'Push notifications on this device';

  @override
  String get privacyPushOnDeviceFailed =>
      'The choice could not be saved. Please try again.';

  @override
  String get privacyPushOnDeviceHint =>
      'Optional. On, this device\'s address and each notification go to the push service; off, the app keeps working and nothing is sent to this device.';

  @override
  String get privacySpaceNotice => 'This space\'s privacy notice';

  @override
  String get privacySpaceNoticeAcknowledge => 'I have read this notice';

  @override
  String get privacySpaceNoticeFailed =>
      'The acknowledgment could not be recorded. Please try again.';

  @override
  String get privacySpaceNoticeRead => 'You acknowledged this version.';

  @override
  String get privacySpaceNoticeUnread => 'Not acknowledged yet — read it here.';

  @override
  String get privacyTitle => 'Privacy & data';

  @override
  String get privacyWhoCanSee => 'Who can see my data';

  @override
  String get privacyWhoCanSeeHint =>
      'The rule per category, the people it names today, and who actually looked.';

  @override
  String processAlsoNeeds(String features) {
    return 'Switching it all on also needs: $features';
  }

  @override
  String processApplied(int count) {
    return '$count features changed.';
  }

  @override
  String get processBillingPayments => 'Billing & payments';

  @override
  String get processBillingPaymentsDesc =>
      'Turn activity into invoices and reconcile what is owed.';

  @override
  String processBlockedIntro(String feature, String features) {
    return '$feature is still needed by: $features';
  }

  @override
  String get processChangeFailed =>
      'The features could not be changed. Nothing was written; try again.';

  @override
  String processConfirmOff(int count) {
    return 'Switch off $count features';
  }

  @override
  String processConfirmOn(int count) {
    return 'Switch on $count features';
  }

  @override
  String get processConflict =>
      'Someone changed the features meanwhile. This is the updated preview — check it again.';

  @override
  String get processCoordination => 'Calendar & coordination';

  @override
  String get processCoordinationDesc =>
      'Coordinate activity, messages and decisions.';

  @override
  String get processDocumentsInformation => 'Documents & information';

  @override
  String get processDocumentsInformationDesc =>
      'Create, share and export workspace information.';

  @override
  String processFeatureCount(int enabled, int total) {
    return '$enabled of $total features on';
  }

  @override
  String get processFeatureOff => 'Off';

  @override
  String get processFeatureOn => 'On';

  @override
  String processFeatureWaiting(String feature) {
    return 'On, waiting for $feature';
  }

  @override
  String get processFilterAll => 'All';

  @override
  String get processFilterEmpty => 'No process matches this filter.';

  @override
  String processHeldBack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count features are on but wait for a switched-off prerequisite',
      one: '1 feature is on but waits for a switched-off prerequisite',
    );
    return '$_temp0';
  }

  @override
  String processInProcess(String process) {
    return 'in $process';
  }

  @override
  String get processIntegrations => 'Integrations & automation';

  @override
  String get processIntegrationsDesc =>
      'Deliver notifications and documents through external services.';

  @override
  String get processKeepDependants => 'Switch off anyway, keep their settings';

  @override
  String get processMembershipCommerce => 'Membership commerce';

  @override
  String get processMembershipCommerceDesc =>
      'Set service prices and member agreements.';

  @override
  String processNeededBy(String features) {
    return 'needed by $features';
  }

  @override
  String get processNothingToDo => 'Already the case — nothing to change.';

  @override
  String get processOperations => 'Operations & administration';

  @override
  String get processOperationsDesc =>
      'Maintain configuration and the application experience.';

  @override
  String processRemoveDependants(int count) {
    return 'Also switch off the $count dependants';
  }

  @override
  String get processReservationsUsage => 'Reservations & usage';

  @override
  String get processReservationsUsageDesc =>
      'Reserve capacity and track its use.';

  @override
  String get processSearchLabel => 'Search processes and features';

  @override
  String get processSectionAlreadyOn => 'Already on';

  @override
  String get processSectionAlsoNeeded => 'Also needed';

  @override
  String get processSectionAlsoOff => 'Also switched off';

  @override
  String get processSectionKeptWaiting => 'Stops working; its setting is kept';

  @override
  String get processSectionSwitchedOff => 'Switched off';

  @override
  String get processSectionSwitchedOn => 'Switched on';

  @override
  String get processSectionWorksAgain => 'Works again';

  @override
  String processSheetTitleOff(String name) {
    return 'Switch off $name';
  }

  @override
  String processSheetTitleOn(String name) {
    return 'Switch on $name';
  }

  @override
  String get processSpaceManagement => 'Space management';

  @override
  String get processSpaceManagementDesc =>
      'Organize the places members can use and when they open.';

  @override
  String get processStateActive => 'Active';

  @override
  String get processStateAvailable => 'Available';

  @override
  String get processStateNeedsAttention => 'Needs attention';

  @override
  String get processStatePartial => 'Partial';

  @override
  String processSubprocessCount(int active, int total) {
    return '$active of $total subprocesses active';
  }

  @override
  String get processSwitchHint =>
      'Tap a feature to change it among the switches.';

  @override
  String get processSwitchOff => 'Switch off';

  @override
  String get processSwitchOn => 'Switch on';

  @override
  String get processUnconfirmed =>
      'The change was written, but the app could not confirm it. Close and reopen the features to see the current state.';

  @override
  String get processWorkspaceAccess => 'Workspace & access';

  @override
  String get processWorkspaceAccessDesc =>
      'Manage membership, roles and access to the space.';

  @override
  String get profilePhotoChoose => 'Choose a photo';

  @override
  String get profilePhotoFileType => 'Image';

  @override
  String get profilePhotoNone => 'Tap to add a photo';

  @override
  String get profilePhotoRemove => 'Remove photo';

  @override
  String get profilePhotoRemoved => 'Photo removed';

  @override
  String get profilePhotoSaveFailed => 'Could not update the photo';

  @override
  String get profilePhotoSaved => 'Photo updated';

  @override
  String get profilePhotoSet => 'Tap to change';

  @override
  String get profilePhotoTitle => 'Photo';

  @override
  String get profileStatusFieldLabel => 'Status';

  @override
  String get profileStatusHelper =>
      'Optional. Visible to members of your workspaces in the member directory. Leave empty to clear it.';

  @override
  String get profileStatusHint => 'In a call · back at 14:00';

  @override
  String get profileStatusNone => 'No status';

  @override
  String get profileStatusSaveFailed => 'Could not save the status';

  @override
  String get profileStatusSaved => 'Status saved';

  @override
  String get profileStatusTitle => 'Status';

  @override
  String get profilesActive => 'Active profile';

  @override
  String get profilesAdd => 'Add a profile';

  @override
  String get profilesAllWorkspaces => 'Every workspace (platform owner)';

  @override
  String get profilesCopyEmail => 'Copy e-mail';

  @override
  String get profilesDefault => 'Default at startup';

  @override
  String get profilesEmailCopied => 'E-mail copied.';

  @override
  String get profilesMakeDefault => 'Use as default at startup';

  @override
  String profilesNotMember(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return 'Not a member · $_temp0';
  }

  @override
  String get profilesOwnersNone => 'No owner.';

  @override
  String profilesOwnersOf(String name) {
    return 'Owners of $name';
  }

  @override
  String get profilesPairDev => 'DEV';

  @override
  String get profilesPairProd => 'PROD';

  @override
  String profilesSiteLine(String site) {
    return 'Site: $site';
  }

  @override
  String get profilesSitePick => 'Change your site';

  @override
  String get profilesTitle => 'Profiles';

  @override
  String get profilesUnavailable => 'Your workspaces could not be loaded.';

  @override
  String provenanceFromTemplate(String name) {
    return 'From template «$name»';
  }

  @override
  String get provenanceProductDefault => 'Product default';

  @override
  String get provenanceResetToDefault => 'Reset to product default';

  @override
  String get provenanceResetToTemplate => 'Reset to template';

  @override
  String get provenanceWorkspaceSetting => 'Workspace setting';

  @override
  String get publicHolidaysAction => 'Add public holidays';

  @override
  String publicHolidaysConfirm(int count) {
    return 'Create $count closure days';
  }

  @override
  String get publicHolidaysCountry => 'Country';

  @override
  String publicHolidaysCreated(int count) {
    return '$count closure days created';
  }

  @override
  String get publicHolidaysLocked => 'Invoiced month — not created';

  @override
  String publicHolidaysLockedMonths(String months) {
    return 'Skipped, already invoiced: $months';
  }

  @override
  String get publicHolidaysNothingToCreate =>
      'Nothing to create — every day is already there.';

  @override
  String get publicHolidaysPresent => 'Already a closure day';

  @override
  String get publicHolidaysPreviewNone => 'No public holidays for this year.';

  @override
  String get publicHolidaysSheetTitle => 'Public holidays';

  @override
  String get publicHolidaysYear => 'Year';

  @override
  String get publicPersonUnavailable => 'This profile is not public.';

  @override
  String get publicProfileCopied => 'Link copied.';

  @override
  String get publicProfileCopy => 'Copy the link';

  @override
  String get publicProfileOff =>
      'Off: people who are not signed in see nothing of you.';

  @override
  String get publicProfileOn =>
      'Anyone with the link reads your name, profession and bio.';

  @override
  String get publicProfilePublishAction => 'Publish';

  @override
  String get publicProfilePublishBody =>
      'Anyone on the internet, signed in or not, will be able to read your name, profession and bio at your link. Your contact details, presence and spaces stay private.';

  @override
  String get publicProfilePublishTitle => 'Publish a public profile?';

  @override
  String get publicProfileTitle => 'Public profile';

  @override
  String get pushCancelledBody => 'A reservation was removed by an admin.';

  @override
  String get pushCancelledTitle => 'Reservation removed';

  @override
  String get pushPendingBody => 'Someone needs your confirmation.';

  @override
  String get pushPendingTitle => 'DesKilo';

  @override
  String get pushStatusNoTransport => 'This build has no push notifications';

  @override
  String get pushStatusNoTransportHint =>
      'Notifications arrive in the app and as local notifications on this device.';

  @override
  String get pushStatusNotConfigured => 'Push notifications are not set up yet';

  @override
  String get pushStatusNotConfiguredHint =>
      'The workspace owner completes the Firebase setup (push-setup guide).';

  @override
  String get pushStatusRegistered => 'Push notifications are active';

  @override
  String get questionEditorActive => 'Asked now';

  @override
  String get questionEditorChoices => 'Choices, one per line';

  @override
  String get questionEditorContextJoin => 'When joining';

  @override
  String get questionEditorContextManaged => 'A managed member\'s information';

  @override
  String get questionEditorContextProfile => 'A member\'s own information';

  @override
  String get questionEditorContexts => 'Where it is asked';

  @override
  String get questionEditorKey => 'Key';

  @override
  String get questionEditorKeyHelp =>
      'Lower-case letters, digits and underscores. It never changes: the answers point at it.';

  @override
  String questionEditorLabelFor(String locale) {
    return 'Label ($locale)';
  }

  @override
  String get questionEditorMax => 'Largest number';

  @override
  String get questionEditorMaxLength => 'Longest answer (characters)';

  @override
  String get questionEditorMin => 'Smallest number';

  @override
  String get questionEditorNotPersonalWarning =>
      'Still personal: the answer is linked to a member, so it is exported and erased with the membership whatever this switch says. Only a documented retention hold can keep it.';

  @override
  String get questionEditorPersonal => 'This is personal data';

  @override
  String get questionEditorPersonalHelp =>
      'Every answer is stored against a member, so it is personal data: carried in their data export and erased when they leave.';

  @override
  String get questionEditorPreview => 'How it will look';

  @override
  String get questionEditorRequired => 'Must be answered';

  @override
  String get questionEditorSave => 'Save the question';

  @override
  String get questionEditorSaveFailed => 'The question was not saved.';

  @override
  String get questionEditorType => 'Answer type';

  @override
  String get questionEditorVisibility => 'Who can see the answer';

  @override
  String get questionEditorVisibilityManagers =>
      'The member, and whoever may see personal data';

  @override
  String get questionEditorVisibilityMembers => 'Every member of the space';

  @override
  String get questionEditorVisibilitySelf => 'Only the member';

  @override
  String get questionTypeBoolean => 'Yes or no';

  @override
  String get questionTypeDate => 'A date';

  @override
  String get questionTypeDecimal => 'A number';

  @override
  String get questionTypeInteger => 'A whole number';

  @override
  String get questionTypeLongText => 'A long answer';

  @override
  String get questionTypeMultiChoice => 'Several of a list';

  @override
  String get questionTypeSingleChoice => 'One of a list';

  @override
  String get questionTypeText => 'A short answer';

  @override
  String get questionsAdd => 'Add a question';

  @override
  String get questionsEmpty => 'No questions yet.';

  @override
  String get questionsInactive => 'Put aside';

  @override
  String get questionsSubtitle =>
      'They appear inside personal information, under your space\'s name.';

  @override
  String get questionsTitle => 'Questions this space asks';

  @override
  String get quotaExceededError =>
      'Monthly half-day quota reached — request extra half-days from the Money tab.';

  @override
  String get quotaRequestButton => 'Request extra half-days';

  @override
  String get quotaRequestCountLabel => 'Number of half-days';

  @override
  String quotaRequestExplainer(String period) {
    return 'Your reservations are capped by your subscription. Extra half-days for $period apply once validated.';
  }

  @override
  String get quotaRequestPending => 'Request sent — waiting for validation.';

  @override
  String get quotaRequestTitle => 'Request extra half-days';

  @override
  String readinessActor(String who) {
    return 'Who: $who';
  }

  @override
  String get readinessActorAdministrator => 'A database administrator';

  @override
  String get readinessActorOperator => 'The server operator';

  @override
  String get readinessActorOwner => 'You';

  @override
  String readinessAll(String ready, String total) {
    return 'All sections ($ready of $total ready)';
  }

  @override
  String get readinessAreaAssistant => 'Assistant access (optional)';

  @override
  String get readinessAreaBackend => 'Server and database version';

  @override
  String get readinessAreaFirstBooking => 'A first booking';

  @override
  String get readinessAreaInvitations => 'Invite the first members';

  @override
  String get readinessAreaLocalSetup =>
      'Details your features need (identity, bank, platforms)';

  @override
  String get readinessAreaPayments => 'How members pay';

  @override
  String get readinessAreaPricing => 'Membership plans and tariffs';

  @override
  String get readinessAreaRecovery => 'Export and recovery';

  @override
  String get readinessAreaRegionRules => 'Opening days, time zone and currency';

  @override
  String get readinessAreaResources => 'Bookable places on the floor plan';

  @override
  String get readinessAreaRolesValidation => 'Roles and who validates requests';

  @override
  String readinessBlocked(String step) {
    return 'Before a first booking: $step';
  }

  @override
  String get readinessFirstBookingReady => 'Ready for a first booking';

  @override
  String get readinessLater => 'Needed later';

  @override
  String get readinessNeededFirst => 'Needed for a first booking';

  @override
  String readinessNext(String step) {
    return 'Next: $step';
  }

  @override
  String get readinessReasonEligibilityExpired =>
      'Your assistant eligibility has expired';

  @override
  String get readinessReasonEligibilityMissing =>
      'A database administrator has not approved you for assistants';

  @override
  String get readinessReasonEligibilityNoIdentity =>
      'Sign in with your verified identity first';

  @override
  String get readinessReasonEligibilityRequested =>
      'Your request waits for a database administrator';

  @override
  String get readinessReasonNoEvidence => 'No export or restore recorded yet';

  @override
  String get readinessReasonNoPolicies => 'No request waits for a validator';

  @override
  String get readinessReasonNotExposed =>
      'This space does not expose anything to assistants yet';

  @override
  String get readinessReasonRecentExport => 'A recent export is on record';

  @override
  String get readinessReasonStaleExport =>
      'The last recorded export is more than 90 days old';

  @override
  String get readinessReasonTooFewValidators =>
      'A policy asks for more validators than this space has';

  @override
  String get readinessSetAside => 'Set aside for later';

  @override
  String get readinessSetAsideAction => 'Later';

  @override
  String get readinessSetAsideFailed => 'That could not be saved. Try again.';

  @override
  String get readinessSetAsideUndo => 'Undo';

  @override
  String get readinessStateNeeds => 'Needs configuration';

  @override
  String get readinessStateNeedsOperator => 'Waiting for someone else';

  @override
  String get readinessStateNotApplicable => 'Not needed here';

  @override
  String get readinessStateReady => 'Ready';

  @override
  String get readinessStateUnavailable => 'Could not be read';

  @override
  String get readinessStateUnverified => 'Not verified yet';

  @override
  String get readinessTitle => 'Setting up this space';

  @override
  String get recordingPrivacyBadge => 'Filming mode — invented people';

  @override
  String get recordingPrivacyBadgeHint =>
      'Filming mode is on: every name, e-mail, telephone number, address and photograph on screen belongs to an invented person. The plan, the bookings and the figures are this workspace\'s own. Switch it off in Settings when you have finished filming.';

  @override
  String get recordingPrivacyWriteRefused =>
      'Not while filming mode is on: this form is showing an invented person, and saving it would write that over somebody\'s real details. Switch filming mode off first.';

  @override
  String get refFacetMonth => 'Month';

  @override
  String get refFacetPerson => 'Person';

  @override
  String get refFacetStatus => 'Status';

  @override
  String get refFacetType => 'Type';

  @override
  String get refFacetWorkspace => 'Workspace';

  @override
  String get refFilterAll => 'All';

  @override
  String get refFilterAmount => 'Amount';

  @override
  String get refFilterClear => 'Clear filters';

  @override
  String refFilterFindIn(String facet) {
    return 'Find in $facet';
  }

  @override
  String get refFilterMore => 'Filters';

  @override
  String get refFilterReset => 'Reset';

  @override
  String refFilterShow(int count) {
    return 'Show $count results';
  }

  @override
  String get refFilterSort => 'Sort';

  @override
  String get refSortAmountHigh => 'Highest amount';

  @override
  String get refSortAmountLow => 'Lowest amount';

  @override
  String get refSortNewest => 'Newest first';

  @override
  String get refSortOldest => 'Oldest first';

  @override
  String get refStatusCancelled => 'Cancelled';

  @override
  String get refStatusDecided => 'Decided';

  @override
  String get refStatusOpen => 'Open (unpaid)';

  @override
  String get refStatusPaid => 'Paid';

  @override
  String get refStatusPending => 'Pending';

  @override
  String get refStatusRefunded => 'Refunded';

  @override
  String get refTypeCreditNote => 'Credit note';

  @override
  String get refTypeInvoice => 'Invoice';

  @override
  String get refusalAlreadyDecided =>
      'Someone has already decided this. The list shows the outcome.';

  @override
  String get refusalChangedMeanwhile =>
      'This changed in the meantime. Reopen it to see where it stands.';

  @override
  String get refusalPermission =>
      'You do not have the permission for this. An owner of the space can grant it in Role management.';

  @override
  String get refusalSession =>
      'Your session has ended. Sign in again, then retry.';

  @override
  String get regionalClock => 'Clock';

  @override
  String get regionalClock12h => '12h';

  @override
  String get regionalClock24h => '24h';

  @override
  String get regionalClockAuto => 'Auto';

  @override
  String get regionalDeviceZone => 'Show times in my time zone';

  @override
  String get regionalDeviceZoneHint =>
      'Off: times show in the workspace\'s zone, the one bookings are made in. On: your device\'s, labelled where it differs.';

  @override
  String get regionalFollowLanguage => 'Automatic';

  @override
  String get regionalFormatLocale => 'Numbers & dates';

  @override
  String regionalFormatLocaleAuto(String locale) {
    return 'Follows the app language ($locale)';
  }

  @override
  String get regionalFormatsTitle => 'Region & formats';

  @override
  String get registerPaymentAmount => 'Amount';

  @override
  String get registerPaymentDate => 'Paid on';

  @override
  String get registerPaymentDone =>
      'Payment registered — the member confirms it from their side.';

  @override
  String get registerPaymentHint =>
      'A payment that reached the workspace — the member confirms it, then it can be matched to an invoice.';

  @override
  String get registerPaymentMember => 'Member';

  @override
  String get registerPaymentMethod => 'Method';

  @override
  String get registerPaymentNote => 'Note';

  @override
  String get registerPaymentSubmit => 'Register';

  @override
  String get registerPaymentTitle => 'Register a payment';

  @override
  String reminderBody(String target, String time) {
    return '$target starts at $time';
  }

  @override
  String reminderHistoryLine(int level, String origin, String date) {
    return 'Level $level · $origin · $date';
  }

  @override
  String get reminderHistoryRefresh => 'Check delivery again';

  @override
  String get reminderHistoryTitle => 'Reminder history';

  @override
  String get reminderOriginAutomatic => 'automatic';

  @override
  String get reminderOriginLegacy => 'earlier';

  @override
  String get reminderOriginManual => 'by hand';

  @override
  String get reminderPdfClosing =>
      'If you have already paid, please disregard this letter.';

  @override
  String get reminderPdfDays => 'days';

  @override
  String get reminderPdfDaysOpen => 'Open for';

  @override
  String get reminderPdfLevelLabel => 'Reminder level';

  @override
  String get reminderPdfOpeningFirm =>
      'despite our previous reminder, the invoice below remains unpaid. Please settle the amount without delay.';

  @override
  String get reminderPdfOpeningFriendly =>
      'this is a friendly reminder that the invoice below is still open. Perhaps it simply slipped through — no worries.';

  @override
  String get reminderPdfTitleFirm => 'Reminder';

  @override
  String get reminderPdfTitleFriendly => 'Payment reminder';

  @override
  String get reminderStatusAccepted =>
      'Accepted by the push service — not proof it was read';

  @override
  String get reminderStatusDeclared =>
      'Shared by the sender — their statement, not a receipt';

  @override
  String get reminderStatusFailed => 'Not delivered';

  @override
  String get reminderStatusLegacy =>
      'Recorded before delivery was tracked — unknown';

  @override
  String get reminderStatusPrepared => 'Prepared';

  @override
  String get reminderStatusQueued => 'Handed to the push service';

  @override
  String get reminderStatusUnknown => 'No answer from the push service';

  @override
  String get reminderTitle => 'Check in soon';

  @override
  String get repartitionAction => 'Distribute an expense';

  @override
  String get repartitionAmount => 'Total amount';

  @override
  String get repartitionAmountLabel => 'Amount';

  @override
  String get repartitionBooked => 'Repartition booked.';

  @override
  String get repartitionExclude => 'Leave out';

  @override
  String get repartitionFiled =>
      'Shares booked — they appear on the next usage invoice.';

  @override
  String get repartitionFiledPending =>
      'Shares filed — they book once validated.';

  @override
  String get repartitionHint =>
      'Split a shared cost over the members. The shares land as lines on each member\'s next usage invoice; a reversal gives the money back as credit notes.';

  @override
  String get repartitionHistory => 'Distributions';

  @override
  String get repartitionHistoryEmpty => 'No distribution yet.';

  @override
  String get repartitionMethod => 'Split by';

  @override
  String get repartitionMethodCustom => 'Custom key';

  @override
  String get repartitionMethodEqual => 'Equal';

  @override
  String get repartitionMethodSubscription => 'Subscription';

  @override
  String get repartitionMethodUsage => 'Usage';

  @override
  String get repartitionNoShares => 'Nobody carries a share — check the key.';

  @override
  String get repartitionPeriod => 'Lands on';

  @override
  String get repartitionPeriodLabel => 'Month';

  @override
  String get repartitionPreview => 'Shares';

  @override
  String get repartitionRememberRule => 'Remember this rule';

  @override
  String get repartitionReverse => 'Reversal — give back as credit notes';

  @override
  String get repartitionRuleHint =>
      'Each share is proposed by subscription percentage. Untick a member to leave them out; with the custom method, type their weight. The adjusted rule is proposed again next month.';

  @override
  String get repartitionRuleNotSaved =>
      'The rule could not be saved, so nothing was shared. Try again.';

  @override
  String get repartitionSharesTotal => 'Total of the shares';

  @override
  String get repartitionStatusConfirmed => 'Booked';

  @override
  String get repartitionStatusExpired => 'Expired';

  @override
  String get repartitionStatusPending => 'Awaiting validation';

  @override
  String get repartitionStatusRejected => 'Rejected';

  @override
  String get repartitionStepBook => 'Book';

  @override
  String get repartitionStepCost => 'The cost';

  @override
  String get repartitionStepExpense => 'The expense';

  @override
  String get repartitionStepRule => 'The rule';

  @override
  String get repartitionSubmit => 'Book the shares';

  @override
  String repartitionSum(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members · $amount',
      one: '1 member · $amount',
    );
    return '$_temp0';
  }

  @override
  String get repartitionTitle => 'Distribute an expense';

  @override
  String get repartitionTitleField => 'What for';

  @override
  String get repartitionTitleLabel => 'Title';

  @override
  String get repartitionWeight => 'Key';

  @override
  String get repartitionWizardSubtitle =>
      'Propose a split by subscription share, adjust, book';

  @override
  String get repartitionWizardTitle => 'Share a cost';

  @override
  String get repartitionWizardWeight => 'Weight';

  @override
  String get repeatDaily => 'Every day';

  @override
  String get repeatNone => 'Does not repeat';

  @override
  String get repeatWeekdays => 'Every weekday';

  @override
  String get repeatWeekly => 'Weekly';

  @override
  String get reportBadgesFooter =>
      'A lost badge should be revoked in Members & plans, not just replaced.';

  @override
  String get reportBadgesIntro =>
      'Cut along the lines. Each card carries one member\'s badge code — present it at the kiosk to check in.';

  @override
  String get reportBadgesTitle => 'Member badges';

  @override
  String get reportCoaAccounts => 'Suggested accounts';

  @override
  String get reportCoaDisclaimer =>
      'Preview only. DesKilo does not keep a ledger and does not do your accounting — your accountant\'s chart always wins.';

  @override
  String get reportCoaIntro =>
      'A suggestion, not your accounting. These are the accounts a bookkeeper in your country would usually use for a space like yours.';

  @override
  String get reportCoaLabel => 'Name';

  @override
  String get reportCoaNumber => 'Account';

  @override
  String get reportCoaTitle => 'Chart of accounts — preview';

  @override
  String get reportColQty => 'Qty';

  @override
  String get reportColTotal => 'Total';

  @override
  String get reportColUnitPrice => 'Unit price';

  @override
  String get reportDesignEmpty => 'Empty band — add an element below.';

  @override
  String get reportDesignErrorInvalidDesign =>
      'That file carries no readable design.';

  @override
  String get reportDesignErrorMalformed => 'That file is not readable JSON.';

  @override
  String get reportDesignErrorNotADesign =>
      'That file is not a DesKilo report design.';

  @override
  String get reportDesignErrorUnknownKind =>
      'That design is for a report this workspace does not have.';

  @override
  String get reportDesignErrorVersion =>
      'That design was written by a newer version of DesKilo.';

  @override
  String get reportDesignErrorWrongKind =>
      'That design belongs to a different report. Open that report and import it there.';

  @override
  String get reportDesignExport => 'Export this design';

  @override
  String get reportDesignFileTypeLabel => 'JSON';

  @override
  String get reportDesignImport => 'Import a design';

  @override
  String get reportDesignImported => 'Design imported. Save to keep it.';

  @override
  String get reportDesignerDesign => 'Design';

  @override
  String get reportDesignerDiscard => 'Discard';

  @override
  String get reportDesignerDiscardBody =>
      'Your changes to the templates are not saved.';

  @override
  String get reportDesignerDiscardTitle => 'Leave without saving?';

  @override
  String get reportDesignerDrag => 'Drag to reorder';

  @override
  String reportDesignerError(String message) {
    return 'The template does not render — $message';
  }

  @override
  String get reportDesignerFields => 'Fields';

  @override
  String get reportDesignerFieldsSearch => 'Search a field';

  @override
  String get reportDesignerInsert => 'Insert element';

  @override
  String get reportDesignerKeepEditing => 'Keep editing';

  @override
  String get reportDesignerMoveTo => 'Move to band';

  @override
  String reportDesignerPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String get reportDesignerPreview => 'Preview';

  @override
  String get reportDesignerRedo => 'Redo';

  @override
  String get reportDesignerReplace => 'Replace';

  @override
  String get reportDesignerReplaceBody =>
      'The bands of this document are replaced. Undo brings them back.';

  @override
  String get reportDesignerReplaceTitle => 'Replace the current layout?';

  @override
  String get reportDesignerSideBySide => 'Design and preview side by side';

  @override
  String get reportDesignerUndo => 'Undo';

  @override
  String get reportDesignerZoom => 'Zoom';

  @override
  String get reportDesignerZoomFit => 'Fit width';

  @override
  String get reportDocAgreement => 'Financial agreement';

  @override
  String get reportDocBadges => 'Member badges';

  @override
  String get reportDocCoa => 'Chart of accounts';

  @override
  String get reportDocPayments => 'Payments report';

  @override
  String get reportDocSpaceCodes => 'Space QR cards';

  @override
  String get reportDocStatus => 'Workspace status';

  @override
  String get reportDocUsage => 'Consumption report';

  @override
  String get reportDocVat => 'VAT report';

  @override
  String get reportDocWorkspace => 'Workspace report';

  @override
  String get reportDocWorkspaceSubtitle =>
      'Everything about the space — through the report editor\'s workspace template';

  @override
  String get reportEditorMarkup => 'Markup';

  @override
  String get reportEditorTitle => 'Report editor';

  @override
  String get reportEditorVisual => 'Visual';

  @override
  String get reportFieldGroupBank => 'Bank details';

  @override
  String get reportFieldGroupDocument => 'Document';

  @override
  String get reportFieldGroupLegal => 'Legal mentions';

  @override
  String get reportFieldGroupLoops => 'Lines & VAT loops';

  @override
  String get reportFieldGroupMember => 'Member & workspace';

  @override
  String get reportFieldGroupMoney => 'Amounts';

  @override
  String get reportFieldGroupSeller => 'Seller';

  @override
  String get reportFieldGroupSites => 'Sites';

  @override
  String get reportFieldGroupStatus => 'Workspace status';

  @override
  String get reportFieldGroupTexts => 'Your texts';

  @override
  String get reportFieldGroupUsage => 'Usage report';

  @override
  String get reportFieldGroupVat => 'VAT report';

  @override
  String get reportFieldMeaningAccountHolder => 'The account holder';

  @override
  String get reportFieldMeaningBankAccount => 'The account number';

  @override
  String get reportFieldMeaningBankCode => 'The bank code';

  @override
  String get reportFieldMeaningBankName => 'The bank\'s name';

  @override
  String get reportFieldMeaningBic => 'The bank\'s BIC';

  @override
  String get reportFieldMeaningBuyerReference =>
      'The buyer\'s own reference (public sector)';

  @override
  String get reportFieldMeaningCharges => 'The charges before payments';

  @override
  String get reportFieldMeaningClientAddress => 'The client\'s postal block';

  @override
  String get reportFieldMeaningClientCompany => 'The client\'s company';

  @override
  String get reportFieldMeaningClientEmail => 'The client\'s e-mail';

  @override
  String get reportFieldMeaningClientLegalId =>
      'The client\'s legal identifier (SIREN…)';

  @override
  String get reportFieldMeaningClientMemberNumber =>
      'The client\'s member number';

  @override
  String get reportFieldMeaningClientName => 'The client\'s full name';

  @override
  String get reportFieldMeaningClientPhone => 'The client\'s phone';

  @override
  String get reportFieldMeaningClientVatId => 'The client\'s VAT number';

  @override
  String get reportFieldMeaningCopy => 'True on a duplicate';

  @override
  String get reportFieldMeaningCreditNote => 'True on a credit note';

  @override
  String get reportFieldMeaningDueDate => 'The settlement date';

  @override
  String get reportFieldMeaningEscompte => 'The early-payment discount mention';

  @override
  String get reportFieldMeaningExemptionReason => 'The VAT exemption mention';

  @override
  String get reportFieldMeaningHasVat => 'True when VAT applies';

  @override
  String get reportFieldMeaningIban => 'The account\'s IBAN';

  @override
  String get reportFieldMeaningInsurance =>
      'The professional insurance mention';

  @override
  String get reportFieldMeaningIssued => 'The issue date';

  @override
  String get reportFieldMeaningIssuedBy => 'Who issued the document';

  @override
  String get reportFieldMeaningLatePenalty =>
      'The late-payment penalty mention';

  @override
  String get reportFieldMeaningLines => 'The invoice lines — a loop';

  @override
  String get reportFieldMeaningMember => 'The member\'s display name';

  @override
  String get reportFieldMeaningNetTotal => 'The total before VAT';

  @override
  String get reportFieldMeaningNumber => 'The document\'s number';

  @override
  String get reportFieldMeaningPaymentReference =>
      'The reference to quote when paying';

  @override
  String get reportFieldMeaningPaymentTerms => 'The payment terms mention';

  @override
  String get reportFieldMeaningPaymentTermsSource =>
      'Where the payment terms come from (member or workspace)';

  @override
  String get reportFieldMeaningPayments => 'Payments already received';

  @override
  String get reportFieldMeaningPendingExpensesTotal =>
      'Expenses still to validate';

  @override
  String get reportFieldMeaningPendingPaymentsTotal =>
      'Payments still to confirm';

  @override
  String get reportFieldMeaningPeriod => 'The month the document covers';

  @override
  String get reportFieldMeaningPeriodMonth =>
      'The month of the period, by name (« September »)';

  @override
  String get reportFieldMeaningPeriodYear => 'The year of the period';

  @override
  String get reportFieldMeaningProforma => 'True on a proforma';

  @override
  String get reportFieldMeaningPurchaseOrder =>
      'The buyer\'s purchase-order reference';

  @override
  String get reportFieldMeaningRecoveryIndemnity =>
      'The recovery indemnity mention';

  @override
  String get reportFieldMeaningRefundTotal => 'The amount refunded';

  @override
  String get reportFieldMeaningReplaces =>
      'The number of the invoice this one replaces';

  @override
  String get reportFieldMeaningSellerLegalForm => 'The seller\'s legal form';

  @override
  String get reportFieldMeaningSellerLegalId =>
      'The seller\'s legal identifier';

  @override
  String get reportFieldMeaningSellerRegistration =>
      'The seller\'s registration (SIREN, RNA…)';

  @override
  String get reportFieldMeaningSellerVatId => 'The seller\'s VAT number';

  @override
  String get reportFieldMeaningSiteAddress => 'The document site\'s address';

  @override
  String get reportFieldMeaningSiteName => 'The document site\'s name';

  @override
  String get reportFieldMeaningSpecialMentions =>
      'The workspace\'s special mentions';

  @override
  String get reportFieldMeaningStatusCreditNotes => 'The credit notes issued';

  @override
  String get reportFieldMeaningStatusCredits => 'The credits granted';

  @override
  String get reportFieldMeaningStatusFrom => 'The status period\'s first day';

  @override
  String get reportFieldMeaningStatusInvoiced => 'What the workspace invoiced';

  @override
  String get reportFieldMeaningStatusMembers =>
      'The member-by-member lines — a loop';

  @override
  String get reportFieldMeaningStatusNet => 'Revenues minus expenses';

  @override
  String get reportFieldMeaningStatusPayments => 'What was collected';

  @override
  String get reportFieldMeaningStatusReimbursed => 'What was reimbursed';

  @override
  String get reportFieldMeaningStatusRepartitioned => 'What was repartitioned';

  @override
  String get reportFieldMeaningStatusTo => 'The status period\'s last day';

  @override
  String get reportFieldMeaningTotal => 'The amount due, everything included';

  @override
  String get reportFieldMeaningUsageExtraHalfDays =>
      'Half-days beyond the subscription';

  @override
  String get reportFieldMeaningUsageIncludedHalfDays =>
      'Half-days included in the subscription';

  @override
  String get reportFieldMeaningUsageOverage => 'The overage charged';

  @override
  String get reportFieldMeaningUsagePaid => 'What the month\'s usage cost';

  @override
  String get reportFieldMeaningUsageRecords =>
      'Every consumption record — a loop';

  @override
  String get reportFieldMeaningUsageRemainingHalfDays => 'Half-days remaining';

  @override
  String get reportFieldMeaningUsageSites =>
      'The other sites the month stood at';

  @override
  String get reportFieldMeaningUsageSupplements => 'The accessory supplements';

  @override
  String get reportFieldMeaningUsageUsedHalfDays => 'Half-days used';

  @override
  String get reportFieldMeaningVat => 'VAT by rate — a loop';

  @override
  String get reportFieldMeaningVatBasisNote =>
      'Whether the period counts what was paid or what was issued';

  @override
  String get reportFieldMeaningVatExigibilityMention =>
      'When the VAT falls due, in words';

  @override
  String get reportFieldMeaningVatPeriod => 'The VAT period reported';

  @override
  String get reportFieldMeaningVatPeriodGross => 'The period\'s gross total';

  @override
  String get reportFieldMeaningVatPeriodNet => 'The period\'s net total';

  @override
  String get reportFieldMeaningVatPeriodVat => 'The period\'s VAT';

  @override
  String get reportFieldMeaningVatPositions =>
      'Every invoice of the VAT period — a loop';

  @override
  String get reportFieldMeaningVatRateTotals =>
      'The VAT period totals by rate — a loop';

  @override
  String get reportFieldMeaningVatTotal => 'The total VAT';

  @override
  String get reportFieldMeaningVoided => 'True when the invoice was cancelled';

  @override
  String get reportFieldMeaningWorkspace => 'The workspace\'s name';

  @override
  String get reportFieldMeaningWorkspaceAddress =>
      'The workspace\'s address, or the document site\'s';

  @override
  String get reportGuideInsertField => 'Insert a field…';

  @override
  String reportGuideInsertedInto(String band) {
    return 'Inserted into $band';
  }

  @override
  String get reportGuideIntro =>
      'Three bands make the PDF: header, body, footer. Write text, put a field where a value goes, and use one markup sign at the start of a line for its style. The e-invoice XML is never touched.';

  @override
  String get reportGuideMarkupTitle => 'Line markup';

  @override
  String get reportGuideSnippetIf => 'A line only when the value exists';

  @override
  String get reportGuideSnippetLoop => 'One row per invoice line';

  @override
  String get reportGuideSnippetTitle =>
      'The title: invoice, credit note or proforma';

  @override
  String get reportGuideSnippetsTitle => 'Ready-made pieces';

  @override
  String get reportGuideTitle => 'Placeholders and markup';

  @override
  String get reportImageAlign => 'Alignment';

  @override
  String get reportImageAlignCenter => 'Centre';

  @override
  String get reportImageAlignLeft => 'Left';

  @override
  String get reportImageAlignRight => 'Right';

  @override
  String get reportImageSize => 'Size';

  @override
  String get reportImageSizeLarge => 'Large';

  @override
  String get reportImageSizeMedium => 'Medium';

  @override
  String get reportImageSizeSmall => 'Small';

  @override
  String get reportImageUpload => 'Upload image';

  @override
  String get reportImagesEmpty =>
      'No image yet — upload your logo, a stamp or a signature and reference it with ![name].';

  @override
  String get reportImagesLoadFailed =>
      'Could not load report images. Try again.';

  @override
  String get reportImagesTitle => 'Report images';

  @override
  String get reportInsertImage => 'Insert image';

  @override
  String get reportLanguageAmbiguous =>
      'This country has several languages — set the workspace language in Workspace settings first.';

  @override
  String get reportLayoutActive => 'Layout active';

  @override
  String get reportLayoutBands => 'Bands';

  @override
  String get reportLayoutExport => 'Export XML';

  @override
  String get reportLayoutFileTypeLabel => 'XML';

  @override
  String get reportLayoutImport => 'Import XML';

  @override
  String get reportLayoutImported => 'Layout imported. Save to keep it.';

  @override
  String get reportLayoutPreview => 'Page preview';

  @override
  String get reportLayoutRemove => 'Remove layout (use bands)';

  @override
  String get reportLayoutSubtitle =>
      'A layout states where every element sits, in mm, cm, px or %. Export it, edit it, check it with `dart run tool/report.dart check`, import it back. When a layout exists it is what prints; remove it and the bands print again.';

  @override
  String get reportLayoutTitle => 'Positioned layout (XML)';

  @override
  String get reportLineBoldRow => 'Bold row';

  @override
  String get reportLineColumns => 'Columns start/end';

  @override
  String get reportLineColumnsSplit => 'Column break';

  @override
  String get reportLineDivider => 'Divider';

  @override
  String get reportLineImage => 'Image';

  @override
  String get reportLineLogic => 'Logic';

  @override
  String get reportLineRow => 'Table row';

  @override
  String get reportLineSection => 'Section';

  @override
  String get reportLineSmall => 'Small print';

  @override
  String get reportLineSpacer => 'Spacing';

  @override
  String get reportLineText => 'Text';

  @override
  String get reportLineTitle => 'Title';

  @override
  String get reportMarkupBoldRow => 'A bold table row';

  @override
  String get reportMarkupColumns => 'Side-by-side columns, split at |||';

  @override
  String get reportMarkupHeading => 'A large title';

  @override
  String get reportMarkupImage =>
      'A library image: size s/m/l, align left/center/right';

  @override
  String get reportMarkupRule => 'A horizontal rule';

  @override
  String get reportMarkupSection => 'A section heading';

  @override
  String get reportMarkupSmall => 'Small muted text';

  @override
  String get reportMarkupTable => 'A table row, one cell per |';

  @override
  String get reportPaymentsPeriodTotal => 'Payments this period';

  @override
  String get reportPendingExpenses => 'Pending expenses';

  @override
  String get reportPendingPayments => 'Pending payments';

  @override
  String get reportPresetClassic => 'Classic';

  @override
  String get reportPresetFormalLetter => 'Formal letter';

  @override
  String get reportPresetProfessional => 'Professional';

  @override
  String get reportPresetSimple => 'Simple';

  @override
  String get reportPresetVerbose => 'Detailed';

  @override
  String get reportPreviewFit => 'Fit the width';

  @override
  String get reportPreviewSimulated => 'Quick preview — sample data';

  @override
  String get reportPreviewTitle => 'Quick preview — your newest invoice';

  @override
  String get reportPreviewZoomIn => 'Zoom in';

  @override
  String get reportPreviewZoomOut => 'Zoom out';

  @override
  String get reportQuickView => 'Quick view';

  @override
  String get reportRegards => 'Kind regards';

  @override
  String get reportSectionFeatures => 'Features';

  @override
  String get reportSectionPrices => 'Prices';

  @override
  String get reportSpaceCodesFooter =>
      'A card that no longer matches its space misleads whoever scans it — reprint the sheet after moving or renaming a space.';

  @override
  String get reportSpaceCodesIntro =>
      'One card per seat, table, room and floor. Stick each card on its space: scanning it opens the same sheet the kiosk shows.';

  @override
  String get reportSpaceCodesTitle => 'Space codes';

  @override
  String get reportSubject => 'Subject';

  @override
  String get reportTemplateClearOverlay => 'Use the default for this language';

  @override
  String get reportTemplateLangDefault => 'Default (all languages)';

  @override
  String get reportTemplateLangInherits => 'Inherits the default';

  @override
  String get reportTemplateLangOverridden => 'Own template';

  @override
  String get reportTextsAdd => 'Add a text';

  @override
  String get reportTextsHint =>
      'Your own wording, placed in any band or layout as text.key. Each language may carry its own value; an empty one falls back to the default language.';

  @override
  String get reportTextsInherited => 'Default language';

  @override
  String get reportTextsKey => 'Key';

  @override
  String get reportTextsKeyExists => 'This key already exists.';

  @override
  String get reportTextsKeyHint =>
      'Letters, digits and underscores, e.g. greeting';

  @override
  String get reportTextsKeyInvalid =>
      'Use letters, digits and underscores only, starting with a letter.';

  @override
  String get reportTextsRemove => 'Remove text';

  @override
  String get reportTextsTitle => 'Texts';

  @override
  String get reportVisualAddLine => 'Add line';

  @override
  String get requestAccept => 'Accept';

  @override
  String get requestBlock => 'Block';

  @override
  String get requestIgnore => 'Ignore';

  @override
  String get reservationCalendarFileButton => 'Save calendar file';

  @override
  String get reservationCalendarFileContents => 'File contents';

  @override
  String get reservationCalendarFileEvent => 'Event';

  @override
  String get reservationCalendarFileLocation => 'Location';

  @override
  String get reservationCalendarFileName => 'File';

  @override
  String get reservationCalendarFileRefused =>
      'This booking cannot be exported: it is not yours, or it no longer exists.';

  @override
  String get reservationCalendarFileSnapshotNote =>
      'This file is a snapshot of the booking as it is now. If the booking is moved or cancelled later, a file already saved or shared does not change — and a shared file cannot be taken back.';

  @override
  String get reservationCalendarFileStale =>
      'The booking changed since this preview. Check it again before saving.';

  @override
  String get reservationCalendarFileStatus => 'Status';

  @override
  String get reservationCalendarFileStatusCancelled => 'Cancelled';

  @override
  String get reservationCalendarFileStatusConfirmed => 'Confirmed';

  @override
  String get reservationCalendarFileTitle => 'Calendar file';

  @override
  String get reservationCalendarFileWhen => 'When';

  @override
  String get reservationCancelledSnack => 'Reservation cancelled.';

  @override
  String get reservationDeleteReasonLabel => 'Reason (optional)';

  @override
  String get reservationDeleteRequestButton => 'Request deletion';

  @override
  String get reservationDeleteRequestExplain =>
      'Past or checked-in bookings are not deleted directly. An owner or admin will decide: was the check-in simply forgotten (the booking stays), or was it never used (it is removed)?';

  @override
  String get reservationDeleteSubmit => 'Send request';

  @override
  String get reservationDeleteSubmitted =>
      'Deletion requested — an owner or admin will decide.';

  @override
  String get reservationEditTimes => 'Edit times';

  @override
  String get reservationEndEarlyAheadOnly =>
      'Pick a time still ahead of now and before the current end.';

  @override
  String get reservationEndEarlyButton => 'End earlier';

  @override
  String get reservationExtendButton => 'Stay longer';

  @override
  String get reservationExtendLaterOnly => 'Pick a time after the current end.';

  @override
  String get reservationLimitError =>
      'Reservation limit reached — you already hold the maximum number of open reservations.';

  @override
  String reservationNoteCheckedOutAt(String time) {
    return 'Completed: checked out at $time.';
  }

  @override
  String get reservationNoteOverNotCheckedIn =>
      'This period is over without a check-in.';

  @override
  String get reservationNoteRecordedAfterEnd =>
      'Recorded after this period had ended, so it is kept as a past visit.';

  @override
  String get reservationRecurring => 'Recurring booking';

  @override
  String get reservationUpdatedSnack => 'Reservation updated.';

  @override
  String get reserveAvailabilityUnavailable =>
      'Availability could not be loaded completely, so no seat is shown as free. Retry to see it.';

  @override
  String get reserveBackToNow => 'Back to now';

  @override
  String get reserveBookingFailed =>
      'Could not reserve — the seat may have just been taken.';

  @override
  String get reserveClosedShort => 'Closed';

  @override
  String get reserveDayView => 'Day';

  @override
  String get reserveFullDayChip => 'Full day';

  @override
  String get reserveMonthView => 'Month';

  @override
  String get reservePickDateTooltip => 'Choose a date';

  @override
  String reserveStaleAvailability(String time) {
    return 'Offline — availability as of $time. A seat shown free may have been taken since.';
  }

  @override
  String get reserveStaleRetry => 'Retry';

  @override
  String get reserveViewMenu => 'View';

  @override
  String get reserveWeekView => 'Week';

  @override
  String get reverseChargeSubtitle =>
      'A customer with a VAT number in another member state is invoiced without tax and self-assesses it (art. 196). Turn it off if you never invoice businesses abroad.';

  @override
  String get reverseChargeTitle => 'Reverse charge for EU businesses';

  @override
  String get rightsKindAccess => 'See a copy of my data';

  @override
  String get rightsKindErasure => 'Erase my data';

  @override
  String get rightsKindObjection => 'Object to a use of my data';

  @override
  String get rightsKindPortability =>
      'Take my data elsewhere (machine-readable)';

  @override
  String get rightsKindRectification => 'Correct my data';

  @override
  String get rightsKindRestriction => 'Restrict how my data is used';

  @override
  String get rightsRequestAsk => 'What do you ask the space?';

  @override
  String get rightsRequestDetails => 'Details (optional)';

  @override
  String get rightsRequestFailed =>
      'The request could not be sent. Please try again.';

  @override
  String get rightsRequestNew => 'Make a request';

  @override
  String get rightsRequestSend => 'Send the request';

  @override
  String rightsRequestSent(String date) {
    return 'Request sent — the space answers by $date.';
  }

  @override
  String get rightsRequestsEmpty => 'No request yet.';

  @override
  String get rightsRequestsHint =>
      'Ask the space for a copy, a correction, a restriction or erasure — answered within one calendar month.';

  @override
  String get rightsRequestsTitle => 'My rights requests';

  @override
  String get rightsStatusCompleted =>
      'Answered — the space recorded what it did';

  @override
  String rightsStatusExtended(String date, String reason) {
    return 'Extended to $date: $reason';
  }

  @override
  String rightsStatusReceived(String date) {
    return 'Received — answer due by $date';
  }

  @override
  String rightsStatusRefused(String reason) {
    return 'Refused: $reason';
  }

  @override
  String get roleAdmin => 'Administrator';

  @override
  String get roleAssignImmediateHint => 'Takes effect at once.';

  @override
  String get roleAssignNothing => 'There is no role left to give.';

  @override
  String get roleAssignQuorumHint => 'Takes effect once validated.';

  @override
  String roleAssignSheetTitle(String name) {
    return 'Give a role to $name';
  }

  @override
  String get roleBuiltInNote =>
      'Built in. What it may do is set in Roles; it is given on each member\'s page and takes effect once validated.';

  @override
  String get roleBuiltInSubtitle => 'Built in. What it may do is set in Roles.';

  @override
  String get roleEditorActive => 'In use';

  @override
  String get roleEditorHolders => 'Members in this role';

  @override
  String get roleEditorKey => 'Key';

  @override
  String get roleEditorKeyHelp =>
      'Lower-case letters, digits and underscores. It never changes: the people who hold the role point at it.';

  @override
  String roleEditorNameFor(String locale) {
    return 'Name ($locale)';
  }

  @override
  String get roleEditorNobody => 'Nobody yet.';

  @override
  String get roleEditorNotYourself => 'You cannot give a role to yourself.';

  @override
  String get roleEditorPermissions => 'What it adds';

  @override
  String get roleEditorSave => 'Save the role';

  @override
  String get roleEditorSaveFailed => 'The role was not saved.';

  @override
  String get roleGiveFailed => 'The role was not given.';

  @override
  String get roleGiven => 'Role given.';

  @override
  String get roleHoldersAdd => 'Add a member';

  @override
  String get roleMember => 'Every member';

  @override
  String get roleOwner => 'Owner';

  @override
  String get roleRefusalExceedsYours =>
      'This role can do things you cannot, so only the owner gives it.';

  @override
  String get roleRefusalNotAssignable => 'This member cannot hold this role.';

  @override
  String get roleRefusalNotPermitted =>
      'Only someone who manages roles can give this one.';

  @override
  String get roleRefusalOwnerOnly =>
      'Only the owner gives a role that manages roles.';

  @override
  String get roleRenameAdministrator => 'Rename';

  @override
  String get roleTakeBackFailed => 'The role was not taken back.';

  @override
  String get roleTakenBack => 'Role taken back.';

  @override
  String get rolesIntroEditor =>
      'Everyone has exactly one base role — User, Administrator, Co-owner or Owner. Any other role adds what its holders may do and never takes anything away. The owner always holds every permission; a co-owner may hold less.';

  @override
  String get rolesIntroReadOnly =>
      'Read-only: these are the permissions each role holds. Your role is highlighted.';

  @override
  String get rolesOfSpaceAdd => 'Add a role';

  @override
  String get rolesOfSpaceEmpty => 'No roles yet.';

  @override
  String get rolesOfSpaceInactive => 'Put aside';

  @override
  String get rolesOfSpaceSubtitle =>
      'Each one adds permissions to what its holders can already do. None takes anything away, and the owner always keeps every permission.';

  @override
  String get rolesOfSpaceTitle => 'Roles this space defines';

  @override
  String get rolesOwnRolesLink => 'The roles this space defines';

  @override
  String get rolesTitle => 'Roles';

  @override
  String get rolesYourRole => 'Your role';

  @override
  String get saftDocumentsOnly => 'Documents only';

  @override
  String get saftLedgerIntro =>
      'With account numbers, the file carries double-entry postings your accountant can import instead of keying in. They cover your sales and the payments against them — not your whole books.';

  @override
  String get saftLedgerTitle => 'Include postings?';

  @override
  String get saftWithPostings => 'With postings';

  @override
  String get sageAccountsIntro =>
      'The defaults are Sage’s own shipped nominal codes. The tax code decides which VAT return these land on, so check it with your accountant if you are not on the standard rate.';

  @override
  String get sageAccountsTitle => 'Sage export';

  @override
  String get sageTaxCode => 'VAT code (T1 / T0 / T9)';

  @override
  String get scanCameraWebUnavailable =>
      'Camera scanning is not available in the browser — type the code, or hold an NFC tag to the device (Chrome on Android).';

  @override
  String get scanJoinHelp =>
      'Point the camera at the invitation QR — you see the workspace before you join.';

  @override
  String get scanJoinNotAnInvite =>
      'That QR is not a DesKilo invitation — scan the one from the invitation message.';

  @override
  String get scanJoinTitle => 'Scan workspace QR';

  @override
  String get scheduleCancel => 'End this schedule';

  @override
  String get scheduleDaily => 'daily';

  @override
  String get scheduleEndsOn => 'Until (optional)';

  @override
  String scheduleEveryDays(Object count) {
    return 'every $count days';
  }

  @override
  String get scheduleEveryLabel => 'Every';

  @override
  String scheduleEveryMonths(Object count) {
    return 'every $count months';
  }

  @override
  String scheduleEveryWeeks(Object count) {
    return 'every $count weeks';
  }

  @override
  String get scheduleMissingFields => 'Name and amount are needed.';

  @override
  String get scheduleMonthly => 'monthly';

  @override
  String get scheduleNew => 'Schedule a recurring expense';

  @override
  String scheduleNextDue(Object date) {
    return 'next: $date';
  }

  @override
  String get scheduleNoEnd => 'No end date';

  @override
  String get schedulePending =>
      'Scheduled — waiting for the validators to confirm it.';

  @override
  String get scheduleStartsOn => 'First occurrence';

  @override
  String get scheduleStatusActive => 'Active';

  @override
  String get scheduleStatusEnded => 'Ended';

  @override
  String get scheduleStatusPending => 'Awaiting validation';

  @override
  String get scheduleStatusRejected => 'Rejected';

  @override
  String get scheduleSubmit => 'Schedule it';

  @override
  String scheduleTimes(Object count) {
    return '$count times';
  }

  @override
  String get scheduleTimesLabel => 'Repetitions (empty = until the end date)';

  @override
  String get scheduleTitleLabel => 'What (e.g. Internet)';

  @override
  String get scheduleUnitDays => 'days';

  @override
  String get scheduleUnitLabel => 'Unit';

  @override
  String get scheduleUnitMonths => 'months';

  @override
  String get scheduleUnitWeeks => 'weeks';

  @override
  String get scheduleUnitYears => 'years';

  @override
  String scheduleUntil(Object date) {
    return 'until $date';
  }

  @override
  String get scheduleValidationHint =>
      'The schedule goes to the validators first. Each due date is then presented to you: confirmed at this amount it counts immediately; a different amount explains itself and is validated again.';

  @override
  String get scheduleWeekly => 'weekly';

  @override
  String get scheduleYearly => 'yearly';

  @override
  String get scheduledAwaitingTitle => 'Scheduled expenses awaiting you';

  @override
  String get scheduledExpensesEmpty => 'No scheduled expense yet.';

  @override
  String scheduledExpensesFinished(int count) {
    return 'Ended and rejected ($count)';
  }

  @override
  String get scheduledExpensesIntro =>
      'Subscriptions the space pays for — internet, phone, electricity. The schedule is validated once; every due date is presented to you before it counts.';

  @override
  String get scheduledExpensesTitle => 'Scheduled expenses';

  @override
  String schemaUpdateBody(int version) {
    return 'This app needs version $version of the DesKilo schema, and the server it connects to runs an older one. Until the server is updated, the app would fail in ways it could not explain, so it stops here.';
  }

  @override
  String get schemaUpdateMember =>
      'Otherwise: tell the person who runs your space. Nothing you entered is lost.';

  @override
  String get schemaUpdateOperator =>
      'If you run this server: apply the missing migrations with `dart run tool/instance.dart install --ref <project>`. Only what is missing runs.';

  @override
  String get schemaUpdateRetry => 'Check again';

  @override
  String get schemaUpdateServer => 'Server settings';

  @override
  String get schemaUpdateTitle => 'This server needs an update';

  @override
  String get seatDayAhead => 'Ahead';

  @override
  String get seatDayFree => 'Free — book it';

  @override
  String get seatDayMine => 'You';

  @override
  String get seatDayNow => 'Now';

  @override
  String get seatDayPast => 'Done';

  @override
  String get seatDaySomeone => 'A member';

  @override
  String get seatDaySubtitle =>
      'Who has this seat, and when. Tap a booking to open it, or a free stretch to take it.';

  @override
  String seatDayTitle(String seat) {
    return 'Seat $seat today';
  }

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
  String get serviceOutOfStock => 'Out of stock';

  @override
  String get serviceOutOfStockHint =>
      'Nothing left on the shelf — the next supply restocks it.';

  @override
  String serviceStockCount(int count) {
    return '$count in stock';
  }

  @override
  String get servicesActive => 'Active';

  @override
  String get servicesEdit => 'Edit service';

  @override
  String get servicesEmpty => 'No services yet.';

  @override
  String get servicesInactive => 'Inactive';

  @override
  String get servicesName => 'Name';

  @override
  String get servicesNew => 'New service';

  @override
  String get servicesPrice => 'Price';

  @override
  String get servicesTitle => 'Services';

  @override
  String get settingsBillingReports => 'Billing & reports';

  @override
  String get settingsFrontCamera => 'Scan with the front camera';

  @override
  String get settingsFrontCameraDesc =>
      'Badges are read with the screen-side camera — turn off to use the back camera.';

  @override
  String get settingsSectionAccount => 'My account';

  @override
  String get settingsSectionAdministration => 'Administration';

  @override
  String get settingsSectionAdvanced => 'Advanced';

  @override
  String get settingsSectionGovernance => 'Governance';

  @override
  String get settingsSectionHelpAbout => 'Help & about';

  @override
  String get settingsSectionMembership => 'My membership';

  @override
  String get settingsSectionWorkspace => 'This workspace';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settlementAction => 'Regroup into one invoice';

  @override
  String get settlementAnnexAlone => 'This invoice only';

  @override
  String settlementAnnexBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'The $count invoices this one replaces can follow it, each on its own pages and stamped as regrouped.',
      one: 'The invoice this one replaces can follow it, on its own pages and stamped as regrouped.',
    );
    return '$_temp0';
  }

  @override
  String get settlementAnnexTitle => 'Attach the regrouped invoices?';

  @override
  String get settlementAnnexWith => 'Attach them';

  @override
  String settlementConfirm(int count, String amount) {
    return 'Regroup $count invoices into one of $amount?';
  }

  @override
  String get settlementDocumentationOnly =>
      'Documentation only — every operation happens on the regrouping invoice.';

  @override
  String settlementDone(String number) {
    return 'Regrouped into $number.';
  }

  @override
  String settlementFoldedIn(String number) {
    return 'Regrouped in $number';
  }

  @override
  String get settlementNeedsTwo =>
      'Pick at least two open invoices of the same member.';

  @override
  String settlementPaidThrough(String number) {
    return 'Paid through $number';
  }

  @override
  String get settlementRegroups => 'This invoice regroups';

  @override
  String settlementRegroupsNumbers(String numbers) {
    return 'Regroups $numbers';
  }

  @override
  String get settlementSettledBy =>
      'Regrouped into another invoice — that one is what is owed and chased.';

  @override
  String get settlementSourcePdf => 'PDF (regrouped)';

  @override
  String get settlementStepPick => 'Choose invoices';

  @override
  String get settlementSummaryHint =>
      'These invoices are folded into one settlement document; each stays readable behind it.';

  @override
  String get settlementVatNote =>
      'The lines and their VAT are carried over from the regrouped invoices; the VAT declaration counts the originals once.';

  @override
  String get shellBarHiddenAnnounce => 'Navigation bar hidden';

  @override
  String get shellBarHideHint => 'Long-press for a full-screen view';

  @override
  String get shellBarShowHint => 'Long-press to show the navigation bar';

  @override
  String get shellBarShownAnnounce => 'Navigation bar shown';

  @override
  String shellPendingDecisions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count decisions await you',
      one: '1 decision awaits you',
    );
    return '$_temp0';
  }

  @override
  String get shellReserveButton => 'Reserve';

  @override
  String get shellSwipeCoachMark =>
      'Swipe the bar down for a full-screen view. Swipe up, or long-press the Reserve button, to bring it back.';

  @override
  String get siteCity => 'City';

  @override
  String get siteCountry => 'Country (code)';

  @override
  String get siteDelete => 'Delete this site';

  @override
  String get siteDeleteHint =>
      'Its levels and members go back to the default site.';

  @override
  String get siteExemptionReason => 'VAT exemption mention (this entity)';

  @override
  String get siteLegalId => 'Establishment registration (SIRET)';

  @override
  String get siteName => 'Site name';

  @override
  String get sitePostalCode => 'Post code';

  @override
  String get siteRegistrationHint =>
      'Only for a site that is a distinct legal entity — usually that is a separate workspace. Empty inherits the workspace\'s numbers.';

  @override
  String get siteSaved => 'Site saved.';

  @override
  String get siteStreet => 'Street';

  @override
  String get siteVatId => 'VAT number (this entity)';

  @override
  String get sitesAdd => 'Add a site';

  @override
  String get sitesDefault => 'Default site';

  @override
  String get sitesIntro =>
      'Every level belongs to a site; the default site carries the workspace\'s address. A member has a home site: that is the address on their documents.';

  @override
  String get sitesLevels => 'Levels';

  @override
  String get sitesSubtitle =>
      'Addresses, the levels at each, and who calls which home';

  @override
  String get sitesTitle => 'Sites';

  @override
  String get spaceAlreadyCheckedInHere =>
      'You are already checked in here. Choose Check out to leave the seat.';

  @override
  String get spaceBackToMe => 'Back to Me';

  @override
  String get spaceBlockedByYou =>
      'You already hold this space for that period.';

  @override
  String get spaceCardInfoLabel => 'Information on the card';

  @override
  String get spaceCardInfoWorkspace => 'Workspace';

  @override
  String get spaceCardSizeLabel => 'Card size';

  @override
  String get spaceCardSizeLarge => 'Large';

  @override
  String get spaceCardSizeMedium => 'Medium';

  @override
  String get spaceCardSizeSmall => 'Small';

  @override
  String get spaceChipTooltip => 'Switch space';

  @override
  String get spaceCodesDesc =>
      'One printable QR card per seat, desk, office and level — members scan to reserve or check in.';

  @override
  String get spaceCodesTitle => 'Space QR codes (PDF)';

  @override
  String get spaceFavoriteAdd => 'Add to favorites';

  @override
  String get spaceFavoriteRemove => 'Remove from favorites';

  @override
  String get spaceKindDesk => 'Desk';

  @override
  String get spaceKindLevel => 'Level';

  @override
  String get spaceKindOffice => 'Office';

  @override
  String get spaceKindSeat => 'Seat';

  @override
  String get spaceManageMyBooking => 'Manage my booking';

  @override
  String spaceMessageReserver(String name) {
    return 'Message $name';
  }

  @override
  String get spaceMoveDown => 'Move down';

  @override
  String get spaceMoveUp => 'Move up';

  @override
  String get spaceNotBookable =>
      'This space is not set up for whole-space reservations.';

  @override
  String get spaceNotWholeBookable =>
      'This space is not set up for whole booking — the owner enables \"Bookable as a whole\" on it in the editor.';

  @override
  String spaceOptions(String name) {
    return 'Options for $name';
  }

  @override
  String get spaceQrSizeLabel => 'QR code size';

  @override
  String get spaceRatingClear => 'No rating';

  @override
  String get spaceScanField => 'Code';

  @override
  String get spaceScanHint =>
      'Point the camera at the card of a seat, desk, office or level — or type its code.';

  @override
  String get spaceScanInvalid => 'Not a space code of this workspace.';

  @override
  String get spaceScanNfcHint => '…or hold the phone to a chair\'s NFC tag.';

  @override
  String get spaceScanTitle => 'Scan a space code';

  @override
  String get spaceScanUnknown =>
      'This code does not match any space here anymore.';

  @override
  String get spaceScanUnknownTag => 'This tag is not linked to any chair.';

  @override
  String get spaceSeatTaken => 'Taken';

  @override
  String get spaceYoursCheckedIn => 'You are checked in here for this slot.';

  @override
  String get spaceYoursNow => 'Reserved by you for this slot.';

  @override
  String get statusAwaiting => 'Awaiting';

  @override
  String get statusCreditNotes => 'Credit notes';

  @override
  String get statusCredits => 'Credits granted';

  @override
  String get statusFrom => 'From';

  @override
  String get statusInvoiced => 'Invoiced';

  @override
  String get statusMembers => 'Members';

  @override
  String get statusNet => 'Net';

  @override
  String get statusNetExplanation =>
      'This subtotal is invoiced amounts less credit notes, reimbursements and credits. It is neither profit nor a bank balance. Matched and received payments overlap and must not be added together.';

  @override
  String get statusPaymentsMatched => 'Payments matched';

  @override
  String get statusPaymentsReceived => 'Payments received';

  @override
  String get statusPrint => 'Print the status';

  @override
  String get statusReimbursed => 'Expenses reimbursed';

  @override
  String get statusRepartitioned => 'Expenses shared out';

  @override
  String get statusSubtitle => 'Revenues, expenses and members over a period';

  @override
  String get statusTitle => 'Workspace status';

  @override
  String get statusTo => 'To';

  @override
  String get subprocessAttendance => 'Attendance & usage';

  @override
  String get subprocessAttendanceDesc =>
      'Record attendance and close check-ins at day end.';

  @override
  String get subprocessAvailability => 'Opening days & hours';

  @override
  String get subprocessAvailabilityDesc =>
      'Define working hours and generate closure days.';

  @override
  String get subprocessCalendar => 'Calendar views';

  @override
  String get subprocessCalendarDesc =>
      'See reservations and pending decisions over time.';

  @override
  String get subprocessCollection => 'Payment collection';

  @override
  String get subprocessCollectionDesc =>
      'Collect payments and follow up overdue invoices.';

  @override
  String get subprocessCommunication => 'Member communication';

  @override
  String get subprocessCommunicationDesc =>
      'Exchange messages and keep track of updates.';

  @override
  String get subprocessConfiguration => 'Configuration & deployment';

  @override
  String get subprocessConfigurationDesc =>
      'Transfer configuration, use templates and manage instances.';

  @override
  String get subprocessDecisions => 'Decisions & approvals';

  @override
  String get subprocessDecisionsDesc =>
      'Review actions and record the required approvals.';

  @override
  String get subprocessDelivery => 'External delivery';

  @override
  String get subprocessDeliveryDesc =>
      'Connect push, WhatsApp and electronic invoice delivery.';

  @override
  String get subprocessDocuments => 'Document publication';

  @override
  String get subprocessDocumentsDesc =>
      'Publish documents and produce printable files.';

  @override
  String get subprocessExpenses => 'Shared expenses';

  @override
  String get subprocessExpensesDesc =>
      'Share costs, replenish supplies and schedule recurring expenses.';

  @override
  String get subprocessExperience => 'Application experience';

  @override
  String get subprocessExperienceDesc =>
      'Adjust help, navigation and display preferences.';

  @override
  String get subprocessInvoicing => 'Invoicing';

  @override
  String get subprocessInvoicingDesc =>
      'Issue and follow immutable invoices through settlement.';

  @override
  String get subprocessPeople => 'People & membership';

  @override
  String get subprocessPeopleDesc =>
      'Identify members and manage their membership and permissions.';

  @override
  String get subprocessPhysicalAccess => 'Physical access';

  @override
  String get subprocessPhysicalAccessDesc =>
      'Use badges, seat tags and the shared check-in kiosk.';

  @override
  String get subprocessPresentation => 'Space presentation';

  @override
  String get subprocessPresentationDesc =>
      'Help members recognize people and places on the plan.';

  @override
  String get subprocessPricing => 'Services & pricing';

  @override
  String get subprocessPricingDesc =>
      'Price services and accessories and agree member terms.';

  @override
  String get subprocessPrivacy => 'Personal data access & exports';

  @override
  String get subprocessPrivacyDesc =>
      'Inspect access to personal data and export records.';

  @override
  String get subprocessRecords => 'Financial records';

  @override
  String get subprocessRecordsDesc =>
      'Understand balances, payments and member statements.';

  @override
  String get subprocessReportDesign => 'Report design';

  @override
  String get subprocessReportDesignDesc =>
      'Design reports and maintain their text and layouts.';

  @override
  String get subprocessReservations => 'Booking desks & spaces';

  @override
  String get subprocessReservationsDesc =>
      'Book seats or whole spaces under the workspace rules.';

  @override
  String get subprocessStructure => 'Space structure';

  @override
  String get subprocessStructureDesc =>
      'Manage sites and the availability of plan objects.';

  @override
  String get subprocessTax => 'VAT management';

  @override
  String get subprocessTaxDesc =>
      'Maintain VAT groups, rates and declarations.';

  @override
  String get supportChanged => 'The context changed. Prepare a new preview.';

  @override
  String get supportDay => 'Last 24 hours';

  @override
  String get supportDemo => 'Demo: simulated local context';

  @override
  String get supportFailed => 'Could not prepare support details. Try again.';

  @override
  String get supportHour => 'Last hour';

  @override
  String get supportPrepare => 'Prepare preview';

  @override
  String get supportPrivacy =>
      'Only this device’s bounded event counts and known checks are included. Identities, server addresses, credentials, business records and raw logs are excluded. Unknown checks are unavailable; an operator can run doctor --support-json separately. Files you share cannot be revoked.';

  @override
  String get supportSaved => 'Saved locally';

  @override
  String supportSize(int bytes) {
    final intl.NumberFormat bytesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String bytesString = bytesNumberFormat.format(bytes);

    return 'Preview: $bytesString bytes';
  }

  @override
  String get supportTitle => 'Support details';

  @override
  String get symbolHint =>
      'A round mark of one or two letters on a colour, unique to this workspace — or use a photo below instead.';

  @override
  String get symbolLetters => 'Letters';

  @override
  String get symbolLettersRule =>
      'Use one or two letters or digits for the symbol.';

  @override
  String get symbolSaveFailed =>
      'The symbol could not be saved. Nothing changed.';

  @override
  String get symbolSaved => 'Symbol saved.';

  @override
  String get symbolTaken =>
      'Another workspace already uses these letters in this colour. Choose another colour or letters — or use a photo instead.';

  @override
  String get symbolTitle => 'Symbol';

  @override
  String get tabCalendar => 'Calendar';

  @override
  String get tabEvents => 'Events';

  @override
  String get tabMoney => 'Money';

  @override
  String get tabPlan => 'Plan';

  @override
  String get taskExportActionBack => 'Go back.';

  @override
  String get taskExportActionCancelReview =>
      'Cancel the review without booking.';

  @override
  String taskExportActionChangeField(String field) {
    return 'Change the field: $field.';
  }

  @override
  String get taskExportActionConfirmBooking => 'Confirm the booking.';

  @override
  String get taskExportActionOpenReserve => 'Open the Reserve screen.';

  @override
  String get taskExportActionSelectDate => 'Choose the date.';

  @override
  String get taskExportActionSelectPeriod => 'Choose the period.';

  @override
  String get taskExportActionSelectResource => 'Choose a place.';

  @override
  String get taskExportActionSwitchView => 'Switch the view.';

  @override
  String get taskExportActionUnknown =>
      'An action this version cannot describe.';

  @override
  String get taskExportActionViewDetails => 'Open the reservation details.';

  @override
  String get taskExportAuthored =>
      'Added while editing: not observed by the recorder.';

  @override
  String get taskExportCompletenessComplete =>
      'Complete: the recording was stopped by the person and every command received an answer.';

  @override
  String get taskExportCompletenessInterrupted =>
      'Interrupted: the app stopped while recording.';

  @override
  String get taskExportCompletenessPartial =>
      'Partial: the recording ended early or a command received no answer.';

  @override
  String taskExportDetail(String field, String value) {
    return '$field: $value';
  }

  @override
  String get taskExportDocFallbackTitle => 'Task procedure';

  @override
  String taskExportDuration(int minutes, int seconds) {
    return 'Duration: $minutes min $seconds s';
  }

  @override
  String get taskExportEndInterrupted => 'Ended because the app stopped.';

  @override
  String get taskExportEndLimitReached =>
      'Ended because a step, size or duration limit was reached.';

  @override
  String get taskExportEndScopeChanged =>
      'Ended because the account, workspace or installation changed.';

  @override
  String get taskExportEndStopped => 'Ended by the person who recorded it.';

  @override
  String get taskExportEndStorageFailed =>
      'Ended because writing the recording failed.';

  @override
  String taskExportExcluded(String category) {
    return 'A protected screen was visited ($category); nothing on it was recorded.';
  }

  @override
  String get taskExportFieldAccessories => 'Accessories';

  @override
  String get taskExportFieldCheckIn => 'Check in';

  @override
  String get taskExportFieldDateRelation => 'Date';

  @override
  String get taskExportFieldForWhom => 'For whom';

  @override
  String get taskExportFieldPeriod => 'Period';

  @override
  String get taskExportFieldRefusal => 'Reason';

  @override
  String get taskExportFieldRepeat => 'Repeat';

  @override
  String get taskExportFieldResourceKind => 'Kind of place';

  @override
  String get taskExportFieldSeriesResult => 'Series';

  @override
  String get taskExportFieldTime => 'Time';

  @override
  String get taskExportFieldUnknown => 'a field this version cannot describe';

  @override
  String get taskExportFieldViewMode => 'View';

  @override
  String taskExportFooter(String page, String pages) {
    return 'Page $page of $pages';
  }

  @override
  String get taskExportIllustrationNotApproved =>
      'Illustration not included: it was not approved.';

  @override
  String get taskExportIncludeIllustrations => 'Include approved illustrations';

  @override
  String get taskExportIntro =>
      'This document describes, step by step, a task recorded in DesKilo. It is documentation: it does not replay the task and it does not prove that the task succeeded. Only what the recording observed is stated as observed.';

  @override
  String get taskExportKindEdited =>
      'Edited procedure: derived from a recording and changed by a person.';

  @override
  String get taskExportKindSource =>
      'Original capture: the steps were observed by the recorder.';

  @override
  String get taskExportLimitEdited =>
      'Steps marked as added while editing were written by a person, not observed.';

  @override
  String get taskExportLimitIncomplete =>
      'The recording is incomplete: what happened after the last step shown is not known.';

  @override
  String get taskExportLimitNoIllustrations =>
      'This document has no illustrations.';

  @override
  String get taskExportLimitNotRunnable =>
      'Some steps come from a newer version and cannot be described here.';

  @override
  String get taskExportLimitRecreated =>
      'Illustrations are recreated from the recording\'s safe facts with invented place names; they are not screenshots of what was on screen.';

  @override
  String get taskExportLimitValues =>
      'Values that were typed or chosen are never recorded: only their kind appears, and \"not recorded\" stands in for anything else.';

  @override
  String get taskExportNoResult => 'No result was recorded for this command.';

  @override
  String taskExportNote(String note) {
    return 'Note written by the person who recorded (their own words): $note';
  }

  @override
  String get taskExportNoteOmitted =>
      'A personal note was left out of this document.';

  @override
  String taskExportOnScreen(String screen) {
    return 'Screen: $screen';
  }

  @override
  String get taskExportOutcomeConfirmed => 'the booking was confirmed';

  @override
  String get taskExportOutcomeRefused => 'the booking was refused';

  @override
  String get taskExportOutcomeRequested =>
      'the booking was requested and waits for a decision';

  @override
  String get taskExportOutcomeSeriesBooked => 'the series was booked';

  @override
  String get taskExportOutcomeUnknown =>
      'no answer could be confirmed; the outcome is unknown';

  @override
  String get taskExportOutcomeUnregistered =>
      'an outcome this version cannot describe';

  @override
  String taskExportPauses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Paused $count times',
      one: 'Paused once',
      zero: 'No pause',
    );
    return '$_temp0';
  }

  @override
  String taskExportPlatform(String platform) {
    return 'Recorded on: $platform';
  }

  @override
  String get taskExportPrereqBookablePlace =>
      'At least one place can be booked.';

  @override
  String get taskExportPrereqSignedIn => 'You are signed in.';

  @override
  String taskExportPrereqStartsOn(String screen) {
    return 'Start on $screen.';
  }

  @override
  String get taskExportPrereqUnknown =>
      'A condition this version cannot describe.';

  @override
  String get taskExportPrereqWorkspaceMember =>
      'You are a member of the workspace.';

  @override
  String get taskExportProtectedAuthentication => 'sign-in';

  @override
  String get taskExportProtectedIdentity => 'identity';

  @override
  String get taskExportProtectedMessenger => 'messages';

  @override
  String get taskExportProtectedOperator => 'operator';

  @override
  String get taskExportProtectedPayment => 'payment';

  @override
  String get taskExportProtectedProvider => 'provider';

  @override
  String get taskExportProtectedSecrets => 'secrets';

  @override
  String get taskExportRefused =>
      'This recording cannot be exported as a Word document.';

  @override
  String taskExportResult(String outcome) {
    return 'Result: $outcome';
  }

  @override
  String taskExportRevision(String revision) {
    return 'Content revision: $revision';
  }

  @override
  String get taskExportSaveFailed =>
      'The Word document could not be saved. The recording is unchanged.';

  @override
  String taskExportSaved(String file) {
    return 'Word document saved: $file';
  }

  @override
  String taskExportSceneAlt(String screen, String step) {
    return 'Illustration: $screen – $step';
  }

  @override
  String get taskExportSceneBookingTitle => 'Book a place';

  @override
  String get taskExportSceneCancel => 'Cancel';

  @override
  String get taskExportSceneConfirm => 'Confirm';

  @override
  String get taskExportSceneDetailTitle => 'Reservation';

  @override
  String get taskExportSceneLater => 'Later';

  @override
  String get taskExportSceneProvenance =>
      'Illustration recreated from the recording, not a screenshot';

  @override
  String get taskExportSectionAbout => 'About this recording';

  @override
  String get taskExportSectionBefore => 'Before you start';

  @override
  String get taskExportSectionLimits => 'Limitations';

  @override
  String get taskExportSectionSteps => 'Steps';

  @override
  String get taskExportStale =>
      'The storyboard belongs to another version of this recording. Review it again before exporting.';

  @override
  String get taskExportStoryboardApprove => 'Approve illustration';

  @override
  String get taskExportStoryboardGap => 'Gap: nothing was recorded here';

  @override
  String get taskExportStoryboardInclude => 'Include';

  @override
  String get taskExportStoryboardLeftOut => 'Step left out by the reviewer.';

  @override
  String get taskExportStoryboardMoveDown => 'Move down';

  @override
  String get taskExportStoryboardMoveUp => 'Move up';

  @override
  String get taskExportStoryboardOrderRefused =>
      'A result cannot come before the command it answers.';

  @override
  String get taskExportStoryboardRenderFailed =>
      'The illustration could not be drawn; this step stays as text.';

  @override
  String get taskExportStoryboardSourceExcluded =>
      'Protected screen: not illustrated';

  @override
  String get taskExportStoryboardSourceScene =>
      'Recreated illustration (not a screenshot)';

  @override
  String get taskExportStoryboardSourceText => 'Text slide';

  @override
  String get taskExportSurfaceAny => 'any screen';

  @override
  String get taskExportSurfaceBookingSheet => 'the booking sheet';

  @override
  String get taskExportSurfaceReservationDetail => 'the reservation details';

  @override
  String get taskExportSurfaceReserve => 'the Reserve screen';

  @override
  String get taskExportSurfaceUnknown =>
      'a screen this version cannot describe';

  @override
  String get taskExportUnrecorded => 'A step this version cannot describe.';

  @override
  String get taskExportValueAfternoon => 'afternoon';

  @override
  String get taskExportValueAllBooked => 'all booked';

  @override
  String get taskExportValueClosed => 'the workspace was closed';

  @override
  String get taskExportValueConflict => 'the place was already taken';

  @override
  String get taskExportValueCustom => 'custom';

  @override
  String get taskExportValueDesk => 'a desk';

  @override
  String get taskExportValueFullDay => 'full day';

  @override
  String get taskExportValueHours => 'by the hour';

  @override
  String get taskExportValueLater => 'later';

  @override
  String get taskExportValueLaterThisWeek => 'later this week';

  @override
  String get taskExportValueList => 'list';

  @override
  String get taskExportValueMorning => 'morning';

  @override
  String get taskExportValueNo => 'no';

  @override
  String get taskExportValueOff => 'off';

  @override
  String get taskExportValueOffline => 'no connection';

  @override
  String get taskExportValueOn => 'on';

  @override
  String get taskExportValueOnce => 'once';

  @override
  String get taskExportValueOtherMember => 'another member';

  @override
  String get taskExportValueOtherPlace => 'another kind of place';

  @override
  String get taskExportValueOtherReason => 'another reason';

  @override
  String get taskExportValuePartiallyBooked => 'partly booked';

  @override
  String get taskExportValuePast => 'a past day';

  @override
  String get taskExportValuePermission => 'a missing permission';

  @override
  String get taskExportValuePlan => 'floor plan';

  @override
  String get taskExportValuePolicy => 'a booking rule';

  @override
  String get taskExportValueQuota => 'a quota';

  @override
  String taskExportValueRedacted(int length) {
    return 'not kept ($length characters)';
  }

  @override
  String get taskExportValueRoom => 'a room';

  @override
  String get taskExportValueSelf => 'myself';

  @override
  String get taskExportValueSeries => 'as a series';

  @override
  String get taskExportValueToday => 'today';

  @override
  String get taskExportValueTomorrow => 'tomorrow';

  @override
  String get taskExportValueWithheld => 'not recorded';

  @override
  String get taskExportValueYes => 'yes';

  @override
  String taskExportVersion(int schema, int contract) {
    return 'Recording format $schema, action contract $contract';
  }

  @override
  String get taskExportWordButton => 'Export as Word document';

  @override
  String get taskGuideCreate => 'Create a guide draft';

  @override
  String get taskGuideEditText => 'Write the words';

  @override
  String get taskGuideIntro =>
      'Each step as a reader will follow it. A step that books waits for the real answer; nothing here is done for the reader.';

  @override
  String get taskGuideManual => 'Do this step yourself';

  @override
  String taskGuideManualProtected(String category) {
    return 'Do this step yourself, on a protected screen: $category';
  }

  @override
  String get taskGuideNoText => 'An instruction still to be written';

  @override
  String get taskGuideOptional => 'The reader may skip it';

  @override
  String get taskGuideRecovery =>
      'If it is refused: choose another place, day or period, then confirm again.';

  @override
  String get taskGuideSave => 'Save the guide';

  @override
  String get taskGuideTitle => 'Guide draft';

  @override
  String taskGuideWaitsFor(String outcomes) {
    return 'Waits for: $outcomes';
  }

  @override
  String get taskOutputBusy => 'This output is already being made.';

  @override
  String get taskOutputDocument => 'Word document';

  @override
  String get taskOutputFailed => 'The output could not be made.';

  @override
  String get taskOutputMake => 'Make';

  @override
  String get taskOutputMissingMedia => 'This task has no images to use.';

  @override
  String get taskOutputStale =>
      'The illustrations were reviewed for an earlier version.';

  @override
  String get taskOutputStoryboard => 'Storyboard';

  @override
  String get taskOutputTooLong => 'This task is too long for this output.';

  @override
  String get taskOutputUnsupportedPlatform => 'Not available on this device.';

  @override
  String get taskRecorderActionBack => 'Went back';

  @override
  String get taskRecorderActionCalendarCancel =>
      'Cancelled a reservation from the calendar';

  @override
  String get taskRecorderActionCalendarFilterKind =>
      'Changed what the calendar shows';

  @override
  String get taskRecorderActionCalendarMove => 'Moved through the dates';

  @override
  String get taskRecorderActionCalendarOpenItem =>
      'Opened an entry from the calendar';

  @override
  String get taskRecorderActionCalendarSelectDay =>
      'Chose a day in the calendar';

  @override
  String get taskRecorderActionCalendarView => 'Switched the calendar view';

  @override
  String get taskRecorderActionCalendarWhose => 'Chose whose calendar to see';

  @override
  String get taskRecorderActionCancelReservation => 'Cancelled the reservation';

  @override
  String get taskRecorderActionCancelReview =>
      'Closed the booking without booking';

  @override
  String get taskRecorderActionCancelRoleEdit =>
      'Closed the role without saving';

  @override
  String get taskRecorderActionCancelValidationRule =>
      'Closed the rule without saving';

  @override
  String get taskRecorderActionChangeField => 'Changed a booking detail';

  @override
  String get taskRecorderActionCheckIn => 'Checked in';

  @override
  String get taskRecorderActionCheckOut => 'Checked out';

  @override
  String get taskRecorderActionCloseMyReservation =>
      'Closed my reservation without changing it';

  @override
  String get taskRecorderActionConfirmBooking => 'Confirmed the booking';

  @override
  String get taskRecorderActionDecideEvent =>
      'Answered a request for a decision';

  @override
  String get taskRecorderActionDeclineOptIn =>
      'Did not switch on a test feature';

  @override
  String get taskRecorderActionGiveRole => 'Gave or took back a role';

  @override
  String get taskRecorderActionOpenReserve => 'Opened Reserve';

  @override
  String get taskRecorderActionOpenRoleMatrix => 'Opened the role matrix';

  @override
  String get taskRecorderActionOpenSpaceRoles =>
      'Opened the roles this space defines';

  @override
  String get taskRecorderActionOpenValidationRules =>
      'Opened the validation rules';

  @override
  String get taskRecorderActionOpenWhatYouCanDo => 'Opened what you can do';

  @override
  String get taskRecorderActionSaveRole => 'Saved a role';

  @override
  String get taskRecorderActionSaveValidationRule => 'Saved a validation rule';

  @override
  String get taskRecorderActionSelectDate => 'Chose the day';

  @override
  String get taskRecorderActionSelectLevel => 'Chose a level';

  @override
  String get taskRecorderActionSelectPeriod => 'Chose the period';

  @override
  String get taskRecorderActionSelectResource => 'Chose a place';

  @override
  String get taskRecorderActionSwitchFeature => 'Switched a feature';

  @override
  String get taskRecorderActionSwitchView => 'Switched the view';

  @override
  String get taskRecorderActionTogglePermission => 'Switched a permission';

  @override
  String get taskRecorderActionUiCloseWindow => 'Closed a window';

  @override
  String get taskRecorderActionUiCommand => 'Ran a command';

  @override
  String get taskRecorderActionUiCommitField => 'Filled in a field';

  @override
  String get taskRecorderActionUiOpenScreen => 'Opened a screen';

  @override
  String get taskRecorderActionUiOpenWindow => 'Opened a window';

  @override
  String get taskRecorderActionUiTap => 'Tapped';

  @override
  String get taskRecorderActionViewDetails => 'Opened the reservation';

  @override
  String get taskRecorderAddNote => 'Add a note';

  @override
  String get taskRecorderCaptureValues => 'Capture values (for issue reports)';

  @override
  String get taskRecorderCaptureValuesHint =>
      'Also keeps what you type and choose — text, numbers, dates, switches — so a developer can reproduce the problem from the file. Passwords, payment details, e-mail addresses, phone numbers and other personal contact data are never kept. Share the file only with people who should see what you entered.';

  @override
  String get taskRecorderCompletenessComplete => 'Complete';

  @override
  String get taskRecorderCompletenessInterrupted => 'Interrupted';

  @override
  String get taskRecorderCompletenessPartial => 'Partial';

  @override
  String get taskRecorderDelete => 'Delete from this device';

  @override
  String get taskRecorderDeleteConfirm =>
      'Delete this recording from this device? Files you exported are not affected, and nothing in the workspace changes.';

  @override
  String get taskRecorderDiscard => 'Discard';

  @override
  String get taskRecorderDisclosureBody =>
      'The recorder notes the steps you take on this workspace\'s screens — which screen, which action, what the app answered — on this device only. It never keeps what you type, names, amounts, messages, codes or passwords. Sign-in, payment, messages and other protected screens leave only a marker. Nothing is uploaded: you decide what to export.';

  @override
  String get taskRecorderDisclosureTitle => 'Before you record';

  @override
  String taskRecorderEditedNote(int count) {
    return 'Edited copy: $count steps left out. The recording on this device is unchanged.';
  }

  @override
  String get taskRecorderEndInterrupted =>
      'Interrupted: the app stopped while recording';

  @override
  String get taskRecorderEndLimitReached => 'Ended: a limit was reached';

  @override
  String get taskRecorderEndScopeChanged =>
      'Ended: the account or workspace changed';

  @override
  String get taskRecorderEndStopped => 'Stopped by you';

  @override
  String get taskRecorderEndStorageFailed =>
      'Ended: it could not be saved on this device';

  @override
  String get taskRecorderExport => 'Export a file';

  @override
  String get taskRecorderExportPackage => 'Export a task package';

  @override
  String get taskRecorderExportPreview => 'What the file will contain';

  @override
  String get taskRecorderExportValuesBody =>
      'It holds what was typed and chosen during the recording. Check it before sharing, and share it only with people who should see that.';

  @override
  String get taskRecorderExportValuesConfirm => 'Save anyway';

  @override
  String get taskRecorderExportValuesTitle => 'This recording contains values';

  @override
  String get taskRecorderFieldAccessories => 'accessories';

  @override
  String get taskRecorderFieldCheckIn => 'check-in';

  @override
  String get taskRecorderFieldForWhom => 'who it is for';

  @override
  String get taskRecorderFieldRepeat => 'repeat';

  @override
  String get taskRecorderFieldTime => 'time';

  @override
  String taskRecorderIndicator(int count) {
    return 'Recording a task: $count steps';
  }

  @override
  String get taskRecorderLeaveOut => 'Leave out of the export';

  @override
  String taskRecorderLimits(int steps, int minutes, int days) {
    return 'Up to $steps steps or $minutes minutes per recording. Recordings are deleted from this device after $days days; a file you exported is yours and stays where you saved it.';
  }

  @override
  String get taskRecorderMyRecordings => 'My recordings on this device';

  @override
  String get taskRecorderNoOutcome => 'No answer recorded';

  @override
  String get taskRecorderNoRecordings => 'No recordings on this device.';

  @override
  String get taskRecorderNoteHint => 'Your own words, kept as you write them';

  @override
  String get taskRecorderOpenRecorder => 'Open the task recorder';

  @override
  String get taskRecorderOutcomeCancelled => 'Cancelled';

  @override
  String get taskRecorderOutcomeCheckedIn => 'Checked in';

  @override
  String get taskRecorderOutcomeCheckedOut => 'Checked out';

  @override
  String get taskRecorderOutcomeCommandDone => 'Done';

  @override
  String get taskRecorderOutcomeCommandPending => 'Sent for validation';

  @override
  String get taskRecorderOutcomeConfirmed => 'Booked';

  @override
  String get taskRecorderOutcomeEventDecided => 'Answer recorded';

  @override
  String get taskRecorderOutcomeEventNotConfirmed =>
      'The answer was not confirmed';

  @override
  String get taskRecorderOutcomeRefused => 'Refused';

  @override
  String get taskRecorderOutcomeRequested => 'Sent for confirmation';

  @override
  String get taskRecorderOutcomeSeries => 'Series booked';

  @override
  String get taskRecorderOutcomeSettingNotSaved => 'Not saved';

  @override
  String get taskRecorderOutcomeSettingPending => 'Sent for validation';

  @override
  String get taskRecorderOutcomeSettingSaved => 'Saved';

  @override
  String get taskRecorderOutcomeUnknown => 'No answer came';

  @override
  String get taskRecorderPause => 'Pause';

  @override
  String get taskRecorderPaused => 'Paused';

  @override
  String get taskRecorderProtectedAuthentication => 'sign-in';

  @override
  String get taskRecorderProtectedIdentity => 'identity';

  @override
  String get taskRecorderProtectedMessenger => 'messages';

  @override
  String get taskRecorderProtectedOperator => 'installation operator';

  @override
  String get taskRecorderProtectedPayment => 'payment';

  @override
  String get taskRecorderProtectedProvider => 'a provider\'s screen';

  @override
  String get taskRecorderProtectedSecrets => 'keys and secrets';

  @override
  String get taskRecorderPutBack => 'Put back';

  @override
  String get taskRecorderRecordATask => 'Record a task';

  @override
  String get taskRecorderRecordThisTask => 'Record this task';

  @override
  String get taskRecorderRecording => 'Recording';

  @override
  String get taskRecorderResume => 'Resume';

  @override
  String get taskRecorderSaveFailed => 'The file could not be saved.';

  @override
  String get taskRecorderSaveNoPath =>
      'The file was handed to your browser or device; it did not say where it went.';

  @override
  String taskRecorderSaved(String path) {
    return 'Saved: $path';
  }

  @override
  String taskRecorderSavedPrivately(String path) {
    return 'Kept only inside the app: $path';
  }

  @override
  String get taskRecorderSegmentGap => 'Paused here';

  @override
  String get taskRecorderSignedOut => 'Sign in to record a task.';

  @override
  String get taskRecorderStart => 'Start recording';

  @override
  String get taskRecorderStartFailed =>
      'The recording could not start on this device.';

  @override
  String taskRecorderStepCount(int count) {
    return '$count steps';
  }

  @override
  String get taskRecorderStepExcluded => 'A protected screen — not recorded';

  @override
  String get taskRecorderStepNote => 'Your note';

  @override
  String get taskRecorderStepUnrecorded =>
      'A step the recorder cannot describe';

  @override
  String get taskRecorderStop => 'Stop';

  @override
  String get taskRecorderTargetAllKinds => 'every kind';

  @override
  String get taskRecorderTargetDefaultRule => 'the default rule';

  @override
  String get taskRecorderTargetUnkeyed => 'an unnamed control';

  @override
  String get taskRecorderTitle => 'Task recorder';

  @override
  String get taskRecorderUnavailable =>
      'Recording is not switched on in this workspace.';

  @override
  String get taskRecorderUnreadable =>
      'This recording cannot be read. You can delete it.';

  @override
  String get taskRecorderUntitled => 'Untitled task';

  @override
  String get taskRecorderValueAccept => 'accepted';

  @override
  String get taskRecorderValueAfternoon => 'afternoon';

  @override
  String get taskRecorderValueAgenda => 'agenda';

  @override
  String get taskRecorderValueAlert => 'an alert';

  @override
  String get taskRecorderValueAllBooked => 'every date booked';

  @override
  String get taskRecorderValueCheckIn => 'with check-in';

  @override
  String get taskRecorderValueClosed => 'closed';

  @override
  String get taskRecorderValueConflict => 'already taken';

  @override
  String get taskRecorderValueConversation => 'a conversation';

  @override
  String get taskRecorderValueCreated => 'created';

  @override
  String get taskRecorderValueCustom => 'custom times';

  @override
  String get taskRecorderValueDay => 'day';

  @override
  String get taskRecorderValueDecision => 'a decision';

  @override
  String get taskRecorderValueDecline => 'declined';

  @override
  String get taskRecorderValueDesk => 'a desk';

  @override
  String get taskRecorderValueEdited => 'edited';

  @override
  String get taskRecorderValueEveryone => 'everyone\'s';

  @override
  String get taskRecorderValueFullDay => 'full day';

  @override
  String get taskRecorderValueHours => 'by the hour';

  @override
  String get taskRecorderValueInvoice => 'an invoice';

  @override
  String get taskRecorderValueLater => 'a later day';

  @override
  String get taskRecorderValueLaterThisWeek => 'later this week';

  @override
  String get taskRecorderValueList => 'list';

  @override
  String get taskRecorderValueMine => 'mine';

  @override
  String get taskRecorderValueMonth => 'month';

  @override
  String get taskRecorderValueMorning => 'morning';

  @override
  String get taskRecorderValueNext => 'forward';

  @override
  String get taskRecorderValueNoCheckIn => 'without check-in';

  @override
  String get taskRecorderValueOff => 'off';

  @override
  String get taskRecorderValueOffline => 'offline';

  @override
  String get taskRecorderValueOn => 'on';

  @override
  String get taskRecorderValueOnce => 'once';

  @override
  String get taskRecorderValueOther => 'other';

  @override
  String get taskRecorderValueOtherMember => 'for another member';

  @override
  String get taskRecorderValuePartiallyBooked => 'some dates refused';

  @override
  String get taskRecorderValuePast => 'a past day';

  @override
  String get taskRecorderValuePayment => 'a payment';

  @override
  String get taskRecorderValuePermission => 'a permission';

  @override
  String get taskRecorderValuePlan => 'plan';

  @override
  String get taskRecorderValuePolicy => 'a booking rule';

  @override
  String get taskRecorderValuePrevious => 'back';

  @override
  String get taskRecorderValueQuota => 'an allowance';

  @override
  String get taskRecorderValueRange => 'a date range';

  @override
  String get taskRecorderValueRenamed => 'renamed';

  @override
  String get taskRecorderValueRoleAdmin => 'administrators';

  @override
  String get taskRecorderValueRoleCoOwner => 'a co-owner';

  @override
  String get taskRecorderValueRoleMember => 'every member';

  @override
  String get taskRecorderValueRoleOwner => 'the owner';

  @override
  String get taskRecorderValueRoom => 'a room';

  @override
  String get taskRecorderValueSelf => 'for me';

  @override
  String get taskRecorderValueSeries => 'repeating';

  @override
  String get taskRecorderValueSomeoneElse => 'another member\'s';

  @override
  String get taskRecorderValueTimeline => 'timeline';

  @override
  String get taskRecorderValueToday => 'today';

  @override
  String get taskRecorderValueTomorrow => 'tomorrow';

  @override
  String get taskRecorderValueWeek => 'week';

  @override
  String get taskRecorderValueWithheld => 'not recorded';

  @override
  String get taskRecorderValuesOn => 'Values are being captured';

  @override
  String get taskWizardAddGuide => 'Add a guide';

  @override
  String get taskWizardAddToGuides => 'Add to my guides';

  @override
  String get taskWizardBuiltIn => 'Guides that come with the app';

  @override
  String get taskWizardDeleteGuide => 'Delete this guide';

  @override
  String get taskWizardDeleteGuideBody =>
      'The guide is removed from this device. The recording it came from is not touched.';

  @override
  String get taskWizardEdit => 'Edit';

  @override
  String get taskWizardFromFile => 'From a task file or package';

  @override
  String get taskWizardFromFileHint =>
      'A recording, a task package or a guide file from someone else.';

  @override
  String get taskWizardFromRecording => 'From one of my recordings';

  @override
  String get taskWizardFromRecordingHint =>
      'Pick a recording; it becomes a guide at once.';

  @override
  String get taskWizardGuideAdded => 'Added to My guides.';

  @override
  String get taskWizardGuideName => 'Name of the guide';

  @override
  String get taskWizardGuideNotSaved => 'The guide could not be kept.';

  @override
  String get taskWizardGuides => 'Guides';

  @override
  String get taskWizardIntro =>
      'Record what you do, turn it into a guide, and follow guides step by step on the real app.';

  @override
  String get taskWizardMakeGuide => 'Make a guide';

  @override
  String get taskWizardNoGuides =>
      'No guide of your own yet. Add one from a recording or a task file.';

  @override
  String get taskWizardOpenFileHint =>
      'Read, edit and export a recording or task package, without an account.';

  @override
  String get taskWizardRecordings => 'Recordings';

  @override
  String get taskWizardSaveChanges => 'Save the changes';

  @override
  String get taskWizardTitle => 'Task wizard';

  @override
  String get taskWizardTools => 'Tools';

  @override
  String get taskWizardUnavailable =>
      'The task recorder is turned off in this workspace: guides can be read and edited here, but not followed.';

  @override
  String taskWorkbenchAccepted(int megabytes) {
    return 'Accepted: .json and .deskilo-task.zip, up to $megabytes MB.';
  }

  @override
  String get taskWorkbenchChoose => 'Choose a task file';

  @override
  String taskWorkbenchClaim(String key, String value) {
    return 'The file says $key: $value';
  }

  @override
  String get taskWorkbenchEdited => 'An edited copy of a recording.';

  @override
  String get taskWorkbenchFileType => 'Task file';

  @override
  String get taskWorkbenchIntro =>
      'Open a saved task file. It is read on this device only; nothing is uploaded and no sign-in is needed.';

  @override
  String get taskWorkbenchOfflineFailed => 'The browser refused to keep it.';

  @override
  String get taskWorkbenchOfflineForget => 'Stop keeping it';

  @override
  String get taskWorkbenchOfflineKeep => 'Keep it on this device';

  @override
  String get taskWorkbenchOfflineOff =>
      'Not kept: without a connection this page will not open.';

  @override
  String get taskWorkbenchOfflineReady =>
      'Kept on this browser: the verified workbench opens without a connection. Workspace actions still need a connection.';

  @override
  String get taskWorkbenchOfflineTitle => 'Use the workbench offline';

  @override
  String get taskWorkbenchOfflineUnsupported =>
      'This browser cannot keep it (a private window usually cannot).';

  @override
  String get taskWorkbenchOpen => 'Open a task file';

  @override
  String get taskWorkbenchRefusedDamaged =>
      'This file is damaged or was changed after it was made.';

  @override
  String get taskWorkbenchRefusedInvalid =>
      'This file does not hold a valid task.';

  @override
  String get taskWorkbenchRefusedNewer =>
      'This file was made by a newer version of the app.';

  @override
  String get taskWorkbenchRefusedTooLarge =>
      'This file is larger than the workbench reads.';

  @override
  String get taskWorkbenchRefusedUnsafe =>
      'This file is built in a way that is not safe to open.';

  @override
  String get taskWorkbenchRefusedUnsupported => 'This is not a task file.';

  @override
  String get taskWorkbenchReviewIllustrations => 'Review the illustrations';

  @override
  String get taskWorkbenchStoryboardRestored =>
      'The reviewed illustrations were restored from the file.';

  @override
  String get taskWorkbenchTitle => 'Task workbench';

  @override
  String get taskWorkbenchTranscriptOnly =>
      'Some steps come from a newer version: shown as a transcript only.';

  @override
  String get taskWorkbenchUntrusted =>
      'A private draft from a file: nothing in it is trusted or sent.';

  @override
  String get templateApplyConflict =>
      'This request was already used for something else. Nothing was applied.';

  @override
  String get templateChangedSinceReview =>
      'This template changed since you reviewed it. Nothing was applied; open it again to review the new version.';

  @override
  String get templateClearFilters => 'Clear the search';

  @override
  String get templateDetailNone => 'No setting matches.';

  @override
  String get templateDetailSearch => 'Find a setting in this template';

  @override
  String get templateDetails => 'What it holds';

  @override
  String templateExportResults(String count) {
    return 'Export these results ($count)';
  }

  @override
  String templateExportTooMany(String max) {
    return 'At most $max templates per workbook. Narrow the search first.';
  }

  @override
  String get templateNoMatch =>
      'No template matches. Change the words, a tag or a requirement.';

  @override
  String templatePrefer(String capability) {
    return 'Prefer: $capability';
  }

  @override
  String templatePreferredChip(String capability) {
    return 'Preferred: $capability';
  }

  @override
  String get templatePricesOtherCurrency =>
      'The template\'s prices are in another currency, so the prices here were left unchanged.';

  @override
  String get templateProfileFull => 'Full configuration profile';

  @override
  String templateProfileSelected(String chosen, String total) {
    return 'Selected groups: $chosen of $total';
  }

  @override
  String get templatePublishLocalNeeds =>
      'A space that applies it will set these up itself:';

  @override
  String templateRegionSuggested(String values) {
    return 'This template was made for $values. Your choice is kept unless you use its values.';
  }

  @override
  String get templateRegionUse => 'Use the template\'s region';

  @override
  String templateRequire(String capability) {
    return 'Require: $capability';
  }

  @override
  String get templateRequirementRemove => 'Remove requirement';

  @override
  String get templateRequirementsReset => 'Reset';

  @override
  String templateResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count templates shown',
      one: '1 template shown',
      zero: 'No template shown',
    );
    return '$_temp0';
  }

  @override
  String templateValidatorsToChoose(String types) {
    return 'Choose who validates $types in the validation settings; those rules were left as they were.';
  }

  @override
  String get templateWhy => 'Why this matches';

  @override
  String get templateWhyHide => 'Hide why';

  @override
  String get templateWidenConfirm => 'Make readable';

  @override
  String templateWidenCount(String count) {
    return '$count settings become readable, exactly as the template holds them now.';
  }

  @override
  String templateWidenExcluded(String count) {
    return '$count kinds of value never leave with it (bank details, sites, addresses…).';
  }

  @override
  String templateWidenTitle(String audience) {
    return 'Make this template readable by: $audience?';
  }

  @override
  String get templatesLoadFailed => 'The templates could not be loaded.';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System default';

  @override
  String get themeTitle => 'Theme';

  @override
  String get threadNoRefs =>
      'References are only shared with people of the same workspace.';

  @override
  String get threadRefsIn => 'References in';

  @override
  String get unblockAction => 'Unblock';

  @override
  String get unblockDone => 'Unblocked.';

  @override
  String get usageAsk => 'Bill the time I was here';

  @override
  String usageAskExplain(String booked, String present, String saved) {
    return 'You booked $booked and were here $present. Ask for the $saved you did not use to stop billing. Somebody else decides it — never you.';
  }

  @override
  String get usageAskSubmit => 'Ask';

  @override
  String get usageAskSubmitted => 'Asked. Somebody else decides it.';

  @override
  String get usageBilled => 'Billed';

  @override
  String get usageBooked => 'Booked';

  @override
  String get usageCorrected => 'Corrected';

  @override
  String get usageDelete => 'Remove this record';

  @override
  String get usageDeleteSubmitted => 'Removal requested.';

  @override
  String get usageEmpty => 'No usage this month.';

  @override
  String get usageLeftEarly => 'Left early';

  @override
  String get usageMember => 'Member';

  @override
  String get usageMemberAll => 'Everyone';

  @override
  String get usageNoShow => 'Nobody checked in — the booking bills in full';

  @override
  String get usagePresent => 'Present';

  @override
  String get usageReasonLabel => 'Why (optional)';

  @override
  String get usageReportButton => 'Month consumption report';

  @override
  String get usageReportExtra => 'Extra half-days';

  @override
  String get usageReportIncluded => 'Included half-days';

  @override
  String get usageReportOverage => 'Overage carried to the next invoice';

  @override
  String get usageReportPaid => 'Paid ahead (participation)';

  @override
  String get usageReportRecordsHeading => 'What was consumed';

  @override
  String get usageReportRemaining => 'Half-days remaining';

  @override
  String get usageReportSupplements =>
      'Supplements (accessories, desks, offices)';

  @override
  String get usageReportUsed => 'Half-days consumed';

  @override
  String get usageTitle => 'Usage';

  @override
  String usageWas(String before) {
    return 'was $before';
  }

  @override
  String get uxAdvancedSection => 'Advanced';

  @override
  String get uxBookingChargePending =>
      'The charge and allowance usage will be calculated according to the member’s plan. A final amount is not available here.';

  @override
  String get uxBookingCheckInHelp =>
      'Also mark me present when confirming this reservation.';

  @override
  String get uxBookingFor => 'Booking for';

  @override
  String get uxBookingModesHelp =>
      'Reserve keeps the selected window. Check in now switches to the current window and marks you present.';

  @override
  String get uxBookingResourceUnavailable => 'Resource unavailable';

  @override
  String get uxDeviceTime => 'Your time';

  @override
  String get uxLinkedReference => 'Linked resource';

  @override
  String get uxManageResource => 'Manage resource';

  @override
  String get uxMyBookings => 'My bookings';

  @override
  String get uxNavFinance => 'Billing & payments';

  @override
  String get uxNavPeople => 'People & access';

  @override
  String get uxNavWorkspace => 'Workspace setup';

  @override
  String get uxOpenWorkspace => 'Open workspace';

  @override
  String get uxPreferencesSection => 'Preferences';

  @override
  String get uxPrivacySection => 'Privacy';

  @override
  String get uxProfileAccount => 'Profile & account';

  @override
  String get uxProfileChooseEnvironment => 'Choose an environment';

  @override
  String get uxProfileSection => 'Profile';

  @override
  String get uxRealSpaceHint => 'Real bookings and invoices';

  @override
  String get uxRealWorkspace => 'Workspace';

  @override
  String get uxResetFilters => 'Reset filters';

  @override
  String get uxTestSpace => 'Test space';

  @override
  String get uxTestSpaceHint => 'Test space: practice bookings and invoices';

  @override
  String get uxWorkspaceTime => 'Workspace time';

  @override
  String get validationAdminsMay => 'Admins may validate';

  @override
  String get validationAllAdmins => 'All admins';

  @override
  String get validationAutoValidateAdmin => 'Admins delete without validation';

  @override
  String get validationAutoValidateDesc =>
      'Their own deletion request settles itself and stays marked as auto-validated.';

  @override
  String get validationAutoValidateOwner => 'Owners delete without validation';

  @override
  String get validationCustomized => 'Customized';

  @override
  String get validationDefaultPolicy => 'Default policy';

  @override
  String get validationInherited => 'Inherits default';

  @override
  String get validationMinAmount => 'Only above this amount';

  @override
  String get validationMinAmountDesc =>
      'Below it the act applies at once. Empty: every amount.';

  @override
  String get validationNoSelfDesc =>
      'Whoever creates an event never validates it. It waits for someone else, or expires undecided.';

  @override
  String get validationNoSelfShort => 'Never your own';

  @override
  String get validationNoSelfTitle => 'Nobody validates their own';

  @override
  String get validationNotEnough => 'Not enough eligible validators.';

  @override
  String get validationOwnerOnly => 'Owner only';

  @override
  String get validationOwnerRequired => 'Owner must always validate';

  @override
  String get validationOwnerSelf => 'The owner may validate their own';

  @override
  String get validationOwnerSelfDesc =>
      'The single exception, and the owner\'s alone: an admin never validates their own act.';

  @override
  String get validationOwnerSelfShort => 'Owner may validate their own';

  @override
  String get validationPickPersons => 'Pick the persons';

  @override
  String get validationRequiredCount => 'Required validations';

  @override
  String get validationSaved => 'Validation rule saved.';

  @override
  String get validationScopeAdmins => 'Admins';

  @override
  String get validationScopeHint =>
      'The owner always may. Admins: every admin, or the ones you list. Listed: exactly these people, whatever their role. All members: anyone active.';

  @override
  String get validationScopeLabel => 'Who validates';

  @override
  String get validationScopeListed => 'Listed persons';

  @override
  String get validationScopeMembers => 'All members';

  @override
  String get validationSentForApproval =>
      'Sent for validation — it applies once approved.';

  @override
  String get validationSequential => 'One after another';

  @override
  String get validationSequentialDesc =>
      'The next validation is asked for once the previous one passed, and the trail numbers each step.';

  @override
  String get validationSpecificAdmins => 'Specific admins';

  @override
  String get validationStepApplies => 'it takes effect';

  @override
  String get validationStepOwnerToo => 'and the owner, always';

  @override
  String validationStepQuorum(int count, String who) {
    return '$who — any $count';
  }

  @override
  String get validationStepRaised => 'Someone asks';

  @override
  String validationStepSequential(int count, String who) {
    return '$who — $count in turn';
  }

  @override
  String get validationThresholdNote => 'Smaller amounts apply straight away.';

  @override
  String get validationTitle => 'Validation rules';

  @override
  String validationTrailAwaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Awaiting $count more validations.',
      one: 'Awaiting 1 more validation.',
    );
    return '$_temp0';
  }

  @override
  String get validationTrailNone => 'No decision yet.';

  @override
  String validationTrailStep(int order) {
    return 'Step $order';
  }

  @override
  String get validationTrailTitle => 'Validation trail';

  @override
  String get validationWorkflowBookings => 'Bookings';

  @override
  String get validationWorkflowBookingsStake =>
      'Until it is accepted, the seat stays as it was.';

  @override
  String get validationWorkflowMoneyStake =>
      'Until it is accepted, the amount does not count on anybody’s statement.';

  @override
  String get validationWorkflowPeople => 'People and roles';

  @override
  String get validationWorkflowPeopleStake =>
      'Until it is accepted, the person keeps the access they have now.';

  @override
  String get vatAccountField => 'VAT account';

  @override
  String get vatAccountHint =>
      'Where the accounting export books collected VAT. Empty = 445710.';

  @override
  String get vatAddRate => 'Add a rate';

  @override
  String get vatChangeByLaw => 'Change by law';

  @override
  String get vatChangeByLawExplainer =>
      'A new value from a date: the old value stays on every supply before it, the new one applies from that day. Nothing is re-pointed.';

  @override
  String get vatChangeInvalid =>
      'A percentage between 0 and 99.99 and a date after the rate\'s start are needed.';

  @override
  String get vatChangeNeedsSave =>
      'Save the rate first; then change it by law.';

  @override
  String get vatDeclBox => 'Box';

  @override
  String get vatDeclBoxes => 'Official form lines';

  @override
  String get vatDeclDisclaimer =>
      'Generated from the period’s issued invoices. Verify against your accounting before filing — this is a filing aid, not tax advice.';

  @override
  String get vatDeclDraft => 'Draft';

  @override
  String get vatDeclEmpty =>
      'No declarations yet — pick a period and generate the first one.';

  @override
  String get vatDeclGenerate => 'Generate';

  @override
  String get vatDeclInvoices => 'Invoices';

  @override
  String get vatDeclMarkFiled => 'Mark as filed';

  @override
  String get vatDeclMarkFiledConfirm =>
      'Confirm you filed this declaration yourself (tax-office portal or your accountant). It becomes immutable.';

  @override
  String get vatDeclNet => 'Net base';

  @override
  String get vatDeclPdf => 'PDF';

  @override
  String get vatDeclPeriod => 'Period';

  @override
  String get vatDeclRate => 'Rate';

  @override
  String get vatDeclRegimeGate =>
      'Declarations exist only under the VAT-registered regime — configure it under VAT settings.';

  @override
  String get vatDeclRejected => 'The platform refused the declaration.';

  @override
  String get vatDeclSeller => 'Seller';

  @override
  String get vatDeclSent => 'Declaration transmitted.';

  @override
  String get vatDeclStatus => 'Status';

  @override
  String get vatDeclSubmitted => 'Submitted';

  @override
  String get vatDeclTitle => 'VAT declaration';

  @override
  String get vatDeclTotals => 'Totals';

  @override
  String get vatDeclTransmit => 'Transmit';

  @override
  String get vatDeclVat => 'VAT';

  @override
  String get vatDeclVatId => 'VAT ID';

  @override
  String get vatDeclXml => 'XML export';

  @override
  String get vatDeclarationBasisInvoice =>
      'Basis: invoices (VAT on documents issued during the period).';

  @override
  String get vatDeclarationBasisPayment =>
      'Basis: receipts (VAT on payments received during the period).';

  @override
  String get vatEffectiveDate => 'Effective date (YYYY-MM-DD)';

  @override
  String get vatEmpty => 'No rate yet — invoices show no VAT.';

  @override
  String get vatExemptionReasonField => 'Exemption reason';

  @override
  String get vatExigibilityInvoice => 'On invoices (accrual)';

  @override
  String get vatExigibilityPayment => 'On receipts (cash)';

  @override
  String get vatExigibilitySubtitle =>
      'On receipts, a period declares what customers paid inside it; on invoices, what you issued. The choice is printed on every invoice.';

  @override
  String get vatExigibilityTitle => 'VAT falls due';

  @override
  String get vatGroupDeposit => 'Deposit (outside VAT)';

  @override
  String get vatGroupExamples => 'What falls in each group';

  @override
  String get vatGroupExcise => 'Excise-bearing';

  @override
  String get vatGroupExempt => 'Exempt';

  @override
  String get vatGroupIntermediate => 'Intermediate';

  @override
  String get vatGroupLabel => 'Group';

  @override
  String get vatGroupNotSubject => 'Not subject';

  @override
  String get vatGroupReduced => 'Reduced';

  @override
  String get vatGroupStandard => 'Standard';

  @override
  String get vatGroupSuperReduced => 'Super-reduced';

  @override
  String get vatGroupZero => 'Zero rate';

  @override
  String get vatIntro =>
      'Prices in DesKilo include VAT. Adding rates changes nothing about what members pay — the tax is extracted from the price you already charge and shown on the invoice.';

  @override
  String get vatKeptRate =>
      'A rate still used by an invoice or a service is kept, deactivated.';

  @override
  String get vatNeedsDefault => 'Mark exactly one rate as the default.';

  @override
  String get vatNewPercent => 'New rate %';

  @override
  String get vatPdfNet => 'Net';

  @override
  String get vatPdfVat => 'VAT';

  @override
  String get vatRateDefaultTooltip =>
      'Default rate — used by subscriptions and by anything without its own rate';

  @override
  String get vatRateIncomplete =>
      'Every rate needs a name and a percentage between 0 and 99.99.';

  @override
  String get vatRateLabelField => 'Name';

  @override
  String get vatRatePercentField => 'Rate %';

  @override
  String get vatRateRemoveTooltip => 'Remove';

  @override
  String get vatRatesTile => 'VAT rates';

  @override
  String get vatRegimeHint =>
      'This workspace is not declared VAT-registered, so invoices show no VAT. Change that under Legal identity.';

  @override
  String get vatReportByRate => 'Totals per rate';

  @override
  String get vatReportCsv => 'VAT report (CSV)';

  @override
  String get vatReportPdf => 'VAT report (PDF)';

  @override
  String get vatReportPositions => 'Positions';

  @override
  String get vatReportTotals => 'Period totals';

  @override
  String get vatSaved => 'VAT rates saved.';

  @override
  String get vatSeed => 'Use the usual rates';

  @override
  String get vatServiceRate => 'VAT rate';

  @override
  String get vatServiceRateDefault => 'Workspace default';

  @override
  String vatShareAmount(String amount) {
    return 'incl. VAT $amount';
  }

  @override
  String get vatSince => 'since';

  @override
  String get vatTitle => 'VAT';

  @override
  String get vatTreatmentAuto => 'Automatic';

  @override
  String get vatTreatmentDomestic => 'Domestic VAT';

  @override
  String get vatTreatmentExempt => 'Exempt buyer';

  @override
  String get vatTreatmentExport => 'Outside the EU';

  @override
  String get vatTreatmentReasonField =>
      'Exemption reason (printed on the invoice)';

  @override
  String get vatTreatmentReverseCharge => 'Reverse charge';

  @override
  String get vatUntil => 'until';

  @override
  String get visibilityAbout => 'Profession and bio';

  @override
  String get visibilityAboutEmpty => 'Add your profession and a few words';

  @override
  String get visibilityAboutMe => 'About me';

  @override
  String get visibilityAboutSaveFailed =>
      'Could not save your profession and bio. Please try again.';

  @override
  String get visibilityBio => 'A few words about you';

  @override
  String visibilityChosenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Members of $count chosen spaces',
      one: 'Members of 1 chosen space',
    );
    return '$_temp0';
  }

  @override
  String get visibilityChosenSpaces => 'Members of chosen spaces';

  @override
  String get visibilityContact => 'WhatsApp and e-mail';

  @override
  String get visibilityElsewhereIntro =>
      'On a connected server you have that server\'s own account. People there who share no space with you see what you allow every signed-in person; contact details and presence never leave your spaces.';

  @override
  String get visibilityElsewhereTitle => 'On my other servers';

  @override
  String get visibilityIdentity => 'Name and photo';

  @override
  String get visibilityIntro =>
      'Each part of your account picks its own audience. Nothing is public unless you choose it.';

  @override
  String get visibilityMySpaces => 'Members of my spaces';

  @override
  String get visibilityNobody => 'Nobody';

  @override
  String visibilityOnServer(String host) {
    return 'Who sees me on $host';
  }

  @override
  String visibilityOnServerUnavailable(String host) {
    return '$host did not answer. Try again later.';
  }

  @override
  String get visibilityPresence => 'In the space today';

  @override
  String get visibilityPreviewCanWrite => 'Can start a conversation with you';

  @override
  String get visibilityPreviewCannotWrite =>
      'Cannot start a conversation with you';

  @override
  String get visibilityPreviewFailed => 'The preview could not be loaded.';

  @override
  String get visibilityPreviewMySpaces => 'A member of my spaces';

  @override
  String get visibilityPreviewNobody => 'Only me';

  @override
  String get visibilityPreviewNothing => 'They see nothing of you.';

  @override
  String get visibilityPreviewSignedIn => 'Anyone signed in';

  @override
  String get visibilityPreviewTitle => 'How others see me';

  @override
  String get visibilityProfession => 'Profession';

  @override
  String get visibilityReachability => 'Who can start a conversation with me';

  @override
  String get visibilitySaveFailed =>
      'Could not save who sees this. Please try again.';

  @override
  String get visibilitySignedIn => 'Anyone signed in';

  @override
  String get visibilityTitle => 'Who sees me';

  @override
  String get visibilityWidenAction => 'Widen';

  @override
  String visibilityWidenConfirm(String field, String audience) {
    return 'Show your $field to: $audience? They will be able to see it.';
  }

  @override
  String get visitCancel => 'Cancel this visit';

  @override
  String get visitCancelFailed =>
      'Could not cancel the visit. Nothing changed; try again.';

  @override
  String get visitGuestNote => 'Guest visit — not a membership';

  @override
  String get visitStatusCancelled => 'Cancelled';

  @override
  String get visitStatusConfirmed => 'Confirmed';

  @override
  String get visitStatusDeclined => 'Declined';

  @override
  String get visitStatusExpired => 'Expired';

  @override
  String get visitStatusRequested => 'Requested';

  @override
  String whatTheyCanDoTitle(String name) {
    return 'What $name can do here';
  }

  @override
  String get whatYouCanDoFromAdministrator => 'From the Administrator role';

  @override
  String get whatYouCanDoFromCoOwner => 'As co-owner';

  @override
  String get whatYouCanDoFromEveryMember => 'As every member';

  @override
  String get whatYouCanDoFromOwner => 'As the owner: everything';

  @override
  String whatYouCanDoFromRole(String role) {
    return 'From the role $role';
  }

  @override
  String get whatYouCanDoIntro =>
      'Everyone here is a member; what you can do — messages, reservations and the rest — comes only from the roles you hold.';

  @override
  String get whatYouCanDoNothingMore => 'Nothing more than a member.';

  @override
  String get whatYouCanDoTitle => 'What you can do here';

  @override
  String get whatsappFieldLabel => 'WhatsApp number';

  @override
  String get whatsappHelper =>
      'Optional. Visible to members of your workspaces so they can reach you on WhatsApp. Leave empty to stop sharing it.';

  @override
  String get whatsappHint => '+44 7912 345678';

  @override
  String get whatsappNotShared => 'Not shared';

  @override
  String get whatsappSaveFailed => 'Could not save the WhatsApp number';

  @override
  String get whatsappSaved => 'WhatsApp number saved';

  @override
  String get whatsappTitle => 'WhatsApp';

  @override
  String get wizardBack => 'Back';

  @override
  String get wizardCardHint =>
      'Issue, send, remind, register and validate payments, match and close — one guided process.';

  @override
  String get wizardCloseHint =>
      'A member with several open invoices can pay ONE; a partly paid invoice can have its remainder written off; a credit note is refunded. Each goes through validation.';

  @override
  String get wizardCloseNone => 'Nothing to regroup, write off or refund.';

  @override
  String get wizardFinish => 'Finish';

  @override
  String wizardIssueAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Issue $count invoices',
      one: 'Issue 1 invoice',
    );
    return '$_temp0';
  }

  @override
  String wizardIssueFailed(String name) {
    return 'Could not issue for $name.';
  }

  @override
  String get wizardIssueHint =>
      'Untick a member to leave them out of this batch. Members already covered are shown as done.';

  @override
  String get wizardIssueNothing => 'Nothing to issue for this period.';

  @override
  String wizardIssuedChip(String number) {
    return 'Issued $number';
  }

  @override
  String get wizardMatchAction => 'Match';

  @override
  String wizardMatchCredit(String amount) {
    return 'Credit available: $amount';
  }

  @override
  String get wizardMatchHint =>
      'An invoice is paid once a real payment is matched to it. Rows with credit on the member\'s account are ready.';

  @override
  String get wizardMatchNoCredit => 'No payment on the account yet';

  @override
  String get wizardMatchNone => 'Every invoice is paid or closed.';

  @override
  String get wizardMatchPending => 'Awaiting validation';

  @override
  String get wizardNext => 'Next';

  @override
  String get wizardPaymentAccept => 'Confirm';

  @override
  String get wizardPaymentReject => 'Reject';

  @override
  String get wizardPaymentsHint =>
      'What members declared waits for your confirmation below. A payment that reached the account without a declaration is registered here — the member then confirms it.';

  @override
  String get wizardPaymentsNone => 'No declared payment waits for you.';

  @override
  String wizardPeriodLabel(String period) {
    return 'Period: $period';
  }

  @override
  String get wizardRefund => 'Refund';

  @override
  String wizardRemindAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Send $count reminders',
      one: 'Send 1 reminder',
    );
    return '$_temp0';
  }

  @override
  String get wizardRemindHint =>
      'Overdue by your reminder rules. One tap records every reminder and notifies the members; the letter opens per row.';

  @override
  String wizardRemindLevel(int level) {
    return 'reminder $level';
  }

  @override
  String get wizardRemindNone => 'No reminder is due by your rules.';

  @override
  String get wizardRemindOne => 'Reminder letter';

  @override
  String get wizardReviewIssued => 'Already issued';

  @override
  String get wizardReviewOpen => 'Open invoices';

  @override
  String get wizardReviewOverdue => 'Reminders due';

  @override
  String get wizardReviewPending => 'Payments to validate';

  @override
  String get wizardReviewToIssue => 'To issue';

  @override
  String get wizardRunEnd => 'End of month';

  @override
  String get wizardRunEndHint =>
      'What the month that just ended cost: usage, consumption and extra charges. Issue, send, remind — then register, validate and match the payments, and close.';

  @override
  String get wizardRunStart => 'Start of month';

  @override
  String get wizardRunStartHint =>
      'The subscriptions members pay ahead: issue them for the coming month, send them, plan the reminders — then the payment side.';

  @override
  String get wizardSendDownload => 'Download the PDF';

  @override
  String get wizardSendHint =>
      'Hand each invoice to its member — share the PDF, or download it to send it your own way.';

  @override
  String get wizardSendNone => 'No invoice of this run to send yet.';

  @override
  String get wizardSendShare => 'Share the PDF';

  @override
  String wizardSettle(int count) {
    return 'Regroup $count';
  }

  @override
  String get wizardStepClose => 'Close';

  @override
  String get wizardStepCompleted => 'Completed';

  @override
  String get wizardStepIssue => 'Issue';

  @override
  String get wizardStepMatch => 'Match';

  @override
  String get wizardStepPayments => 'Payments';

  @override
  String get wizardStepRemind => 'Remind';

  @override
  String get wizardStepReview => 'Review';

  @override
  String get wizardStepSend => 'Send';

  @override
  String get wizardStepSkipped => 'Skipped — suggested settings';

  @override
  String get wizardStepSummary => 'Summary';

  @override
  String get wizardStepUnavailable => 'Not available yet';

  @override
  String get wizardSubmitting => 'Submitting';

  @override
  String get wizardSummaryHint => 'What this run did';

  @override
  String get wizardTallyDecided => 'Payments confirmed or rejected';

  @override
  String get wizardTallyIssued => 'Invoices issued';

  @override
  String get wizardTallyMatched => 'Invoices matched';

  @override
  String get wizardTallyNothing => 'Nothing was changed.';

  @override
  String get wizardTallyRefunds => 'Refunds';

  @override
  String get wizardTallyRegistered => 'Payments registered';

  @override
  String get wizardTallyReminded => 'Reminders sent';

  @override
  String get wizardTallySettled => 'Regroupings';

  @override
  String get wizardTallyShared => 'PDFs shared or downloaded';

  @override
  String get wizardTallyWriteoffs => 'Write-offs requested';

  @override
  String get wizardTitle => 'Invoicing wizard';

  @override
  String get wizardTodoHeading => 'Still open — whose move';

  @override
  String get wizardTodoNone => 'Nothing left open.';

  @override
  String get wizardWhoValidators => 'Validators';

  @override
  String get wizardWhoYou => 'You';

  @override
  String get wizardWriteoff => 'Write off';

  @override
  String get wordingChangedOnly => 'Changed only';

  @override
  String get wordingDefaultLabel => 'Product default';

  @override
  String get wordingIntro =>
      'Rename a small, approved set of product words. Everything else keeps the product\'s own wording, and a term you have not renamed shows exactly as before.';

  @override
  String get wordingLocale => 'Language';

  @override
  String get wordingNone => 'No term matches.';

  @override
  String get wordingReset => 'Reset';

  @override
  String get wordingResetHint =>
      'Reset removes your word and brings the product\'s back.';

  @override
  String get wordingRow => 'Wording';

  @override
  String get wordingRowHint =>
      'The words this space uses for a seat, the legend and the tabs.';

  @override
  String get wordingSavedOne => 'Saved';

  @override
  String get wordingSearch => 'Search a word';

  @override
  String get wordingSurfaceBooking => 'Booking';

  @override
  String get wordingSurfaceLegend => 'Legend';

  @override
  String get wordingSurfaceNavigation => 'Navigation';

  @override
  String get wordingSurfacePlan => 'The space';

  @override
  String get wordingTitle => 'Wording';

  @override
  String get workbookExportBuilding => 'Building the workbook…';

  @override
  String get workbookExportCancelled => 'Export cancelled. Nothing was saved.';

  @override
  String workbookExportReading(String done, String total) {
    return 'Reading templates: $done of $total';
  }

  @override
  String get workbookExportSaving => 'Choose where to save it…';

  @override
  String get workbookExportTitle => 'Exporting the workbook';

  @override
  String get workbookNote =>
      'A snapshot of template definitions. Editing this file changes nothing in DesKilo, and it is not a backup of any workspace: it holds no members, bookings, invoices or credentials.';

  @override
  String get workbookStateDefault =>
      'the template does not say; the default applies';

  @override
  String get workbookStateExcluded => 'deliberately never published';

  @override
  String get workbookStateInherit =>
      'the template does not say; the target keeps its own';

  @override
  String get workbookStateLocal => 'to be set locally';

  @override
  String get workbookStatePresent => 'the template sets this value';

  @override
  String get workbookStateUnknown => 'could not be read; nothing is claimed';

  @override
  String get workbookWide =>
      'Catalogs, RolePermissions, Validations and Fields show a value where the template sets it, and its state otherwise';

  @override
  String get workspaceAddressLabel => 'Workspace address';

  @override
  String get workspaceCodeCopied => 'Copied';

  @override
  String get workspaceCodeCopy => 'Copy ID';

  @override
  String get workspaceCodeEdit => 'Change workspace ID';

  @override
  String get workspaceCodeExplainer =>
      'Coworkers scan this QR code — or type the ID — to join this workspace.';

  @override
  String get workspaceCodeHint => '4–20 letters or digits, unique';

  @override
  String get workspaceCodeLabel => 'Workspace ID';

  @override
  String get workspaceCodeRejected =>
      'That ID was rejected — it must be 4–20 letters or digits and not already taken.';

  @override
  String get workspaceCodeSharePng => 'Share as PNG';

  @override
  String get workspaceCodeTitle => 'Workspace ID & QR';

  @override
  String get workspaceConfigAvailability => 'Availability';

  @override
  String get workspaceConfigBookableWhole => 'bookable as a whole';

  @override
  String get workspaceConfigClosures => 'Closures';

  @override
  String get workspaceConfigColName => 'Name';

  @override
  String get workspaceConfigColRole => 'Role';

  @override
  String get workspaceConfigColStatus => 'Status';

  @override
  String get workspaceConfigEmptyLevel => 'No rooms';

  @override
  String get workspaceConfigFeatures => 'Enabled features';

  @override
  String get workspaceConfigFloorPlan => 'Floor plan';

  @override
  String get workspaceConfigGranularity => 'Booking granularity';

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
  String get workspaceConfigInvitations => 'Invitations';

  @override
  String get workspaceConfigMembersSection => 'Members';

  @override
  String get workspaceConfigNone => 'None';

  @override
  String get workspaceConfigOpenDays => 'Open days';

  @override
  String get workspaceConfigOverview => 'Overview';

  @override
  String get workspaceConfigPdfExport => 'Export configuration (PDF)';

  @override
  String get workspaceConfigPdfExportSubtitle =>
      'Complete snapshot: settings, all members and the floor plan.';

  @override
  String workspaceConfigPdfGeneratedOn(String date) {
    return 'Generated on $date';
  }

  @override
  String get workspaceConfigPdfTitle => 'Workspace configuration';

  @override
  String get workspaceConfigSeats => 'Seats';

  @override
  String get workspaceCountryLabel => 'Country';

  @override
  String get workspaceCurrencyLabel => 'Currency';

  @override
  String get workspaceDangerZone => 'Danger zone';

  @override
  String workspaceDeskOpacityValue(int percent) {
    return 'Opacity: $percent%';
  }

  @override
  String get workspaceDeskTransparencyHelper =>
      'Lower the desk opacity so a level\'s background photo shows through the tables.';

  @override
  String get workspaceDeskTransparencyTitle => 'Desk transparency';

  @override
  String get workspaceExcelExport => 'Export data (Excel)';

  @override
  String get workspaceExcelExportSubtitle =>
      'One ZIP: every dataset in a workbook (bookings, payments, invoices, members, the floor plan — a tab each), a manifest counting its rows, and the space\'s stored files.';

  @override
  String get workspaceFieldsOptional => 'optional';

  @override
  String get workspaceFieldsPersonalNote =>
      'Your answers are personal data: they are part of your data export and are erased when you leave this space, unless the space documents a legal obligation to keep one.';

  @override
  String get workspaceFieldsSaveFailed =>
      'Your answers to this space\'s questions were not saved. Your other details were.';

  @override
  String workspaceFieldsTitle(String workspace) {
    return 'Questions from $workspace';
  }

  @override
  String get workspaceGenericError => 'Something went wrong. Please try again.';

  @override
  String get workspaceInviteCodeInvalid =>
      'No workspace ID found — paste the invitation or type the ID.';

  @override
  String get workspaceInviteCodeLabel => 'Invite code';

  @override
  String get workspaceInvitePasteHint =>
      'Paste the whole invitation message — the ID is found automatically.';

  @override
  String get workspaceLanguageHelper =>
      'Invitations are written in this language by default. Your own app language is in Settings.';

  @override
  String get workspaceLanguageLabel => 'Workspace language';

  @override
  String get workspaceLanguageUnset => 'Sender\'s app language';

  @override
  String get workspaceNameLabel => 'Workspace name';

  @override
  String get workspacePaymentsBillingTitle => 'Payments & billing';

  @override
  String get workspaceResetConfirmButton => 'Reset workspace';

  @override
  String workspaceResetConfirmLabel(String phrase) {
    return 'Type \"$phrase\" to confirm';
  }

  @override
  String get workspaceResetConfirmPhrase => 'I agree';

  @override
  String get workspaceResetDialogTitle => 'Reset this workspace?';

  @override
  String get workspaceResetDone => 'Workspace reset.';

  @override
  String get workspaceResetSubtitle =>
      'Delete all bookings, money and the floor plan. Keeps settings and members.';

  @override
  String get workspaceResetTitle => 'Reset workspace';

  @override
  String get workspaceResetWarning =>
      'This permanently deletes every reservation, all money and ledger entries, the activity feed, and the entire floor plan — floors, rooms, tables, seats and images. Workspace settings, fee bands, availability, features, catalogs and members are kept. This cannot be undone.';

  @override
  String get workspaceSettingsConflict =>
      'Someone changed these settings while you were editing. Nothing was saved; your changes are still here.';

  @override
  String get workspaceSettingsCurrencyHelper =>
      'Defaults from the country — override if your community bills in another currency.';

  @override
  String get workspaceSettingsSaved => 'Workspace saved.';

  @override
  String get workspaceSettingsTitle => 'Workspace';

  @override
  String get workspaceTimezoneHint => 'Europe/London';

  @override
  String get workspaceTimezoneLabel => 'Time zone';

  @override
  String get workspaceTimezoneUnknown => 'Pick a time zone from the list';

  @override
  String get workspaceWhatsappGroupHelper =>
      'Shown to members so they can join the community\'s WhatsApp group. Paste the group\'s invite link (https://chat.whatsapp.com/…). Leave empty to show nothing.';

  @override
  String get workspaceWhatsappGroupInvalid =>
      'Must be a chat.whatsapp.com invite link';

  @override
  String get workspaceWhatsappGroupLabel => 'WhatsApp group link';

  @override
  String get workspaceWhatsappGroupTitle => 'WhatsApp group';

  @override
  String get workspaceXmlErrorInvalidPlan =>
      'The floor plan in the file is invalid: rooms, desks or seats overlap or extend outside their parent.';

  @override
  String get workspaceXmlErrorInvalidValue =>
      'The file contains an invalid value and cannot be imported.';

  @override
  String get workspaceXmlErrorMalformed => 'The file is not readable XML.';

  @override
  String get workspaceXmlErrorMissingAttribute =>
      'The file is incomplete — a required value is missing.';

  @override
  String get workspaceXmlErrorMissingElement =>
      'The file is incomplete — a required section is missing.';

  @override
  String get workspaceXmlErrorUnsupportedVersion =>
      'The file was exported by a newer version of DesKilo and cannot be imported.';

  @override
  String get workspaceXmlErrorWrongRoot =>
      'This is not a DesKilo workspace file.';

  @override
  String get workspaceXmlExport => 'Export workspace (XML)';

  @override
  String get workspaceXmlExportSubtitle =>
      'Settings and floor plan as a shareable file. No members, bookings or money data.';

  @override
  String get workspaceXmlFileTypeLabel => 'XML';

  @override
  String get workspaceXmlImport => 'Import workspace (XML)';

  @override
  String get workspaceXmlImportConfigurationOnly =>
      'The configuration was applied. The floor plan was kept: this space already has reservations, so its plan cannot be replaced.';

  @override
  String get workspaceXmlImportConfirm => 'Replace and import';

  @override
  String get workspaceXmlImportPartial =>
      'Part of the import was applied before it stopped — check the settings and the floor plan below.';

  @override
  String workspaceXmlImportPreviewAccessories(int count) {
    return 'Accessories: $count';
  }

  @override
  String workspaceXmlImportPreviewConfiguration(
    int settings,
    int tables,
    int rows,
  ) {
    return 'Configuration: $settings settings, $rows rows in $tables tables';
  }

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
  String get workspaceXmlImportPreviewTitle => 'Replace floor plan?';

  @override
  String get workspaceXmlImportPreviewWarning =>
      'The current floor plan will be deleted and replaced, and the workspace settings will be overwritten. This cannot be undone.';

  @override
  String get workspaceXmlImportReservationsError =>
      'This workspace already has reservations, so its floor plan cannot be replaced. Imports are only possible before the first booking.';

  @override
  String get workspaceXmlImportSubtitle =>
      'Restore settings and floor plan from an exported file. Replaces the current floor plan.';

  @override
  String get workspaceXmlImportSuccess => 'Workspace imported.';
}
