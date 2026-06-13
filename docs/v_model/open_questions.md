# Open Questions

These questions should be answered before locking the v0.1 baseline
for implementation. The baseline is documented in
[`v0_1_baseline.md`](v0_1_baseline.md); the items below are the
remaining decisions that are *not* blocking but would change scope
or shape if answered differently.

1. **What does the "I'm up" anchor look like on the home screen?**
   - A persistent floating button?
   - A card pinned to the top?
   - A swipe-down gesture?
   - Current answer: a card pinned to the top of the home screen,
     with a long-press to anchor (no double-tap by accident). The
     quick-settings tile is a v0.2 candidate.
2. **Should the home screen show the streak-at-stake for the
   current reminder?**
   - Yes: "Don't break a 12-day streak".
   - No: shame is not the product.
   - Current answer: yes, but with a soft tone ("12 days in —
   - keep it going") and a settings toggle to hide it.
3. **Should interval habits support "snooze" or only "I drank /
   missed"?**
   - Snooze creates a new mini-window; a user could abuse it.
   - No snooze on Auto mode; on-time or missed.
   - Current answer: no snooze on Auto mode. The point of Auto is
     that time is the proof.
4. **Should the user be able to "lock" a habit's schedule for a
   week or a month to prevent edits?**
   - Useful for "I committed to this for 30 days" feel.
   - v0.2 candidate; v0.1 lets the user edit any field anytime
     (with the immutability rules of ADR-012).
5. **What happens if the user revokes `READ_CONTACTS` after
   adding a person?**
   - Pause all person-based habits, banner explains why.
   - v0.1: pause, banner. Re-granting the permission resumes.
6. **What happens if the SAF backup URI is revoked?**
   - Pause auto-backup, banner explains, ask the user to pick a
     new folder.
   - v0.1: pause, banner, manual re-pick. v0.2: try to recover
     gracefully if Android retains the URI across permission
     changes.
7. **Should the streak be visible on the home widget?**
   - Yes: "12-day streak — drink water in 8 min".
   - No: the widget is for *upcoming* not *past*.
   - Current answer: yes. The streak is the point.
8. **Should the app offer a "share my streak" feature?**
   - Social pressure / accountability.
   - Out of v0.1 scope. Tracking it as a possible v0.2.
9. **What if the user has the same habit name twice?**
   - Forbid duplicates? Allow with a disambiguator?
   - Current answer: forbid duplicates. The model throws
     `DuplicateHabitName`; the UI shows a suggestion.
10. **Should the app support per-habit color / icon customization?**
    - Small joy, useful for at-a-glance scanning.
    - v0.1 ships one icon per habit (preset list). Color is a
      v0.2.
11. **What is the minimum Android version?**
    - API 28 (Android 9) is the floor. Some users are on API 26
      (Android 8).
    - Current answer: API 28. Older devices are out of v0.1 scope.
12. **What if the user's phone does not have a vibrator or a
    speaker?**
    - Reminder is silent + visual.
    - The app should still fire, even on a tablet with no
      vibrator.
13. **What if the user adds a habit but never opens the app?**
    - Reminders still fire (because the alarm is in the OS).
    - The boot receiver keeps the schedule alive.
    - The app never silently "expires" a habit.
14. **Should the home screen widget be tappable per-item or only
    as a whole?**
    - Tappable per-item is the only useful design.
    - v0.1 supports per-item tap; whole-widget tap opens the app.
15. **How does the user discover the OEM auto-start card?**
    - Only on first run? Or surfaced again in Settings?
    - v0.1: surfaced on first run + always available in Settings.
16. **Should the user be able to test a mission without scheduling
    a real habit?**
    - Yes, useful for "I want to feel the Shake-N before I commit".
    - v0.1: a "Try a mission" screen in Settings → Missions.
17. **Should the app be a launcher (replace the home screen)?**
    - Some habit apps do this; some users love it, some hate it.
    - No. Streak is an app, not a launcher.
18. **Should the app support Android Auto or Wear OS?**
    - Out of v0.1 scope. Possible v0.2.
19. **What is the language for the v0.1 release?**
    - English only.
    - i18n is v0.2.
20. **Should we ship a `CHANGELOG.md` and `RELEASE_NOTES.md`?**
    - Yes, the standard 3-app pattern.
    - Track in v0.2 once the first release is cut.
