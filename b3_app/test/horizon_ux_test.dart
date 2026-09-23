import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:b3_app/features/results/screens/results_screen.dart';
import 'package:b3_app/features/progression/models/resilience_session.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/data/app_knowledge_dataset.dart';

void main() {
  group('Horizon UX Tests', () {
    testWidgets('Horizon selector is visible and defaults to 24h', (WidgetTester tester) async {
      final config = HouseholdConfig(
        ownedAssets: ['radiateur_elec'],
        ownedResources: ['elec'],
        assessedResources: {'elec'}
      );
      
      final session = ResilienceSession(
        knowledgeJson: appKnowledgeBase,
        scenarioId: 'panne_elec',
        initialConfig: config
      );
      
      await tester.pumpWidget(MaterialApp(home: ResultsScreen(session: session)));
      await tester.pumpAndSettle();
      
      expect(find.text('Si la situation durait...'), findsOneWidget);
      expect(find.text('24 h'), findsOneWidget);
      expect(find.text('6 h'), findsOneWidget);
      expect(find.text('72 h'), findsOneWidget);
      expect(find.text('7 j'), findsOneWidget);
      
      expect(session.horizon, PreparednessHorizon.oneDay);
    });

    testWidgets('Changing horizon updates the summary and Action Plan', (WidgetTester tester) async {
      final config = HouseholdConfig(
        ownedAssets: ['poele_bois'],
        ownedResources: ['bois'],
        assessedResources: {'bois'},
        resourceDurations: {'bois': const Duration(hours: 48)}
      );
      
      final session = ResilienceSession(
        knowledgeJson: appKnowledgeBase,
        scenarioId: 'panne_gaz',
        initialConfig: config
      );
      
      await tester.pumpWidget(MaterialApp(home: ResultsScreen(session: session)));
      await tester.pumpAndSettle();
      
      // Default 24h
      expect(session.horizon, PreparednessHorizon.oneDay);
      // It should be sufficient (48h > 24h)
      expect(session.simulationResult!.nodeStates['chauffer'], B3State.maintained);
      
      // Click 72h
      await tester.tap(find.text('72 h'));
      await tester.pumpAndSettle();
      
      // Should now be insufficient
      expect(session.horizon, PreparednessHorizon.threeDays);
      expect(session.simulationResult!.nodeStates['chauffer'], B3State.degraded);
      expect(find.textContaining('capacité(s) insuffisante(s)'), findsWidgets);
      
      // Action plan should reflect the change
      final actionPlan = session.actionPlan!;
      final recommendedActions = actionPlan.items;
      // Because it's degraded due to resourceExhausted, it should recommend to increase resource
      expect(recommendedActions.any((a) => a.description.contains('72h')), isTrue);
    });

    testWidgets('UNKNOWN remains "A verifier" across horizons', (WidgetTester tester) async {
      final config = HouseholdConfig(
        ownedAssets: ['poele_bois'],
        ownedResources: ['bois'],
        assessedResources: {'bois'},
        unknownResources: {'bois'}
      );
      
      final session = ResilienceSession(
        knowledgeJson: appKnowledgeBase,
        scenarioId: 'panne_gaz',
        initialConfig: config
      );
      
      await tester.pumpWidget(MaterialApp(home: ResultsScreen(session: session)));
      await tester.pumpAndSettle();
      
      expect(session.horizon, PreparednessHorizon.oneDay);
      expect(session.simulationResult!.nodeStates['chauffer'], B3State.unknown);
      
      await tester.tap(find.text('7 j'));
      await tester.pumpAndSettle();
      
      expect(session.horizon, PreparednessHorizon.sevenDays);
      expect(session.simulationResult!.nodeStates['chauffer'], B3State.unknown);
      // Make sure the UI still says it's uncertain
      expect(find.text("À vérifier (info manquante)"), findsWidgets);

      await tester.tap(find.text('72 h'));
      await tester.pumpAndSettle();
      expect(session.horizon, PreparednessHorizon.threeDays);
      expect(find.text("À vérifier (info manquante)"), findsWidgets);

      await tester.tap(find.text('6 h'));
      await tester.pumpAndSettle();
      expect(session.horizon, PreparednessHorizon.sixHours);
      expect(find.text("À vérifier (info manquante)"), findsWidgets);
    });
    
    testWidgets('NOT_ASSESSED remains "Non évalué" across horizons', (WidgetTester tester) async {
      final config = HouseholdConfig(
        ownedAssets: ['poele_bois'],
        ownedResources: ['bois'], // implicitly owned but not assessed
        assessedResources: {}
      );
      
      final session = ResilienceSession(
        knowledgeJson: appKnowledgeBase,
        scenarioId: 'panne_gaz',
        initialConfig: config
      );
      
      await tester.pumpWidget(MaterialApp(home: ResultsScreen(session: session)));
      await tester.pumpAndSettle();
      
      expect(session.horizon, PreparednessHorizon.oneDay);
      expect(session.simulationResult!.nodeStates['chauffer'], B3State.notAssessed);
      
      await tester.tap(find.text('6 h'));
      await tester.pumpAndSettle();
      
      expect(session.horizon, PreparednessHorizon.sixHours);
      expect(session.simulationResult!.nodeStates['chauffer'], B3State.notAssessed);
      expect(find.text('Non évalué'), findsWidgets);
    });
    
    testWidgets('FAILED remains "Indisponible" across horizons', (WidgetTester tester) async {
      final config = HouseholdConfig(
        ownedAssets: ['poele_bois'],
        ownedResources: [],
        assessedResources: {'bois'}
      );
      
      final session = ResilienceSession(
        knowledgeJson: appKnowledgeBase,
        scenarioId: 'panne_gaz',
        initialConfig: config
      );
      
      await tester.pumpWidget(MaterialApp(home: ResultsScreen(session: session)));
      await tester.pumpAndSettle();
      
      expect(session.horizon, PreparednessHorizon.oneDay);
      expect(session.simulationResult!.nodeStates['chauffer'], B3State.failed);
      
      await tester.tap(find.text('72 h'));
      await tester.pumpAndSettle();
      
      expect(session.horizon, PreparednessHorizon.threeDays);
      expect(session.simulationResult!.nodeStates['chauffer'], B3State.failed);
      expect(find.text("Indisponible dans ce scénario"), findsWidgets);
    });

  });
}
