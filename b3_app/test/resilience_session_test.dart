import 'package:flutter_test/flutter_test.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/features/progression/models/resilience_session.dart';
import 'package:b3_app/features/progression/models/household_update.dart';
import 'package:b3_app/features/progression/models/progression_result.dart';

void main() {
  const integrationDataset = '''
  {
    "systems": [
      {"id": "chauffage", "name": "Chauffage"}
    ],
    "capabilities": [
      {"id": "chauffer", "name": "Se chauffer", "assets": ["rad_elec", "poele_bois"]}
    ],
    "assets": [
      {"id": "rad_elec", "name": "Radiateur", "requires": ["electricite_reseau"]},
      {"id": "poele_bois", "name": "Poêle à bois", "requires": ["bois"]}
    ],
    "resources": [
      {"id": "electricite_reseau", "name": "Électricité Réseau"},
      {"id": "bois", "name": "Bois"}
    ],
    "scenarios": [
      {
        "id": "panne_elec",
        "name": "Panne électrique",
        "duration": 48,
        "overrides": {
          "electricite_reseau": "failed"
        }
      }
    ]
  }
  ''';

  test('TEST A — UNKNOWN → suffisant', () {
    final config = HouseholdConfig(
      ownedAssets: ['poele_bois'],
      ownedResources: ['bois'],
      unknownResources: {'bois'},
      assessedCapabilities: {'chauffer'},
    );
    final session = ResilienceSession(
      knowledgeJson: integrationDataset,
      scenarioId: 'panne_elec',
      initialConfig: config,
    );
    
    final result = session.recalculate(const ResourceUpdate(
      resourceId: 'bois',
      isOwned: true,
      duration: Duration(hours: 72),
      isUnknown: false,
      nature: UpdateNature.observation,
    ));
    
    expect(result.changedCapabilities.length, 1);
    expect(result.changedCapabilities.first.beforeState, B3State.unknown);
    expect(result.changedCapabilities.first.afterState, B3State.maintained);
    expect(result.changedCapabilities.first.meaning, ProgressionMeaning.favorableSituationConfirmed);
  });

  test('TEST B — UNKNOWN → absent', () {
    final config = HouseholdConfig(
      ownedAssets: ['poele_bois'],
      ownedResources: ['bois'],
      unknownResources: {'bois'},
      assessedCapabilities: {'chauffer'},
    );
    final session = ResilienceSession(
      knowledgeJson: integrationDataset,
      scenarioId: 'panne_elec',
      initialConfig: config,
    );
    
    final result = session.recalculate(const ResourceUpdate(
      resourceId: 'bois',
      isOwned: false,
      isUnknown: false,
      nature: UpdateNature.observation,
    ));
    
    expect(result.changedCapabilities.first.afterState, B3State.failed);
    expect(result.changedCapabilities.first.meaning, ProgressionMeaning.vulnerabilityConfirmed);
  });

  test('TEST C — NOT_ASSESSED → UNKNOWN', () {
    final config = HouseholdConfig(
      ownedAssets: ['poele_bois'],
      ownedResources: ['bois'],
      assessedResources: {},
      assessedCapabilities: {'chauffer'},
    );
    final session = ResilienceSession(
      knowledgeJson: integrationDataset,
      scenarioId: 'panne_elec',
      initialConfig: config,
    );
    
    expect(session.simulationResult!.nodeStates['bois'], B3State.notAssessed);
    
    session.recalculate(const ResourceUpdate(
      resourceId: 'bois',
      isUnknown: true,
      nature: UpdateNature.observation,
    ));
    
    expect(session.simulationResult!.nodeStates['bois'], B3State.unknown);
  });

  test('TEST D — ajout asset', () {
    final config = HouseholdConfig(
      ownedAssets: ['rad_elec'],
      assessedCapabilities: {'chauffer'},
    );
    final session = ResilienceSession(
      knowledgeJson: integrationDataset,
      scenarioId: 'panne_elec',
      initialConfig: config,
    );
    
    expect(session.simulationResult!.nodeStates['chauffer'], B3State.failed);
    
    final result = session.recalculate(const AssetOwnershipUpdate(assetId: 'poele_bois', isOwned: true, nature: UpdateNature.intervention));
    
    expect(session.simulationResult!.nodeStates['poele_bois'], B3State.notAssessed);
    expect(result.changedCapabilities.first.afterState, B3State.notAssessed);
    expect(result.changedCapabilities.first.meaning, ProgressionMeaning.unchanged);
  });

  test('TEST E — asset + ressource', () {
    final config = HouseholdConfig(
      ownedAssets: ['rad_elec', 'poele_bois'],
      assessedCapabilities: {'chauffer'},
    );
    final session = ResilienceSession(
      knowledgeJson: integrationDataset,
      scenarioId: 'panne_elec',
      initialConfig: config,
    );
    
    final result = session.recalculate(const ResourceUpdate(
      resourceId: 'bois',
      isOwned: true,
      duration: Duration(hours: 72),
      isUnknown: false,
      nature: UpdateNature.intervention,
    ));
    
    expect(result.changedCapabilities.first.afterState, B3State.maintained);
    expect(result.changedCapabilities.first.meaning, ProgressionMeaning.resilienceImproved);
  });

  test('TEST F — autonomie augmentée', () {
    final config = HouseholdConfig(
      ownedAssets: ['poele_bois'],
      ownedResources: ['bois'],
      assessedResources: {'bois'},
      resourceDurations: {'bois': const Duration(hours: 24)},
      assessedCapabilities: {'chauffer'},
    );
    final session = ResilienceSession(
      knowledgeJson: integrationDataset,
      scenarioId: 'panne_elec',
      initialConfig: config,
    );
    
    expect(session.simulationResult!.nodeStates['chauffer'], B3State.degraded);
    
    final result = session.recalculate(const ResourceUpdate(
      resourceId: 'bois',
      isOwned: true,
      duration: Duration(hours: 72),
      isUnknown: false,
      nature: UpdateNature.intervention,
    ));
    
    expect(result.changedCapabilities.first.meaning, ProgressionMeaning.resilienceImproved);
    expect(session.simulationResult!.nodeStates['chauffer'], B3State.maintained);
  });

  test('TEST G — Action Plan recalculé', () {
    final config = HouseholdConfig(
      ownedAssets: ['poele_bois'],
      ownedResources: ['bois'],
      unknownResources: {'bois'},
      assessedCapabilities: {'chauffer'},
    );
    final session = ResilienceSession(
      knowledgeJson: integrationDataset,
      scenarioId: 'panne_elec',
      initialConfig: config,
    );
    
    expect(session.actionPlan!.items.any((i) => i.type == RecommendationType.verify), true);
    
    session.recalculate(const ResourceUpdate(
      resourceId: 'bois',
      isOwned: true,
      duration: Duration(hours: 72),
      isUnknown: false,
      nature: UpdateNature.observation,
    ));
    
    expect(session.actionPlan!.items.any((i) => i.type == RecommendationType.verify), false);
  });

  test('TEST H — snapshot immutable', () {
    final config = HouseholdConfig(
      ownedAssets: ['rad_elec'],
      assessedCapabilities: {'chauffer'},
    );
    final session = ResilienceSession(
      knowledgeJson: integrationDataset,
      scenarioId: 'panne_elec',
      initialConfig: config,
    );
    
    final result = session.recalculate(const AssetOwnershipUpdate(assetId: 'poele_bois', isOwned: true, nature: UpdateNature.intervention));
    
    expect(result.beforeConfig.ownedAssets.contains('poele_bois'), false);
    expect(result.afterConfig.ownedAssets.contains('poele_bois'), true);
  });

  test('TEST I — action non structurée', () {
    final config = HouseholdConfig(
      ownedAssets: ['rad_elec'],
      assessedCapabilities: {'chauffer'},
    );
    final session = ResilienceSession(
      knowledgeJson: integrationDataset,
      scenarioId: 'panne_elec',
      initialConfig: config,
    );
    
    final result = session.recalculate(const ActionCompletedUpdate(actionId: 'test_action'));
    
    expect(session.completedActionIds.contains('test_action'), true);
    expect(result.hasStructuralChange, false);
    expect(result.changedCapabilities.isEmpty, true);
  });

  test('TEST J — déterminisme', () {
    final config = HouseholdConfig(
      ownedAssets: ['poele_bois'],
      ownedResources: ['bois'],
      unknownResources: {'bois'},
      assessedCapabilities: {'chauffer'},
    );
    final session = ResilienceSession(
      knowledgeJson: integrationDataset,
      scenarioId: 'panne_elec',
      initialConfig: config,
    );
    
    session.recalculate(const ResourceUpdate(
      resourceId: 'bois',
      isOwned: true,
      duration: Duration(hours: 72),
      isUnknown: false,
      nature: UpdateNature.observation,
    ));
    
    final r2 = session.recalculate(const ResourceUpdate(
      resourceId: 'bois',
      isOwned: true,
      duration: Duration(hours: 72),
      isUnknown: false,
      nature: UpdateNature.observation,
    ));
    
    expect(r2.changedCapabilities.isEmpty, true);
  });

  test('TEST K — anti-invention', () {
    final config = HouseholdConfig(
      ownedAssets: ['rad_elec'],
      assessedCapabilities: {'chauffer'},
    );
    final session = ResilienceSession(
      knowledgeJson: integrationDataset,
      scenarioId: 'panne_elec',
      initialConfig: config,
    );
    
    session.recalculate(const AssetOwnershipUpdate(assetId: 'poele_bois', isOwned: true, nature: UpdateNature.intervention));
    
    expect(session.config.ownedResources.contains('bois'), false);
    expect(session.config.unknownResources.contains('bois'), false);
  });

  test('TEST L — plan après échec', () {
    final config = HouseholdConfig(
      ownedAssets: ['poele_bois'],
      ownedResources: ['bois'],
      unknownResources: {'bois'},
      assessedCapabilities: {'chauffer'},
    );
    final session = ResilienceSession(
      knowledgeJson: integrationDataset,
      scenarioId: 'panne_elec',
      initialConfig: config,
    );
    
    session.recalculate(const ResourceUpdate(
      resourceId: 'bois',
      isOwned: false,
      isUnknown: false,
      nature: UpdateNature.observation,
    ));
    
    expect(session.actionPlan!.items.any((i) => i.type == RecommendationType.verify), false);
    expect(session.actionPlan!.items.any((i) => i.type == RecommendationType.acquire), true);
  });

  test('TEST M — observation favorable ≠ amélioration physique', () {
    final config = HouseholdConfig(
      ownedAssets: ['poele_bois'],
      ownedResources: ['bois'],
      unknownResources: {'bois'},
      assessedCapabilities: {'chauffer'},
    );
    final session = ResilienceSession(
      knowledgeJson: integrationDataset,
      scenarioId: 'panne_elec',
      initialConfig: config,
    );
    
    final result = session.recalculate(const ResourceUpdate(
      resourceId: 'bois',
      isOwned: true,
      duration: Duration(hours: 72),
      isUnknown: false,
      nature: UpdateNature.observation,
    ));
    
    expect(result.changedCapabilities.first.meaning, ProgressionMeaning.favorableSituationConfirmed);
    expect(result.changedCapabilities.first.hasImproved, false);
  });

  test('TEST N — intervention favorable = amélioration physique', () {
    final config = HouseholdConfig(
      ownedAssets: ['poele_bois'],
      ownedResources: ['bois'],
      assessedResources: {'bois'},
      resourceDurations: {'bois': const Duration(hours: 24)},
      assessedCapabilities: {'chauffer'},
    );
    final session = ResilienceSession(
      knowledgeJson: integrationDataset,
      scenarioId: 'panne_elec',
      initialConfig: config,
    );
    
    final result = session.recalculate(const ResourceUpdate(
      resourceId: 'bois',
      isOwned: true,
      duration: Duration(hours: 72),
      isUnknown: false,
      nature: UpdateNature.intervention,
    ));
    
    expect(result.changedCapabilities.first.meaning, ProgressionMeaning.resilienceImproved);
    expect(result.changedCapabilities.first.hasImproved, true);
  });

  test('TEST O — ActionCompletedUpdate notifie les listeners', () {
    final config = HouseholdConfig(ownedAssets: []);
    final session = ResilienceSession(
      knowledgeJson: integrationDataset,
      scenarioId: 'panne_elec',
      initialConfig: config,
    );
    
    int listenerCalls = 0;
    session.addListener(() {
      listenerCalls++;
    });
    
    session.recalculate(const ActionCompletedUpdate(actionId: 'test_action'));
    
    expect(listenerCalls, 1);
  });

  test('TEST P — initialConfig isolée de la session', () {
    final config = HouseholdConfig(ownedAssets: []);
    final session = ResilienceSession(
      knowledgeJson: integrationDataset,
      scenarioId: 'panne_elec',
      initialConfig: config,
    );
    
    config.ownedAssets.add('poele_bois');
    
    expect(session.config.ownedAssets.contains('poele_bois'), false);
  });
}
