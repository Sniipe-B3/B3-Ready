import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:b3_app/features/progression/models/resilience_session.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/features/action_plan/screens/action_plan_screen.dart';

void main() {
  const integrationDataset = '''
  {
    "systems": [
      {"id": "chauffage", "name": "Chauffage"}
    ],
    "capabilities": [
      {"id": "chauffer", "name": "Se chauffer", "assets": ["poele_bois"]}
    ],
    "assets": [
      {"id": "poele_bois", "name": "Poêle à bois", "requires": ["bois"]}
    ],
    "resources": [
      {"id": "bois", "name": "Bois"}
    ],
    "scenarios": [
      {
        "id": "panne_elec",
        "name": "Panne électrique",
        "duration": 48,
        "overrides": {}
      }
    ]
  }
  ''';

  testWidgets('FLOW 1 — VERIFY (Observation) -> Confirmation, pas amelioration', (WidgetTester tester) async {
    final config = HouseholdConfig(
      ownedAssets: ['poele_bois'],
      ownedResources: ['bois'],
      unknownResources: {'bois'},
      assessedCapabilities: {'chauffer'},
    );
    final session = ResilienceSession(
      knowledgeJson: integrationDataset,
      scenarioId: 'panne_elec',
      initialConfig: config,
    );

    await tester.pumpWidget(MaterialApp(
      home: ActionPlanScreen(session: session),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Mettre à jour ma situation").first);
    await tester.pumpAndSettle();

    expect(find.text("Qu'avez-vous constaté ou réalisé ?"), findsOneWidget);
    
    // VERIFY -> "Plusieurs jours"
    await tester.tap(find.text("Plusieurs jours (> 72h)"));
    await tester.pumpAndSettle();

    expect(find.text("Situation mieux connue"), findsOneWidget);
    expect(find.text("Cette capacité est maintenant confirmée disponible."), findsOneWidget);
    expect(find.text("Votre résilience s'est améliorée !"), findsNothing);
  });

  testWidgets('FLOW 2 — Intervention -> Amelioration', (WidgetTester tester) async {
    final config = HouseholdConfig(
      ownedAssets: ['poele_bois'],
      ownedResources: ['bois'],
      assessedResources: {'bois'},
      resourceDurations: {'bois': const Duration(hours: 12)},
      assessedCapabilities: {'chauffer'},
    );
    final session = ResilienceSession(
      knowledgeJson: integrationDataset,
      scenarioId: 'panne_elec',
      initialConfig: config,
    );

    await tester.pumpWidget(MaterialApp(
      home: ActionPlanScreen(session: session),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Mettre à jour ma situation").first);
    await tester.pumpAndSettle();

    // Augmente l'autonomie à >72h
    await tester.tap(find.text("Plusieurs jours (> 72h)"));
    await tester.pumpAndSettle();

    expect(find.text("Amélioration enregistrée"), findsOneWidget);
    expect(find.text("Votre résilience s'est améliorée !"), findsOneWidget);
  });
}
