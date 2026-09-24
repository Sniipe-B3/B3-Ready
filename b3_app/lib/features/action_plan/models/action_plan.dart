import 'package:b3_engine/b3_engine.dart';


enum ActionPriority {
  essential,
  important,
  toVerify,
  improvement,
}

enum ActionUrgencyCategory {
  top,
  important,
  later,
}

enum PriorityReasonType {
  blocksPurchaseDecision,
  usesExistingSolution,
  affectsMultipleCapabilities,
  affectsMultipleScenarios,
  appearsAtShortHorizon,
}

class PriorityReason {
  final PriorityReasonType type;
  final String description;
  PriorityReason(this.type, this.description);
}

class ActionPlanItem {
  final String id;
  final String title;
  final String description;
  final String reason;
  final RecommendationType type;
  final ActionPriority priority;
  final Set<String> capabilityIds;
  final Set<String> causeNodeIds;
  final String? targetAssetId;
  final String? targetResourceId;

  final Set<String> affectedScenarioIds;
  final PreparednessHorizon? earliestAffectedHorizon;
  final ActionUrgencyCategory? urgency;
  final List<PriorityReason> priorityReasons;
  final String? primaryScenarioId;

  ActionPlanItem({
    required this.id,
    required this.title,
    required this.description,
    required this.reason,
    required this.type,
    required this.priority,
    required this.capabilityIds,
    this.causeNodeIds = const {},
    this.targetAssetId,
    this.targetResourceId,
    this.affectedScenarioIds = const {},
    this.earliestAffectedHorizon,
    this.urgency,
    this.priorityReasons = const [],
    this.primaryScenarioId,
  });
}

class ActionPlan {
  final List<ActionPlanItem> items;
  ActionPlan(this.items);
}
