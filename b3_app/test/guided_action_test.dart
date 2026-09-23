import 'package:flutter_test/flutter_test.dart';
import 'package:b3_app/features/action_plan/models/action_plan.dart';
import 'package:b3_app/features/action_plan/services/guided_action_mapper.dart';
import 'package:b3_app/features/action_plan/models/guided_action_details.dart';
import 'package:b3_app/data/app_knowledge_dataset.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/features/progression/models/resilience_session.dart';
import 'package:b3_app/features/progression/utils/action_update_resolver.dart';
import 'package:b3_app/features/progression/models/household_update.dart';

void main() {
  group('GUIDED ACTION TESTS', () {
    test('TEST A - VERIFY WATER', () {
      final config = HouseholdConfig(
        ownedAssets: ['stock_eau_potable'],
        unknownResources: {'reserve_eau_potable'},
      );
      final session = ResilienceSession(
        knowledgeJson: appKnowledgeBase,
        scenarioId: 'coupure_eau',
        initialConfig: config,
      );
      
      final items = session.actionPlan?.items ?? [];
      final item = items.firstWhere((i) => i.targetAssetId == 'stock_eau_potable');
      
      final mapper = GuidedActionMapper(appKnowledgeBase);
      final details = mapper.map(item, 'coupure_eau');
      
      expect(item.type, RecommendationType.verify);
      expect(details.why.contains('autonomie'), isTrue);
      expect(details.ctaLabel, 'Vérifier maintenant');
    });

    test('TEST B - PAYMENT ALTERNATIVE', () {
      final config = HouseholdConfig(
        ownedAssets: ['paiement_electronique'],
        assessedCapabilities: {'effectuer_paiement_essentiel'}
      );
      final session = ResilienceSession(
        knowledgeJson: appKnowledgeBase,
        scenarioId: 'panne_paiement',
        initialConfig: config,
      );
      
      final items = session.actionPlan?.items ?? [];
      final item = items.firstWhere((i) => i.capabilityIds.contains('effectuer_paiement_essentiel'));
      
      final mapper = GuidedActionMapper(appKnowledgeBase);
      final details = mapper.map(item, 'panne_paiement');
      
      expect(details.todo.contains('espèces'), isTrue);
    });

    test('TEST C - NO INVENTION', () {
      final config = HouseholdConfig(ownedAssets: []);
      final session = ResilienceSession(
        knowledgeJson: appKnowledgeBase,
        scenarioId: 'coupure_eau',
        initialConfig: config,
      );
      
      final copyBefore = session.config.clone();
      
      final items = session.actionPlan?.items ?? [];
      final mapper = GuidedActionMapper(appKnowledgeBase);
      mapper.map(items.first, 'coupure_eau');
      
      expect(session.config.ownedAssets, copyBefore.ownedAssets);
      expect(session.config.ownedResources, copyBefore.ownedResources);
      expect(session.config.assessedResources, copyBefore.assessedResources);
      expect(session.config.unknownResources, copyBefore.unknownResources);
      expect(session.config.resourceDurations, copyBefore.resourceDurations);
      expect(session.config.assessedCapabilities, copyBefore.assessedCapabilities);
    });

    test('TEST D - COMPLETION', () {
      final config = HouseholdConfig(ownedAssets: []);
      final session = ResilienceSession(
        knowledgeJson: appKnowledgeBase,
        scenarioId: 'coupure_eau',
        initialConfig: config,
      );
      
      final copyBefore = session.config.clone();
      
      final item = session.actionPlan!.items.first;
      final update = ActionUpdateResolver.resolveActionCompleted(item);
      final result = session.recalculate(update);
      
      expect(session.completedActionIds.contains(item.id), isTrue);
      
      expect(result.afterConfig.ownedAssets, copyBefore.ownedAssets);
      expect(result.afterConfig.ownedResources, copyBefore.ownedResources);
      expect(result.afterConfig.assessedResources, copyBefore.assessedResources);
      expect(result.afterConfig.unknownResources, copyBefore.unknownResources);
      expect(result.afterConfig.resourceDurations, copyBefore.resourceDurations);
      expect(result.afterConfig.assessedCapabilities, copyBefore.assessedCapabilities);
      expect(result.afterConfig.capabilityOverrides, copyBefore.capabilityOverrides);
    });

    test('TEST E - STRUCTURAL UPDATE', () {
      final config = HouseholdConfig(ownedAssets: ['radiateur_elec'], assessedCapabilities: {'chauffer'});
      final session = ResilienceSession(
        knowledgeJson: appKnowledgeBase,
        scenarioId: 'panne_elec',
        initialConfig: config,
      );
      
      final item = session.actionPlan!.items.firstWhere((i) => i.targetAssetId == 'poele_bois' && i.type == RecommendationType.createAlternative);
      final update = ActionUpdateResolver.resolveAssetUpdate(item, true);
      final newResult = session.recalculate(update);
      
      expect(newResult.afterConfig.ownedAssets.contains('poele_bois'), isTrue);
      final hasAction = newResult.afterPlan?.items.any((i) => i.targetAssetId == 'poele_bois' && i.type == RecommendationType.createAlternative) ?? false;
      expect(hasAction, isFalse);
    });

    test('TEST F - CAUSAL EXPLANATION', () {
      final config = HouseholdConfig(ownedAssets: ['radiateur_elec'], assessedCapabilities: {'chauffer'});
      final session = ResilienceSession(
        knowledgeJson: appKnowledgeBase,
        scenarioId: 'panne_elec',
        initialConfig: config,
      );
      
      final item = session.actionPlan!.items.firstWhere((i) => i.capabilityIds.contains('chauffer'));
      final mapper = GuidedActionMapper(appKnowledgeBase);
      final details = mapper.map(item, 'panne_elec');
      
      expect(details.observed, 'Chauffer le logement → Réseau Électrique → Panne électrique prolongée');
    });

    test('TEST G - DETERMINISM', () {
      final config = HouseholdConfig(ownedAssets: []);
      final session = ResilienceSession(
        knowledgeJson: appKnowledgeBase,
        scenarioId: 'coupure_eau',
        initialConfig: config,
      );
      
      final item = session.actionPlan!.items.first;
      final mapper1 = GuidedActionMapper(appKnowledgeBase);
      final mapper2 = GuidedActionMapper(appKnowledgeBase);
      
      final d1 = mapper1.map(item, 'coupure_eau');
      final d2 = mapper2.map(item, 'coupure_eau');
      
      expect(d1.title, d2.title);
      expect(d1.why, d2.why);
      expect(d1.observed, d2.observed);
      expect(d1.todo, d2.todo);
      expect(d1.ctaLabel, d2.ctaLabel);
      expect(d1.item.id, d2.item.id);
    });

    test('TEST H - OFFLINE', () {
      final config = HouseholdConfig(ownedAssets: []);
      final session = ResilienceSession(
        knowledgeJson: appKnowledgeBase,
        scenarioId: 'coupure_eau',
        initialConfig: config,
      );
      
      final item = session.actionPlan!.items.first;
      final mapper = GuidedActionMapper(appKnowledgeBase);
      
      final details = mapper.map(item, 'coupure_eau');
      expect(details, isNotNull);
    });

    test('TEST J - 7 TYPES CTA EXPECTATIONS', () {
      final mapper = GuidedActionMapper(appKnowledgeBase);
      
      
      GuidedActionDetails mapType(RecommendationType type) => mapper.map(
        ActionPlanItem(id: 'dummy', title: 'title', description: 'desc', reason: 'reason', type: type, priority: ActionPriority.essential, capabilityIds: {}), 
        null
      );
      
      expect(mapType(RecommendationType.verify).ctaLabel, 'Vérifier maintenant');
      expect(mapType(RecommendationType.useExisting).ctaLabel, 'Configurer cette solution');
      expect(mapType(RecommendationType.organize).ctaLabel, 'Marquer comme organisé');
      expect(mapType(RecommendationType.learn).ctaLabel, 'Marquer comme appris');
      expect(mapType(RecommendationType.createAlternative).ctaLabel, 'Voir mes options');
      expect(mapType(RecommendationType.acquire).ctaLabel, "J'ai ajouté cette solution");
      expect(mapType(RecommendationType.invest).ctaLabel, 'Explorer cette amélioration');
      
      for (var type in RecommendationType.values) {
         final res = mapType(type);
         expect(res.todo.isNotEmpty, isTrue);
         expect(res.why.isNotEmpty, isTrue);
      }
    });
    
    test('TEST I - NO ACTION', () {
      final config = HouseholdConfig(
        ownedAssets: ['poele_bois', 'stock_eau_potable'],
        assessedCapabilities: {'chauffer', 'boire_eau_potable'}
      ); 
      final session = ResilienceSession(
        knowledgeJson: appKnowledgeBase,
        scenarioId: 'panne_gaz',
        initialConfig: config,
      );
      
      final items = session.actionPlan?.items ?? [];
      final hasPriorityAction = items.any((i) => i.priority == ActionPriority.essential);
      
      expect(hasPriorityAction, isFalse);
    });
    test('TEST K - CTA BEHAVIOR FOR ORGANIZE AND LEARN', () {
      final itemOrganize = ActionPlanItem(id: 'org', title: 'org', description: 'org', reason: 'org', type: RecommendationType.organize, priority: ActionPriority.essential, capabilityIds: {});
      final itemLearn = ActionPlanItem(id: 'lrn', title: 'lrn', description: 'lrn', reason: 'lrn', type: RecommendationType.learn, priority: ActionPriority.essential, capabilityIds: {});
      
      final updateOrg = ActionUpdateResolver.resolveActionCompleted(itemOrganize);
      final updateLrn = ActionUpdateResolver.resolveActionCompleted(itemLearn);
      
      expect(updateOrg is ActionCompletedUpdate, isTrue);
      expect(updateLrn is ActionCompletedUpdate, isTrue);
    });
  });
}
