import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:b3_app/app/app.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/data/household_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Global Overview End-to-End Test', (WidgetTester tester) async {
    final initialSnapshot = HouseholdSnapshot(
      config: HouseholdConfig(
        ownedAssets: ['radiateur_elec', 'plaques_elec'],
        ownedResources: [],
        resourceDurations: {},
        assessedCapabilities: {'chauffer', 'cuisiner'},
        capabilityOverrides: {},
        assessedResources: {},
        unknownResources: {},
      ),
      schemaVersion: 1,
      scenarioId: 'global',
      completedActionIds: [],
    );

    SharedPreferences.setMockInitialValues({
      'b3_household_snapshot': jsonEncode(initialSnapshot.toJson()),
    });

    tester.view.physicalSize = const Size(1080, 5000);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(const B3App());
    await tester.pumpAndSettle();

    await tester.tap(find.text("Résilience par scénario"), warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.tap(find.text("Vue globale du foyer"), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Check sections exist
    expect(find.text('Fragilités récurrentes'), findsOneWidget);
    expect(find.text('Dépendances communes'), findsOneWidget);
    expect(find.text('Actions utiles dans plusieurs scénarios'), findsOneWidget);

    // Tap on capability (cuisiner)
    final btnCuisiner = find.text('cuisiner');
    expect(btnCuisiner, findsWidgets);
    await tester.tap(btnCuisiner.first);
    await tester.pumpAndSettle();
    expect(find.text('Vulnérable'), findsWidgets);
    
    // Close modal by tapping far away
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    final btnVoirAction = find.text("Voir l'action");
    expect(btnVoirAction, findsWidgets);
    await tester.tap(btnVoirAction.first, warnIfMissed: false);
    await tester.pumpAndSettle();

    final btnOuvrirAction = find.text("Ouvrir dans mon plan d'action");
    expect(btnOuvrirAction, findsOneWidget);
    await tester.tap(btnOuvrirAction);
    await tester.pumpAndSettle();

    // Inside ProgressionScreen
    // Inside ProgressionScreen, it just shows the success message
    final btnVoirNouveauPlan = find.text("Voir mon nouveau plan");
    expect(btnVoirNouveauPlan, findsOneWidget);
    await tester.tap(btnVoirNouveauPlan);
    await tester.pumpAndSettle();

    // It should pop back to OverviewScreen (since GlobalOverviewScreen also popped itself)
    expect(find.text('Votre foyer face aux perturbations'), findsOneWidget);
  });
}
