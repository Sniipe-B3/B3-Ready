import 'package:flutter_test/flutter_test.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/features/scenarios/services/cross_scenario_analyzer.dart';
import 'package:b3_app/features/scenarios/models/scenario_analysis.dart';
import 'package:b3_app/features/action_plan/models/action_plan.dart';
import 'package:b3_app/data/app_knowledge_dataset.dart';

void main() {
  late CrossScenarioAnalyzer analyzer;

  setUp(() {
    analyzer = CrossScenarioAnalyzer(appKnowledgeBase);
  });

  ScenarioAnalysis _mockAnalysis({
    required String scenarioId,
    required Map<String, B3State> capStates,
    required Map<String, List<String>> causes,
    required List<ActionPlanItem> items,
    required Map<String, B3State> otherStates,
  }) {
    final nodes = <B3Node>[];
    final states = <String, B3State>{};

    for (var capId in capStates.keys) {
      nodes.add(Capability(id: capId, name: capId, rule: EvaluationRule.any));
      states[capId] = capStates[capId]!;
    }
    for (var otherId in otherStates.keys) {
      states[otherId] = otherStates[otherId]!;
    }

    final traces = <String, ReasoningTrace>{};
    for (var entry in causes.entries) {
       // entry.key is capability
       final capTrace = ReasoningTrace();
       final depStates = <String, B3State>{};
       
       for (var c in entry.value) {
         depStates[c] = B3State.failed;
         final causeTrace = ReasoningTrace();
         causeTrace.add(TraceStep(
           node: Capability(id: c, name: c),
           state: B3State.failed,
           type: ReasonType.initialOverride,
           description: c,
         ));
         traces[c] = causeTrace;
       }
       
       capTrace.add(TraceStep(
           node: Capability(id: entry.key, name: entry.key),
           state: B3State.failed,
           type: ReasonType.evaluatedChildren,
           description: 'deps failed',
           dependencyStates: depStates,
       ));
       traces[entry.key] = capTrace;
    }

    final result = SimulationResult(states, traces, [], []);
    final plan = ActionPlan(items);
    return ScenarioAnalysis(
      scenarioId: scenarioId,
      scenarioName: scenarioId,
      scenario: Scenario(name: scenarioId, duration: const Duration(hours: 1), systemOverrides: {}),
      simulationResult: result,
      actionPlan: plan,
      graph: nodes,
    );
  }

  group('CrossScenarioAnalyzer Tests', () {
    test('TEST A - RECURRING CAPABILITY', () {
      final a1 = _mockAnalysis(
        scenarioId: 'panne_elec',
        capStates: {'cuisiner': B3State.failed},
        causes: {},
        items: [],
        otherStates: {},
      );
      final a2 = _mockAnalysis(
        scenarioId: 'panne_gaz',
        capStates: {'cuisiner': B3State.failed},
        causes: {},
        items: [],
        otherStates: {},
      );
      
      final overview = analyzer.analyze([a1, a2]);
      expect(overview.recurringIssues.length, 1);
      expect(overview.recurringIssues.first.capabilityId, 'cuisiner');
      expect(overview.recurringIssues.first.scenarioIds.length, 2);
    });

    test('TEST B - PAS DE FAUX RECURRING', () {
      final a1 = _mockAnalysis(
        scenarioId: 'panne_elec',
        capStates: {'cuisiner': B3State.failed},
        causes: {},
        items: [],
        otherStates: {},
      );
      final a2 = _mockAnalysis(
        scenarioId: 'panne_gaz',
        capStates: {'cuisiner': B3State.maintained}, // maintained is ignored in RecurringCapabilityIssue
        causes: {},
        items: [],
        otherStates: {},
      );
      
      final overview = analyzer.analyze([a1, a2]);
      expect(overview.recurringIssues.isEmpty, isTrue); // FAILED in 1, MAINTAINED in 1 => NOT recurring
    });

    test('TEST C - UNKNOWN SÉPARÉ', () {
      final a1 = _mockAnalysis(
        scenarioId: 'panne_elec',
        capStates: {'cuisiner': B3State.failed},
        causes: {},
        items: [],
        otherStates: {},
      );
      final a2 = _mockAnalysis(
        scenarioId: 'panne_gaz',
        capStates: {'cuisiner': B3State.unknown},
        causes: {},
        items: [],
        otherStates: {},
      );
      
      final overview = analyzer.analyze([a1, a2]);
      expect(overview.recurringIssues.isEmpty, isTrue); // FAILED in 1, UNKNOWN in 1 => NOT recurring
      
      expect(overview.uncertainties.length, 1);
      expect(overview.uncertainties.first.nodeId, 'cuisiner');
      expect(overview.uncertainties.first.unknownScenarioIds.length, 1); // The UNKNOWN one
      expect(overview.uncertainties.first.unknownScenarioIds.first, 'panne_gaz');
    });

    test('TEST D - COMMON DEPENDENCY (Multiple Caps)', () {
      final a1 = _mockAnalysis(
        scenarioId: 'panne_elec',
        capStates: {'chauffer': B3State.failed, 'acceder_internet': B3State.failed},
        causes: {
          'chauffer': ['elec'],
          'acceder_internet': ['elec'],
        },
        items: [],
        otherStates: {},
      );
      
      final overview = analyzer.analyze([a1]);
      expect(overview.commonDependencies.length, 1);
      expect(overview.commonDependencies.first.causeNodeId, 'elec');
      expect(overview.commonDependencies.first.capabilityIds.contains('chauffer'), isTrue);
      expect(overview.commonDependencies.first.capabilityIds.contains('acceder_internet'), isTrue);
    });

    test('TEST D2 - COMMON DEPENDENCY (Multiple Scenarios)', () {
      final a1 = _mockAnalysis(scenarioId: 's1', capStates: {'chauffer': B3State.failed}, causes: {'chauffer': ['elec']}, items: [], otherStates: {});
      final a2 = _mockAnalysis(scenarioId: 's2', capStates: {'chauffer': B3State.failed}, causes: {'chauffer': ['elec']}, items: [], otherStates: {});
      
      final overview = analyzer.analyze([a1, a2]);
      expect(overview.commonDependencies.length, 1);
      expect(overview.commonDependencies.first.causeNodeId, 'elec');
      expect(overview.commonDependencies.first.scenarioIds.length, 2);
    });

    test('TEST D3 - NOT COMMON DEPENDENCY', () {
      final a1 = _mockAnalysis(scenarioId: 's1', capStates: {'chauffer': B3State.failed}, causes: {'chauffer': ['elec']}, items: [], otherStates: {});
      
      final overview = analyzer.analyze([a1]);
      expect(overview.commonDependencies.isEmpty, isTrue); // Only 1 capability in 1 scenario
    });

    test('TEST E - CAUSE COMMUNE != ACTION COMMUNE', () {
      final items = [
        ActionPlanItem(id: 'a1', title: '', description: '', reason: '', type: RecommendationType.createAlternative, priority: ActionPriority.essential, capabilityIds: {'chauffer'}, causeNodeIds: {'elec'}, targetAssetId: 'poele_bois'),
        ActionPlanItem(id: 'a2', title: '', description: '', reason: '', type: RecommendationType.createAlternative, priority: ActionPriority.essential, capabilityIds: {'acceder_internet'}, causeNodeIds: {'elec'}, targetAssetId: 'radio'),
      ];
      final a1 = _mockAnalysis(
        scenarioId: 'panne_elec',
        capStates: {'chauffer': B3State.failed, 'acceder_internet': B3State.failed},
        causes: {'chauffer': ['elec'], 'acceder_internet': ['elec']},
        items: items,
        otherStates: {},
      );
      final overview = analyzer.analyze([a1]);
      expect(overview.commonDependencies.length, 1);
      expect(overview.actions.length, 2); // 2 distinct actions despite common cause
    });

    test('TEST F - ACTION COMMUNE', () {
      final i1 = ActionPlanItem(id: 'x1', title: '', description: '', reason: '', type: RecommendationType.createAlternative, priority: ActionPriority.essential, capabilityIds: {'chauffer'}, causeNodeIds: {'elec'}, targetAssetId: 'poele_bois');
      final i2 = ActionPlanItem(id: 'x2', title: '', description: '', reason: '', type: RecommendationType.createAlternative, priority: ActionPriority.essential, capabilityIds: {'chauffer'}, causeNodeIds: {'gaz'}, targetAssetId: 'poele_bois');
      
      final a1 = _mockAnalysis(scenarioId: 's1', capStates: {}, causes: {}, items: [i1], otherStates: {});
      final a2 = _mockAnalysis(scenarioId: 's2', capStates: {}, causes: {}, items: [i2], otherStates: {});
      
      final overview = analyzer.analyze([a1, a2]);
      expect(overview.actions.length, 1);
      expect(overview.actions.first.scenarioIds.length, 2);
    });

    test('TEST G - ACTIONS DIFFÉRENTES', () {
      final i1 = ActionPlanItem(id: 'x1', title: '', description: '', reason: '', type: RecommendationType.verify, priority: ActionPriority.toVerify, capabilityIds: {'chauffer'}, causeNodeIds: {}, targetResourceId: 'bois');
      final i2 = ActionPlanItem(id: 'x2', title: '', description: '', reason: '', type: RecommendationType.acquire, priority: ActionPriority.improvement, capabilityIds: {'chauffer'}, causeNodeIds: {}, targetResourceId: 'bois');
      
      final a1 = _mockAnalysis(scenarioId: 's1', capStates: {}, causes: {}, items: [i1], otherStates: {});
      final a2 = _mockAnalysis(scenarioId: 's2', capStates: {}, causes: {}, items: [i2], otherStates: {});
      
      final overview = analyzer.analyze([a1, a2]);
      expect(overview.actions.length, 2); // Different types
    });

    test('TEST H - TARGET ASSET DIFFÉRENT', () {
      final i1 = ActionPlanItem(id: 'x1', title: '', description: '', reason: '', type: RecommendationType.createAlternative, priority: ActionPriority.essential, capabilityIds: {'cuisiner'}, causeNodeIds: {}, targetAssetId: 'poele_bois');
      final i2 = ActionPlanItem(id: 'x2', title: '', description: '', reason: '', type: RecommendationType.createAlternative, priority: ActionPriority.essential, capabilityIds: {'cuisiner'}, causeNodeIds: {}, targetAssetId: 'rechaud_gaz');
      
      final a1 = _mockAnalysis(scenarioId: 's1', capStates: {}, causes: {}, items: [i1], otherStates: {});
      final a2 = _mockAnalysis(scenarioId: 's2', capStates: {}, causes: {}, items: [i2], otherStates: {});
      
      final overview = analyzer.analyze([a1, a2]);
      expect(overview.actions.length, 2); // Different targetAssetId
    });

    test('TEST 1 - PRIORISATION — NE PAS TRIER D\'ABORD PAR FRÉQUENCE', () {
      final i1 = ActionPlanItem(id: 'x1', title: '', description: '', reason: '', type: RecommendationType.createAlternative, priority: ActionPriority.essential, capabilityIds: {'chauffer'}, causeNodeIds: {}, targetAssetId: 'a1');
      final i2 = ActionPlanItem(id: 'x2', title: '', description: '', reason: '', type: RecommendationType.verify, priority: ActionPriority.toVerify, capabilityIds: {'cuisiner'}, causeNodeIds: {}, targetAssetId: 'a2');
      
      // a1 in 1 scenario
      final a1 = _mockAnalysis(scenarioId: 's1', capStates: {}, causes: {}, items: [i1, i2], otherStates: {});
      // a2 in 3 more scenarios
      final a2 = _mockAnalysis(scenarioId: 's2', capStates: {}, causes: {}, items: [i2], otherStates: {});
      final a3 = _mockAnalysis(scenarioId: 's3', capStates: {}, causes: {}, items: [i2], otherStates: {});
      final a4 = _mockAnalysis(scenarioId: 's4', capStates: {}, causes: {}, items: [i2], otherStates: {});
      
      final overview = analyzer.analyze([a1, a2, a3, a4]);
      expect(overview.actions.length, 2);
      
      // action 1: a1 (essential, 1 scenario)
      // action 2: a2 (toVerify, 4 scenarios)
      // essential MUST be sorted first
      expect(overview.actions[0].targetAssetId, 'a1');
      expect(overview.actions[1].targetAssetId, 'a2');
    });

    test('TEST 2 - UNKNOWN ET NOT_ASSESSED SÉPARÉS', () {
      final a1 = _mockAnalysis(scenarioId: 's1', capStates: {}, causes: {}, items: [], otherStates: {'bois': B3State.unknown});
      final a2 = _mockAnalysis(scenarioId: 's2', capStates: {}, causes: {}, items: [], otherStates: {'bois': B3State.notAssessed});
      
      final overview = analyzer.analyze([a1, a2]);
      expect(overview.uncertainties.length, 1);
      final unc = overview.uncertainties.first;
      expect(unc.unknownScenarioIds, ['s1']);
      expect(unc.notAssessedScenarioIds, ['s2']);
    });

    test('TEST 3 - ACTIONIDENTITY TARGETS NULL (Même type, même target, causes diff = MÊME ACTION)', () {
      // Si deux recommandations ont même type, même capabilityId mais causes différentes, 
      // elles génèrent la même action dans ActionPlanBuilder (c.f. audit).
      // CrossScenarioAnalyzer doit donc les fusionner !
      final i1 = ActionPlanItem(id: 'x1', title: 'Learn 1', description: '', reason: '', type: RecommendationType.learn, priority: ActionPriority.important, capabilityIds: {'cap1'}, causeNodeIds: {'cause1'});
      final i2 = ActionPlanItem(id: 'x2', title: 'Learn 2', description: '', reason: '', type: RecommendationType.learn, priority: ActionPriority.important, capabilityIds: {'cap1'}, causeNodeIds: {'cause2'});
      
      final a1 = _mockAnalysis(scenarioId: 's1', capStates: {}, causes: {}, items: [i1], otherStates: {});
      final a2 = _mockAnalysis(scenarioId: 's2', capStates: {}, causes: {}, items: [i2], otherStates: {});
      
      final overview = analyzer.analyze([a1, a2]);
      expect(overview.actions.length, 1); // Fusionnées car même type et même fallbackTarget (cap1)
      expect(overview.actions.first.causeNodeIds, {'cause1', 'cause2'}); // Les causes sont agrégées
    });

    test('TEST K - INVALID ANALYSIS', () {
      final a1 = _mockAnalysis(scenarioId: 's1', capStates: {'cuisiner': B3State.failed}, causes: {}, items: [], otherStates: {});
      final a2 = ScenarioAnalysis.error(scenarioId: 's2', scenarioName: 's2', error: 'boom');
      final a3 = _mockAnalysis(scenarioId: 's3', capStates: {'cuisiner': B3State.failed}, causes: {}, items: [], otherStates: {});
      
      final overview = analyzer.analyze([a1, a2, a3]);
      expect(overview.recurringIssues.length, 1); // S1 and S3
      expect(overview.recurringIssues.first.scenarioIds.length, 2);
    });

    test('TEST L - ANTI-INVENTION', () {
      // Only one action targetAssetId="radio"
      final i1 = ActionPlanItem(id: 'x1', title: '', description: '', reason: '', type: RecommendationType.createAlternative, priority: ActionPriority.essential, capabilityIds: {'acceder_internet'}, causeNodeIds: {}, targetAssetId: 'radio');
      final a1 = _mockAnalysis(scenarioId: 's1', capStates: {}, causes: {}, items: [i1], otherStates: {});
      
      final overview = analyzer.analyze([a1]);
      expect(overview.actions.length, 1);
      expect(overview.actions.first.targetAssetId, 'radio');
      // No poele_bois should exist
      expect(overview.actions.any((a) => a.targetAssetId == 'poele_bois'), isFalse);
    });

    test('TEST I - DETERMINISME', () {
      final i1 = ActionPlanItem(id: 'x1', title: '', description: '', reason: '', type: RecommendationType.createAlternative, priority: ActionPriority.essential, capabilityIds: {'acceder_internet'}, causeNodeIds: {}, targetAssetId: 'radio');
      final a1 = _mockAnalysis(scenarioId: 's1', capStates: {'cap1': B3State.failed}, causes: {'cap1': ['elec']}, items: [i1], otherStates: {});
      final a2 = _mockAnalysis(scenarioId: 's2', capStates: {'cap1': B3State.failed}, causes: {'cap1': ['elec']}, items: [i1], otherStates: {});
      
      final overview1 = analyzer.analyze([a1, a2]);
      final overview2 = analyzer.analyze([a1, a2]);
      
      expect(overview1.recurringIssues.length, overview2.recurringIssues.length);
      expect(overview1.recurringIssues.first.capabilityId, overview2.recurringIssues.first.capabilityId);
      
      expect(overview1.actions.length, overview2.actions.length);
      expect(overview1.actions.first.id, overview2.actions.first.id);
    });

    test('TEST J - IMMUTABILITE', () {
      final i1 = ActionPlanItem(id: 'x1', title: '', description: '', reason: '', type: RecommendationType.createAlternative, priority: ActionPriority.essential, capabilityIds: {'acceder_internet'}, causeNodeIds: {}, targetAssetId: 'radio');
      final a1 = _mockAnalysis(scenarioId: 's1', capStates: {'cap1': B3State.failed}, causes: {'cap1': ['elec']}, items: [i1], otherStates: {});
      
      final oldActionsLength = a1.actionPlan!.items.length;
      final oldGraphLength = a1.graph!.length;
      
      analyzer.analyze([a1]);
      
      expect(a1.actionPlan!.items.length, oldActionsLength);
      expect(a1.graph!.length, oldGraphLength);
    });

    test('TEST O - ORDRE GLOBAL DETERMINISTE', () {
      // Actions with SAME priority, SAME type, SAME frequency, SAME capabilities length
      final i1 = ActionPlanItem(id: 'B', title: '', description: '', reason: '', type: RecommendationType.createAlternative, priority: ActionPriority.essential, capabilityIds: {'c1'}, causeNodeIds: {}, targetAssetId: 'B_asset');
      final i2 = ActionPlanItem(id: 'A', title: '', description: '', reason: '', type: RecommendationType.createAlternative, priority: ActionPriority.essential, capabilityIds: {'c1'}, causeNodeIds: {}, targetAssetId: 'A_asset');
      final i3 = ActionPlanItem(id: 'C', title: '', description: '', reason: '', type: RecommendationType.createAlternative, priority: ActionPriority.essential, capabilityIds: {'c1'}, causeNodeIds: {}, targetAssetId: 'C_asset');
      
      final a1 = _mockAnalysis(scenarioId: 's1', capStates: {}, causes: {}, items: [i1, i2, i3], otherStates: {});
      
      final overview = analyzer.analyze([a1]);
      
      expect(overview.actions[0].targetAssetId, 'A_asset');
      expect(overview.actions[1].targetAssetId, 'B_asset');
      expect(overview.actions[2].targetAssetId, 'C_asset');
    });
  });
}
