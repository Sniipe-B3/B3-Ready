import 'package:b3_engine/b3_engine.dart';
import '../../action_plan/models/action_plan.dart';

class RecurringCapabilityIssue {
  final String capabilityId;
  final String capabilityName;
  final Map<String, B3State> statesByScenario; // scenarioId -> B3State

  RecurringCapabilityIssue({
    required this.capabilityId,
    required this.capabilityName,
    required this.statesByScenario,
  });

  List<String> get scenarioIds => statesByScenario.keys.toList();
  List<String> get failedScenarioIds => statesByScenario.entries.where((e) => e.value == B3State.failed).map((e) => e.key).toList();
  List<String> get degradedScenarioIds => statesByScenario.entries.where((e) => e.value == B3State.degraded).map((e) => e.key).toList();
}

class CommonDependencyIssue {
  final String causeNodeId;
  final String causeNodeName;
  final Set<String> capabilityIds;
  final Set<String> scenarioIds;

  CommonDependencyIssue({
    required this.causeNodeId,
    required this.causeNodeName,
    required this.capabilityIds,
    required this.scenarioIds,
  });
}

class CrossScenarioAction {
  final String id;
  final String title;
  final RecommendationType type;
  final String? targetAssetId;
  final String? targetResourceId;
  final Set<String> scenarioIds;
  final Set<String> capabilityIds;
  final Map<String, ActionPriority> prioritiesByScenario; // scenarioId -> priority
  final Map<String, String> reasonsByScenario; // scenarioId -> reason
  final Set<String> causeNodeIds;

  CrossScenarioAction({
    required this.id,
    required this.title,
    required this.type,
    this.targetAssetId,
    this.targetResourceId,
    required this.scenarioIds,
    required this.capabilityIds,
    required this.prioritiesByScenario,
    required this.reasonsByScenario,
    required this.causeNodeIds,
  });

  ActionPriority get highestPriority {
    if (prioritiesByScenario.values.contains(ActionPriority.essential)) return ActionPriority.essential;
    if (prioritiesByScenario.values.contains(ActionPriority.important)) return ActionPriority.important;
    if (prioritiesByScenario.values.contains(ActionPriority.improvement)) return ActionPriority.improvement;
    return ActionPriority.toVerify;
  }
}

class GlobalUncertainty {
  final String nodeId;
  final String nodeName;
  final Map<String, B3State> statesByScenario; // scenarioId -> B3State (UNKNOWN or NOT_ASSESSED)

  GlobalUncertainty({
    required this.nodeId,
    required this.nodeName,
    required this.statesByScenario,
  });

  List<String> get scenarioIds => statesByScenario.keys.toList();
  List<String> get unknownScenarioIds => statesByScenario.entries.where((e) => e.value == B3State.unknown).map((e) => e.key).toList();
  List<String> get notAssessedScenarioIds => statesByScenario.entries.where((e) => e.value == B3State.notAssessed).map((e) => e.key).toList();
}

class GlobalHouseholdOverview {
  final List<RecurringCapabilityIssue> recurringIssues;
  final List<CommonDependencyIssue> commonDependencies;
  final List<CrossScenarioAction> actions;
  final List<GlobalUncertainty> uncertainties;

  GlobalHouseholdOverview({
    required this.recurringIssues,
    required this.commonDependencies,
    required this.actions,
    required this.uncertainties,
  });
}
