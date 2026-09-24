
import 'package:b3_app/features/action_plan/global_action_plan_builder.dart';
import 'package:b3_app/features/scenarios/services/multi_scenario_analyzer.dart';
import 'package:b3_app/data/app_knowledge_dataset.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/features/action_plan/models/action_plan.dart';
import 'package:b3_app/features/action_plan/roadmap_builder.dart';






void main() {
  group('RoadmapBuilder Tests', () {
    test('TEST A — BASIC STAGING', () {
      final builder = PreparednessRoadmapBuilder();
      final plan = ActionPlan([
        ActionPlanItem(id: 'acq_top', type: RecommendationType.acquire, priority: ActionPriority.essential, capabilityIds: {'c1'}, title: '', description: '', reason: '', targetAssetId: 'a1'),
        ActionPlanItem(id: 'acq_important', type: RecommendationType.acquire, priority: ActionPriority.important, capabilityIds: {'c2'}, title: '', description: '', reason: '', targetAssetId: 'a2'),
        ActionPlanItem(id: 'acq_later', type: RecommendationType.acquire, priority: ActionPriority.improvement, capabilityIds: {'c3'}, title: '', description: '', reason: '', targetAssetId: 'a3'),
      ]);
      
      final roadmap = builder.build(plan, []);
      
      expect(roadmap.now.length, 1);
      expect(roadmap.now.first.item.id, 'acq_top');
      
      expect(roadmap.next.length, 1);
      expect(roadmap.next.first.item.id, 'acq_important');
      
      expect(roadmap.later.length, 1);
      expect(roadmap.later.first.item.id, 'acq_later');
    });

    test('TEST B — VERIFY DEFERS PURCHASE', () {
      final builder = PreparednessRoadmapBuilder();
      final plan = ActionPlan([
        ActionPlanItem(id: 'ver_bat', type: RecommendationType.verify, priority: ActionPriority.toVerify, capabilityIds: {'c1'}, title: '', description: '', reason: '', targetAssetId: 'bat', priorityReasons: [PriorityReason(PriorityReasonType.blocksPurchaseDecision, '')]),
        // Even if the acquire is essential!
        ActionPlanItem(id: 'acq_bat', type: RecommendationType.acquire, priority: ActionPriority.essential, capabilityIds: {'c1'}, title: '', description: '', reason: '', targetAssetId: 'bat'),
      ]);
      
      final roadmap = builder.build(plan, []);
      
      expect(roadmap.now.length, 1);
      expect(roadmap.now.first.item.id, 'ver_bat');
      
      expect(roadmap.next.length, 1);
      expect(roadmap.next.first.item.id, 'acq_bat');
      expect(roadmap.next.first.deferredByItemIds, ['ver_bat']);
    });

    test('TEST C — EXISTING DEFERS PURCHASE', () {
      final builder = PreparednessRoadmapBuilder();
      final plan = ActionPlan([
        ActionPlanItem(id: 'use_bat', type: RecommendationType.useExisting, priority: ActionPriority.important, capabilityIds: {'c1'}, title: '', description: '', reason: '', targetAssetId: 'bat', priorityReasons: [PriorityReason(PriorityReasonType.usesExistingSolution, '')]),
        ActionPlanItem(id: 'acq_bat', type: RecommendationType.acquire, priority: ActionPriority.essential, capabilityIds: {'c1'}, title: '', description: '', reason: '', targetAssetId: 'bat'),
      ]);
      
      final roadmap = builder.build(plan, []);
      
      expect(roadmap.now.length, 1);
      expect(roadmap.now.first.item.id, 'use_bat');
      
      expect(roadmap.next.length, 1);
      expect(roadmap.next.first.item.id, 'acq_bat');
      expect(roadmap.next.first.deferredByItemIds, ['use_bat']);
    });

    test('TEST D — DIFFERENT TARGET', () {
      final builder = PreparednessRoadmapBuilder();
      final plan = ActionPlan([
        ActionPlanItem(id: 'ver_a', type: RecommendationType.verify, priority: ActionPriority.toVerify, capabilityIds: {'c1'}, title: '', description: '', reason: '', targetAssetId: 'targetA'),
        ActionPlanItem(id: 'acq_b', type: RecommendationType.acquire, priority: ActionPriority.essential, capabilityIds: {'c2'}, title: '', description: '', reason: '', targetAssetId: 'targetB'),
      ]);
      
      final roadmap = builder.build(plan, []);
      
      expect(roadmap.now.length, 2);
      expect(roadmap.now.any((s) => s.item.id == 'ver_a'), true);
      expect(roadmap.now.any((s) => s.item.id == 'acq_b'), true);
    });

    test('TEST E — UNKNOWN', () {
      final builder = PreparednessRoadmapBuilder();
      final plan = ActionPlan([
        ActionPlanItem(id: 'ver_unk', type: RecommendationType.verify, priority: ActionPriority.toVerify, capabilityIds: {'c1'}, title: '', description: '', reason: '', targetAssetId: 'targetA'),
      ]);
      
      final roadmap = builder.build(plan, []);
      
      expect(roadmap.now.length, 1);
      expect(roadmap.now.first.item.id, 'ver_unk');
    });

    test('TEST F — DETERMINISM', () {
      final builder = PreparednessRoadmapBuilder();
      final plan1 = ActionPlan([
        ActionPlanItem(id: 'item1', type: RecommendationType.acquire, priority: ActionPriority.essential, capabilityIds: {'c1'}, title: '', description: '', reason: '', targetAssetId: 'targetA'),
        ActionPlanItem(id: 'item2', type: RecommendationType.acquire, priority: ActionPriority.important, capabilityIds: {'c1'}, title: '', description: '', reason: '', targetAssetId: 'targetB'),
      ]);
      final plan2 = ActionPlan([
        ActionPlanItem(id: 'item2', type: RecommendationType.acquire, priority: ActionPriority.important, capabilityIds: {'c1'}, title: '', description: '', reason: '', targetAssetId: 'targetB'),
        ActionPlanItem(id: 'item1', type: RecommendationType.acquire, priority: ActionPriority.essential, capabilityIds: {'c1'}, title: '', description: '', reason: '', targetAssetId: 'targetA'),
      ]);
      
      final rm1 = builder.build(plan1, []);
      final rm2 = builder.build(plan2, []);
      
      expect(rm1.now.length, 1);
      expect(rm1.next.length, 1);
      expect(rm2.now.length, 1);
      expect(rm2.next.length, 1);
      
      expect(rm1.now.first.item.id, rm2.now.first.item.id);
      expect(rm1.next.first.item.id, rm2.next.first.item.id);
    });

    test('TEST G — NO DUPLICATE', () {
      final builder = PreparednessRoadmapBuilder();
      final plan = ActionPlan([
        ActionPlanItem(id: 'item1', type: RecommendationType.acquire, priority: ActionPriority.essential, capabilityIds: {'c1'}, title: '', description: '', reason: '', targetAssetId: 'targetA'),
      ]);
      
      final roadmap = builder.build(plan, []);
      
      int count = 0;
      if (roadmap.now.any((s) => s.item.id == 'item1')) count++;
      if (roadmap.next.any((s) => s.item.id == 'item1')) count++;
      if (roadmap.later.any((s) => s.item.id == 'item1')) count++;
      
      expect(count, 1);
    });


    test('TEST H — COMPLETION RECALC', () {
      final builder = PreparednessRoadmapBuilder();
      
      // Simulate GlobalActionPlan BEFORE
      final planBefore = ActionPlan([
        ActionPlanItem(id: 'acq_radio', type: RecommendationType.acquire, priority: ActionPriority.essential, capabilityIds: {'info'}, title: '', description: '', reason: '', targetAssetId: 'radio_piles'),
        ActionPlanItem(id: 'acq_eau', type: RecommendationType.acquire, priority: ActionPriority.important, capabilityIds: {'eau'}, title: '', description: '', reason: '', targetAssetId: 'stock_eau'),
      ]);
      
      final roadmapBefore = builder.build(planBefore, []);
      expect(roadmapBefore.now.length, 1); // acq_radio
      expect(roadmapBefore.next.length, 1); // acq_eau
      
      // Simulate completing acq_radio
      // The Engine (GlobalActionPlanBuilder) recalculates and naturally removes acq_radio
      // because we now own radio_piles.
      final planAfter = ActionPlan([
        ActionPlanItem(id: 'acq_eau', type: RecommendationType.acquire, priority: ActionPriority.important, capabilityIds: {'eau'}, title: '', description: '', reason: '', targetAssetId: 'stock_eau'),
      ]);
      
      // Build Roadmap AFTER. We don't need to pass completedActionIds to filter it!
      final roadmapAfter = builder.build(planAfter, []);
      
      expect(roadmapAfter.now.any((s) => s.item.id == 'acq_radio'), false);
      expect(roadmapAfter.next.any((s) => s.item.id == 'acq_radio'), false);
      
      // Ensure acq_eau moves up or stays where it should
      expect(roadmapAfter.now.length, 0);
      expect(roadmapAfter.next.length, 1);
      expect(roadmapAfter.next.first.item.id, 'acq_eau');
    });
    

    test('TEST H2 — REAL COMPLETION RECALC (E2E)', () {
      final config = HouseholdConfig(ownedAssets: [], unknownResources: {}, assessedResources: {}, ownedResources: []);
      const kbJson = appKnowledgeBase;
      final analyzer = MultiScenarioAnalyzer(kbJson);
      final planBuilder = GlobalActionPlanBuilder(kbJson);
      final roadmapBuilder = PreparednessRoadmapBuilder();

      // BEFORE
      final analysesBefore = analyzer.analyze(config, ['panne_elec']);
      final planBefore = planBuilder.build(analysesBefore, config);
      final roadmapBefore = roadmapBuilder.build(planBefore, []);
      
      // Pick a real verify action that targets a resource
      final stepToComplete = roadmapBefore.now.first;
      final actionToComplete = stepToComplete.item;

      // APPLY: the user clicks the action and we update the config (e.g., they don't have the resource)
      config.ownedAssets.addAll(['radio_piles', 'poele_bois', 'stock_eau', 'batterie_externe', 'box_internet']);
      config.ownedResources.addAll(['piles', 'bois', 'eau']);

      // AFTER
      final analysesAfter = analyzer.analyze(config, ['panne_elec']);
      final planAfter = planBuilder.build(analysesAfter, config);
      final roadmapAfter = roadmapBuilder.build(planAfter, []);

      // The VERIFY action is naturally gone from the new plan!
      expect(roadmapAfter.now.any((s) => s.item.id == actionToComplete.id), false);
      expect(roadmapAfter.next.any((s) => s.item.id == actionToComplete.id), false);
    });

    test('TEST I — NEW PRIORITY EMERGES', () {
      final builder = PreparednessRoadmapBuilder();
      
      // A VERIFY blocks an ACQUIRE
      final planBefore = ActionPlan([
        ActionPlanItem(id: 'ver_bois', type: RecommendationType.verify, priority: ActionPriority.toVerify, capabilityIds: {'chauffage'}, title: '', description: '', reason: '', targetResourceId: 'bois', priorityReasons: [PriorityReason(PriorityReasonType.blocksPurchaseDecision, '')]),
        ActionPlanItem(id: 'acq_poele', type: RecommendationType.acquire, priority: ActionPriority.essential, capabilityIds: {'chauffage'}, title: '', description: '', reason: '', targetResourceId: 'bois'),
      ]);
      
      final roadmapBefore = builder.build(planBefore, []);
      expect(roadmapBefore.now.length, 1);
      expect(roadmapBefore.now.first.item.id, 'ver_bois');
      expect(roadmapBefore.next.first.item.id, 'acq_poele'); // Deferred
      
      // Simulate verifying bois. Turns out we don't have it.
      // The Engine recalculates. The VERIFY is gone, but we still need the ACQUIRE.
      final planAfter = ActionPlan([
        ActionPlanItem(id: 'acq_poele', type: RecommendationType.acquire, priority: ActionPriority.essential, capabilityIds: {'chauffage'}, title: '', description: '', reason: '', targetResourceId: 'bois'),
      ]);
      
      final roadmapAfter = builder.build(planAfter, []);
      
      // VERIFY is gone
      expect(roadmapAfter.now.any((s) => s.item.id == 'ver_bois'), false);
      
      // ACQUIRE is freed and moves to NOW
      expect(roadmapAfter.now.length, 1);
      expect(roadmapAfter.now.first.item.id, 'acq_poele');
    });
    
    test('TEST J — IMMUTABILITY', () {
       // Deep snapshot of inputs
       final plan = ActionPlan([
         ActionPlanItem(id: 'item1', type: RecommendationType.acquire, priority: ActionPriority.essential, capabilityIds: {'c1'}, title: 'A', description: 'B', reason: 'C', targetAssetId: 't1', causeNodeIds: {'cause1'}, affectedScenarioIds: {'panne_elec'}, priorityReasons: [PriorityReason(PriorityReasonType.blocksPurchaseDecision, 'reason1')]),
       ]);
       final completedIds = ['c1', 'c2'];
       
       final originalPlanIds = plan.items.map((i) => i.id).toList();
       final originalPriorities = plan.items.map((i) => i.priority).toList();
       final originalUrgencies = plan.items.map((i) => i.urgency).toList();
       final originalCapabilityIds = plan.items.map((i) => i.capabilityIds.toList()).toList();
       final originalCauseNodeIds = plan.items.map((i) => i.causeNodeIds.toList()).toList();
       final originalAffectedScenarioIds = plan.items.map((i) => i.affectedScenarioIds.toList()).toList();
       final originalPriorityReasons = plan.items.map((i) => i.priorityReasons.map((r) => r.type).toList()).toList();
       final originalCompletedIds = List<String>.from(completedIds);
       
       final builder = PreparednessRoadmapBuilder();
       builder.build(plan, completedIds);
       
       // Verify no mutation
       expect(plan.items.map((i) => i.id).toList(), equals(originalPlanIds));
       expect(plan.items.map((i) => i.priority).toList(), equals(originalPriorities));
       expect(plan.items.map((i) => i.urgency).toList(), equals(originalUrgencies));
       expect(plan.items.map((i) => i.capabilityIds.toList()).toList(), equals(originalCapabilityIds));
       expect(plan.items.map((i) => i.causeNodeIds.toList()).toList(), equals(originalCauseNodeIds));
       expect(plan.items.map((i) => i.affectedScenarioIds.toList()).toList(), equals(originalAffectedScenarioIds));
       expect(plan.items.map((i) => i.priorityReasons.map((r) => r.type).toList()).toList(), equals(originalPriorityReasons));
       expect(completedIds, equals(originalCompletedIds));
    });
  });
}
