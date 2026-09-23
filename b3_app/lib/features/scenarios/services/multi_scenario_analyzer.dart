import 'dart:convert';
import 'package:b3_engine/b3_engine.dart';
import '../../action_plan/action_plan_builder.dart';
import '../models/scenario_analysis.dart';

class MultiScenarioAnalyzer {
  final String knowledgeJson;

  MultiScenarioAnalyzer(this.knowledgeJson);

  List<ScenarioAnalysis> analyze(HouseholdConfig config, List<String> scenarioIds, {Duration? horizonDuration}) {
    final results = <ScenarioAnalysis>[];
    
    // Parse knowledge base to get scenario names just in case some fail to parse
    final kb = jsonDecode(knowledgeJson);
    final scenariosData = kb['scenarios'] as List<dynamic>? ?? [];
    
    for (final id in scenarioIds) {
      final scenarioData = scenariosData.firstWhere((s) => s['id'] == id, orElse: () => null);
      final name = scenarioData != null ? scenarioData['name'] as String : id;

      try {
        final scenario = DataMapper.parseScenario(knowledgeJson, id, horizonDuration);
        final graph = DataMapper.buildGraph(knowledgeJson, config.clone());
        
        final simulationResult = B3Engine().runSimulation(graph, scenario);
        final recommendations = RecommendationEngine(knowledgeJson).generate(simulationResult, config, scenario);
        final actionPlan = ActionPlanBuilder(knowledgeJson).build(recommendations, simulationResult);

        results.add(ScenarioAnalysis(
          scenarioId: id,
          scenarioName: scenario.name,
          scenario: scenario,
          simulationResult: simulationResult,
          recommendations: recommendations,
          actionPlan: actionPlan,
          graph: graph,
        ));
      } catch (e) {
        results.add(ScenarioAnalysis.error(
          scenarioId: id,
          scenarioName: name,
          error: e.toString(),
        ));
      }
    }

    return results;
  }
}
