import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:b3_app/features/action_plan/models/action_plan.dart';
import 'package:b3_app/features/action_plan/models/guided_action_details.dart';
import 'package:b3_app/features/action_plan/screens/guided_action_screen.dart';
import 'package:b3_app/features/progression/models/resilience_session.dart';
import 'package:b3_app/data/app_knowledge_dataset.dart';
import 'package:b3_engine/b3_engine.dart';

void main() {
  testWidgets('UI TEST - GuidedActionScreen', (WidgetTester tester) async {
    final session = ResilienceSession(
      knowledgeJson: appKnowledgeBase,
      scenarioId: 'coupure_eau',
      initialConfig: HouseholdConfig(ownedAssets: []),
    );
    
    final item = ActionPlanItem(
      id: 'test_action',
      title: 'Titre de l\'action',
      description: 'Ce que vous pouvez faire',
      reason: 'Pourquoi cette action',
      type: RecommendationType.verify,
      priority: ActionPriority.essential,
      capabilityIds: {'disposer_eau'},
    );
    
    final details = GuidedActionDetails(
      item: item,
      title: 'Titre de l\'action',
      why: 'Pourquoi cette action est proposée',
      observed: 'Capacité concernée : Eau',
      todo: 'Ce que vous pouvez faire',
      ctaLabel: 'CTA Action',
    );
    
    await tester.pumpWidget(MaterialApp(
      home: GuidedActionScreen(
        details: details,
        session: session,
        onUpdate: () {},
        onUnderstand: () {},
      ),
    ));
    
    expect(find.text('Titre de l\'action'), findsOneWidget);
    expect(find.text('Pourquoi cette action est proposée'), findsNWidgets(2));
    expect(find.text('Capacité concernée : Eau'), findsOneWidget);
    expect(find.text('Ce que vous pouvez faire'), findsNWidgets(2));
    expect(find.text('CTA Action'), findsOneWidget);
    expect(find.text('Comprendre pourquoi (Voir la dépendance)'), findsOneWidget);
  });
}
