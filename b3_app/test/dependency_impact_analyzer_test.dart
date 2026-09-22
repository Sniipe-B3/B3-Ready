import 'package:flutter_test/flutter_test.dart';
import 'package:b3_app/features/scenarios/services/dependency_impact_analyzer.dart';
import 'package:b3_app/features/scenarios/models/scenario_analysis.dart';
import 'package:b3_app/features/scenarios/models/global_household_overview.dart';

import 'package:b3_app/features/action_plan/models/action_plan.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/data/app_knowledge_dataset.dart';

void main() {
  group('DependencyImpactAnalyzer Tests', () {
    late DependencyImpactAnalyzer analyzer;

    setUp(() {
      analyzer = DependencyImpactAnalyzer(appKnowledgeBase);
    });

    ScenarioAnalysis _mockAnalysis({
      required String scenarioId,
      required Map<String, B3State> capStates,
      required Map<String, List<String>> causes,
    }) {
      final nodes = <B3Node>[];
      final states = <String, B3State>{};

      for (var capId in capStates.keys) {
        // Just mock a capability node that is isolated, but its causes will be simulated via traces
        nodes.add(Capability(id: capId, name: capId, rule: EvaluationRule.any));
        states[capId] = capStates[capId]!;
      }
      states['elec'] = B3State.failed; // For protection check logic

      final traces = <String, ReasoningTrace>{};
      for (var entry in causes.entries) {
        final capId = entry.key;
        final deps = entry.value;

        // Add trace for capability pointing to dependencies
        final depMap = <String, B3State>{};
        for (var d in deps) {
          depMap[d] = B3State.failed;
        }
        traces[capId] = ReasoningTrace()..add(TraceStep(
          node: Capability(id: capId, name: capId, rule: EvaluationRule.any),
          state: B3State.failed,
          type: ReasonType.evaluatedChildren,
          description: '',
          dependencyStates: depMap,
        ));

        // Add trace for each dependency to be a root cause
        for (var d in deps) {
          if (!traces.containsKey(d)) {
            traces[d] = ReasoningTrace()..add(TraceStep(
              node: System(id: d, name: d),
              state: B3State.failed,
              type: ReasonType.initialOverride,
              description: '',
            ));
          }
        }
      }

      final result = SimulationResult(states, traces, [], []);
      return ScenarioAnalysis(
        scenarioId: scenarioId,
        scenarioName: scenarioId,
        simulationResult: result,
        actionPlan: ActionPlan([]),
        graph: nodes,
      );
    }

    CrossScenarioAction _mockAction(String id, List<String> capIds, List<String> causeIds) {
      return CrossScenarioAction(
        id: id,
        title: id,
        type: RecommendationType.useExisting,
        scenarioIds: {'s1'},
        capabilityIds: capIds.toSet(),
        prioritiesByScenario: {},
        reasonsByScenario: {},
        causeNodeIds: causeIds.toSet(),
      );
    }

    test('TEST A - DEPENDENCY IMPACT BASIC', () {
      final a1 = _mockAnalysis(
        scenarioId: 's1',
        capStates: {'chauffer': B3State.failed, 'acceder_internet': B3State.failed},
        causes: {'chauffer': ['elec'], 'acceder_internet': ['elec']},
      );
      final impacts = analyzer.analyze([a1], []);
      
      expect(impacts.length, 1);
      expect(impacts.first.causeNodeId, 'elec');
      expect(impacts.first.affectedCapabilityIds, containsAll(['chauffer', 'acceder_internet']));
      expect(impacts.first.vulnerableCapabilityIds, containsAll(['chauffer', 'acceder_internet']));
    });

    test('TEST B - MAINTAINED NON VULNERABLE', () {
      final a1 = _mockAnalysis(
        scenarioId: 's1',
        capStates: {'chauffer': B3State.maintained, 'acceder_internet': B3State.failed},
        causes: {'chauffer': ['elec'], 'acceder_internet': ['elec']},
      );
      final impacts = analyzer.analyze([a1], []);
      
      expect(impacts.length, 1);
      expect(impacts.first.vulnerableCapabilityIds, contains('acceder_internet'));
      expect(impacts.first.vulnerableCapabilityIds.contains('chauffer'), isFalse);
      expect(impacts.first.maintainedCapabilityIds, contains('chauffer'));
    });

    test('TEST C - UNKNOWN', () {
      final a1 = _mockAnalysis(
        scenarioId: 's1',
        capStates: {'chauffer': B3State.unknown},
        causes: {'chauffer': ['elec']},
      );
      // Since it's only 1 capability in 1 scenario, it might be filtered out if it doesn't meet the >=2 threshold.
      // Let's add a second one.
      final a2 = _mockAnalysis(
        scenarioId: 's2',
        capStates: {'chauffer': B3State.unknown},
        causes: {'chauffer': ['elec']},
      );
      
      final impacts = analyzer.analyze([a1, a2], []);
      expect(impacts.length, 1);
      expect(impacts.first.uncertainCapabilityIds, contains('chauffer'));
      expect(impacts.first.vulnerableCapabilityIds.isEmpty, isTrue);
    });

    test('TEST D - ACTION RELATION', () {
      final a1 = _mockAnalysis(
        scenarioId: 's1',
        capStates: {'chauffer': B3State.failed, 'acceder_internet': B3State.failed},
        causes: {'chauffer': ['elec'], 'acceder_internet': ['elec']},
      );
      final action = _mockAction('poele_bois', ['chauffer'], ['elec']);
      
      final impacts = analyzer.analyze([a1], [action]);
      expect(impacts.first.relatedActions.length, 1);
      expect(impacts.first.relatedActions.first.affectedCapabilityIds, contains('chauffer'));
      expect(impacts.first.relatedActions.first.affectedCapabilityIds.contains('acceder_internet'), isFalse);
    });

    test('TEST E - PAS DE FAUX LIEN', () {
      final a1 = _mockAnalysis(
        scenarioId: 's1',
        capStates: {'cuisiner': B3State.failed, 'acceder_internet': B3State.failed},
        causes: {'cuisiner': ['elec'], 'acceder_internet': ['elec']},
      );
      final action = _mockAction('rechaud_gaz', ['cuisiner'], ['elec']);
      
      final impacts = analyzer.analyze([a1], [action]);
      expect(impacts.first.relatedActions.length, 1);
      expect(impacts.first.relatedActions.first.affectedCapabilityIds, contains('cuisiner'));
      expect(impacts.first.relatedActions.first.affectedCapabilityIds.contains('acceder_internet'), isFalse);
    });

    test('TEST F - ACTION SANS CAUSE', () {
      final a1 = _mockAnalysis(
        scenarioId: 's1',
        capStates: {'chauffer': B3State.failed, 'acceder_internet': B3State.failed},
        causes: {'chauffer': ['elec'], 'acceder_internet': ['elec']},
      );
      final action = _mockAction('random_action', ['chauffer'], []);
      
      final impacts = analyzer.analyze([a1], [action]);
      expect(impacts.first.relatedActions.isEmpty, isTrue);
    });

    test('TEST G - PLUSIEURS SCÉNARIOS', () {
      final a1 = _mockAnalysis(
        scenarioId: 's1',
        capStates: {'chauffer': B3State.failed},
        causes: {'chauffer': ['elec']},
      );
      final a2 = _mockAnalysis(
        scenarioId: 's2',
        capStates: {'chauffer': B3State.failed},
        causes: {'chauffer': ['elec']},
      );
      final impacts = analyzer.analyze([a1, a2], []);
      expect(impacts.first.affectedScenarioIds.length, 2);
    });

    test('TEST H - PLUSIEURS ACTIONS', () {
      final a1 = _mockAnalysis(
        scenarioId: 's1',
        capStates: {'chauffer': B3State.failed, 'cuisiner': B3State.failed},
        causes: {'chauffer': ['elec'], 'cuisiner': ['elec']},
      );
      final action1 = _mockAction('poele_bois', ['chauffer'], ['elec']);
      final action2 = _mockAction('rechaud_gaz', ['cuisiner'], ['elec']);
      
      final impacts = analyzer.analyze([a1], [action1, action2]);
      expect(impacts.first.relatedActions.length, 2);
    });

    test('TEST I - DÉTERMINISME', () {
      final a1 = _mockAnalysis(
        scenarioId: 's1',
        capStates: {'chauffer': B3State.failed, 'cuisiner': B3State.failed},
        causes: {'chauffer': ['elec'], 'cuisiner': ['elec']},
      );
      final action1 = _mockAction('poele_bois', ['chauffer'], ['elec']);
      final action2 = _mockAction('rechaud_gaz', ['cuisiner'], ['elec']);
      
      final impacts1 = analyzer.analyze([a1], [action1, action2]);
      final impacts2 = analyzer.analyze([a1], [action1, action2]);
      
      expect(impacts1.length, impacts2.length);
      expect(impacts1.first.causeNodeId, impacts2.first.causeNodeId);
      expect(impacts1.first.relatedActions.length, impacts2.first.relatedActions.length);
      expect(impacts1.first.affectedCapabilityIds, impacts2.first.affectedCapabilityIds);
      expect(impacts1.first.vulnerableCapabilityIds, impacts2.first.vulnerableCapabilityIds);
      expect(impacts1.first.maintainedCapabilityIds, impacts2.first.maintainedCapabilityIds);
      expect(impacts1.first.uncertainCapabilityIds, impacts2.first.uncertainCapabilityIds);
    });

    test('TEST J - IMMUTABILITÉ', () {
      final a1 = _mockAnalysis(
        scenarioId: 's1',
        capStates: {'chauffer': B3State.failed, 'cuisiner': B3State.failed},
        causes: {'chauffer': ['elec'], 'cuisiner': ['elec']},
      );
      
      final initialCaps = Map.of(a1.simulationResult!.nodeStates);
      analyzer.analyze([a1], []);
      
      expect(a1.simulationResult!.nodeStates, initialCaps);
    });

    test('TEST K - INVALID ANALYSIS', () {
      final a1 = _mockAnalysis(
        scenarioId: 's1',
        capStates: {'chauffer': B3State.failed, 'cuisiner': B3State.failed},
        causes: {'chauffer': ['elec'], 'cuisiner': ['elec']},
      );
      final errorAnalysis = ScenarioAnalysis.error(scenarioId: 's2', scenarioName: 's2', error: 'failed');
      
      final impacts = analyzer.analyze([a1, errorAnalysis], []);
      expect(impacts.length, 1);
      expect(impacts.first.causeNodeId, 'elec');
    });

    test('TEST L - ANTI-INVENTION', () {
      final impacts = analyzer.analyze([], []);
      expect(impacts.isEmpty, isTrue);
    });
  });
}
