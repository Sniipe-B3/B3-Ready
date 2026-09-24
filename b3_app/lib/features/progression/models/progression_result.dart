import 'package:b3_engine/b3_engine.dart';
import '../../action_plan/models/action_plan.dart';
import 'household_update.dart';

enum ProgressionMeaning {
  resilienceImproved,
  favorableSituationConfirmed,
  vulnerabilityConfirmed,
  resilienceDegraded,
  knowledgeImproved,
  unchanged,
}

class CapabilityChange {
  final String capabilityId;
  final String capabilityName;
  final B3State beforeState;
  final B3State afterState;
  final ProgressionMeaning meaning;

  CapabilityChange({
    required this.capabilityId,
    required this.capabilityName,
    required this.beforeState,
    required this.afterState,
    required this.meaning,
  });

  bool get hasImproved => meaning == ProgressionMeaning.resilienceImproved;
  bool get hasBetterKnowledge => meaning == ProgressionMeaning.knowledgeImproved || 
                                 meaning == ProgressionMeaning.favorableSituationConfirmed || 
                                 meaning == ProgressionMeaning.vulnerabilityConfirmed;
}

class ProgressionResult {
  final HouseholdConfig beforeConfig;
  final HouseholdConfig afterConfig;
  final SimulationResult? beforeResult;
  final SimulationResult? afterResult;
  final ActionPlan? beforePlan;
  final ActionPlan? afterPlan;
  final UpdateNature updateNature;
  
  final List<CapabilityChange> changedCapabilities;
  final bool hasStructuralChange;
  final List<String>? beforeCompletedActionIds;
  final List<String>? afterCompletedActionIds;


  List<String> get resolvedActionIds {
    if (beforePlan == null || afterPlan == null) return [];
    final beforeIds = beforePlan!.items.map((i) => i.id).toSet();
    final afterIds = afterPlan!.items.map((i) => i.id).toSet();
    return beforeIds.difference(afterIds).toList();
  }

  List<String> get newActionIds {
    if (beforePlan == null || afterPlan == null) return [];
    final beforeIds = beforePlan!.items.map((i) => i.id).toSet();
    final afterIds = afterPlan!.items.map((i) => i.id).toSet();
    return afterIds.difference(beforeIds).toList();
  }
  ProgressionResult({
    required this.beforeConfig,
    required this.afterConfig,
    required this.beforeResult,
    required this.afterResult,
    required this.beforePlan,
    required this.afterPlan,
    required this.changedCapabilities,
    required this.updateNature,
    required this.hasStructuralChange,
    this.beforeCompletedActionIds,
    this.afterCompletedActionIds,
  });
}
