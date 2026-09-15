import 'package:test/test.dart';
import 'package:b3_engine/b3_engine.dart';

void main() {
  final scenario = DataMapper.parseScenario(b3KnowledgeBase, 'panne_elec');
  final recEngine = RecommendationEngine(b3KnowledgeBase);

  test('TEST 1 — Vulnérabilité simple', () {
    final household = HouseholdConfig(
      ownedAssets: ['plaque_elec'],
      assessedCapabilities: {'cuisiner'}
    );
    final graph = DataMapper.buildGraph(b3KnowledgeBase, household);
    final result = B3Engine().runSimulation(graph, scenario);
    
    final recs = recEngine.generate(result, household, scenario);
    
    expect(result.nodeStates['cuisiner'], B3State.failed);
    expect(recs.any((r) => r.capabilityId == 'cuisiner' && r.targetAssetId == 'rechaud_gaz'), true);
  });

  test('TEST 2 — Pas de recommandation d achat inutile', () {
    final household = HouseholdConfig(
      ownedAssets: ['plaque_elec', 'rechaud_gaz'],
      assessedCapabilities: {'cuisiner'}
    );
    final graph = DataMapper.buildGraph(b3KnowledgeBase, household);
    final result = B3Engine().runSimulation(graph, scenario);
    
    final recs = recEngine.generate(result, household, scenario);
    
    expect(result.nodeStates['cuisiner'], B3State.maintained);
    expect(recs.any((r) => r.capabilityId == 'cuisiner'), false);
  });

  test('TEST 3 — Fausse redondance', () {
    final household = HouseholdConfig(
      ownedAssets: ['plaque_elec', 'four_elec'],
      assessedCapabilities: {'cuisiner'}
    );
    final graph = DataMapper.buildGraph(b3KnowledgeBase, household);
    final result = B3Engine().runSimulation(graph, scenario);
    
    final recs = recEngine.generate(result, household, scenario);
    
    expect(result.nodeStates['cuisiner'], B3State.failed);
    expect(recs.any((r) => r.capabilityId == 'cuisiner' && r.targetAssetId == 'rechaud_gaz'), true);
    expect(recs.any((r) => r.type == RecommendationType.createAlternative && r.targetAssetId == 'four_elec'), false);
  });

  test('TEST 4 & 5 — Incertitude et NOT_ASSESSED', () {
    final household = HouseholdConfig(ownedAssets: []);
    final graph = DataMapper.buildGraph(b3KnowledgeBase, household);
    final result = B3Engine().runSimulation(graph, scenario);
    
    final recs = recEngine.generate(result, household, scenario);
    
    expect(recs.where((r) => r.type == RecommendationType.verify).length, 6);
    expect(recs.any((r) => r.type == RecommendationType.createAlternative), false);
  });

  test('TEST 6 — Explication (Traceability)', () {
    final household = HouseholdConfig(
      ownedAssets: ['plaque_elec'],
      assessedCapabilities: {'cuisiner'}
    );
    final result = B3Engine().runSimulation(DataMapper.buildGraph(b3KnowledgeBase, household), scenario);
    final recs = recEngine.generate(result, household, scenario);
    
    final rec = recs.firstWhere((r) => r.targetAssetId == 'rechaud_gaz');
    
    expect(rec.reason.contains('plaque_elec'), true);
    expect(rec.reason.contains('indépendante des systèmes affectés'), true);
  });

  test('TEST 7 — Non-invention', () {
    final household = HouseholdConfig(
      ownedAssets: ['plaque_elec'],
      assessedCapabilities: {'cuisiner'}
    );
    final result = B3Engine().runSimulation(DataMapper.buildGraph(b3KnowledgeBase, household), scenario);
    final recs = recEngine.generate(result, household, scenario);
    
    final validTargets = ['rechaud_gaz', 'rechaud_bois'];
    for (var r in recs.where((r) => r.capabilityId == 'cuisiner' && r.type == RecommendationType.createAlternative)) {
      expect(validTargets.contains(r.targetAssetId), true);
    }
  });

  test('TEST 8 — Plusieurs alternatives', () {
    final household = HouseholdConfig(
      ownedAssets: ['plaque_elec'],
      assessedCapabilities: {'cuisiner'}
    );
    final result = B3Engine().runSimulation(DataMapper.buildGraph(b3KnowledgeBase, household), scenario);
    final recs = recEngine.generate(result, household, scenario);
    
    expect(recs.any((r) => r.targetAssetId == 'rechaud_gaz'), true);
    expect(recs.any((r) => r.targetAssetId == 'rechaud_bois'), true);
  });

  test('TEST 9 — Solution déjà possédée (Resource Exhausted)', () {
    final household = HouseholdConfig(
      ownedAssets: ['rechaud_bois'],
      resourceDurations: {'bois': Duration(hours: 12)}, // 12h de bois
      assessedCapabilities: {'cuisiner'}
    );
    final graph = DataMapper.buildGraph(b3KnowledgeBase, household);
    final result = B3Engine().runSimulation(graph, scenario);
    
    expect(result.nodeStates['cuisiner'], B3State.degraded);
    
    final recs = recEngine.generate(result, household, scenario);
    
    final rec = recs.firstWhere((r) => r.targetAssetId == 'rechaud_bois');
    expect(rec.type, RecommendationType.organize); 
    expect(rec.reason.contains('Ressource épuisée'), true);
  });

  test('TEST 10 — Déterminisme', () {
    final household = HouseholdConfig(
      ownedAssets: ['plaque_elec'],
      assessedCapabilities: {'cuisiner'}
    );
    final result = B3Engine().runSimulation(DataMapper.buildGraph(b3KnowledgeBase, household), scenario);
    final recs1 = recEngine.generate(result, household, scenario);
    final recs2 = recEngine.generate(result, household, scenario);
    
    expect(recs1.length, recs2.length);
    for (int i = 0; i < recs1.length; i++) {
      expect(recs1[i].id, recs2[i].id);
    }
  });
}
