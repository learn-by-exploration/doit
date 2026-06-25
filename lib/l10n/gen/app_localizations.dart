import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('en'),
    Locale('es'),
  ];

  /// The app display name shown in the launcher and About section.
  ///
  /// In en, this message translates to:
  /// **'do it'**
  String get appTitle;

  /// Home screen AppBar title. Mirrors the app name for the non-selection mode.
  ///
  /// In en, this message translates to:
  /// **'do it'**
  String get homeAppBarTitle;

  /// Home screen AppBar title when the user has entered selection mode.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No selection} =1{1 selected} other{{count} selected}}'**
  String homeSelectionAppBarTitle(int count);

  /// No description provided for @homeSnackbarMarkedDone.
  ///
  /// In en, this message translates to:
  /// **'Marked done.'**
  String get homeSnackbarMarkedDone;

  /// Snackbar copy after a bulk-mark operation.
  ///
  /// In en, this message translates to:
  /// **'Marked {count} do(s) done.'**
  String homeSnackbarMarkedCount(int count);

  /// No description provided for @homeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No dos yet.'**
  String get homeEmptyTitle;

  /// No description provided for @homeRetryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get homeRetryButton;

  /// No description provided for @homeAddSheetNewDo.
  ///
  /// In en, this message translates to:
  /// **'New do'**
  String get homeAddSheetNewDo;

  /// No description provided for @homeAddSheetNewPerson.
  ///
  /// In en, this message translates to:
  /// **'New person'**
  String get homeAddSheetNewPerson;

  /// No description provided for @homeAddSheetFromTemplate.
  ///
  /// In en, this message translates to:
  /// **'From template'**
  String get homeAddSheetFromTemplate;

  /// No description provided for @settingsAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsAppBarTitle;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsSectionAnchor.
  ///
  /// In en, this message translates to:
  /// **'Wake-up anchor'**
  String get settingsSectionAnchor;

  /// No description provided for @settingsSectionPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get settingsSectionPermissions;

  /// No description provided for @settingsSectionReliability.
  ///
  /// In en, this message translates to:
  /// **'Reliability'**
  String get settingsSectionReliability;

  /// No description provided for @settingsSectionDeviceState.
  ///
  /// In en, this message translates to:
  /// **'Device state'**
  String get settingsSectionDeviceState;

  /// No description provided for @settingsSectionStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get settingsSectionStats;

  /// No description provided for @settingsStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get settingsStatsTitle;

  /// No description provided for @settingsStatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Streaks, completion rate, 7-day chart.'**
  String get settingsStatsSubtitle;

  /// No description provided for @settingsSectionBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get settingsSectionBackup;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsAnchorManual.
  ///
  /// In en, this message translates to:
  /// **'Manual — I tap \"I\'m up\"'**
  String get settingsAnchorManual;

  /// No description provided for @settingsAnchorFirstUnlock.
  ///
  /// In en, this message translates to:
  /// **'First unlock of the day'**
  String get settingsAnchorFirstUnlock;

  /// No description provided for @settingsAnchorEither.
  ///
  /// In en, this message translates to:
  /// **'Either, with confirmation'**
  String get settingsAnchorEither;

  /// No description provided for @settingsReminderReliabilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminder reliability'**
  String get settingsReminderReliabilityTitle;

  /// No description provided for @settingsReminderReliabilityOptimal.
  ///
  /// In en, this message translates to:
  /// **'Optimal — exact alarm granted.'**
  String get settingsReminderReliabilityOptimal;

  /// No description provided for @settingsReminderReliabilityDegraded.
  ///
  /// In en, this message translates to:
  /// **'Degraded — using WorkManager fallback.'**
  String get settingsReminderReliabilityDegraded;

  /// No description provided for @settingsReminderReliabilityUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown — first launch, probe pending.'**
  String get settingsReminderReliabilityUnknown;

  /// No description provided for @settingsTestReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Send a test reminder'**
  String get settingsTestReminderTitle;

  /// No description provided for @settingsTestReminderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fires a notification in ~5 seconds.'**
  String get settingsTestReminderSubtitle;

  /// No description provided for @settingsTestReminderSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Test reminder scheduled for 5s from now.'**
  String get settingsTestReminderSnackbar;

  /// No description provided for @settingsRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get settingsRestoreTitle;

  /// No description provided for @settingsRestoreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a do it .json backup file.'**
  String get settingsRestoreSubtitle;

  /// About-section subtitle. Carries the version string verbatim.
  ///
  /// In en, this message translates to:
  /// **'{version} — local-only. See PRIVACY.md for the data we store and the data we do not.'**
  String settingsAboutAppVersion(String version);

  /// No description provided for @settingsLicensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get settingsLicensesTitle;

  /// No description provided for @settingsLicensesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Flutter, Drift, flutter_local_notifications, …'**
  String get settingsLicensesSubtitle;

  /// No description provided for @permissionNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get permissionNotificationsTitle;

  /// No description provided for @permissionContactsTitle.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get permissionContactsTitle;

  /// No description provided for @permissionExactAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Exact alarms'**
  String get permissionExactAlarmTitle;

  /// No description provided for @permissionLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get permissionLocationTitle;

  /// No description provided for @permissionCalendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get permissionCalendarTitle;

  /// No description provided for @permissionUsageStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Usage access'**
  String get permissionUsageStatsTitle;

  /// No description provided for @permissionFullScreenIntentTitle.
  ///
  /// In en, this message translates to:
  /// **'Full-screen access'**
  String get permissionFullScreenIntentTitle;

  /// No description provided for @permissionStatusGranted.
  ///
  /// In en, this message translates to:
  /// **'Granted'**
  String get permissionStatusGranted;

  /// No description provided for @permissionStatusDenied.
  ///
  /// In en, this message translates to:
  /// **'Not granted — tap to ask again'**
  String get permissionStatusDenied;

  /// No description provided for @permissionStatusBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked. Tap \'Settings\' to grant.'**
  String get permissionStatusBlocked;

  /// No description provided for @permissionStatusNotAsked.
  ///
  /// In en, this message translates to:
  /// **'Not asked yet — tap to ask'**
  String get permissionStatusNotAsked;

  /// No description provided for @permissionSettingsButton.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get permissionSettingsButton;

  /// No description provided for @permissionBackupFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup folder'**
  String get permissionBackupFolderTitle;

  /// No description provided for @permissionBackupFolderNotPicked.
  ///
  /// In en, this message translates to:
  /// **'Not picked — tap to pick'**
  String get permissionBackupFolderNotPicked;

  /// No description provided for @permissionBackupFolderRePick.
  ///
  /// In en, this message translates to:
  /// **'Re-pick'**
  String get permissionBackupFolderRePick;

  /// No description provided for @permissionBackupFolderSet.
  ///
  /// In en, this message translates to:
  /// **'Backup folder set: {path}'**
  String permissionBackupFolderSet(String path);

  /// No description provided for @permissionBackupFolderError.
  ///
  /// In en, this message translates to:
  /// **'Folder picker error: {message}'**
  String permissionBackupFolderError(String message);

  /// No description provided for @permissionCallScreeningTitle.
  ///
  /// In en, this message translates to:
  /// **'Call-screening role'**
  String get permissionCallScreeningTitle;

  /// No description provided for @permissionCallScreeningChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get permissionCallScreeningChecking;

  /// No description provided for @permissionCallScreeningHeld.
  ///
  /// In en, this message translates to:
  /// **'Held — Japan routine can intercept calls.'**
  String get permissionCallScreeningHeld;

  /// No description provided for @permissionCallScreeningNotHeld.
  ///
  /// In en, this message translates to:
  /// **'Not held — tap \"Change\" to grant the role.'**
  String get permissionCallScreeningNotHeld;

  /// No description provided for @permissionCallScreeningChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get permissionCallScreeningChange;

  /// No description provided for @permissionCallScreeningGrant.
  ///
  /// In en, this message translates to:
  /// **'Grant'**
  String get permissionCallScreeningGrant;

  /// No description provided for @onboardingAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to do it'**
  String get onboardingAppBarTitle;

  /// No description provided for @onboardingLastStepAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Last step'**
  String get onboardingLastStepAppBarTitle;

  /// No description provided for @onboardingStepNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get onboardingStepNotificationsTitle;

  /// No description provided for @onboardingStepNotificationsBody.
  ///
  /// In en, this message translates to:
  /// **'do it sends a daily reminder for each do. Android asks for the notification permission once.'**
  String get onboardingStepNotificationsBody;

  /// No description provided for @onboardingStepNotificationsCta.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get onboardingStepNotificationsCta;

  /// No description provided for @onboardingStepContactsTitle.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get onboardingStepContactsTitle;

  /// No description provided for @onboardingStepContactsBody.
  ///
  /// In en, this message translates to:
  /// **'If you add a \"cadence\" do — call Mom every Sunday — do it reads the contact you pick. It never imports the whole address book.'**
  String get onboardingStepContactsBody;

  /// No description provided for @onboardingStepContactsCta.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get onboardingStepContactsCta;

  /// No description provided for @onboardingStepExactAlarmsTitle.
  ///
  /// In en, this message translates to:
  /// **'Exact alarms'**
  String get onboardingStepExactAlarmsTitle;

  /// No description provided for @onboardingStepExactAlarmsBody.
  ///
  /// In en, this message translates to:
  /// **'Exact alarms fire reminders on the minute, not up to 15 minutes late. If you decline, do it falls back to a best-effort schedule.'**
  String get onboardingStepExactAlarmsBody;

  /// No description provided for @onboardingStepExactAlarmsCta.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get onboardingStepExactAlarmsCta;

  /// No description provided for @onboardingStepBackupFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup folder'**
  String get onboardingStepBackupFolderTitle;

  /// No description provided for @onboardingStepBackupFolderBody.
  ///
  /// In en, this message translates to:
  /// **'Pick a folder on your phone (or SD card) for nightly auto-backups. do it writes a single encrypted file; the folder stays yours.'**
  String get onboardingStepBackupFolderBody;

  /// No description provided for @onboardingStepBackupFolderCta.
  ///
  /// In en, this message translates to:
  /// **'Pick folder'**
  String get onboardingStepBackupFolderCta;

  /// No description provided for @onboardingStepCallScreeningTitle.
  ///
  /// In en, this message translates to:
  /// **'Call-screening role'**
  String get onboardingStepCallScreeningTitle;

  /// No description provided for @onboardingStepCallScreeningBody.
  ///
  /// In en, this message translates to:
  /// **'Optional: let do it screen incoming calls so the Japan routine can ring specific contacts through silent mode. Android will ask you to confirm.'**
  String get onboardingStepCallScreeningBody;

  /// No description provided for @onboardingStepCallScreeningCta.
  ///
  /// In en, this message translates to:
  /// **'Grant'**
  String get onboardingStepCallScreeningCta;

  /// No description provided for @onboardingSkipCta.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkipCta;

  /// No description provided for @onboardingOpenAndroidSettingsCta.
  ///
  /// In en, this message translates to:
  /// **'Open Android settings'**
  String get onboardingOpenAndroidSettingsCta;
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
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
