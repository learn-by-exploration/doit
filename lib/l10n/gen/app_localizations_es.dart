// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

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
      other: '$countString seleccionados',
      one: '1 seleccionado',
      zero: 'Sin selección',
    );
    return '$_temp0';
  }

  @override
  String get homeSnackbarMarkedDone => 'Marcado como hecho.';

  @override
  String homeSnackbarMarkedCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    return 'Marcados $countString como hechos.';
  }

  @override
  String get homeTileMarkDone => 'Marcar como hecho';

  @override
  String get homeTileStreakLabel => 'días seguidos';

  @override
  String get homeTileAlreadyDoneTooltip => 'Ya marcado como hecho hoy';

  @override
  String get homeTileStrongModeHint => 'Abre la cadena de misiones';

  @override
  String get homeTileSkipToday => 'Saltar hoy';

  @override
  String get homeTileSkipAlready => 'Día de descanso tomado';

  @override
  String get homeTileSkipSuccess =>
      'Día de descanso tomado — la racha se mantiene.';

  @override
  String get homeTileSkipBudgetExhausted =>
      'No quedan días de descanso este mes.';

  @override
  String homeTileBudgetRemaining(int remaining, int limit) {
    return '$remaining/$limit días de descanso restantes';
  }

  @override
  String get homeTileBudgetNoRemaining => 'No quedan días de descanso';

  @override
  String get homeEmptyTitle => 'Sin tareas aún.';

  @override
  String get homeRetryButton => 'Reintentar';

  @override
  String get homeAddSheetNewDo => 'Nueva tarea';

  @override
  String get homeAddSheetNewPerson => 'Nueva persona';

  @override
  String get homeAddSheetFromTemplate => 'Desde plantilla';

  @override
  String get settingsAppBarTitle => 'Ajustes';

  @override
  String get settingsSectionAppearance => 'Apariencia';

  @override
  String get settingsSectionAnchor => 'Ancla de despertar';

  @override
  String get settingsSectionPermissions => 'Permisos';

  @override
  String get settingsSectionReliability => 'Fiabilidad';

  @override
  String get settingsSectionDeviceState => 'Estado del dispositivo';

  @override
  String get settingsSectionStats => 'Estadísticas';

  @override
  String get settingsStatsTitle => 'Estadísticas';

  @override
  String get settingsStatsSubtitle =>
      'Rachas, tasa de cumplimiento, gráfico de 7 días.';

  @override
  String get settingsSectionBackup => 'Copia de seguridad';

  @override
  String get settingsSectionAbout => 'Acerca de';

  @override
  String get settingsThemeDark => 'Oscuro';

  @override
  String get settingsThemeLight => 'Claro';

  @override
  String get settingsThemeSystem => 'Sistema';

  @override
  String get settingsAnchorManual => 'Manual — tocas \"Ya estoy despierto\"';

  @override
  String get settingsAnchorFirstUnlock => 'Primer desbloqueo del día';

  @override
  String get settingsAnchorEither => 'Cualquiera, con confirmación';

  @override
  String get settingsReminderReliabilityTitle =>
      'Fiabilidad de los recordatorios';

  @override
  String get settingsReminderReliabilityOptimal =>
      'Óptima — alarma exacta concedida.';

  @override
  String get settingsReminderReliabilityDegraded =>
      'Degradada — usando fallback de WorkManager.';

  @override
  String get settingsReminderReliabilityUnknown =>
      'Desconocida — primer inicio, comprobación pendiente.';

  @override
  String get settingsTestReminderTitle => 'Enviar un recordatorio de prueba';

  @override
  String get settingsTestReminderSubtitle =>
      'Envía una notificación en ~5 segundos.';

  @override
  String get settingsTestReminderSnackbar =>
      'Recordatorio de prueba programado en 5s.';

  @override
  String get settingsRestoreTitle => 'Restaurar desde copia de seguridad';

  @override
  String get settingsRestoreSubtitle =>
      'Elige un archivo .json de copia de seguridad de do it.';

  @override
  String settingsAboutAppVersion(String version) {
    return '$version — solo local. Consulta PRIVACY.md para los datos que guardamos y los que no.';
  }

  @override
  String get settingsLicensesTitle => 'Licencias de código abierto';

  @override
  String get settingsLicensesSubtitle =>
      'Flutter, Drift, flutter_local_notifications, …';

  @override
  String get permissionNotificationsTitle => 'Notificaciones';

  @override
  String get permissionContactsTitle => 'Contactos';

  @override
  String get permissionExactAlarmTitle => 'Alarmas exactas';

  @override
  String get permissionLocationTitle => 'Ubicación';

  @override
  String get permissionCalendarTitle => 'Calendario';

  @override
  String get permissionUsageStatsTitle => 'Acceso de uso';

  @override
  String get permissionFullScreenIntentTitle => 'Acceso a pantalla completa';

  @override
  String get permissionStatusGranted => 'Concedido';

  @override
  String get permissionStatusDenied =>
      'No concedido — toca para pedir de nuevo';

  @override
  String get permissionStatusBlocked =>
      'Bloqueado. Toca \"Ajustes\" para conceder.';

  @override
  String get permissionStatusNotAsked =>
      'Aún no se ha pedido — toca para pedir';

  @override
  String get permissionSettingsButton => 'Ajustes';

  @override
  String get permissionBackupFolderTitle => 'Carpeta de copia';

  @override
  String get permissionBackupFolderNotPicked => 'Sin elegir — toca para elegir';

  @override
  String get permissionBackupFolderRePick => 'Reelegir';

  @override
  String permissionBackupFolderSet(String path) {
    return 'Carpeta de copia: $path';
  }

  @override
  String permissionBackupFolderError(String message) {
    return 'Error del selector: $message';
  }

  @override
  String get permissionCallScreeningTitle => 'Rol de filtrado de llamadas';

  @override
  String get permissionCallScreeningChecking => 'Comprobando…';

  @override
  String get permissionCallScreeningHeld =>
      'Concedido — la rutina Japón puede interceptar llamadas.';

  @override
  String get permissionCallScreeningNotHeld =>
      'Sin conceder — toca \"Cambiar\" para conceder el rol.';

  @override
  String get permissionCallScreeningChange => 'Cambiar';

  @override
  String get permissionCallScreeningGrant => 'Conceder';

  @override
  String get onboardingAppBarTitle => 'Bienvenido a do it';

  @override
  String get onboardingLastStepAppBarTitle => 'Último paso';

  @override
  String get onboardingStepNotificationsTitle => 'Notificaciones';

  @override
  String get onboardingStepNotificationsBody =>
      'do it envía un recordatorio diario para cada tarea. Android pide el permiso de notificación una sola vez.';

  @override
  String get onboardingStepNotificationsCta => 'Permitir';

  @override
  String get onboardingStepContactsTitle => 'Contactos';

  @override
  String get onboardingStepContactsBody =>
      'Si añades una tarea de cadencia — llamar a mamá cada domingo — do it lee el contacto que elijas. Nunca importa toda la agenda.';

  @override
  String get onboardingStepContactsCta => 'Permitir';

  @override
  String get onboardingStepExactAlarmsTitle => 'Alarmas exactas';

  @override
  String get onboardingStepExactAlarmsBody =>
      'Las alarmas exactas disparan los recordatorios al minuto, no hasta 15 minutos tarde. Si las rechazas, do it usa una programación de mejor esfuerzo.';

  @override
  String get onboardingStepExactAlarmsCta => 'Permitir';

  @override
  String get onboardingStepBackupFolderTitle => 'Carpeta de copia';

  @override
  String get onboardingStepBackupFolderBody =>
      'Elige una carpeta en tu teléfono (o tarjeta SD) para las copias automáticas nocturnas. do it escribe un único archivo cifrado; la carpeta sigue siendo tuya.';

  @override
  String get onboardingStepBackupFolderCta => 'Elegir carpeta';

  @override
  String get onboardingStepCallScreeningTitle => 'Rol de filtrado de llamadas';

  @override
  String get onboardingStepCallScreeningBody =>
      'Opcional: permite que do it filtre llamadas entrantes para que la rutina Japón pueda hacer sonar contactos específicos en modo silencio. Android te pedirá que confirmes.';

  @override
  String get onboardingStepCallScreeningCta => 'Conceder';

  @override
  String get onboardingSkipCta => 'Omitir';

  @override
  String get onboardingOpenAndroidSettingsCta => 'Abrir ajustes de Android';
}
