// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'do it';

  @override
  String get homeAppBarTitle => 'do it';

  @override
  String homeSelectionAppBarTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString selected',
      one: '1 selected',
      zero: 'No selection',
    );
    return '$_temp0';
  }

  @override
  String get homeSnackbarMarkedDone => 'Marked done.';

  @override
  String homeSnackbarMarkedCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    return 'Marked $countString do(s) done.';
  }

  @override
  String get homeTileMarkDone => 'Mark done';

  @override
  String get homeTileStreakLabel => 'day streak';

  @override
  String get homeTileAlreadyDoneTooltip => 'Already done for today';

  @override
  String get homeTileStrongModeHint => 'Opens the mission chain';

  @override
  String get homeTileSkipToday => 'Skip today';

  @override
  String get homeTileSkipAlready => 'Rest day taken';

  @override
  String get homeTileSkipSuccess => 'Rest day taken — streak holds.';

  @override
  String get homeTileSkipBudgetExhausted => 'No rest days left this month.';

  @override
  String homeTileBudgetRemaining(int remaining, int limit) {
    return '$remaining/$limit rest days left';
  }

  @override
  String get homeTileBudgetNoRemaining => 'No rest days left';

  @override
  String get homeTileUndoToday => 'Undo today';

  @override
  String get homeTileUndoConfirm => 'Undo today\'s completion?';

  @override
  String get homeTileUndoConfirmBody =>
      'This will remove today\'s check-in. The streak will update.';

  @override
  String get homeTileUndoSuccess => 'Completion removed.';

  @override
  String get homeTileUndoNotToday => 'Nothing to undo for today.';

  @override
  String get homeTileSparklineSemantics => 'Last 7 days';

  @override
  String get homeEmptyTitle => 'No dos yet.';

  @override
  String get homeRetryButton => 'Retry';

  @override
  String get homeAddSheetNewDo => 'New do';

  @override
  String get homeAddSheetNewPerson => 'New person';

  @override
  String get homeAddSheetFromTemplate => 'From template';

  @override
  String get settingsAppBarTitle => 'Settings';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsSectionAnchor => 'Wake-up anchor';

  @override
  String get settingsSectionPermissions => 'Permissions';

  @override
  String get settingsSectionReliability => 'Reliability';

  @override
  String get settingsSectionDeviceState => 'Device state';

  @override
  String get settingsSectionStats => 'Stats';

  @override
  String get settingsStatsTitle => 'Stats';

  @override
  String get settingsStatsSubtitle => 'Streaks, completion rate, 7-day chart.';

  @override
  String get settingsSectionBackup => 'Backup';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsAnchorManual => 'Manual — I tap \"I\'m up\"';

  @override
  String get settingsAnchorFirstUnlock => 'First unlock of the day';

  @override
  String get settingsAnchorEither => 'Either, with confirmation';

  @override
  String get settingsReminderReliabilityTitle => 'Reminder reliability';

  @override
  String get settingsReminderReliabilityOptimal =>
      'Optimal — exact alarm granted.';

  @override
  String get settingsReminderReliabilityDegraded =>
      'Degraded — using WorkManager fallback.';

  @override
  String get settingsReminderReliabilityUnknown =>
      'Unknown — first launch, probe pending.';

  @override
  String get settingsTestReminderTitle => 'Send a test reminder';

  @override
  String get settingsTestReminderSubtitle =>
      'Fires a notification in ~5 seconds.';

  @override
  String get settingsTestReminderSnackbar =>
      'Test reminder scheduled for 5s from now.';

  @override
  String get settingsRestoreTitle => 'Restore from backup';

  @override
  String get settingsRestoreSubtitle => 'Pick a do it .json backup file.';

  @override
  String settingsAboutAppVersion(String version) {
    return '$version — local-only. See PRIVACY.md for the data we store and the data we do not.';
  }

  @override
  String get settingsLicensesTitle => 'Open source licenses';

  @override
  String get settingsLicensesSubtitle =>
      'Flutter, Drift, flutter_local_notifications, …';

  @override
  String get permissionNotificationsTitle => 'Notifications';

  @override
  String get permissionContactsTitle => 'Contacts';

  @override
  String get permissionExactAlarmTitle => 'Exact alarms';

  @override
  String get permissionLocationTitle => 'Location';

  @override
  String get permissionCalendarTitle => 'Calendar';

  @override
  String get permissionUsageStatsTitle => 'Usage access';

  @override
  String get permissionFullScreenIntentTitle => 'Full-screen access';

  @override
  String get permissionStatusGranted => 'Granted';

  @override
  String get permissionStatusDenied => 'Not granted — tap to ask again';

  @override
  String get permissionStatusBlocked => 'Blocked. Tap \'Settings\' to grant.';

  @override
  String get permissionStatusNotAsked => 'Not asked yet — tap to ask';

  @override
  String get permissionSettingsButton => 'Settings';

  @override
  String get permissionBackupFolderTitle => 'Backup folder';

  @override
  String get permissionBackupFolderNotPicked => 'Not picked — tap to pick';

  @override
  String get permissionBackupFolderRePick => 'Re-pick';

  @override
  String permissionBackupFolderSet(String path) {
    return 'Backup folder set: $path';
  }

  @override
  String permissionBackupFolderError(String message) {
    return 'Folder picker error: $message';
  }

  @override
  String get permissionCallScreeningTitle => 'Call-screening role';

  @override
  String get permissionCallScreeningChecking => 'Checking…';

  @override
  String get permissionCallScreeningHeld =>
      'Held — Japan routine can intercept calls.';

  @override
  String get permissionCallScreeningNotHeld =>
      'Not held — tap \"Change\" to grant the role.';

  @override
  String get permissionCallScreeningChange => 'Change';

  @override
  String get permissionCallScreeningGrant => 'Grant';

  @override
  String get onboardingAppBarTitle => 'Welcome to do it';

  @override
  String get onboardingLastStepAppBarTitle => 'Last step';

  @override
  String get onboardingStepNotificationsTitle => 'Notifications';

  @override
  String get onboardingStepNotificationsBody =>
      'do it sends a daily reminder for each do. Android asks for the notification permission once.';

  @override
  String get onboardingStepNotificationsCta => 'Allow';

  @override
  String get onboardingStepContactsTitle => 'Contacts';

  @override
  String get onboardingStepContactsBody =>
      'If you add a \"cadence\" do — call Mom every Sunday — do it reads the contact you pick. It never imports the whole address book.';

  @override
  String get onboardingStepContactsCta => 'Allow';

  @override
  String get onboardingStepExactAlarmsTitle => 'Exact alarms';

  @override
  String get onboardingStepExactAlarmsBody =>
      'Exact alarms fire reminders on the minute, not up to 15 minutes late. If you decline, do it falls back to a best-effort schedule.';

  @override
  String get onboardingStepExactAlarmsCta => 'Allow';

  @override
  String get onboardingStepBackupFolderTitle => 'Backup folder';

  @override
  String get onboardingStepBackupFolderBody =>
      'Pick a folder on your phone (or SD card) for nightly auto-backups. do it writes a single encrypted file; the folder stays yours.';

  @override
  String get onboardingStepBackupFolderCta => 'Pick folder';

  @override
  String get onboardingStepCallScreeningTitle => 'Call-screening role';

  @override
  String get onboardingStepCallScreeningBody =>
      'Optional: let do it screen incoming calls so the Japan routine can ring specific contacts through silent mode. Android will ask you to confirm.';

  @override
  String get onboardingStepCallScreeningCta => 'Grant';

  @override
  String get onboardingSkipCta => 'Skip';

  @override
  String get onboardingOpenAndroidSettingsCta => 'Open Android settings';
}
