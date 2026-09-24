import 'package:b3_engine/b3_engine.dart';
import 'models/action_plan.dart';

enum RoadmapStage {
  now,
  next,
  later,

}

class RoadmapStep {
  final ActionPlanItem item;
  final RoadmapStage stage;
  final List<String> deferredByItemIds;

  RoadmapStep(this.item, this.stage, {this.deferredByItemIds = const []});
}

class PreparednessRoadmap {
  final List<RoadmapStep> steps;

  PreparednessRoadmap(this.steps);

  List<RoadmapStep> get now => steps.where((s) => s.stage == RoadmapStage.now).toList();
  List<RoadmapStep> get next => steps.where((s) => s.stage == RoadmapStage.next).toList();
  List<RoadmapStep> get later => steps.where((s) => s.stage == RoadmapStage.later).toList();
}

class PreparednessRoadmapBuilder {
  PreparednessRoadmap build(ActionPlan plan, List<String> completedActionIds) {
    final steps = <RoadmapStep>[];
    final incompleteItems = plan.items;

    for (var item in plan.items) {

      // Check if this item (ACQUIRE/INVEST) is deferred by a VERIFY, USE_EXISTING, or ORGANIZE 
      // on the exact same canonical target that is not yet completed.
      final defers = incompleteItems.where((other) {
        if (other.id == item.id) return false;
        if (item.type != RecommendationType.acquire && item.type != RecommendationType.invest) return false;

        final target = item.targetResourceId ?? item.targetAssetId ?? 'general';
        final otherTarget = other.targetResourceId ?? other.targetAssetId ?? 'general';
        if (target != otherTarget || target == 'general') return false;

        return other.type == RecommendationType.verify ||
               other.type == RecommendationType.useExisting ||
               other.type == RecommendationType.organize;
      }).toList();

      RoadmapStage stage;

      if (defers.isNotEmpty) {
        // Deferred items get pushed to next, or later if they are naturally later
        // Let's just put them in NEXT so they are visible as upcoming, unless they are naturally LATER
        if (item.priority == ActionPriority.improvement) {
          stage = RoadmapStage.later;
        } else {
          stage = RoadmapStage.next;
        }
        steps.add(RoadmapStep(item, stage, deferredByItemIds: defers.map((e) => e.id).toList()));
        continue;
      }

      final isBlockingVerify = item.priorityReasons.any((r) => r.type == PriorityReasonType.blocksPurchaseDecision);
      final usesExisting = item.priorityReasons.any((r) => r.type == PriorityReasonType.usesExistingSolution);
      final shortHorizon = item.priorityReasons.any((r) => r.type == PriorityReasonType.appearsAtShortHorizon) &&
                           (item.earliestAffectedHorizon == PreparednessHorizon.sixHours || item.earliestAffectedHorizon == PreparednessHorizon.oneDay);
      
      if (isBlockingVerify || usesExisting || shortHorizon || item.priority == ActionPriority.essential || item.priority == ActionPriority.toVerify) {
        stage = RoadmapStage.now;
      } else if (item.priority == ActionPriority.important || item.urgency == ActionUrgencyCategory.top || item.urgency == ActionUrgencyCategory.important) {
        stage = RoadmapStage.next;
      } else {
        stage = RoadmapStage.later;
      }

      steps.add(RoadmapStep(item, stage));
    }

    // Sort to maintain original GlobalActionPlan order within stages
    steps.sort((a, b) {
      if (a.stage != b.stage) return a.stage.index.compareTo(b.stage.index);
      return plan.items.indexOf(a.item).compareTo(plan.items.indexOf(b.item));
    });

    return PreparednessRoadmap(steps);
  }
}
