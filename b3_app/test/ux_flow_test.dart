import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:b3_app/features/home/screens/home_screen.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/data/household_repository.dart';
import 'package:b3_app/data/household_snapshot.dart';

class TestHouseholdRepository implements HouseholdRepository {
  HouseholdSnapshot? _snapshot;

  @override
  Future<HouseholdSnapshot?> load() async => _snapshot;

  @override
  Future<void> save(HouseholdSnapshot snapshot) async {
    _snapshot = snapshot;
  }

  @override
  Future<void> clear() async {
    _snapshot = null;
  }
}

void main() {
  testWidgets('First use flow - starts diagnostic',
      (WidgetTester tester) async {
    final repo = TestHouseholdRepository();

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(repository: repo),
    ));
    await tester.pumpAndSettle();

    // Verify "Commencer mon diagnostic" is visible
    expect(find.text('Commencer mon diagnostic'), findsOneWidget);

    // Tap it
    await tester.ensureVisible(find.text('Commencer mon diagnostic'));
    await tester.tap(find.text('Commencer mon diagnostic'));
    await tester.pumpAndSettle();

    // Verify we are on diagnostic screen with intro text
    expect(
        find.text(
            'B3 va analyser les moyens dont votre foyer dispose si certains services deviennent indisponibles.\nRépondez simplement selon votre situation actuelle.'),
        findsOneWidget);
    expect(find.text('Question 1'), findsOneWidget);
  });

  testWidgets('Resume flow - avoids immediate diagnostic',
      (WidgetTester tester) async {
    final repo = TestHouseholdRepository();
    final config = HouseholdConfig(ownedAssets: []);
    await repo.save(HouseholdSnapshot(
        scenarioId: 'panne_elec',
        schemaVersion: 1,
        config: config,
        completedActionIds: []));

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(repository: repo),
    ));
    await tester.pumpAndSettle();

    // Verify "Reprendre mon analyse" is visible
    expect(find.text('Reprendre mon analyse'), findsOneWidget);
    expect(find.text('Commencer mon diagnostic'), findsNothing);

    // Tap resume
    await tester.ensureVisible(find.text('Reprendre mon analyse'));
    await tester.tap(find.text('Reprendre mon analyse'));
    await tester.pumpAndSettle();

    // Should be on results/overview
    expect(find.text('Bilan de résilience'), findsOneWidget);
  });

  testWidgets('Responsive width test', (WidgetTester tester) async {
    final widths = [320.0, 360.0, 390.0, 430.0];
    final repo = TestHouseholdRepository();

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final w in widths) {
      tester.view.physicalSize = Size(w, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(repository: repo),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Commencer mon diagnostic'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
