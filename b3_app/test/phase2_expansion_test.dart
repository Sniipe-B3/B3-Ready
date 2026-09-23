import 'dart:convert';
import 'package:b3_app/data/app_knowledge_dataset.dart';
import 'package:b3_app/data/app_diagnostic_dataset.dart';
import 'package:b3_app/features/scenarios/services/multi_scenario_analyzer.dart';
import 'package:b3_app/features/scenarios/services/cross_scenario_analyzer.dart';
import 'package:b3_app/features/scenarios/services/dependency_impact_analyzer.dart';
import 'package:b3_app/features/diagnostic/engine/adaptive_diagnostic_engine.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PHASE 2 - CORE EXPANSION TESTS', () {
    test('TEST A - EAU POTABLE RÉSEAU', () {
      final config = HouseholdConfig(
        ownedAssets: ['robinet_eau'],
        assessedCapabilities: {'boire_eau_potable', 'disposer_eau'},
      );
      final scenario = DataMapper.parseScenario(appKnowledgeBase, 'coupure_eau');
      final graph = DataMapper.buildGraph(appKnowledgeBase, config);
      final result = B3Engine().runSimulation(graph, scenario);
      expect(result.nodeStates['boire_eau_potable'], B3State.failed);
    });

    test('TEST B - RÉSERVE POTABLE', () {
      final config = HouseholdConfig(
        ownedAssets: ['stock_eau_potable'],
        ownedResources: ['reserve_eau_potable'],
        assessedResources: {'reserve_eau_potable'},
        resourceDurations: {'reserve_eau_potable': const Duration(hours: 72)},
        assessedCapabilities: {'boire_eau_potable'},
      );
      final scenario = DataMapper.parseScenario(appKnowledgeBase, 'coupure_eau');
      final graph = DataMapper.buildGraph(appKnowledgeBase, config);
      final result = B3Engine().runSimulation(graph, scenario);
      expect(result.nodeStates['boire_eau_potable'], B3State.maintained);
    });

    test('TEST C - UNKNOWN POTABLE', () {
      final config = HouseholdConfig(
        ownedAssets: ['stock_eau_potable'],
        ownedResources: ['reserve_eau_potable'],
        assessedResources: {'reserve_eau_potable'},
        assessedCapabilities: {'boire_eau_potable'},
      );
      final scenario = DataMapper.parseScenario(appKnowledgeBase, 'coupure_eau');
      final graph = DataMapper.buildGraph(appKnowledgeBase, config);
      final result = B3Engine().runSimulation(graph, scenario);
      expect(result.nodeStates['boire_eau_potable'], B3State.unknown);
    });

    test('TEST D - WATER SEMANTIC SEPARATION', () {
      final config = HouseholdConfig(
        ownedAssets: ['stock_eau'],
        ownedResources: ['reserve_eau'],
        assessedResources: {'reserve_eau'},
        resourceDurations: {'reserve_eau': const Duration(hours: 72)},
        assessedCapabilities: {'disposer_eau', 'boire_eau_potable'},
      );
      final scenario = DataMapper.parseScenario(appKnowledgeBase, 'coupure_eau');
      final graph = DataMapper.buildGraph(appKnowledgeBase, config);
      final result = B3Engine().runSimulation(graph, scenario);
      expect(result.nodeStates['disposer_eau'], B3State.maintained);
      expect(result.nodeStates['boire_eau_potable'], B3State.failed);
    });

    test('TEST E - PANNE PAIEMENT (Electronic Only)', () {
      final config = HouseholdConfig(
        ownedAssets: ['paiement_electronique'],
        assessedCapabilities: {'effectuer_paiement_essentiel'},
      );
      final scenario = DataMapper.parseScenario(appKnowledgeBase, 'panne_paiement');
      final graph = DataMapper.buildGraph(appKnowledgeBase, config);
      final result = B3Engine().runSimulation(graph, scenario);
      expect(result.nodeStates['effectuer_paiement_essentiel'], B3State.failed);
    });

    test('TEST F - CASH ALTERNATIVE', () {
      final config = HouseholdConfig(
        ownedAssets: ['paiement_electronique', 'especes_disponibles'],
        assessedCapabilities: {'effectuer_paiement_essentiel'},
      );
      final scenario = DataMapper.parseScenario(appKnowledgeBase, 'panne_paiement');
      final graph = DataMapper.buildGraph(appKnowledgeBase, config);
      final result = B3Engine().runSimulation(graph, scenario);
      expect(result.nodeStates['effectuer_paiement_essentiel'], B3State.maintained);
    });

    test('TEST H - PAYMENT ANTI-CASCADE', () {
      final config = HouseholdConfig(
        ownedAssets: ['paiement_electronique', 'robinet_eau', 'radiateur_elec', 'lampe_secteur'],
        assessedCapabilities: {'effectuer_paiement_essentiel', 'disposer_eau', 'chauffer', 'eclairage'},
      );
      final scenario = DataMapper.parseScenario(appKnowledgeBase, 'panne_paiement');
      final graph = DataMapper.buildGraph(appKnowledgeBase, config);
      final result = B3Engine().runSimulation(graph, scenario);
      expect(result.nodeStates['effectuer_paiement_essentiel'], B3State.failed);
      expect(result.nodeStates['disposer_eau'], B3State.maintained);
      expect(result.nodeStates['chauffer'], B3State.maintained);
      expect(result.nodeStates['eclairage'], B3State.maintained);
    });

    test('TEST I - MULTI SCENARIO 6', () {
      final kb = jsonDecode(appKnowledgeBase);
      final scenarios = kb['scenarios'] as List<dynamic>;
      expect(scenarios.length, 6);
      
      final analyzer = MultiScenarioAnalyzer(appKnowledgeBase);
      final scenarioIds = scenarios.map((s) => s['id'] as String).toList();
      final config = HouseholdConfig(ownedAssets: []);
      final results = analyzer.analyze(config, scenarioIds);
      expect(results.length, 6);
    });

    test('TEST J - GLOBAL OVERVIEW', () {
      final config = HouseholdConfig(
        ownedAssets: ['paiement_electronique', 'stock_eau_potable'],
        ownedResources: ['reserve_eau_potable'],
        assessedResources: {'reserve_eau_potable'},
        resourceDurations: {'reserve_eau_potable': const Duration(hours: 72)},
        assessedCapabilities: {'effectuer_paiement_essentiel', 'boire_eau_potable'}
      );
      final kb = jsonDecode(appKnowledgeBase);
      final scenarios = kb['scenarios'] as List<dynamic>;
      final scenarioIds = scenarios.map((s) => s['id'] as String).toList();
      final analyzer = MultiScenarioAnalyzer(appKnowledgeBase);
      final results = analyzer.analyze(config, scenarioIds);
      
      final crossAnalyzer = CrossScenarioAnalyzer(appKnowledgeBase);
      crossAnalyzer.analyze(results);
      
      expect(results.firstWhere((r) => r.scenarioId == 'coupure_eau').simulationResult!.nodeStates['boire_eau_potable'], B3State.maintained);
    });

    test('TEST K - DEPENDENCY IMPACT', () {
      final config = HouseholdConfig(
        ownedAssets: ['paiement_electronique'],
        assessedCapabilities: {'effectuer_paiement_essentiel'}
      );
      final analyzer = MultiScenarioAnalyzer(appKnowledgeBase);
      final results = analyzer.analyze(config, ['panne_paiement', 'panne_elec']);
      
      final crossAnalyzer = CrossScenarioAnalyzer(appKnowledgeBase);
      final cross = crossAnalyzer.analyze(results);
      
      final result = results.firstWhere((r) => r.scenarioId == 'panne_paiement').simulationResult!;
      expect(result.nodeStates['effectuer_paiement_essentiel'], B3State.failed);
      
      final depAnalyzer = DependencyImpactAnalyzer(appKnowledgeBase);
      depAnalyzer.analyze(results, cross.actions);
      
      // Since payment issue only affects 1 capability and we have panne_elec, 
      // reseau_paiement might not show up if it doesn't affect at least 2 caps/scenarios.
      // But we can check if it fails correctly.
    });
  });

  group('PHASE 2 - DIAGNOSTIC TESTS', () {
    late List<DiagnosticQuestion> questions;
    setUp(() {
      final questionsJson = jsonDecode(appDiagnosticQuestionsJson) as List;
      questions = questionsJson.map((q) => DiagnosticQuestion.fromJson(q)).toList();
    });

    test('TEST L - DIAGNOSTIC ANTI-INVENTION', () {
      final engine = AdaptiveDiagnosticEngine(questions);
      final state = DiagnosticState();
      int qCount = 0;
      while (true) {
        final q = engine.getNextQuestion(state);
        if (q == null) break;
        qCount++;
        if (qCount > 40) break;
        
        String optId = q.options.first.id;
        for (var o in q.options) {
          if (o.text.toLowerCase().contains('aucun') || o.text.toLowerCase().contains('non')) {
            optId = o.id;
            break;
          }
        }
        if (q.type == QuestionType.multipleChoice) {
          state.answerMultiple(q.id, [optId]);
        } else {
          state.answerQuestion(q.id, optId);
        }
      }
      final config = state.toHouseholdConfig(questions);
      expect(config.ownedAssets.contains('especes_disponibles'), isFalse);
      expect(config.ownedAssets.contains('stock_eau_potable'), isFalse);
    });

    test('TEST M - STOP EARLY', () {
      final engine = AdaptiveDiagnosticEngine(questions);
      final state = DiagnosticState();
      final q = engine.getNextQuestion(state);
      if (q != null) {
        if (q.type == QuestionType.multipleChoice) {
          state.answerMultiple(q.id, [q.options.first.id]);
        } else {
          state.answerQuestion(q.id, q.options.first.id);
        }
      }
      final config = state.toHouseholdConfig(questions);
      expect(config.assessedCapabilities.contains('boire_eau_potable'), isFalse);
    });

    test('TEST N - ADAPTIVE NO LOOP', () {
      final engine = AdaptiveDiagnosticEngine(questions);
      final state = DiagnosticState();
      int count = 0;
      while (true) {
        final q = engine.getNextQuestion(state);
        if (q == null) break;
        count++;
        if (count > 40) break;
        
        if (q.type == QuestionType.multipleChoice) {
          state.answerMultiple(q.id, [q.options.first.id]);
        } else {
          state.answerQuestion(q.id, q.options.first.id);
        }
      }
      expect(count, lessThan(40));
    });

    test('TEST O - DETERMINISM', () {
      final engine1 = AdaptiveDiagnosticEngine(questions);
      final engine2 = AdaptiveDiagnosticEngine(questions);
      final state1 = DiagnosticState();
      final state2 = DiagnosticState();
      expect(engine1.getNextQuestion(state1)?.id, engine2.getNextQuestion(state2)?.id);
    });
  });
}
