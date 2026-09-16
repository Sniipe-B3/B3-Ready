import 'package:b3_engine/b3_engine.dart';
import 'models/action_plan.dart';

class ActionPlanBuilder {
  final String knowledgeJson;

  ActionPlanBuilder(this.knowledgeJson);

  ActionPlan build(List<Recommendation> recommendations, SimulationResult result) {
    final Map<String, List<Recommendation>> grouped = {};

    for (var rec in recommendations) {
      // Clé de dédoublonnage : type d'action + cible réelle (ressource, asset, ou à défaut la capability)
      String target = rec.targetResourceId ?? rec.targetAssetId ?? rec.capabilityId;
      String key = '${rec.type.name}_$target';
      grouped.putIfAbsent(key, () => []).add(rec);
    }

    final items = <ActionPlanItem>[];

    for (var group in grouped.values) {
      final first = group.first;

      final capabilityIds = <String>{};
      final causeNodeIds = <String>{};
      
      ActionPriority highestPriority = ActionPriority.improvement;

      for (var rec in group) {
        capabilityIds.add(rec.capabilityId);
        causeNodeIds.addAll(rec.causeNodeIds);

        final state = result.nodeStates[rec.capabilityId] ?? B3State.notAssessed;

        ActionPriority itemPriority;
        if (state == B3State.failed) {
          itemPriority = ActionPriority.essential;
        } else if (state == B3State.degraded) {
          itemPriority = ActionPriority.important;
        } else if (state == B3State.unknown || state == B3State.notAssessed) {
          itemPriority = ActionPriority.toVerify;
        } else {
          itemPriority = ActionPriority.improvement;
        }

        if (itemPriority.index < highestPriority.index) {
          highestPriority = itemPriority;
        }
      }

      items.add(ActionPlanItem(
        id: first.id,
        title: first.title,
        description: first.description,
        reason: first.reason,
        type: first.type,
        priority: highestPriority,
        capabilityIds: capabilityIds,
        causeNodeIds: causeNodeIds,
      ));
    }

    items.sort((a, b) {
      int pCmp = a.priority.index.compareTo(b.priority.index);
      if (pCmp != 0) return pCmp;

      int typeOrder(RecommendationType t) {
        switch (t) {
          case RecommendationType.verify: return 1;
          case RecommendationType.useExisting: return 2;
          case RecommendationType.organize: return 3;
          case RecommendationType.learn: return 4;
          case RecommendationType.createAlternative: return 5;
          case RecommendationType.acquire: return 6;
          case RecommendationType.invest: return 7;
        }
      }

      int tCmp = typeOrder(a.type).compareTo(typeOrder(b.type));
      if (tCmp != 0) return tCmp;

      int cCmp = b.capabilityIds.length.compareTo(a.capabilityIds.length);
      if (cCmp != 0) return cCmp;

      return a.id.compareTo(b.id);
    });

    if (items.length > 5) {
      return ActionPlan(items.sublist(0, 5));
    }
    return ActionPlan(items);
  }
}
