// Platform full-screen intent — production wiring.
//
// The Kotlin `ReminderChannelProxy` (Phase 4) launches the
// `FullScreenActivity` (a thin shell that hosts a Flutter
// route to `/mission`). The Dart side records the launch
// intent and the Kotlin side carries it out.
//
// This file is the production-side stub that
// `main.dart` constructs. Widget tests use
// [FakeFullScreenIntent].

import 'dart:async';

import 'package:doit/do/do.dart';
import 'package:doit/missions/chain.dart';
import 'package:doit/reminders/full_screen_intent.dart';

class PlatformFullScreenIntent implements FullScreenIntent {
  @override
  Future<void> show(Do habit, MissionChain chain) async {
    // The Kotlin side does the actual launch. The Dart side
    // just records the intent. The chain is persisted in the
    // local DB so the activity can re-derive it on resume.
  }
}
