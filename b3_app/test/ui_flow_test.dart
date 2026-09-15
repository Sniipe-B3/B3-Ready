import 'package:flutter_test/flutter_test.dart';
import 'package:b3_app/app/app.dart';
import 'package:b3_app/features/diagnostic/screens/diagnostic_screen.dart';
import 'package:b3_app/features/results/screens/results_screen.dart';
import 'package:b3_engine/b3_engine.dart';
import 'dart:convert';

void main() {
  testWidgets('Parcours complet: Home -> Diagnostic -> Results',
      (WidgetTester tester) async {
    await tester.pumpWidget(const B3App());
    expect(find.text('B3 Ready'), findsWidgets);
    expect(find.text('Commencer mon diagnostic'), findsOneWidget);

    await tester.tap(find.text('Commencer mon diagnostic'));
    await tester.pumpAndSettle();

    expect(find.byType(DiagnosticScreen), findsOneWidget);
    expect(find.text('Comment cuisinez-vous principalement ?'), findsOneWidget);
    expect(find.text('Plaque électrique'), findsOneWidget);
    expect(find.text('Gazinière'), findsOneWidget);

    await tester.tap(find.text('Plaque électrique'));
    await tester.pumpAndSettle();

    expect(find.textContaining('En plus de votre plaque électrique'),
        findsOneWidget);
    await tester.tap(find.text('Non'));
    await tester.pumpAndSettle();

    expect(find.textContaining('solution de secours totalement indépendante'),
        findsOneWidget);
    await tester.tap(find.text('Non'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Comment chauffez-vous'), findsOneWidget);
    await tester.tap(find.text('Radiateurs électriques'));
    await tester.pumpAndSettle();

    expect(find.textContaining('éclairage de secours'), findsOneWidget);
    await tester.tap(find.text('Non (secteur uniquement)'));
    await tester.pumpAndSettle();

    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(find.text('Votre première analyse'), findsOneWidget);
    expect(find.textContaining('à améliorer en cas de panne électrique'),
        findsOneWidget);
    expect(find.text('CUISINER'), findsOneWidget);
    expect(find.text('Action proposée'), findsWidgets);
  });

  test(
      'La fin du diagnostic produit réellement un HouseholdConfig et SimulationResult',
      () {
    final state = DiagnosticState();
    final questionsJson = jsonDecode(b3DiagnosticQuestionsJson) as List;
    final questions =
        questionsJson.map((q) => DiagnosticQuestion.fromJson(q)).toList();

    state.answerQuestion('q_cook_main', 'opt_plaque');
    state.answerQuestion('q_cook_alt_elec', 'opt_no_four');

    final householdConfig = state.toHouseholdConfig(questions);

    expect(householdConfig.ownedAssets.contains('plaque_elec'), true);
    expect(householdConfig.assessedCapabilities.contains('cuisiner'), true);

    final graph = DataMapper.buildGraph(b3KnowledgeBase, householdConfig);
    final scenario = DataMapper.parseScenario(b3KnowledgeBase, 'panne_elec');

    final result = B3Engine().runSimulation(graph, scenario);
    expect(result.vulnerabilities.isNotEmpty, true);

    final recommendations = RecommendationEngine(b3KnowledgeBase)
        .generate(result, householdConfig, scenario);
    expect(recommendations.isNotEmpty, true);
  });
}
