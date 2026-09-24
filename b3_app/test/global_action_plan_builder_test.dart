import 'package:flutter_test/flutter_test.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/data/app_knowledge_dataset.dart';
import 'package:b3_app/features/action_plan/global_action_plan_builder.dart';
import 'package:b3_app/features/action_plan/models/action_plan.dart';
import 'package:b3_app/features/scenarios/models/scenario_analysis.dart';

void main() {
  group('GlobalActionPlanBuilder Tests (A-J)', () {
    late GlobalActionPlanBuilder builder;
    late HouseholdConfig config;
    const String kbJson = appKnowledgeBase; // Using real KB string
    
    setUp(() {
      builder = GlobalActionPlanBuilder(kbJson);
      config = HouseholdConfig(
        ownedAssets: [],
        ownedResources: [],
        resourceDurations: {},
        assessedCapabilities: {},
        capabilityOverrides: {},
        assessedResources: {'reserve_eau'},
        unknownResources: {},
      );
    });
    
    ScenarioAnalysis createAnalysis(String scenarioId, List<Recommendation> recs, [Duration duration = const Duration(hours: 24)]) {
      return ScenarioAnalysis(
        scenarioId: scenarioId,
        scenarioName: scenarioId,
        scenario: Scenario(name: scenarioId, duration: duration, systemOverrides: {}),
        simulationResult: SimulationResult({}, {}, [], []),
        recommendations: recs,
      );
    }
    
    test('TEST A — VERIFY VS ACQUIRE (SAME TARGET AND DIFFERENT TARGET)', () {
      final recAcq = Recommendation(id: 'acq_target_A', targetResourceId: 'targetA', type: RecommendationType.acquire, priority: RecommendationPriority.high, capabilityId: 'cap1', title: 'Acq A', description: '', reason: '', causeNodeIds: {});
      final recVer = Recommendation(id: 'ver_target_A', targetResourceId: 'targetA', type: RecommendationType.verify, priority: RecommendationPriority.high, capabilityId: 'cap1', title: 'Ver A', description: '', reason: '', causeNodeIds: {});
      final recAcqB = Recommendation(id: 'acq_target_B', targetResourceId: 'targetB', type: RecommendationType.acquire, priority: RecommendationPriority.high, capabilityId: 'cap1', title: 'Acq B', description: '', reason: '', causeNodeIds: {});
      final recVerC = Recommendation(id: 'ver_target_C', targetResourceId: 'targetC', type: RecommendationType.verify, priority: RecommendationPriority.high, capabilityId: 'cap1', title: 'Ver C', description: '', reason: '', causeNodeIds: {});

      final analyses = [createAnalysis('s1', [recAcq, recVer, recAcqB, recVerC])];
      final plan = builder.build(analyses, config);
      
      expect(plan.items.length, 4);
      // ver_target_A blocks acq_target_A -> top
      final verA = plan.items.firstWhere((i) => i.id == 'ver_target_A');
      expect(verA.urgency, ActionUrgencyCategory.top);
      expect(verA.priorityReasons.any((r) => r.type == PriorityReasonType.blocksPurchaseDecision), true);
      
      // ver_target_C has no acquire -> later
      final verC = plan.items.firstWhere((i) => i.id == 'ver_target_C');
      expect(verC.urgency, ActionUrgencyCategory.later);
      expect(verC.priorityReasons.any((r) => r.type == PriorityReasonType.blocksPurchaseDecision), false);
      
      // Since verA is top, it should be at index 0
      expect(plan.items[0].id, 'ver_target_A');
    });

    test('TEST B — EXISTING VS BUY (SAME TARGET AND DIFFERENT TARGET)', () {
      final recAcq = Recommendation(id: 'acq_target_A', targetResourceId: 'targetA', type: RecommendationType.acquire, priority: RecommendationPriority.high, capabilityId: 'cap1', title: 'Acq A', description: '', reason: '', causeNodeIds: {});
      final recOrg = Recommendation(id: 'org_target_A', targetResourceId: 'targetA', type: RecommendationType.useExisting, priority: RecommendationPriority.high, capabilityId: 'cap1', title: 'Org A', description: '', reason: '', causeNodeIds: {});
      final recOrgB = Recommendation(id: 'org_target_B', targetResourceId: 'targetB', type: RecommendationType.useExisting, priority: RecommendationPriority.high, capabilityId: 'cap1', title: 'Org B', description: '', reason: '', causeNodeIds: {});

      final analyses = [createAnalysis('s1', [recAcq, recOrg, recOrgB])];
      final plan = builder.build(analyses, config);
      
      final orgA = plan.items.firstWhere((i) => i.id == 'org_target_A');
      expect(orgA.urgency, ActionUrgencyCategory.important);
      expect(orgA.priorityReasons.any((r) => r.type == PriorityReasonType.usesExistingSolution), true);

      final orgB = plan.items.firstWhere((i) => i.id == 'org_target_B');
      expect(orgB.urgency, ActionUrgencyCategory.later);
      expect(orgB.priorityReasons.any((r) => r.type == PriorityReasonType.usesExistingSolution), false);
      
      // orgA should come before acqA due to the comparator explicit rule
      final idxOrgA = plan.items.indexWhere((i) => i.id == 'org_target_A');
      final idxAcqA = plan.items.indexWhere((i) => i.id == 'acq_target_A');
      expect(idxOrgA < idxAcqA, true);
    });

    test('TEST G — DEDUP (G1, G2, G3)', () {
      // G1: same canonical action in two scenarios -> merged
      final recG1A = Recommendation(id: 'acquire_targetX', targetResourceId: 'targetX', type: RecommendationType.acquire, priority: RecommendationPriority.high, capabilityId: 'cap1', title: '', description: '', reason: '', causeNodeIds: {});
      final recG1B = Recommendation(id: 'acquire_targetX', targetResourceId: 'targetX', type: RecommendationType.acquire, priority: RecommendationPriority.high, capabilityId: 'cap2', title: '', description: '', reason: '', causeNodeIds: {});
      
      // G2: same type but different targets -> NOT merged
      final recG2A = Recommendation(id: 'acquire_targetY', targetResourceId: 'targetY', type: RecommendationType.acquire, priority: RecommendationPriority.high, capabilityId: 'cap1', title: '', description: '', reason: '', causeNodeIds: {});
      final recG2B = Recommendation(id: 'acquire_targetZ', targetResourceId: 'targetZ', type: RecommendationType.acquire, priority: RecommendationPriority.high, capabilityId: 'cap1', title: '', description: '', reason: '', causeNodeIds: {});

      // G3: same target but different type -> NOT merged
      final recG3A = Recommendation(id: 'verify_targetW', targetResourceId: 'targetW', type: RecommendationType.verify, priority: RecommendationPriority.high, capabilityId: 'cap1', title: '', description: '', reason: '', causeNodeIds: {});
      final recG3B = Recommendation(id: 'acquire_targetW', targetResourceId: 'targetW', type: RecommendationType.acquire, priority: RecommendationPriority.high, capabilityId: 'cap1', title: '', description: '', reason: '', causeNodeIds: {});

      final analyses = [
        createAnalysis('s1', [recG1A, recG2A, recG3A]),
        createAnalysis('s2', [recG1B, recG2B, recG3B]),
      ];
      final plan = builder.build(analyses, config);
      
      final g1 = plan.items.firstWhere((i) => i.id == 'acquire_targetX');
      expect(g1.affectedScenarioIds.length, 2, reason: 'G1 should be merged');
      expect(g1.capabilityIds.length, 2); // cap1 and cap2

      final g2Y = plan.items.firstWhere((i) => i.id == 'acquire_targetY');
      final g2Z = plan.items.firstWhere((i) => i.id == 'acquire_targetZ');
      expect(g2Y.affectedScenarioIds.length, 1);
      expect(g2Z.affectedScenarioIds.length, 1);

      final g3V = plan.items.firstWhere((i) => i.id == 'verify_targetW');
      final g3A = plan.items.firstWhere((i) => i.id == 'acquire_targetW');
      expect(g3V.affectedScenarioIds.length, 1);
      expect(g3A.affectedScenarioIds.length, 1);
    });

    test('ACTIONPRIORITY — PRÉSERVER LES ÉTATS', () {
      final config = HouseholdConfig(ownedAssets: [], ownedResources: [], resourceDurations: {}, assessedCapabilities: {}, capabilityOverrides: {}, assessedResources: {'reserve_eau'}, unknownResources: {});
      
      final recFailed = Recommendation(id: 'acq_failed', type: RecommendationType.acquire, priority: RecommendationPriority.high, capabilityId: 'cap1', title: '', description: '', reason: '', causeNodeIds: {});
      final recDegraded = Recommendation(id: 'acq_degraded', type: RecommendationType.acquire, priority: RecommendationPriority.high, capabilityId: 'cap2', title: '', description: '', reason: '', causeNodeIds: {});
      final recUnknown = Recommendation(id: 'acq_unknown', type: RecommendationType.acquire, priority: RecommendationPriority.high, capabilityId: 'cap3', title: '', description: '', reason: '', causeNodeIds: {});
      final recNotAssessed = Recommendation(id: 'acq_not_assessed', type: RecommendationType.acquire, priority: RecommendationPriority.high, capabilityId: 'cap4', title: '', description: '', reason: '', causeNodeIds: {});
      final recMaintained = Recommendation(id: 'acq_maintained', type: RecommendationType.acquire, priority: RecommendationPriority.high, capabilityId: 'cap5', title: '', description: '', reason: '', causeNodeIds: {});

      // Create a fake simulation result
      final graph = DataMapper.buildGraph(kbJson, config);
      final sim = B3Engine().runSimulation(graph, DataMapper.parseScenario(kbJson, 'panne_elec', const Duration(hours: 24)));
      
      // Inject fake states
      sim.nodeStates['cap1'] = B3State.failed;
      sim.nodeStates['cap2'] = B3State.degraded;
      sim.nodeStates['cap3'] = B3State.unknown;
      sim.nodeStates['cap4'] = B3State.notAssessed;
      sim.nodeStates['cap5'] = B3State.maintained;

      final analysis = ScenarioAnalysis(
        scenarioId: 'panne_elec',
        scenarioName: 'Panne',
        scenario: DataMapper.parseScenario(kbJson, 'panne_elec', const Duration(hours: 24)),
        simulationResult: sim,
        recommendations: [recFailed, recDegraded, recUnknown, recNotAssessed, recMaintained],
      );

      final plan = builder.build([analysis], config);
      
      expect(plan.items.firstWhere((i) => i.id == 'acq_failed').priority, ActionPriority.essential);
      expect(plan.items.firstWhere((i) => i.id == 'acq_degraded').priority, ActionPriority.important);
      expect(plan.items.firstWhere((i) => i.id == 'acq_unknown').priority, ActionPriority.toVerify);
      expect(plan.items.firstWhere((i) => i.id == 'acq_not_assessed').priority, ActionPriority.toVerify);
      expect(plan.items.firstWhere((i) => i.id == 'acq_maintained').priority, ActionPriority.improvement);
    });

    test('TEST E — ORDRE HORIZON RÉEL', () {
      final localConfig = HouseholdConfig(
        ownedAssets: ['radiateur_elec', 'plaque_elec'],
        ownedResources: [],
        resourceDurations: {},
        assessedCapabilities: {'chauffer', 'cuisiner'},
        capabilityOverrides: {},
        assessedResources: {'reserve_eau'},
        unknownResources: {},
      );
      
      // action A (chauffer fails at 6h/24h)
      final recA = Recommendation(id: 'acq_chauffage', type: RecommendationType.acquire, priority: RecommendationPriority.high, capabilityId: 'chauffer', title: '', description: '', reason: '', causeNodeIds: {});
      // action B (we need an action that fails later. Since 'eau' fails at 72h without water reserves. Wait, what fails at 72h?)
      // Let's use a capability that has a resource duration! 
      // If we own 'bouteille_eau' with duration 48h. Then 'disposer_eau' fails at 72h!
      localConfig.ownedAssets.add('stock_eau');
      localConfig.assessedCapabilities.add('disposer_eau');
      localConfig.ownedResources.add('reserve_eau');
      localConfig.resourceDurations['reserve_eau'] = const Duration(hours: 48);
      
      final recB = Recommendation(id: 'acq_eau', type: RecommendationType.acquire, priority: RecommendationPriority.high, capabilityId: 'disposer_eau', title: '', description: '', reason: '', causeNodeIds: {});
      
      final analysisElec = ScenarioAnalysis(
        scenarioId: 'panne_elec',
        scenarioName: 'Panne Electrique',
        scenario: DataMapper.parseScenario(kbJson, 'panne_elec', const Duration(hours: 24)),
        simulationResult: B3Engine().runSimulation(DataMapper.buildGraph(kbJson, localConfig), DataMapper.parseScenario(kbJson, 'panne_elec', const Duration(hours: 24))),
        recommendations: [recA],
      );
      
      final analysisEau = ScenarioAnalysis(
        scenarioId: 'coupure_eau',
        scenarioName: 'Coupure Eau',
        scenario: DataMapper.parseScenario(kbJson, 'coupure_eau', const Duration(days: 7)),
        simulationResult: B3Engine().runSimulation(DataMapper.buildGraph(kbJson, localConfig), DataMapper.parseScenario(kbJson, 'coupure_eau', const Duration(days: 7))),
        recommendations: [recB],
      );

      final plan = builder.build([analysisElec, analysisEau], localConfig);
      final itemA = plan.items.firstWhere((i) => i.id == 'acq_chauffage');
      final itemB = plan.items.firstWhere((i) => i.id == 'acq_eau');
      
      expect(itemA.earliestAffectedHorizon == PreparednessHorizon.sixHours || itemA.earliestAffectedHorizon == PreparednessHorizon.oneDay, true);
      expect(itemB.earliestAffectedHorizon == PreparednessHorizon.threeDays, true);
      
      final idxA = plan.items.indexOf(itemA);
      final idxB = plan.items.indexOf(itemB);
      expect(idxA < idxB, true);
    });

    test('TEST F — VRAI UNKNOWN', () {
      final localConfig = HouseholdConfig(
        ownedAssets: ['poele_bois'],
        ownedResources: [],
        resourceDurations: {},
        assessedCapabilities: {'chauffer'},
        capabilityOverrides: {},
        assessedResources: {'res_bois'},
        unknownResources: {'res_bois'}, 
      );
      
      final recUnknown = Recommendation(id: 'ver_bois', type: RecommendationType.verify, priority: RecommendationPriority.high, capabilityId: 'chauffer', title: '', description: '', reason: '', causeNodeIds: {});
      
      final analysisElec = ScenarioAnalysis(
        scenarioId: 'panne_elec',
        scenarioName: 'Panne',
        scenario: DataMapper.parseScenario(kbJson, 'panne_elec', const Duration(hours: 24)),
        simulationResult: B3Engine().runSimulation(DataMapper.buildGraph(kbJson, localConfig), DataMapper.parseScenario(kbJson, 'panne_elec', const Duration(hours: 24))),
        recommendations: [recUnknown],
      );

      final plan = builder.build([analysisElec], localConfig);
      final itemU = plan.items.firstWhere((i) => i.id == 'ver_bois');
      
      expect(itemU.earliestAffectedHorizon, isNull);
      expect(itemU.priorityReasons.any((r) => r.type == PriorityReasonType.appearsAtShortHorizon), false);
    });

    test('TEST PRIMARY SCENARIO REVERSE', () {
      final rec = Recommendation(id: 'acq_x', type: RecommendationType.acquire, priority: RecommendationPriority.high, capabilityId: 'cap1', title: '', description: '', reason: '', causeNodeIds: {});
      final plan1 = builder.build([createAnalysis('s1', [rec]), createAnalysis('s2', [rec])], config);
      final plan2 = builder.build([createAnalysis('s2', [rec]), createAnalysis('s1', [rec])], config);
      
      expect(plan1.items.first.primaryScenarioId, 's1');
      expect(plan2.items.first.primaryScenarioId, 's1'); // Still 's1' because of lexical sort
    });

    test('TEST ACTION PRIORITY HISTORIQUE', () {
      final rec = Recommendation(id: 'acq_x', type: RecommendationType.acquire, priority: RecommendationPriority.medium, capabilityId: 'cap1', title: '', description: '', reason: '', causeNodeIds: {});
      final analysis = createAnalysis('s1', [rec]);
      analysis.simulationResult!.nodeStates['cap1'] = B3State.degraded;
      final plan = builder.build([analysis], config);
      expect(plan.items.first.priority, ActionPriority.important);
      
      analysis.simulationResult!.nodeStates['cap1'] = B3State.failed;
      final plan2 = builder.build([analysis], config);
      expect(plan2.items.first.priority, ActionPriority.essential);
    });
  });
}
