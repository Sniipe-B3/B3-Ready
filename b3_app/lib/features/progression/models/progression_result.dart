import 'package:b3_engine/b3_engine.dart';
import '../../action_plan/models/action_plan.dart';

class CapabilityChange {
  final String capabilityId;
  final String capabilityName;
  final B3State beforeState;
  final B3State afterState;

  CapabilityChange({
    required this.capabilityId,
    required this.capabilityName,
    required this.beforeState,
    required this.afterState,
  });

  bool get hasImproved {
    // Defines "improvement" as a genuine increase in resilience,
    // not just UNKNOWN -> FAILED (which is knowledge, not resilience).
    if (beforeState == B3State.failed && (afterState == B3State.maintained || afterState == B3State.degraded)) { return true; }
    if (beforeState == B3State.degraded && afterState == B3State.maintained) { return true; }
    if (beforeState == B3State.unknown && afterState == B3State.maintained) { return true; }
    if (beforeState == B3State.notAssessed && afterState == B3State.maintained) { return true; }
    return false;
  }

  bool get hasDegraded {
    if (beforeState == B3State.maintained && afterState != B3State.maintained) { return true; }
    if (beforeState == B3State.degraded && afterState == B3State.failed) { return true; }
    if ((beforeState == B3State.unknown || beforeState == B3State.notAssessed) && afterState == B3State.failed) { return true; }
    return false;
  }

  bool get hasBetterKnowledge {
    if ((beforeState == B3State.unknown || beforeState == B3State.notAssessed) && 
        (afterState != B3State.unknown && afterState != B3State.notAssessed)) { return true; }
    return false;
  }
}

class ProgressionResult {
  final HouseholdConfig beforeConfig;
  final HouseholdConfig afterConfig;
  final SimulationResult beforeResult;
  final SimulationResult afterResult;
  final ActionPlan beforePlan;
  final ActionPlan afterPlan;
  
  final List<CapabilityChange> changedCapabilities;
  final bool hasStructuralChange;

  ProgressionResult({
    required this.beforeConfig,
    required this.afterConfig,
    required this.beforeResult,
    required this.afterResult,
    required this.beforePlan,
    required this.afterPlan,
    required this.changedCapabilities,
    this.hasStructuralChange = true,
  });
}
