// Tests for the AddPersonScreen.

import 'package:doit/screens/add_person.dart';
import 'package:doit/services/db.dart';
import 'package:doit/services/db/schema.dart';
import 'package:doit/services/person_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _resetDb(WidgetTester tester) async {
  await AppDatabaseService.instance.closeForTesting();
  final db = AppDatabase(NativeDatabase.memory());
  await AppDatabaseService.instance.init(overrideDb: db);
  addTearDown(() async {
    await AppDatabaseService.instance.closeForTesting();
  });
}

Widget _wrap() => const MaterialApp(home: AddPersonScreen());

void main() {
  setUp(() {
    PersonRepository.instance;
  });

  testWidgets('Save with no contact shows error', (tester) async {
    await _resetDb(tester);
    await tester.pumpWidget(_wrap());
    await tester.tap(find.byKey(const ValueKey('add_person.save')));
    await tester.pump();
    expect(find.text('Pick a contact first.'), findsOneWidget);
  });

  testWidgets('Pick contact then save pops the route', (tester) async {
    await _resetDb(tester);
    await tester.pumpWidget(_wrap());
    await tester.tap(find.byKey(const ValueKey('add_person.pick_contact')));
    await tester.pump();
    expect(find.text('Demo Contact'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('add_person.save')));
    await tester.pumpAndSettle();
    expect(find.byType(AddPersonScreen), findsNothing);
  });
}
