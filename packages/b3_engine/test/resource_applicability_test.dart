import 'package:test/test.dart';
import 'package:b3_engine/b3_engine.dart';
import 'dart:convert';

void main() {
  final recEngine = RecommendationEngine(b3KnowledgeBase);
  final scenarioElec = DataMapper.parseScenario(b3KnowledgeBase, 'panne_elec');
  final scenarioElecGaz = DataMapper.parseScenario(b3KnowledgeBase, 'panne_elec_gaz');

  test('TEST A — Ressource connue suffisante', () {
    final household = HouseholdConfig(
      ownedAssets: ['rechaud_bois'],
      ownedResources: ['bois'],
      assessedResources: {'bois'},
      resourceDurations: {'bois': Duration(hours: 72)},
      assessedCapabilities: {'cuisiner'}
    );
    final result = B3Engine().runSimulation(DataMapper.buildGraph(b3KnowledgeBase, household), scenarioElec);
    final recs = recEngine.generate(result, household, scenarioElec);

    expect(result.nodeStates['cuisiner'], B3State.maintained);
    expect(recs.any((r) => r.capabilityId == 'cuisiner'), false); // Aucune recommandation
  });

  test('TEST B — Ressource connue insuffisante', () {
    final household = HouseholdConfig(
      ownedAssets: ['rechaud_bois'],
      ownedResources: ['bois'],
      assessedResources: {'bois'},
      resourceDurations: {'bois': Duration(hours: 12)},
      assessedCapabilities: {'cuisiner'}
    );
    final result = B3Engine().runSimulation(DataMapper.buildGraph(b3KnowledgeBase, household), scenarioElec);
    final recs = recEngine.generate(result, household, scenarioElec);

    expect(result.nodeStates['cuisiner'], B3State.degraded);
    
    // Doit proposer d'augmenter le bois
    final rec = recs.firstWhere((r) => r.id.contains('rechaud_bois'));
    expect(rec.type, RecommendationType.organize);
    expect(rec.title.toLowerCase().contains('bois'), true);
  });

  test('TEST C — Ressource absente', () {
    final household = HouseholdConfig(
      ownedAssets: ['rechaud_gaz'],
      ownedResources: [], // Ne possède PAS de gaz
      assessedResources: {'gaz'}, // Mais on a évalué le gaz (l'utilisateur a dit "non")
      assessedCapabilities: {'cuisiner'}
    );
    final result = B3Engine().runSimulation(DataMapper.buildGraph(b3KnowledgeBase, household), scenarioElec);
    final recs = recEngine.generate(result, household, scenarioElec);

    expect(result.nodeStates['cuisiner'], B3State.failed);
    
    // La reco doit dire "Acquérir la ressource : Gaz"
    final rec = recs.firstWhere((r) => r.id.contains('rechaud_gaz'));
    expect(rec.type, RecommendationType.acquire);
    expect(rec.title.toLowerCase().contains('gaz'), true);
  });

  test('TEST D — Ressource présente mais durée inconnue', () {
    final household = HouseholdConfig(
      ownedAssets: ['rechaud_gaz'],
      ownedResources: ['gaz'],
      assessedResources: {'gaz'},
      // Aucune duration spécifiée
      assessedCapabilities: {'cuisiner'}
    );
    final result = B3Engine().runSimulation(DataMapper.buildGraph(b3KnowledgeBase, household), scenarioElec);
    
    // Le moteur considère que dur==null -> unknown
    expect(result.nodeStates['cuisiner'], B3State.unknown);
  });

  test('TEST E — Ressource jamais évaluée', () {
    final household = HouseholdConfig(
      ownedAssets: ['rechaud_gaz'],
      ownedResources: [], 
      assessedResources: {}, // Jamais évalué
      assessedCapabilities: {'cuisiner'}
    );
    final result = B3Engine().runSimulation(DataMapper.buildGraph(b3KnowledgeBase, household), scenarioElec);
    
    // Doit être NOT_ASSESSED, qui remonte la chaîne via ANY/ALL jusqu'à la capability
    expect(result.nodeStates['cuisiner'], B3State.notAssessed);
  });

  test('TEST F — Alternative théorique mais prérequis affecté', () {
    final household = HouseholdConfig(
      ownedAssets: ['plaque_elec'],
      assessedCapabilities: {'cuisiner'}
    );
    // Panne elec ET panne gaz
    final result = B3Engine().runSimulation(DataMapper.buildGraph(b3KnowledgeBase, household), scenarioElecGaz);
    final recs = recEngine.generate(result, household, scenarioElecGaz);

    expect(result.nodeStates['cuisiner'], B3State.failed);
    // Ne doit pas recommander réchaud gaz car gaz système est affecté
    expect(recs.any((r) => r.targetAssetId == 'rechaud_gaz'), false);
  });

  test('TEST G — Alternative indépendante (Recommandation avec condition ressource)', () {
    final household = HouseholdConfig(
      ownedAssets: ['plaque_elec'],
      assessedCapabilities: {'cuisiner'}
    );
    final result = B3Engine().runSimulation(DataMapper.buildGraph(b3KnowledgeBase, household), scenarioElec);
    final recs = recEngine.generate(result, household, scenarioElec);

    // Rechaud gaz proposé, et la description doit contenir la réserve
    final rec = recs.firstWhere((r) => r.targetAssetId == 'rechaud_gaz');
    expect(rec.description.contains('sous réserve'), true);
  });

  test('TEST H — Pas d invention', () {
    final minimalJson = '''
    {
      "systems": [{"id": "sys_elec", "name": "Electricité"}],
      "assets": [{"id": "plaque", "name": "Plaque", "requires": ["sys_elec"]}],
      "capabilities": [{"id": "cuisiner", "name": "Cuisiner", "assets": ["plaque"]}],
      "scenarios": [{"id": "panne", "name": "Panne", "duration": 24, "overrides": {"sys_elec": "failed"}}]
    }
    ''';
    final customEngine = RecommendationEngine(minimalJson);
    final scenario = DataMapper.parseScenario(minimalJson, 'panne');
    final household = HouseholdConfig(ownedAssets: ['plaque'], assessedCapabilities: {'cuisiner'});
    final result = B3Engine().runSimulation(DataMapper.buildGraph(minimalJson, household), scenario);
    final recs = customEngine.generate(result, household, scenario);

    expect(recs.where((r) => r.type == RecommendationType.createAlternative).isEmpty, true);
  });

  test('TEST I — Redondance réelle + ressource', () {
    final household = HouseholdConfig(
      ownedAssets: ['plaque_elec', 'rechaud_gaz'],
      ownedResources: ['gaz'],
      assessedResources: {'gaz'},
      resourceDurations: {'gaz': Duration(hours: 72)},
      assessedCapabilities: {'cuisiner'}
    );
    final result = B3Engine().runSimulation(DataMapper.buildGraph(b3KnowledgeBase, household), scenarioElec);
    final recs = recEngine.generate(result, household, scenarioElec);

    expect(result.nodeStates['cuisiner'], B3State.maintained);
    expect(recs.any((r) => r.capabilityId == 'cuisiner'), false);
  });

  test('TEST J — Multi-système + ressources', () {
    final household = HouseholdConfig(
      ownedAssets: ['plaque_elec', 'rechaud_gaz', 'rechaud_bois'],
      ownedResources: ['gaz', 'bois'],
      assessedResources: {'gaz', 'bois'},
      resourceDurations: {'gaz': Duration(hours: 72), 'bois': Duration(hours: 72)},
      assessedCapabilities: {'cuisiner'}
    );
    // Panne elec + gaz
    final result = B3Engine().runSimulation(DataMapper.buildGraph(b3KnowledgeBase, household), scenarioElecGaz);
    
    // plaque_elec = FAILED, rechaud_gaz = FAILED, rechaud_bois = MAINTAINED
    expect(result.nodeStates['cuisiner'], B3State.maintained);
  });
}
