import 'package:flutter_test/flutter_test.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/features/progression/models/household_update.dart';
import 'package:b3_app/features/progression/models/resilience_session.dart';

const integrationDataset = '''{
  "systems": [
    {"id": "elec", "name": "Réseau Electrique"}
  ],
  "resources": [
    {"id": "bois", "name": "Bois de chauffage"}
  ],
  "assets": [
    {"id": "rad_elec", "name": "Radiateur", "requires": ["elec"]},
    {"id": "poele_bois", "name": "Poêle à bois", "requires": ["bois"]}
  ],
  "capabilities": [
    {"id": "chauffer", "name": "Chauffer", "assets": ["rad_elec", "poele_bois"]}
  ],
  "scenarios": [
    {"id": "panne_elec", "name": "Panne Elec", "duration": 48, "overrides": {"elec": "failed"}}
  ]
}''';

void main() {
  test('TEST A — UNKNOWN → SUFFISANT', () {
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
    
    expect(session.simulationResult.nodeStates['bois'], B3State.unknown);
    expect(session.simulationResult.nodeStates['poele_bois'], B3State.unknown);
    expect(session.simulationResult.nodeStates['chauffer'], B3State.unknown);
    
    expect(session.actionPlan.items.any((i) => i.type == RecommendationType.verify), true);
    
    final result = session.recalculate(const ResourceUpdate(
      resourceId: 'bois',
      isOwned: true,
      duration: Duration(hours: 72),
      isUnknown: false,
    ));
    
    expect(result.changedCapabilities.length, 1);
    expect(result.changedCapabilities.first.beforeState, B3State.unknown);
    expect(result.changedCapabilities.first.afterState, B3State.maintained);
    expect(result.changedCapabilities.first.hasImproved, true);
    
    expect(session.simulationResult.nodeStates['bois'], B3State.maintained);
    expect(session.simulationResult.nodeStates['poele_bois'], B3State.maintained);
    expect(session.simulationResult.nodeStates['chauffer'], B3State.maintained);
    
    expect(session.actionPlan.items.any((i) => i.type == RecommendationType.verify), false);
  });

  test('TEST B — UNKNOWN → ABSENT', () {
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
    ));
    
    expect(result.changedCapabilities.first.afterState, B3State.failed);
    expect(result.changedCapabilities.first.hasImproved, false);
    expect(result.changedCapabilities.first.hasBetterKnowledge, true);
    expect(result.changedCapabilities.first.hasDegraded, true);
    
    expect(session.simulationResult.nodeStates['bois'], B3State.failed);
  });

  test('TEST C — NOT_ASSESSED → UNKNOWN', () {
    final config = HouseholdConfig(
      ownedAssets: ['poele_bois'],
      ownedResources: ['bois'], // possédé
      assessedResources: {}, // pas évalué
      assessedCapabilities: {'chauffer'},
    );
    final session = ResilienceSession(
      knowledgeJson: integrationDataset,
      scenarioId: 'panne_elec',
      initialConfig: config,
    );
    
    expect(session.simulationResult.nodeStates['bois'], B3State.notAssessed);
    
    session.recalculate(const ResourceUpdate(
      resourceId: 'bois',
      isUnknown: true,
    ));
    
    expect(session.simulationResult.nodeStates['bois'], B3State.unknown);
  });

  test('TEST D, E, K — AJOUT D ASSET, ANTI-INVENTION ET AJOUT RESSOURCE', () {
    final config = HouseholdConfig(
      ownedAssets: ['rad_elec'],
      assessedCapabilities: {'chauffer'},
    );
    final session = ResilienceSession(
      knowledgeJson: integrationDataset,
      scenarioId: 'panne_elec',
      initialConfig: config,
    );
    
    expect(session.simulationResult.nodeStates['chauffer'], B3State.failed);
    
    // Ajout de poele_bois (Test D)
    final result = session.recalculate(const AssetOwnershipUpdate(assetId: 'poele_bois', isOwned: true));
    
    // Le bois n'a jamais été évalué, donc il est NOT_ASSESSED. 
    // poele_bois devient NOT_ASSESSED.
    // chauffer devient NOT_ASSESSED.
    // Donc PAS AUTOMATIQUEMENT MAINTAINED ! Et n'invente pas le bois (Test K).
    expect(session.config.ownedResources.contains('bois'), false);
    expect(session.config.unknownResources.contains('bois'), false);
    
    expect(session.simulationResult.nodeStates['poele_bois'], B3State.notAssessed);
    expect(session.simulationResult.nodeStates['chauffer'], B3State.notAssessed);
    expect(result.changedCapabilities.first.afterState, B3State.notAssessed);
    
    // L'utilisateur ajoute le bois (Test E)
    final result2 = session.recalculate(const ResourceUpdate(
      resourceId: 'bois',
      isOwned: true,
      duration: Duration(hours: 72),
      isUnknown: false,
    ));
    
    expect(result2.changedCapabilities.first.afterState, B3State.maintained);
    expect(session.simulationResult.nodeStates['chauffer'], B3State.maintained);
  });

  test('TEST F — AUTONOMIE AUGMENTÉE', () {
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
    
    expect(session.simulationResult.nodeStates['chauffer'], B3State.degraded);
    
    session.recalculate(const ResourceUpdate(
      resourceId: 'bois',
      isOwned: true,
      duration: Duration(hours: 72),
      isUnknown: false,
    ));
    
    expect(session.simulationResult.nodeStates['chauffer'], B3State.maintained);
  });

  test('TEST G, L — ACTION PLAN RECALCULÉ ET PLAN APRES ECHEC', () {
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
    
    expect(session.actionPlan.items.any((i) => i.type == RecommendationType.verify), true);
    
    session.recalculate(const ResourceUpdate(
      resourceId: 'bois',
      isOwned: false, // Résultat vérif: ABSENT !
      isUnknown: false,
    ));
    
    // Le VERIFY a disparu
    expect(session.actionPlan.items.any((i) => i.type == RecommendationType.verify), false);
    // Mais on recommande maintenant de régler la situation (CreateAlternative)
    expect(session.actionPlan.items.any((i) => i.type == RecommendationType.acquire), true);
  });

  test('TEST H — SNAPSHOT IMMUTABLE', () {
    final config = HouseholdConfig(
      ownedAssets: ['rad_elec'],
      assessedCapabilities: {'chauffer'},
    );
    final session = ResilienceSession(
      knowledgeJson: integrationDataset,
      scenarioId: 'panne_elec',
      initialConfig: config,
    );
    
    final result = session.recalculate(const AssetOwnershipUpdate(assetId: 'poele_bois', isOwned: true));
    
    expect(result.beforeConfig.ownedAssets.contains('poele_bois'), false);
    expect(result.afterConfig.ownedAssets.contains('poele_bois'), true);
  });

  test('TEST I — ACTION NON STRUCTURÉE', () {
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
    // Same config
    expect(result.beforeConfig.ownedAssets, result.afterConfig.ownedAssets);
  });

  test('TEST J — DÉTERMINISME', () {
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
    ));
    
    // Recalculer exactement la même chose depuis le NOUVEL état ne doit rien changer aux capacités (avant = apres = maintained).
    final r2 = session.recalculate(const ResourceUpdate(
      resourceId: 'bois',
      isOwned: true,
      duration: Duration(hours: 72),
      isUnknown: false,
    ));
    
    expect(r2.changedCapabilities.isEmpty, true);
  });
}
