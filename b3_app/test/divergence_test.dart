import 'package:flutter_test/flutter_test.dart';
import 'package:b3_app/features/progression/models/resilience_session.dart';
import 'package:b3_app/features/scenarios/services/multi_scenario_analyzer.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/data/app_knowledge_dataset.dart';

void main() {
  test('Divergence Global Overview vs Scenario Detail (Bois 24h)', () {
    final config = HouseholdConfig(
      ownedAssets: ['poele_bois'],
      ownedResources: ['bois'],
      assessedResources: {'bois'},
      resourceDurations: {'bois': const Duration(hours: 24)},
      assessedCapabilities: {'chauffer'}
    );

    final globalOverview = MultiScenarioAnalyzer(appKnowledgeBase).analyze(config, ['panne_gaz'], horizonDuration: const Duration(hours: 24));
    final panneGazAnalysis = globalOverview.firstWhere((a) => a.scenarioId == 'panne_gaz');
    
    final stateGlobal = panneGazAnalysis.simulationResult!.nodeStates['chauffer'];
    
    final session = ResilienceSession(
      knowledgeJson: appKnowledgeBase,
      scenarioId: 'panne_gaz',
      initialConfig: config
    );
    
    final stateDetail = session.simulationResult!.nodeStates['chauffer'];
    
    expect(stateGlobal, B3State.maintained);
    expect(stateGlobal, equals(stateDetail));
  });

  test('Preservation of native duration when horizon is not provided', () {
    final config = HouseholdConfig(
      ownedAssets: ['poele_bois'],
      ownedResources: ['bois'],
      assessedResources: {'bois'},
      resourceDurations: {'bois': const Duration(hours: 24)},
      assessedCapabilities: {'chauffer'}
    );

    // No horizonDuration passed. panne_gaz has native duration 48h.
    final globalOverview = MultiScenarioAnalyzer(appKnowledgeBase).analyze(config, ['panne_gaz']);
    final panneGazAnalysis = globalOverview.firstWhere((a) => a.scenarioId == 'panne_gaz');
    
    final stateGlobal = panneGazAnalysis.simulationResult!.nodeStates['chauffer'];
    
    // Since 24h < 48h, it should be degraded!
    expect(stateGlobal, B3State.degraded);
  });

  test('Strict Capability parity between Global Overview and Scenario Detail', () {
    final config = HouseholdConfig(
      ownedAssets: ['poele_bois', 'smartphone', 'radiateur_elec'],
      ownedResources: ['bois', 'batterie', 'elec'],
      assessedResources: {'bois', 'batterie', 'elec'},
      resourceDurations: {
        'bois': const Duration(hours: 36),
        'batterie': const Duration(hours: 12),
        'elec': const Duration(hours: 120),
      },
      assessedCapabilities: {'chauffer', 'communiquer', 'eclairage', 'conserver_aliments'}
    );

    final globalOverview = MultiScenarioAnalyzer(appKnowledgeBase).analyze(config, ['panne_elec'], horizonDuration: const Duration(hours: 24));
    final globalResult = globalOverview.firstWhere((a) => a.scenarioId == 'panne_elec').simulationResult!;
    
    final session = ResilienceSession(
      knowledgeJson: appKnowledgeBase,
      scenarioId: 'panne_elec',
      initialConfig: config
    );
    final detailResult = session.simulationResult!;

    final graph = DataMapper.buildGraph(appKnowledgeBase, config);
    final capabilities = graph.whereType<Capability>();
    
    expect(capabilities.isNotEmpty, true, reason: 'Test setup should have capabilities');
    int count = 0;
    for (final cap in capabilities) {
      count++;
      expect(
        globalResult.nodeStates[cap.id],
        detailResult.nodeStates[cap.id],
        reason: 'Capability ${cap.id} should match at 24h horizon'
      );
    }
    print('Compared $count capabilities successfully.');
  });
}
