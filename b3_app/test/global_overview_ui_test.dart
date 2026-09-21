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
        ownedAssets: ['radiateur_elec', 'plaque_elec'],
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
    expect(find.text('Fragilités récurrentes'), findsNothing); // Aucune car vulnérable dans 1 seul scénario !
    expect(find.text('Dépendances communes'), findsOneWidget);
    expect(find.text('Actions utiles dans plusieurs scénarios'), findsOneWidget);
    
    // Noms humains (elec -> Réseau Électrique)
    expect(find.text('elec'), findsNothing);
    expect(find.text('cuisiner'), findsNothing);
    expect(find.text('Réseau Électrique'), findsWidgets);

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
