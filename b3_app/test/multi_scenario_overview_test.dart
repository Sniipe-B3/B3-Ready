import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:b3_app/app/app.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/data/household_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('20. TEST OVERVIEW et 21. TEST PROGRESSION -> OVERVIEW', (WidgetTester tester) async {
    // Injecter un Household vulnérable en base
    final initialSnapshot = HouseholdSnapshot(
      config: HouseholdConfig(
        ownedAssets: ['radiateur_elec'],
        ownedResources: [],
        resourceDurations: {},
        assessedCapabilities: {'chauffer'},
        capabilityOverrides: {},
        assessedResources: {},
        unknownResources: {},
      ),
      schemaVersion: 1,
      scenarioId: 'panne_elec',
      completedActionIds: [],
    );

    SharedPreferences.setMockInitialValues({
      'b3_household_snapshot': jsonEncode(initialSnapshot.toJson()),
    });

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(const B3App());
    await tester.pumpAndSettle();

    // On est sur l'écran d'accueil, avec une configuration déjà existante.
    expect(find.text('B3 Ready'), findsOneWidget);
    
    final btnOverview = find.text('Résilience par scénario');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
    await tester.pumpAndSettle();
    
    await tester.tap(btnOverview, warnIfMissed: false);
    await tester.pumpAndSettle();

    // 20. TEST OVERVIEW : les 5 scénarios apparaissent
    expect(find.text('Panne électrique prolongée'), findsOneWidget);
    expect(find.text('Coupure réseau gaz'), findsOneWidget);
    expect(find.text("Coupure d'eau"), findsOneWidget);
    expect(find.text('Panne Internet fixe'), findsOneWidget);
    expect(find.text('Panne réseau mobile'), findsOneWidget);

    // Tap panne_gaz
    final tapGaz = find.text('Coupure réseau gaz');
    await tester.tap(tapGaz, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Vérifier l'affichage du nom de gaz
    expect(find.text('Coupure réseau gaz'), findsWidgets); // Titre principal
    // Et ne contient PAS panne électrique
    final fullTextGaz = tester.allWidgets.whereType<Text>().map((t) => t.data).join(' ');
    expect(fullTextGaz.contains('Vulnérable en cas de panne électrique'), isFalse);
    
    // Revenir à l'Overview
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    // 21. TEST PROGRESSION -> OVERVIEW
    // Scroll back up just in case
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 800));
    await tester.pumpAndSettle();

    // Ouvrir panne_elec
    final tapElec = find.text('Panne électrique prolongée');
    await tester.tap(tapElec, warnIfMissed: false);
    await tester.pumpAndSettle();

    final btnPlan = find.text("Voir mon plan d'action");
    await tester.ensureVisible(btnPlan);
    await tester.tap(btnPlan);
    await tester.pumpAndSettle();

    final btnUpdate = find.text("Mettre à jour ma situation").first;
    await tester.ensureVisible(btnUpdate);
    await tester.tap(btnUpdate);
    await tester.pumpAndSettle();

    final textsActionPlan = tester.allWidgets.whereType<Text>().map((t) => t.data).toList();
    debugPrint('DEBUG ACTION PLAN TEXTS: $textsActionPlan');

    final btnSolution = find.text("J'ai mis cette solution en place");
    await tester.ensureVisible(btnSolution);
    await tester.tap(btnSolution);
    await tester.pumpAndSettle();

    final btnPlanNew = find.text("Voir mon nouveau plan");
    await tester.ensureVisible(btnPlanNew);
    await tester.tap(btnPlanNew);
    await tester.pumpAndSettle();

    // Revenir à Overview via le back de ActionPlanScreen puis ResultsScreen
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();

    // Overview recalculé.
    final prefs = await SharedPreferences.getInstance();
    final newSnapshotStr = prefs.getString('b3_household_snapshot');
    final newSnapshot = HouseholdSnapshot.fromJson(jsonDecode(newSnapshotStr!));
    
    debugPrint('DEBUG OWNED ASSETS: ${newSnapshot.config.ownedAssets}');
    expect(newSnapshot.config.ownedAssets.contains('poele_bois'), isTrue);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
