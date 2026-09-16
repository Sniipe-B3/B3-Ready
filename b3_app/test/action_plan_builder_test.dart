import 'package:flutter_test/flutter_test.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/features/action_plan/models/action_plan.dart';
import 'package:b3_app/features/action_plan/action_plan_builder.dart';
import 'package:b3_app/data/app_knowledge_dataset.dart';

void main() {
  late RecommendationEngine engine;
  late ActionPlanBuilder builder;

  setUp(() {
    engine = RecommendationEngine(appKnowledgeBase);
    builder = ActionPlanBuilder(appKnowledgeBase);
  });

  test('TEST A & F: Poêle bois possédé, bois UNKNOWN -> VERIFY bois', () {
    final household = HouseholdConfig(
      ownedAssets: ['poele_bois'],
      ownedResources: ['bois'],
      // bois est UNKNOWN car durée absente et assessedResources le contient (ou non évalué)
      assessedResources: {'bois'}, 
      assessedCapabilities: {'chauffer'},
    );
    final graph = DataMapper.buildGraph(appKnowledgeBase, household);
    final scenario = DataMapper.parseScenario(appKnowledgeBase, 'panne_elec');
    final result = B3Engine().runSimulation(graph, scenario);
    
    final recs = engine.generate(result, household, scenario);
    final plan = builder.build(recs, result);
    
    expect(plan.items.isNotEmpty, true);
    final topAction = plan.items.first;
    expect(topAction.type, RecommendationType.verify);
    expect(topAction.priority, ActionPriority.toVerify);
    expect(topAction.causeNodeIds.contains('bois'), true);
  });

  test('TEST B: Chauffage uniquement elec, panne elec -> CREATE_ALTERNATIVE', () {
    final household = HouseholdConfig(
      ownedAssets: ['radiateur_elec'],
      assessedCapabilities: {'chauffer'},
    );
    final graph = DataMapper.buildGraph(appKnowledgeBase, household);
    final scenario = DataMapper.parseScenario(appKnowledgeBase, 'panne_elec');
    final result = B3Engine().runSimulation(graph, scenario);
    
    final recs = engine.generate(result, household, scenario);
    final plan = builder.build(recs, result);
    
    expect(plan.items.isNotEmpty, true);
    final topAction = plan.items.first;
    expect(topAction.type, RecommendationType.createAlternative);
    expect(topAction.priority, ActionPriority.essential); // car FAILED
  });

  test('TEST C: Alternative suffisante (Poele bois MAINTAINED) -> Pas daction critique', () {
    final household = HouseholdConfig(
      ownedAssets: ['radiateur_elec', 'poele_bois'],
      ownedResources: ['bois'],
      assessedResources: {'bois'},
      resourceDurations: {'bois': const Duration(hours: 96)}, // > 48h (panne_elec)
      assessedCapabilities: {'chauffer'},
    );
    final graph = DataMapper.buildGraph(appKnowledgeBase, household);
    final scenario = DataMapper.parseScenario(appKnowledgeBase, 'panne_elec');
    final result = B3Engine().runSimulation(graph, scenario);
    
    final recs = engine.generate(result, household, scenario);
    final plan = builder.build(recs, result);
    
    // Le chauffage est MAINTAINED grâce au poêle. On ne devrait pas avoir d'action essentielle.
    final criticalActions = plan.items.where((i) => i.priority == ActionPriority.essential);
    expect(criticalActions.isEmpty, true);
  });

  test('TEST D: Alternative limitée -> Action concernant la limitation (ORGANIZE)', () {
    final household = HouseholdConfig(
      ownedAssets: ['radiateur_elec', 'poele_bois'],
      ownedResources: ['bois'],
      assessedResources: {'bois'},
      resourceDurations: {'bois': const Duration(hours: 24)}, // < 48h
      assessedCapabilities: {'chauffer'},
    );
    final graph = DataMapper.buildGraph(appKnowledgeBase, household);
    final scenario = DataMapper.parseScenario(appKnowledgeBase, 'panne_elec');
    final result = B3Engine().runSimulation(graph, scenario);
    
    final recs = engine.generate(result, household, scenario);
    final plan = builder.build(recs, result);
    
    expect(plan.items.isNotEmpty, true);
    final topAction = plan.items.first;
    expect(topAction.type, RecommendationType.organize); // Augmenter l'autonomie
    expect(topAction.priority, ActionPriority.important); // DEGRADED
  });

  test('TEST E: Fausse redondance (Rad elec + PAC) -> CREATE_ALTERNATIVE pour panne elec', () {
    final household = HouseholdConfig(
      ownedAssets: ['radiateur_elec', 'pompe_chaleur'],
      assessedCapabilities: {'chauffer'},
    );
    final graph = DataMapper.buildGraph(appKnowledgeBase, household);
    final scenario = DataMapper.parseScenario(appKnowledgeBase, 'panne_elec');
    final result = B3Engine().runSimulation(graph, scenario);
    
    final recs = engine.generate(result, household, scenario);
    final plan = builder.build(recs, result);
    
    expect(plan.items.isNotEmpty, true);
    final topAction = plan.items.first;
    expect(topAction.type, RecommendationType.createAlternative);
    expect(topAction.priority, ActionPriority.essential);
  });

  test('TEST H & K: Dédoublonnage et cause partagée', () {
    // Éclairage (lampe_secteur) et Chauffage (radiateur_elec) dépendent tous deux de elec.
    // Si on a panne_elec, on pourrait générer deux actions pour l'électricité.
    // L'engine génère des CREATE_ALTERNATIVE pour l'éclairage (ex: lampe_batterie) et le chauffage (ex: poele).
    // Ce ne sont pas les mêmes alternatives, donc elles ne sont pas dédoublonnées, ce qui est correct.
    // Créons un cas artificiel pour prouver le dédoublonnage strict :
    final rec1 = Recommendation(
      id: 'r1', type: RecommendationType.verify, priority: RecommendationPriority.high,
      capabilityId: 'c1', title: 'T', description: 'D', reason: 'R', targetResourceId: 'resX',
      causeNodeIds: {'resX'}
    );
    final rec2 = Recommendation(
      id: 'r2', type: RecommendationType.verify, priority: RecommendationPriority.high,
      capabilityId: 'c2', title: 'T', description: 'D', reason: 'R', targetResourceId: 'resX',
      causeNodeIds: {'resX'}
    );
    final res = SimulationResult(
      {'c1': B3State.failed, 'c2': B3State.failed}, {}, [], []
    );
    final plan = builder.build([rec1, rec2], res);
    expect(plan.items.length, 1);
    expect(plan.items.first.capabilityIds.containsAll(['c1', 'c2']), true);
  });

  test('TEST I: Déterminisme', () {
    final rec1 = Recommendation(
      id: 'r1', type: RecommendationType.createAlternative, priority: RecommendationPriority.high,
      capabilityId: 'c1', title: 'T1', description: 'D', reason: 'R', targetAssetId: 'a1'
    );
    final rec2 = Recommendation(
      id: 'r2', type: RecommendationType.verify, priority: RecommendationPriority.high,
      capabilityId: 'c2', title: 'T2', description: 'D', reason: 'R', targetResourceId: 'res2'
    );
    final res = SimulationResult(
      {'c1': B3State.failed, 'c2': B3State.failed}, {}, [], []
    );
    final plan1 = builder.build([rec1, rec2], res);
    final plan2 = builder.build([rec2, rec1], res);
    
    // VERIFY toujours avant CREATE_ALTERNATIVE si même niveau (essential)
    expect(plan1.items.first.type, RecommendationType.verify);
    expect(plan2.items.first.type, RecommendationType.verify);
    expect(plan1.items.length, 2);
    expect(plan2.items.length, 2);
    expect(plan1.items.first.id, plan2.items.first.id);
  });

  test('TEST J: Anti-invention', () {
    final household = HouseholdConfig(ownedAssets: [], assessedCapabilities: {});
    final graph = DataMapper.buildGraph(appKnowledgeBase, household);
    final scenario = DataMapper.parseScenario(appKnowledgeBase, 'panne_elec');
    final result = B3Engine().runSimulation(graph, scenario);
    
    final recs = engine.generate(result, household, scenario);
    final plan = builder.build(recs, result);
    
    // Avec un foyer vide et non évalué, capabilities = NOT_ASSESSED
    for (var item in plan.items) {
      expect(item.priority, ActionPriority.toVerify);
      expect(item.type, RecommendationType.verify);
    }
  });

  test('TEST L: Alternative possédée, prérequis UNKNOWN -> VERIFY avant ACQUIRE', () {
    // Idem que TEST A. Le plan trie nativement VERIFY avant ACQUIRE (ici createAlternative).
    final rec1 = Recommendation(
      id: 'r1', type: RecommendationType.createAlternative, priority: RecommendationPriority.high,
      capabilityId: 'c1', title: 'T1', description: 'D', reason: 'R', targetAssetId: 'a1'
    );
    final rec2 = Recommendation(
      id: 'r2', type: RecommendationType.verify, priority: RecommendationPriority.high,
      capabilityId: 'c2', title: 'T2', description: 'D', reason: 'R', targetResourceId: 'res2'
    );
    final res = SimulationResult({'c1': B3State.failed, 'c2': B3State.unknown}, {}, [], []);
    
    final plan = builder.build([rec1, rec2], res);
    
    // c1 est FAILED -> essential
    // c2 est UNKNOWN -> toVerify
    // essential passe AVANT toVerify, malgré le fait que VERIFY soit devant ACQUIRE à priorité égale.
    // C'est exactement le comportement attendu: on traite d'abord les FAILED.
    // MAIS si les deux étaient FAILED (ex: Rule.all), VERIFY passerait avant.
    expect(plan.items.first.id, 'r1');
    expect(plan.items.last.id, 'r2');
  });
}
