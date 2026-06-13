// Streak — Phase 0 scaffold entry.
//
// This file is intentionally minimal. It boots the Flutter binding,
// runs a `MaterialApp` with a dark default theme (per
// docs/v_model/architecture_options.md § "Early Design Decisions"),
// and shows a placeholder home screen. No business logic ships in
// Phase 0 — that lands in later phases per the V-Model discipline
// in AGENTS.md.

import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StreakApp());
}

class StreakApp extends StatelessWidget {
  const StreakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Streak',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.dark,
      home: const ScaffoldScaffold(),
    );
  }
}

/// Phase 0 placeholder. Replaced by `lib/screens/home.dart` in Phase 5.
class ScaffoldScaffold extends StatelessWidget {
  const ScaffoldScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Streak — scaffold')),
      body: const Center(
        child: Text(
          'Streak is loading.',
          key: ValueKey<String>('streak.scaffold.subtitle'),
        ),
      ),
    );
  }
}
