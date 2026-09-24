import 'dart:convert';
import 'package:b3_engine/b3_engine.dart';

import 'models/action_plan.dart';
import '../scenarios/models/scenario_analysis.dart';

class GlobalActionPlanBuilder {
  final String knowledgeJson;
  late final Map<String, dynamic> kb;
  late final List<dynamic> horizonsData;

  GlobalActionPlanBuilder(this.knowledgeJson) {
    kb = jsonDecode(knowledgeJson);
  }

  String _getCanonicalTarget(String? targetResourceId, String? targetAssetId, Set<String> capabilityIds, String id) {
    if (targetResourceId != null) return 'res_$targetResourceId';
    if (targetAssetId != null) return 'asset_$targetAssetId';
    if (capabilityIds.isNotEmpty) return 'caps_${(capabilityIds.toList()..sort()).join('_')}';
    return id;
  }

  ActionPlan build(List<ScenarioAnalysis> analyses, HouseholdConfig config) {
    final Map<String, List<_ScenarioRec>> grouped = {};

    for (var analysis in analyses) {
      if (!analysis.isAvailable || analysis.simulationResult == null || analysis.recommendations == null) continue;
      
      for (var rec in analysis.recommendations!) {
        grouped.putIfAbsent(rec.id, () => []).add(_ScenarioRec(rec, analysis.scenarioId, analysis.scenario!.duration, analysis.simulationResult!));
      }
    }

    final draftItems = <_DraftItem>[];

    for (var group in grouped.values) {
      final firstRec = group.first.rec;
      
      final capabilityIds = <String>{};
      final causeNodeIds = <String>{};
      final affectedScenarioIds = <String>{};
      
      ActionPriority highestPriority = ActionPriority.improvement;

      for (var srec in group) {
        capabilityIds.add(srec.rec.capabilityId);
        causeNodeIds.addAll(srec.rec.causeNodeIds);
        affectedScenarioIds.add(srec.scenarioId);
        
        final state = srec.result.nodeStates[srec.rec.capabilityId] ?? B3State.notAssessed;
        ActionPriority itemPriority = ActionPriority.improvement;
        if (state == B3State.failed) {
          itemPriority = ActionPriority.essential;
        } else if (state == B3State.degraded) {
          itemPriority = ActionPriority.important;
        } else if (state == B3State.unknown || state == B3State.notAssessed) {
          itemPriority = ActionPriority.toVerify;
        }
        
        if (itemPriority.index < highestPriority.index) {
          highestPriority = itemPriority;
        }
      }
      
      final sortedScenarios = affectedScenarioIds.toList()..sort();
      final primaryScenarioId = sortedScenarios.first;

      PreparednessHorizon? earliestAffectedHorizon;
      
      final horizons = [
        PreparednessHorizon.sixHours,
        PreparednessHorizon.oneDay,
        PreparednessHorizon.threeDays,
        PreparednessHorizon.sevenDays,
      ];
      
      for (var horizon in horizons) {
        bool affectedAtHorizon = false;
        
        for (var scenarioId in affectedScenarioIds) {
          Duration dur = const Duration(hours: 24);
          if (horizon == PreparednessHorizon.sixHours) { dur = const Duration(hours: 6); }
          else if (horizon == PreparednessHorizon.oneDay) { dur = const Duration(hours: 24); }
          else if (horizon == PreparednessHorizon.threeDays) { dur = const Duration(hours: 72); }
          else if (horizon == PreparednessHorizon.sevenDays) { dur = const Duration(days: 7); }
          
          Scenario scenario;
          try {
            scenario = DataMapper.parseScenario(knowledgeJson, scenarioId, dur);
          } catch (e) {
            continue;
          }
          final graph = DataMapper.buildGraph(knowledgeJson, config.clone());
          final result = B3Engine().runSimulation(graph, scenario);
          
          for (var capId in capabilityIds) {
            final state = result.nodeStates[capId];
            if (state == B3State.failed || state == B3State.degraded) {
              affectedAtHorizon = true;
              break;
            }
          }
          if (affectedAtHorizon) break;
        }
        
        if (affectedAtHorizon) {
          earliestAffectedHorizon = horizon;
          break;
        }
      }

      draftItems.add(_DraftItem(
        id: firstRec.id,
        title: firstRec.title,
        description: firstRec.description,
        reason: firstRec.reason,
        type: firstRec.type,
        priority: highestPriority,
        capabilityIds: capabilityIds,
        targetAssetId: firstRec.targetAssetId,
        targetResourceId: firstRec.targetResourceId,
        causeNodeIds: causeNodeIds,
        affectedScenarioIds: affectedScenarioIds,
        earliestAffectedHorizon: earliestAffectedHorizon,
        primaryScenarioId: primaryScenarioId,
      ));
    }

    final items = <ActionPlanItem>[];

    for (var draft in draftItems) {
      final target = _getCanonicalTarget(draft.targetResourceId, draft.targetAssetId, draft.capabilityIds, draft.id);
      final hasPurchase = draftItems.any((x) => (x.type == RecommendationType.acquire || x.type == RecommendationType.invest) && _getCanonicalTarget(x.targetResourceId, x.targetAssetId, x.capabilityIds, x.id) == target);
      
      ActionUrgencyCategory urgency = ActionUrgencyCategory.later;
      final reasons = <PriorityReason>[];
      
      bool isBlockingVerify = draft.type == RecommendationType.verify && hasPurchase;
      bool usesExisting = (draft.type == RecommendationType.useExisting || draft.type == RecommendationType.organize) && hasPurchase;
      
      if (isBlockingVerify) {
        urgency = ActionUrgencyCategory.top;
        reasons.add(PriorityReason(PriorityReasonType.blocksPurchaseDecision, "Cette vérification conditionne une décision d'action."));
      } else if (draft.earliestAffectedHorizon == PreparednessHorizon.sixHours || draft.earliestAffectedHorizon == PreparednessHorizon.oneDay) {
        urgency = ActionUrgencyCategory.top;
        reasons.add(PriorityReason(PriorityReasonType.appearsAtShortHorizon, "Cette vulnérabilité apparaît dès les premières 24h."));
      } else if (draft.earliestAffectedHorizon != null) {
        urgency = ActionUrgencyCategory.important;
        reasons.add(PriorityReason(PriorityReasonType.appearsAtShortHorizon, "Cette vulnérabilité est confirmée."));
      } else if (usesExisting) {
        urgency = ActionUrgencyCategory.important;
        reasons.add(PriorityReason(PriorityReasonType.usesExistingSolution, "Utilise une solution que vous possédez déjà."));
      }
      
      if (draft.affectedScenarioIds.length > 1) {
        if (urgency == ActionUrgencyCategory.later) urgency = ActionUrgencyCategory.important;
        reasons.add(PriorityReason(PriorityReasonType.affectsMultipleScenarios, "Cette action sécurise plusieurs scénarios."));
      }
      if (draft.capabilityIds.length > 1) {
        if (urgency == ActionUrgencyCategory.later) urgency = ActionUrgencyCategory.important;
        reasons.add(PriorityReason(PriorityReasonType.affectsMultipleCapabilities, "Cette action sécurise plusieurs besoins."));
      }
      
      items.add(ActionPlanItem(
        id: draft.id,
        title: draft.title,
        description: draft.description,
        reason: draft.reason,
        type: draft.type,
        priority: draft.priority,
        capabilityIds: draft.capabilityIds,
        targetAssetId: draft.targetAssetId,
        targetResourceId: draft.targetResourceId,
        causeNodeIds: draft.causeNodeIds,
        affectedScenarioIds: draft.affectedScenarioIds,
        earliestAffectedHorizon: draft.earliestAffectedHorizon,
        urgency: urgency,
        priorityReasons: reasons,
        primaryScenarioId: draft.primaryScenarioId,
      ));
    }

    items.sort((a, b) {
      final targetA = _getCanonicalTarget(a.targetResourceId, a.targetAssetId, a.capabilityIds, a.id);
      final targetB = _getCanonicalTarget(b.targetResourceId, b.targetAssetId, b.capabilityIds, b.id);
      
      if (targetA == targetB) {
        if (a.type == RecommendationType.verify && (b.type == RecommendationType.acquire || b.type == RecommendationType.invest)) return -1;
        if (b.type == RecommendationType.verify && (a.type == RecommendationType.acquire || a.type == RecommendationType.invest)) return 1;
        
        if ((a.type == RecommendationType.useExisting || a.type == RecommendationType.organize) && (b.type == RecommendationType.acquire || b.type == RecommendationType.invest)) return -1;
        if ((b.type == RecommendationType.useExisting || b.type == RecommendationType.organize) && (a.type == RecommendationType.acquire || a.type == RecommendationType.invest)) return 1;
      }
      
      int hA = a.earliestAffectedHorizon?.duration.inHours ?? 99999;
      int hB = b.earliestAffectedHorizon?.duration.inHours ?? 99999;
      int hCmp = hA.compareTo(hB);
      if (hCmp != 0) return hCmp;
      
      int sCmp = b.affectedScenarioIds.length.compareTo(a.affectedScenarioIds.length);
      if (sCmp != 0) return sCmp;
      
      int cCmp = b.capabilityIds.length.compareTo(a.capabilityIds.length);
      if (cCmp != 0) return cCmp;
      
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
      
      return a.id.compareTo(b.id);
    });

    return ActionPlan(items);
  }
}


class _DraftItem {
  final String id;
  final String title;
  final String description;
  final String reason;
  final RecommendationType type;
  final ActionPriority priority;
  final Set<String> capabilityIds;
  final String? targetAssetId;
  final String? targetResourceId;
  final Set<String> causeNodeIds;
  final Set<String> affectedScenarioIds;
  final PreparednessHorizon? earliestAffectedHorizon;
  final String? primaryScenarioId;
  _DraftItem({
    required this.id, required this.title, required this.description, required this.reason,
    required this.type, required this.priority, required this.capabilityIds,
    this.targetAssetId, this.targetResourceId, required this.causeNodeIds,
    required this.affectedScenarioIds, this.earliestAffectedHorizon, this.primaryScenarioId,
  });
}


class _ScenarioRec {
  final Recommendation rec;
  final String scenarioId;
  final Duration scenarioDuration;
  final SimulationResult result;
  _ScenarioRec(this.rec, this.scenarioId, this.scenarioDuration, this.result);
}
