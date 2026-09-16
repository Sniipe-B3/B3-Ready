import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:b3_app/features/home/screens/home_screen.dart';
import 'package:b3_app/data/household_snapshot.dart';
import 'package:b3_app/data/household_repository.dart';
import 'package:b3_engine/b3_engine.dart';

void main() {
  testWidgets('FLOW Resume', (WidgetTester tester) async {
    final repo = FakeHouseholdRepository();
    final config = HouseholdConfig(ownedAssets: ['poele_bois']);
    final snapshot = HouseholdSnapshot(
      schemaVersion: 1, 
      scenarioId: 'panne_elec', 
      completedActionIds: [], 
      config: config
    );
    await repo.save(snapshot);

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(repository: repo),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Reprendre mon foyer'), findsOneWidget);
    expect(find.text('Commencer mon diagnostic'), findsNothing);

    // Tap Reprendre mon foyer
    final btn = find.text('Reprendre mon foyer');
    await tester.ensureVisible(btn);
    await tester.pumpAndSettle();
    await tester.tap(btn);
    await tester.pumpAndSettle();

    // Should go to Results screen. Since we used a fake snapshot and didn't provide questions,
    // the results screen will reconstruct the session and show the result.
    expect(find.text('Bilan de résilience'), findsOneWidget);
  });

  testWidgets('FLOW Reset', (WidgetTester tester) async {
    final repo = FakeHouseholdRepository();
    final config = HouseholdConfig(ownedAssets: ['poele_bois']);
    final snapshot = HouseholdSnapshot(
      schemaVersion: 1, 
      scenarioId: 'panne_elec', 
      completedActionIds: [], 
      config: config
    );
    await repo.save(snapshot);

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(repository: repo),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Réinitialiser mon foyer'), findsOneWidget);

    // Tap reset
    final btnReset = find.text('Réinitialiser mon foyer');
    await tester.ensureVisible(btnReset);
    await tester.pumpAndSettle();
    await tester.tap(btnReset);
    await tester.pumpAndSettle();

    // Confirm dialog
    expect(find.text('Toutes vos données locales seront supprimées. Confirmer ?'), findsOneWidget);
    await tester.tap(find.text('Réinitialiser'));
    await tester.pumpAndSettle();

    // Now it should be clear
    expect(find.text('Reprendre mon foyer'), findsNothing);
    expect(find.text('Commencer mon diagnostic'), findsOneWidget);
  });
}
