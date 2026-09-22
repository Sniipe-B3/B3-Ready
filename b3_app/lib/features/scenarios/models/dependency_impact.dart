

class DependencyLeverageAction {
  final String crossScenarioActionId;
  final String dependencyNodeId;
  final Set<String> affectedCapabilityIds;
  final Set<String> scenarioIds;

  DependencyLeverageAction({
    required this.crossScenarioActionId,
    required this.dependencyNodeId,
    required this.affectedCapabilityIds,
    required this.scenarioIds,
  });
}

class DependencyImpact {
  final String causeNodeId;
  final String causeNodeName;

  final Set<String> affectedCapabilityIds;
  final Set<String> affectedScenarioIds;

  final Set<String> maintainedCapabilityIds;
  final Set<String> vulnerableCapabilityIds;
  final Set<String> uncertainCapabilityIds; // For UNKNOWN / NOT_ASSESSED

  final List<DependencyLeverageAction> relatedActions;

  DependencyImpact({
    required this.causeNodeId,
    required this.causeNodeName,
    required this.affectedCapabilityIds,
    required this.affectedScenarioIds,
    required this.maintainedCapabilityIds,
    required this.vulnerableCapabilityIds,
    required this.uncertainCapabilityIds,
    required this.relatedActions,
  });
}
