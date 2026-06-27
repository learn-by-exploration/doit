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

  /// Tooltip / aria-label for the in-app home tile's 'Mark done' IconButton. Mirrors the widget surface (v1.4a).
  ///
  /// In en, this message translates to:
  /// **'Mark done'**
  String get homeTileMarkDone;

  /// Subtitle rendered next to the streak number on the in-app home tile (e.g. '5 day streak'). Mirrors the widget's middle row.
  ///
  /// In en, this message translates to:
  /// **'day streak'**
  String get homeTileStreakLabel;

  /// Tooltip shown when the user long-presses a 'Done' tile that has already been marked done today.
  ///
  /// In en, this message translates to:
  /// **'Already done for today'**
  String get homeTileAlreadyDoneTooltip;

  /// Tooltip shown for the tile's 'Mark done' IconButton on a Strong-mode do. The tap launches the mission UI (v1.3d / SYS-114) which writes the completion on ChainPassed.
  ///
  /// In en, this message translates to:
  /// **'Opens the mission chain'**
  String get homeTileStrongModeHint;

  /// Tooltip / aria-label for the in-app home tile's 'Skip today' IconButton (v1.4c / SYS-117). Tap writes a rest-day completion (consumes one budget unit) so the streak is credited and the day is marked intentionally off.
  ///
  /// In en, this message translates to:
  /// **'Skip today'**
  String get homeTileSkipToday;

  /// Tooltip shown when the user long-presses a tile that has already been marked as a rest day for today. Mirrors the 'Already done for today' hint for the manual-completion surface.
  ///
  /// In en, this message translates to:
  /// **'Rest day taken'**
  String get homeTileSkipAlready;

  /// Snackbar copy after a successful 'Skip today' tap (v1.4c / SYS-117).
  ///
  /// In en, this message translates to:
  /// **'Rest day taken — streak holds.'**
  String get homeTileSkipSuccess;

  /// Snackbar copy when the user taps 'Skip today' but the do has zero rest-day budget remaining for the current month (v1.4c / SYS-117).
  ///
  /// In en, this message translates to:
  /// **'No rest days left this month.'**
  String get homeTileSkipBudgetExhausted;

  /// Caption under the streak badge on the home tile (v1.4c / SYS-117). Renders only when restDaysPerMonth > 0 and at least one rest day has been used. placeholders: remaining (int) and limit (int).
  ///
  /// In en, this message translates to:
  /// **'{remaining}/{limit} rest days left'**
  String homeTileBudgetRemaining(int remaining, int limit);

  /// Caption under the streak badge on the home tile when restDaysPerMonth > 0 but the user has used all budget units for the month (v1.4c / SYS-117). Distinct from 'No budget configured' — the do opted into rest days but has used them all.
  ///
  /// In en, this message translates to:
  /// **'No rest days left'**
  String get homeTileBudgetNoRemaining;

  /// Tooltip / aria-label for the in-app home tile's 'Undo today' IconButton (v1.4d / SYS-118). Visible only when the tile is 'resolved' for today (Done tap or Skip tap recorded). Tap opens a confirm dialog; the confirm reverts the completion via CompletionLogService.deleteById.
  ///
  /// In en, this message translates to:
  /// **'Undo today'**
  String get homeTileUndoToday;

  /// Title of the AlertDialog that confirms an in-app home tile Undo tap (v1.4d / SYS-118). Mirrors the CompletionLogSection's 'Delete this completion?' title but at the tile surface.
  ///
  /// In en, this message translates to:
  /// **'Undo today\'s completion?'**
  String get homeTileUndoConfirm;

  /// Body copy of the AlertDialog that confirms an in-app home tile Undo tap (v1.4d / SYS-118). Sets the user's expectation: the row is deleted, the streak decrements by 1 (or the rest-day budget re-increments by 1 for the skip path).
  ///
  /// In en, this message translates to:
  /// **'This will remove today\'s check-in. The streak will update.'**
  String get homeTileUndoConfirmBody;

  /// Snackbar copy after a successful in-app home tile Undo tap (v1.4d / SYS-118). Mirrors the CompletionLogSection's 'Completion removed.' snackbar but at the tile surface.
  ///
  /// In en, this message translates to:
  /// **'Completion removed.'**
  String get homeTileUndoSuccess;

  /// Snackbar copy when the in-app home tile Undo tap completes but the DB has no row to delete (v1.4d / SYS-118). Defensive — the dialog is gated on _isResolvedToday == true, but the DB is the source of truth and a concurrent app-tile rebuild could leave a dangling flag.
  ///
  /// In en, this message translates to:
  /// **'Nothing to undo for today.'**
  String get homeTileUndoNotToday;

  /// Semantics label for the streak history sparkline row on the in-app home tile. Originally wrapped a 7-dot row (v1.4e / SYS-119); extended to a 14-day window (a fortnight) in v1.4i / SYS-123 so the rest-day color distinction has enough context to be useful. The Semantics node wraps the dots so screen readers announce 'Last 14 days' once instead of 14 separate dots.
  ///
  /// In en, this message translates to:
  /// **'Last 14 days'**
  String get homeTileSparklineSemantics;

  /// Tooltip / accessibility label for a sparkline dot whose underlying completion row has source = 'rest_day' (v1.4i / SYS-123). The dot is filled with colorScheme.tertiary so the user can spot rest days at a glance; the tooltip reinforces the meaning for screen-reader users.
  ///
  /// In en, this message translates to:
  /// **'Rest day'**
  String get homeTileSparklineRestDayTooltip;

  /// Tooltip / accessibility label for a sparkline dot whose underlying completion row has source in 'manual' / 'notification' / 'mission' (v1.4i / SYS-123). The dot is filled with colorScheme.primary.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get homeTileSparklineDoneTooltip;

  /// Tooltip / accessibility label for a sparkline dot whose underlying day has no completion row (v1.4i / SYS-123). The dot is outlined with colorScheme.outline.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get homeTileSparklineMissedTooltip;

  /// Legend label rendered below the sparkline row for the primary-filled 'done' swatch (v1.4i / SYS-123). Mirrors the homeTileSparklineDoneTooltip semantics.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get homeTileSparklineLegendDone;

  /// Legend label rendered below the sparkline row for the tertiary-filled 'rest day' swatch (v1.4i / SYS-123). Mirrors the homeTileSparklineRestDayTooltip semantics.
  ///
  /// In en, this message translates to:
  /// **'Rest day'**
  String get homeTileSparklineLegendRestDay;

  /// Legend label rendered below the sparkline row for the outlined 'missed' swatch (v1.4i / SYS-123). Mirrors the homeTileSparklineMissedTooltip semantics.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get homeTileSparklineLegendMissed;

  /// Tooltip / contentDescription for the Android home widget's 'Skip today' ImageButton (v1.4f / SYS-120). Tapping it appends a rest-day completion via CompletionLogService (consuming one rest-day budget unit) so the streak is credited and the day is marked intentionally off. Mirrors the in-app tile's `homeTileSkipToday`.
  ///
  /// In en, this message translates to:
  /// **'Skip today'**
  String get widgetSkipToday;

  /// Tooltip / contentDescription for the Android home widget's 'Undo today' ImageButton (v1.4f / SYS-120). Tapping it deletes today's completion (or rest-day) row via CompletionLogService.deleteById. Visible only when isCompletedToday is true; mirrors the in-app tile's `homeTileUndoToday`.
  ///
  /// In en, this message translates to:
  /// **'Undo today'**
  String get widgetUndoToday;

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

  /// Tooltip for the in-app home tile's per-tile edit IconButton (v1.4h / SYS-122). Tapping opens the AddHabitScreen in edit mode for this do — same destination as the body-tap but explicit so the affordance is discoverable without long-press.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get homeTileEdit;

  /// Tooltip for the in-app home tile's per-tile delete IconButton (v1.4h / SYS-122). Tapping opens a confirm dialog; on confirm, the do is removed from the DB and the tile disappears. The post-delete SnackBar offers an Undo action that re-saves the captured do.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get homeTileDelete;

  /// Title of the AlertDialog that confirms a per-tile delete tap (v1.4h / SYS-122). Includes the do name so the user can verify they're deleting the right entry — destructive actions should always confirm. The {doName} placeholder is the do's display name.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{doName}\"?'**
  String homeTileDeleteConfirm(String doName);

  /// Body copy of the AlertDialog that confirms a per-tile delete tap (v1.4h / SYS-122). Sets the expectation: cascade-delete the completions too (the CompletionLogService.deleteByHabit foreign-key cascade handles this), and tells the user the SnackBar will offer an Undo affordance.
  ///
  /// In en, this message translates to:
  /// **'This will remove the do and all of its completions. You can undo for a few seconds after.'**
  String get homeTileDeleteConfirmBody;

  /// Snackbar copy after a successful per-tile delete tap (v1.4h / SYS-122). The {doName} placeholder is the captured do's name. The SnackBar has an Undo action that re-saves the captured do via DoRepository.save.
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{doName}\".'**
  String homeSnackbarDoDeleted(String doName);

  /// Action label for the per-tile delete SnackBar's Undo affordance (v1.4h / SYS-122). Tapping it re-saves the captured do via DoRepository.save, restoring the row + its streak history (the streak calculator re-derives from the surviving completions). Matches the standard Material 'Undo' pattern.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get homeSnackbarDoDeletedUndo;

  /// Snackbar copy when the per-tile delete helper returns false (DB locked, constraint violation, etc.) — the tile is NOT removed and the user can retry. Defensive: the home screen keeps its previous state so a partial delete doesn't leave the UI inconsistent.
  ///
  /// In en, this message translates to:
  /// **'Could not delete. Try again.'**
  String get homeSnackbarDoDeleteFailed;

  /// Caption under the streak badge on the home tile when restDaysPerMonth == 0 (v1.4j / SYS-124). The caption is the affordance — tapping it opens the RestDayPickerDialog so the user can set a non-zero budget. Previously this state was hidden entirely (the caption early-returned); v1.4j surfaces it so users learn the budget exists.
  ///
  /// In en, this message translates to:
  /// **'No rest days configured'**
  String get homeTileBudgetZeroCaption;

  /// Title of the RestDayPickerDialog (v1.4j / SYS-124). Shown from both the home tile (tap the budget caption) and the AddHabitScreen (tap the form row). Title is the same on both surfaces — single source of truth via the shared picker helper.
  ///
  /// In en, this message translates to:
  /// **'Rest days per month'**
  String get homeTileBudgetEditTitle;

  /// Body copy of the RestDayPickerDialog (v1.4j / SYS-124). Explains the scope ('each month') and the roll-over behavior ('resets on the 1st') so the user can set a number with the right mental model. Mirrors the design docs on SkipBudget (v1.4c / SYS-117).
  ///
  /// In en, this message translates to:
  /// **'How many rest days you can take each month. Resets on the 1st.'**
  String get homeTileBudgetEditDescription;

  /// Save button label of the RestDayPickerDialog (v1.4j / SYS-124). 'Save' matches the AddHabitScreen save pattern; 'OK' was rejected to avoid overloading the term (we already use 'OK' on the interval-picker dialog at add_habit.dart:621-660).
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get homeTileBudgetEditOk;

  /// Cancel button label of the RestDayPickerDialog (v1.4j / SYS-124). Matches the cancel pattern on the interval-picker dialog at add_habit.dart:621-660.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get homeTileBudgetEditCancel;

  /// Snackbar copy after a successful home tile budget edit tap (v1.4j / SYS-124). The {newValue} placeholder is the picked integer (0..31). Distinct from homeSnackbarDoDeleted (v1.4h) — this is a non-destructive update.
  ///
  /// In en, this message translates to:
  /// **'Rest-day budget set to {newValue}.'**
  String homeSnackbarBudgetUpdated(int newValue);

  /// Snackbar copy when the home tile budget edit save throws (e.g. DoInvalidRestDays if validation is bypassed somehow — defensive, the picker clamps inline so this never fires in practice; v1.4j / SYS-124). The tile is NOT removed on failure.
  ///
  /// In en, this message translates to:
  /// **'Could not update budget. Try again.'**
  String get homeSnackbarBudgetUpdateFailed;

  /// Form-row label on the AddHabitScreen (v1.4j / SYS-124) showing the current restDaysPerMonth value. The {value} placeholder is the picked integer. The label is the affordance — tapping the row opens the RestDayPickerDialog. Closes the silent-reset bug from v1.0 where the value was hardcoded to 2 in all 5 switch branches of _save() and never exposed as a form input.
  ///
  /// In en, this message translates to:
  /// **'Rest days per month: {value}'**
  String addHabitRestDaysLabel(int value);

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

  /// v1.4k / Phase 38 / SYS-125 / ADR-055 / WF-052. AppBar title of the Android AppWidget configuration activity — shown to the user when they bind the do it home widget from the launcher. Mirrors the launcher 'Pick a do' prompt.
  ///
  /// In en, this message translates to:
  /// **'Choose a do for do it'**
  String get widgetConfigureTitle;

  /// v1.4k / Phase 38 / SYS-125 / ADR-055 / WF-052. Empty-state copy shown inside the widget configuration activity when the user has zero dos. Tapping the 'Add a do' button on the same screen pops the user back to MainActivity so the first-run flow can take over.
  ///
  /// In en, this message translates to:
  /// **'Add a do in do it to use the home widget.'**
  String get widgetConfigureEmptyState;

  /// v1.4k / Phase 38 / SYS-125 / ADR-055 / WF-052. CTA label on the widget-configuration empty-state. Pops the configuration activity so the launcher can show the home widget at its default state (or the user can return to MainActivity to add a do).
  ///
  /// In en, this message translates to:
  /// **'Back to do it'**
  String get widgetConfigureBackToHome;
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
