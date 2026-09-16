import 'package:b3_engine/b3_engine.dart';

enum ActionPriority {
  essential,
  important,
  toVerify,
  improvement,
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
  });
}

class ActionPlan {
  final List<ActionPlanItem> items;
  ActionPlan(this.items);
}

