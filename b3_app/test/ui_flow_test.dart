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
      tester.view.physicalSize = const Size(1080, 2400); 
      tester.view.devicePixelRatio = 1.0; 
      addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });

      final config = HouseholdConfig(
        ownedAssets: ['poele_bois'],
        ownedResources: ['bois'],
        assessedResources: {'bois'},
        resourceDurations: {'bois': const Duration(hours: 12)}
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
      
      // Scroll down to the Action Plan button
      final actionPlanButton = find.text("Voir mon plan d'action");
      await tester.scrollUntilVisible(actionPlanButton, 500.0, scrollable: find.byType(Scrollable).first);
      await tester.tap(actionPlanButton);
      await tester.pumpAndSettle();
      
      expect(session.horizon, PreparednessHorizon.threeDays);
      expect(find.byType(ActionPlanScreen), findsOneWidget);
      
      // Scroll to the first action button
      // We look for a FilledButton that isn't the back button (if back button exists).
      // Actually we can look for "Voir comment faire". Wait, does it say that?
      // In ActionPlanItemCard the button text is "Voir comment faire". Let's check ActionPlanScreen!
      // In ActionPlanScreen we just found FilledButton. Let's find by text.
      // Wait, is it "Voir comment faire" ? Let's use a Finder by Type FilledButton inside a Card.
      final actionButton = find.descendant(of: find.byType(Card), matching: find.byType(FilledButton)).first;
      await tester.scrollUntilVisible(actionButton, 500.0, scrollable: find.byType(Scrollable).first);
      await tester.tap(actionButton);
      await tester.pumpAndSettle();
      
      expect(find.byType(GuidedActionScreen), findsOneWidget);
      expect(session.horizon, PreparednessHorizon.threeDays);
      
      // Back from GuidedActionScreen
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ActionPlanScreen), findsOneWidget);
      
      // Back from ActionPlanScreen
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ResultsScreen), findsOneWidget);
      
      expect(session.horizon, PreparednessHorizon.threeDays);
    });

    testWidgets('Responsive 320px for SegmentedButton', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
      
      final config = HouseholdConfig(ownedAssets: []);
      final session = ResilienceSession(
        knowledgeJson: appKnowledgeBase,
        scenarioId: 'panne_gaz',
        initialConfig: config
      );
      
      await tester.pumpWidget(MaterialApp(home: ResultsScreen(session: session)));
      await tester.pumpAndSettle();
      
      expect(tester.takeException(), isNull);
      
      expect(find.text('6 h'), findsOneWidget);
      expect(find.text('24 h'), findsOneWidget);
      expect(find.text('72 h'), findsOneWidget);
      expect(find.text('7 j'), findsOneWidget);
    });
  });
}
