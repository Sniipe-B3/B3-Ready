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

  ActionPlanItem({
    required this.id,
    required this.title,
    required this.description,
    required this.reason,
    required this.type,
    required this.priority,
    required this.capabilityIds,
    this.causeNodeIds = const {},
  });
}

class ActionPlan {
  final List<ActionPlanItem> items;
  ActionPlan(this.items);
}
