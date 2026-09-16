import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:b3_app/features/action_plan/action_plan_builder.dart';
import 'package:b3_app/features/action_plan/models/action_plan.dart';
import 'package:b3_engine/b3_engine.dart';

void main() {
  final Map<String, dynamic> mockKnowledgeBase = {
    'capabilities': [],
    'assets': [],
    'resources': [],
    'systems': [],
  };

  test('TEST A — Bois UNKNOWN -> VERIFY bois', () {
    final builder = ActionPlanBuilder(jsonEncode(mockKnowledgeBase));
    final rec = Recommendation(
      id: 'r1', type: RecommendationType.verify, priority: RecommendationPriority.high,
      capabilityId: 'chauffer', title: 'T', description: 'Vous ne connaissez pas encore la quantité disponible.', reason: 'R', targetResourceId: 'bois'
    );
    final result = SimulationResult({'chauffer': B3State.unknown}, {}, [], []);
    final plan = builder.build([rec], result);
    expect(plan.items.length, 1);
    expect(plan.items.first.priority, ActionPriority.toVerify);
    expect(plan.items.first.type, RecommendationType.verify);
  });

  test('TEST B — Chauffage électrique seul + panne électrique -> CREATE_ALTERNATIVE', () {
    final builder = ActionPlanBuilder(jsonEncode(mockKnowledgeBase));
    final rec = Recommendation(
      id: 'r1', type: RecommendationType.createAlternative, priority: RecommendationPriority.high,
      capabilityId: 'chauffer', title: 'T', description: 'D', reason: 'R', targetAssetId: 'poele'
    );
    final result = SimulationResult({'chauffer': B3State.failed}, {}, [], []);
    final plan = builder.build([rec], result);
    expect(plan.items.length, 1);
    expect(plan.items.first.priority, ActionPriority.essential);
    expect(plan.items.first.type, RecommendationType.createAlternative);
  });

  test('TEST C — Alternative suffisante -> pas d\'action critique inutile', () {
    final builder = ActionPlanBuilder(jsonEncode(mockKnowledgeBase));
    final rec = Recommendation(
      id: 'r1', type: RecommendationType.useExisting, priority: RecommendationPriority.low,
      capabilityId: 'chauffer', title: 'T', description: 'D', reason: 'R'
    );
    final result = SimulationResult({'chauffer': B3State.maintained}, {}, [], []);
    final plan = builder.build([rec], result);
    expect(plan.items.length, 1);
    expect(plan.items.first.priority, ActionPriority.improvement);
  });

  test('TEST D — Alternative limitée -> action sur autonomie/ressource', () {
    final builder = ActionPlanBuilder(jsonEncode(mockKnowledgeBase));
    final rec = Recommendation(
      id: 'r1', type: RecommendationType.organize, priority: RecommendationPriority.medium,
      capabilityId: 'chauffer', title: 'T', description: 'D', reason: 'R', targetResourceId: 'bois'
    );
    final result = SimulationResult({'chauffer': B3State.degraded}, {}, [], []);
    final plan = builder.build([rec], result);
    expect(plan.items.length, 1);
    expect(plan.items.first.priority, ActionPriority.important);
    expect(plan.items.first.type, RecommendationType.organize);
  });

  test('TEST E — Fausse redondance -> vulnérabilité réelle', () {
    final builder = ActionPlanBuilder(jsonEncode(mockKnowledgeBase));
    final rec = Recommendation(
      id: 'r1', type: RecommendationType.createAlternative, priority: RecommendationPriority.high,
      capabilityId: 'chauffer', title: 'T', description: 'D', reason: 'R', targetAssetId: 'poele_bois'
    );
    final result = SimulationResult({'chauffer': B3State.failed}, {}, [], []);
    final plan = builder.build([rec], result);
    expect(plan.items.length, 1);
    expect(plan.items.first.priority, ActionPriority.essential);
  });

  test('TEST F — Ressource UNKNOWN -> VERIFY avec formulation UNKNOWN', () {
    final builder = ActionPlanBuilder(jsonEncode(mockKnowledgeBase));
    final rec = Recommendation(
      id: 'r1', type: RecommendationType.verify, priority: RecommendationPriority.high,
      capabilityId: 'chauffer', title: 'T', description: 'Vous ne connaissez pas encore la quantité disponible.', reason: 'R', targetResourceId: 'bois'
    );
    final result = SimulationResult({'chauffer': B3State.unknown}, {}, [], []);
    final plan = builder.build([rec], result);
    expect(plan.items.length, 1);
    expect(plan.items.first.description, 'Vous ne connaissez pas encore la quantité disponible.');
    expect(plan.items.first.priority, ActionPriority.toVerify);
  });

  test('TEST G — Ressource NOT_ASSESSED -> VERIFY avec formulation NOT_ASSESSED', () {
    final builder = ActionPlanBuilder(jsonEncode(mockKnowledgeBase));
    final rec = Recommendation(
      id: 'r1', type: RecommendationType.verify, priority: RecommendationPriority.high,
      capabilityId: 'chauffer', title: 'T', description: 'Cette information n\'a pas encore été vérifiée.', reason: 'R', targetResourceId: 'bois'
    );
    final result = SimulationResult({'chauffer': B3State.notAssessed}, {}, [], []);
    final plan = builder.build([rec], result);
    expect(plan.items.length, 1);
    expect(plan.items.first.description, 'Cette information n\'a pas encore été vérifiée.');
    expect(plan.items.first.priority, ActionPriority.toVerify);
  });

  test('TEST H — Dédoublonnage', () {
    final builder = ActionPlanBuilder(jsonEncode(mockKnowledgeBase));
    final rec1 = Recommendation(
      id: 'r1', type: RecommendationType.verify, priority: RecommendationPriority.high,
      capabilityId: 'chauffer', title: 'T', description: 'D', reason: 'R', targetResourceId: 'bois'
    );
    final rec2 = Recommendation(
      id: 'r2', type: RecommendationType.verify, priority: RecommendationPriority.high,
      capabilityId: 'cuisiner', title: 'T', description: 'D', reason: 'R', targetResourceId: 'bois'
    );
    final result = SimulationResult({'chauffer': B3State.unknown, 'cuisiner': B3State.unknown}, {}, [], []);
    final plan = builder.build([rec1, rec2], result);
    expect(plan.items.length, 1);
    expect(plan.items.first.capabilityIds.length, 2);
  });

  test('TEST I — Déterminisme', () {
    final builder = ActionPlanBuilder(jsonEncode(mockKnowledgeBase));
    final rec1 = Recommendation(
      id: 'r1', type: RecommendationType.createAlternative, priority: RecommendationPriority.high,
      capabilityId: 'chauffer', title: 'T1', description: 'D', reason: 'R', targetAssetId: 'a1'
    );
    final rec2 = Recommendation(
      id: 'r2', type: RecommendationType.verify, priority: RecommendationPriority.high,
      capabilityId: 'cuisiner', title: 'T2', description: 'D', reason: 'R', targetResourceId: 'res2'
    );
    final result = SimulationResult({'chauffer': B3State.failed, 'cuisiner': B3State.unknown}, {}, [], []);
    
    final plan1 = builder.build([rec1, rec2], result);
    final plan2 = builder.build([rec2, rec1], result);
    
    expect(plan1.items.first.id, plan2.items.first.id);
  });

  test('TEST J — Anti-invention', () {
    final builder = ActionPlanBuilder(jsonEncode(mockKnowledgeBase));
    final rec = Recommendation(
      id: 'r1', type: RecommendationType.verify, priority: RecommendationPriority.high,
      capabilityId: 'chauffer', title: 'T', description: 'D', reason: 'R'
    );
    final result = SimulationResult({'chauffer': B3State.unknown}, {}, [], []);
    final plan = builder.build([rec], result);
    expect(plan.items.length, 1);
    expect(plan.items.first.type, RecommendationType.verify);
    expect(plan.items.first.priority, ActionPriority.toVerify);
  });

  test('TEST K — Cause partagée', () {
    final builder = ActionPlanBuilder(jsonEncode(mockKnowledgeBase));
    final rec1 = Recommendation(
      id: 'r1', type: RecommendationType.verify, priority: RecommendationPriority.high,
      capabilityId: 'capA', title: 'T', description: 'D', reason: 'R', targetResourceId: 'cause1'
    );
    final rec2 = Recommendation(
      id: 'r2', type: RecommendationType.verify, priority: RecommendationPriority.high,
      capabilityId: 'capB', title: 'T', description: 'D', reason: 'R', targetResourceId: 'cause1'
    );
    final rec3 = Recommendation(
      id: 'r3', type: RecommendationType.verify, priority: RecommendationPriority.high,
      capabilityId: 'capC', title: 'T', description: 'D', reason: 'R', targetResourceId: 'cause2'
    );
    final result = SimulationResult({'capA': B3State.unknown, 'capB': B3State.unknown, 'capC': B3State.unknown}, {}, [], []);
    
    final plan = builder.build([rec1, rec2, rec3], result);
    expect(plan.items.length, 2);
    // L'item pour cause1 doit être premier car il impacte 2 capacités
    expect(plan.items.first.capabilityIds.contains('capA'), true);
    expect(plan.items.first.capabilityIds.contains('capB'), true);
  });

  test('TEST L — VERIFY avant achat UNIQUEMENT lorsque le VERIFY est un prérequis de cette même décision.', () {
    // Both concern "chauffer". Since both belong to same capability and thus same capability state,
    // they get the same Priority logic?
    // Wait, if chauffer is FAILED, both get ActionPriority.essential.
    // In this case, VERIFY comes before ACQUIRE due to the hierarchy enum!
    final builder = ActionPlanBuilder(jsonEncode(mockKnowledgeBase));
    final recVerify = Recommendation(
      id: 'r_ver', type: RecommendationType.verify, priority: RecommendationPriority.high,
      capabilityId: 'chauffer', title: 'Vérifier bois', description: 'D', reason: 'R', targetResourceId: 'bois'
    );
    final recAcquire = Recommendation(
      id: 'r_acq', type: RecommendationType.acquire, priority: RecommendationPriority.high,
      capabilityId: 'chauffer', title: 'Acheter bois', description: 'D', reason: 'R', targetResourceId: 'bois'
    );
    final result = SimulationResult({'chauffer': B3State.failed}, {}, [], []);
    
    final plan = builder.build([recAcquire, recVerify], result);
    expect(plan.items.first.type, RecommendationType.verify);
    expect(plan.items.last.type, RecommendationType.acquire);
  });

  test('TEST L-BIS — VERIFY indépendant ne masque pas FAILED critique', () {
    // VERIFY on CapA (UNKNOWN), ACQUIRE on CapB (FAILED)
    final builder = ActionPlanBuilder(jsonEncode(mockKnowledgeBase));
    final recVerify = Recommendation(
      id: 'r_ver', type: RecommendationType.verify, priority: RecommendationPriority.high,
      capabilityId: 'capA', title: 'Vérifier A', description: 'D', reason: 'R'
    );
    final recAcquire = Recommendation(
      id: 'r_acq', type: RecommendationType.acquire, priority: RecommendationPriority.high,
      capabilityId: 'capB', title: 'Acheter B', description: 'D', reason: 'R'
    );
    final result = SimulationResult({'capA': B3State.unknown, 'capB': B3State.failed}, {}, [], []);
    
    final plan = builder.build([recVerify, recAcquire], result);
    // CapB FAILED -> ActionPriority.essential
    // CapA UNKNOWN -> ActionPriority.toVerify
    // Essential must precede toVerify.
    expect(plan.items.first.type, RecommendationType.acquire);
    expect(plan.items.first.priority, ActionPriority.essential);
    expect(plan.items.last.type, RecommendationType.verify);
  });
}
