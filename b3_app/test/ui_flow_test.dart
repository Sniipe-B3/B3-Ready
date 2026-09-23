import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:b3_app/features/results/screens/results_screen.dart';
import 'package:b3_app/features/action_plan/screens/action_plan_screen.dart';
import 'package:b3_app/features/action_plan/screens/guided_action_screen.dart';
import 'package:b3_app/features/progression/models/resilience_session.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/data/app_knowledge_dataset.dart';

void main() {
  group('Navigation Horizon Test', () {
    testWidgets('Session horizon is preserved across navigation', (WidgetTester tester) async {
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
      
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Navigator(
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (context) => ResultsScreen(session: session),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      
      expect(session.horizon, PreparednessHorizon.oneDay);
      
      // Select 72h
      await tester.tap(find.text('72 h'));
      await tester.pumpAndSettle();
      
      expect(session.horizon, PreparednessHorizon.threeDays);
      
      // Go to Action Plan
      await tester.tap(find.text('Voir mon plan d\'action'));
      await tester.pumpAndSettle();
      
      // We are in Action Plan, ensure horizon is still 72h
      expect(session.horizon, PreparednessHorizon.threeDays);
      expect(find.byType(ActionPlanScreen), findsOneWidget);
      
      // Find the Organize action and go to Guided Action
      // Wait, there might be a button "Voir l'action" or we tap the ListTile.
      // ActionPlanItemCard has a button or is clickable.
      await tester.tap(find.text('Augmenter l\'autonomie : Bois de chauffage (bûches)'));
      await tester.pumpAndSettle();
      
      expect(find.byType(GuidedActionScreen), findsOneWidget);
      expect(session.horizon, PreparednessHorizon.threeDays);
      
      // Back
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ActionPlanScreen), findsOneWidget);
      
      // Back
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ResultsScreen), findsOneWidget);
      
      // Horizon still 72h
      expect(session.horizon, PreparednessHorizon.threeDays);
    });

    testWidgets('Responsive 320px for SegmentedButton', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      
      final config = HouseholdConfig(ownedAssets: []);
      final session = ResilienceSession(
        knowledgeJson: appKnowledgeBase,
        scenarioId: 'panne_gaz',
        initialConfig: config
      );
      
      await tester.pumpWidget(MaterialApp(home: ResultsScreen(session: session)));
      await tester.pumpAndSettle();
      
      // Ensure no exceptions
      expect(tester.takeException(), isNull);
      
      // All labels must be visible
      expect(find.text('6 h'), findsOneWidget);
      expect(find.text('24 h'), findsOneWidget);
      expect(find.text('72 h'), findsOneWidget);
      expect(find.text('7 j'), findsOneWidget);
      
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
