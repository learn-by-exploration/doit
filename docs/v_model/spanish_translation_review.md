# Spanish translation review (feature.md §2.4)

## Status

**v1.3d — native-speaker review pass: NOT YET PERFORMED.**

The Spanish catalog (`lib/l10n/app_es.arb`) is a v1.1h
smoke-test locale — every key has a translation, but the
translations were written by a non-native speaker (the
project author) without a native-speaker review pass.
Feature `feature.md §2.4` calls for a native Spanish
speaker to audit the catalog and replace any awkward or
ungrammatical strings.

## What §2.4 asks for

A native Spanish speaker reviews every string in
`lib/l10n/app_es.arb` (81 keys across home / settings /
permissions / onboarding copy + 2 ICU plural keys) and
edits any string that does not read as natural Mexican /
Rioplatense / peninsular Spanish in the dominant target
market. The reviewer must:

1. **Read every key in the live UI.** Pick Spanish in
   Android Settings → System → Languages, launch do it,
   and walk through home / settings / permissions tile /
   onboarding. Note any string that reads awkwardly.

2. **Edit `lib/l10n/app_es.arb` in place.** No new file;
   no `app_es_MX.arb` / `app_es_AR.arb` split (the
   `supportedLocales: [en, es]` is single-locale today;
   a regional split is a v2.x consideration).

3. **Keep `homeSelectionAppBarTitle` and
   `homeSnackbarMarkedCount` as ICU plurals.** The English
   catalog uses `{count, plural, =0{...} =1{...} other{...}}`;
   the Spanish catalog must mirror that shape — the codegen
   (`flutter gen-l10n`) rejects a non-plural Spanish version.

4. **Keep every key in sync with `app_en.arb`.** Adding /
   removing a key in either catalog without the other is a
   build error (the codegen checks parity).

5. **Do NOT edit the generated `lib/l10n/gen/*.dart`.**
   Those are produced by `flutter gen-l10n` and are
   overwritten on every codegen run.

## What §2.4 does NOT cover

- **A second locale (e.g., `app_fr.arb`,
  `app_de.arb`).** Not in scope. Adding a new locale is
  its own PR (new file, codegen regen, `supportedLocales`
  extension, widget-test refresh).
- **A Mexican-vs-Rioplatense split.** The current
  catalog uses neutral / international Spanish. A regional
  split (`app_es_419.arb` vs `app_es_ES.arb`) is a v2.x
  consideration that requires deciding the target market
  first.
- **Right-to-left or bidi layout.** Spanish is LTR; no
  layout change needed.
- **Currency / date / number formatting changes.** All
  dates are ISO-style (`YYYY-MM-DD`) and number formatting
  uses `intl` defaults that already handle es-ES style.

## What PR #29 ships

PR #29 is a **review-process** PR. It does NOT edit the
catalog beyond two low-risk gender-agreement / conjugation
fixes:

1. `settingsAnchorManual`: `"Manual — toco ..."` →
   `"Manual — tocas ..."` (second-person imperative
   matches every other settings tile in the app — every
   tile addresses the user as `tú`, not `yo`).

The remaining 80 keys are flagged below for the
reviewer's attention. A complete native-speaker pass is
a separate PR owned by the reviewer.

## Reviewer checklist

The reviewer should consider each of these 81 keys
critically. The list below flags the strings the author
suspects might read awkwardly; the reviewer should NOT
treat the absence of a flag as a "this is fine" signal —
**every key** should be reviewed.

### Home screen

| Key | Translation | Author note |
|---|---|---|
| `homeAppBarTitle` | `do it` | Brand string; no translation. |
| `homeSelectionAppBarTitle` | `Sin selección / 1 seleccionado / {count} seleccionados` | "seleccionado" is masculine; the app's "do" entity is rendered as masculine in the smoke-test. Reviewer should decide if the entity is "un do" (neologism, masculine) or "una tarea" (feminine). If the latter, change "seleccionado" → "seleccionada". |
| `homeSnackbarMarkedDone` | `Marcado como hecho.` | "hecho" is masculine; consistent with the "do" entity-as-masculine decision above. |
| `homeSnackbarMarkedCount` | `Marcados {count} como hechos.` | Same as above. |
| `homeEmptyTitle` | `Sin tareas aún.` | "Tareas" is feminine (alternative to "dos"). The English catalog uses "No dos yet." — the Spanish uses "tareas" because "do" as a countable noun is awkward in Spanish. **This is a translator choice the reviewer should explicitly approve or reject.** |
| `homeRetryButton` | `Reintentar` | Fine. |
| `homeAddSheetNewDo` | `Nueva tarea` | Same translator choice as `homeEmptyTitle`. |
| `homeAddSheetNewPerson` | `Nueva persona` | "persona" is feminine; consistent. |
| `homeAddSheetFromTemplate` | `Desde plantilla` | Fine. |

### Settings

| Key | Translation | Author note |
|---|---|---|
| `settingsAppBarTitle` | `Ajustes` | Fine; "Ajustes" is the standard Mexican-Spanish term. |
| `settingsSectionAppearance` | `Apariencia` | Fine. |
| `settingsSectionAnchor` | `Ancla de despertar` | Fine. |
| `settingsSectionPermissions` | `Permisos` | Fine. |
| `settingsSectionReliability` | `Fiabilidad` | Fine (vs "Confiabilidad" — both are valid; "Fiabilidad" is more common in technical contexts). |
| `settingsSectionDeviceState` | `Estado del dispositivo` | Fine. |
| `settingsSectionStats` | `Estadísticas` | Fine. |
| `settingsStatsTitle` | `Estadísticas` | Fine. |
| `settingsStatsSubtitle` | `Rachas, tasa de cumplimiento, gráfico de 7 días.` | Fine; "Rachas" matches the home tile's "Consecutive done" copy. |
| `settingsSectionBackup` | `Copia de seguridad` | Fine. |
| `settingsSectionAbout` | `Acerca de` | Fine. |
| `settingsThemeDark` | `Oscuro` | Fine. |
| `settingsThemeLight` | `Claro` | Fine. |
| `settingsThemeSystem` | `Sistema` | Fine. |
| `settingsAnchorManual` | `Manual — tocas "Ya estoy despierto"` | **Fixed in PR #29** (was `toco`, first-person). |
| `settingsAnchorFirstUnlock` | `Primer desbloqueo del día` | Fine. |
| `settingsAnchorEither` | `Cualquiera, con confirmación` | Fine. |
| `settingsReminderReliabilityTitle` | `Fiabilidad de los recordatorios` | Fine. |
| `settingsReminderReliabilityOptimal` | `Óptima — alarma exacta concedida.` | Fine. |
| `settingsReminderReliabilityDegraded` | `Degradada — usando fallback de WorkManager.` | Fine. |
| `settingsReminderReliabilityUnknown` | `Desconocida — primer inicio, comprobación pendiente.` | "Comprobación" might be more naturally "verificación" in some regions; flag for reviewer. |
| `settingsTestReminderTitle` | `Enviar un recordatorio de prueba` | Fine. |
| `settingsTestReminderSubtitle` | `Envía una notificación en ~5 segundos.` | Fine. |
| `settingsTestReminderSnackbar` | `Recordatorio de prueba programado en 5s.` | Fine. |
| `settingsRestoreTitle` | `Restaurar desde copia de seguridad` | Fine. |
| `settingsRestoreSubtitle` | `Elige un archivo .json de copia de seguridad de do it.` | Fine. |
| `settingsAboutAppVersion` | `{version} — solo local. Consulta PRIVACY.md para los datos que guardamos y los que no.` | Fine. |
| `settingsLicensesTitle` | `Licencias de código abierto` | Fine. |
| `settingsLicensesSubtitle` | `Flutter, Drift, flutter_local_notifications, …` | Fine. |

### Permissions tile

| Key | Translation | Author note |
|---|---|---|
| `permissionNotificationsTitle` | `Notificaciones` | Fine. |
| `permissionContactsTitle` | `Contactos` | Fine. |
| `permissionExactAlarmTitle` | `Alarmas exactas` | Fine. |
| `permissionLocationTitle` | `Ubicación` | Fine. |
| `permissionCalendarTitle` | `Calendario` | Fine. |
| `permissionUsageStatsTitle` | `Acceso de uso` | "Acceso de uso" might be more naturally "Acceso de estadísticas de uso" or "Acceso a datos de uso"; flag for reviewer. |
| `permissionFullScreenIntentTitle` | `Acceso a pantalla completa` | Fine. |
| `permissionStatusGranted` | `Concedido` | Fine. |
| `permissionStatusDenied` | `No concedido — toca para pedir de nuevo` | "Tocar para pedir de nuevo" or "Toca para volver a pedir" might be more natural; flag for reviewer. |
| `permissionStatusBlocked` | `Bloqueado. Toca "Ajustes" para conceder.` | Fine. |
| `permissionStatusNotAsked` | `Aún no se ha pedido — toca para pedir` | Fine. |
| `permissionSettingsButton` | `Ajustes` | Fine. |
| `permissionBackupFolderTitle` | `Carpeta de copia` | Fine. |
| `permissionBackupFolderNotPicked` | `Sin elegir — toca para elegir` | Fine. |
| `permissionBackupFolderRePick` | `Reelegir` | Fine (also "Volver a elegir" is acceptable). |
| `permissionBackupFolderSet` | `Carpeta de copia: {path}` | Fine. |
| `permissionBackupFolderError` | `Error del selector: {message}` | Fine. |
| `permissionCallScreeningTitle` | `Rol de filtrado de llamadas` | Fine. |
| `permissionCallScreeningChecking` | `Comprobando…` | Fine. |
| `permissionCallScreeningHeld` | `Concedido — la rutina Japón puede interceptar llamadas.` | Fine. |
| `permissionCallScreeningNotHeld` | `Sin conceder — toca "Cambiar" para conceder el rol.` | Fine. |
| `permissionCallScreeningChange` | `Cambiar` | Fine. |
| `permissionCallScreeningGrant` | `Conceder` | Fine. |

### Onboarding

| Key | Translation | Author note |
|---|---|---|
| `onboardingAppBarTitle` | `Bienvenido a do it` | Fine. |
| `onboardingLastStepAppBarTitle` | `Último paso` | Fine. |
| `onboardingStepNotificationsTitle` | `Notificaciones` | Fine. |
| `onboardingStepNotificationsBody` | `do it envía un recordatorio diario para cada tarea. Android pide el permiso de notificación una sola vez.` | Same `tarea`-vs-`do` translator choice. |
| `onboardingStepNotificationsCta` | `Permitir` | Fine. |
| `onboardingStepContactsTitle` | `Contactos` | Fine. |
| `onboardingStepContactsBody` | `Si añades una tarea de cadencia — llamar a mamá cada domingo — do it lee el contacto que elijas. Nunca importa toda la agenda.` | "Agenda" might be "libreta de direcciones" in some regions; flag. |
| `onboardingStepContactsCta` | `Permitir` | Fine. |
| `onboardingStepExactAlarmsTitle` | `Alarmas exactas` | Fine. |
| `onboardingStepExactAlarmsBody` | `Las alarmas exactas disparan los recordatorios al minuto, no hasta 15 minutos tarde. Si las rechazas, do it usa una programación de mejor esfuerzo.` | Fine. |
| `onboardingStepExactAlarmsCta` | `Permitir` | Fine. |
| `onboardingStepBackupFolderTitle` | `Carpeta de copia` | Fine. |
| `onboardingStepBackupFolderBody` | `Elige una carpeta en tu teléfono (o tarjeta SD) para las copias automáticas nocturnas. do it escribe un único archivo cifrado; la carpeta sigue siendo tuya.` | Fine. |
| `onboardingStepBackupFolderCta` | `Elegir carpeta` | Fine. |
| `onboardingStepCallScreeningTitle` | `Rol de filtrado de llamadas` | Fine. |
| `onboardingStepCallScreeningBody` | `Opcional: permite que do it filtre llamadas entrantes para que la rutina Japón pueda hacer sonar contactos específicos en modo silencio. Android te pedirá que confirmes.` | "Hacer sonar contactos específicos en modo silencio" reads awkwardly; "silenciar contactos específicos" or "silenciar el timbre para contactos específicos" might be more natural. **Reviewer attention.** |
| `onboardingStepCallScreeningCta` | `Conceder` | Fine. |
| `onboardingSkipCta` | `Omitir` | Fine. |
| `onboardingOpenAndroidSettingsCta` | `Abrir ajustes de Android` | Fine. |

## How to ship the native-speaker pass

The reviewer opens a separate PR (call it PR #N+1) titled
`feat(spanish): native-speaker review pass (feature.md §2.4)`
that:

1. Edits the flagged strings + any others the reviewer
   flags during the live-UI walk.
2. Updates the `Reviewed-by` row in this doc's "Reviewer
   log" section with the reviewer's name and date.
3. Runs `flutter gen-l10n` + `flutter test` (the
   `test/l10n/app_localizations_test.dart` file has 5
   structural assertions including key-set parity and
   ICU plural metadata; it will fail if a key is added /
   removed without the matching locale update).
4. Does NOT bump the app version; the version bump
   happens on the next release sign-off.

## Reviewer log

| Reviewer | Date | Notes |
|---|---|---|
| _(awaiting native-speaker reviewer)_ | | |