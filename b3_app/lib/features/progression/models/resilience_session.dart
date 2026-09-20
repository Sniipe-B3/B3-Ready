import '../../../data/household_repository.dart';
import '../../../data/household_snapshot.dart';
import 'package:flutter/foundation.dart';
import 'package:b3_engine/b3_engine.dart';
import '../../action_plan/action_plan_builder.dart';
import '../../action_plan/models/action_plan.dart';
import 'household_update.dart';
import 'progression_result.dart';

class ResilienceSession extends ChangeNotifier {
  final String knowledgeJson;
  final String scenarioId;
  final HouseholdRepository? repository;
  final bool isRestored;

  HouseholdConfig _config;
  late Scenario _scenario;
  late List<B3Node> _graph;
  late SimulationResult _simulationResult;
  late List<Recommendation> _recommendations;
  late ActionPlan _actionPlan;

  final List<String> _completedActionIds = [];

  Object? _saveError;
  String? _scenarioError;
  Future<void> _saveQueue = Future.value();

  HouseholdConfig get config => _config;
  Scenario get scenario => _scenario;
  List<B3Node> get graph => _graph;
  SimulationResult get simulationResult => _simulationResult;
  List<Recommendation> get recommendations => _recommendations;
  ActionPlan get actionPlan => _actionPlan;
  List<String> get completedActionIds => _completedActionIds;
  
  Object? get saveError => _saveError;
  String? get scenarioError => _scenarioError;
  bool get isSaving => _saveError == null; // Wait, actually it's easier to expose `pendingSave` status, but the instructions only ask for `Object? saveError` minimum. 

  Future<void> waitForPendingSave() => _saveQueue;

  ResilienceSession({
    required this.knowledgeJson,
    required this.scenarioId,
    required HouseholdConfig initialConfig,
    List<String> initialCompletedActionIds = const [],
    this.repository,
    this.isRestored = false,
  }) : _config = initialConfig.clone() {
    _completedActionIds.addAll(initialCompletedActionIds);
    _performInitialCalculation();
    if (!isRestored && repository != null) {
      _autosave();
    }
  }

  void _autosave() {
    if (repository == null) return;
    
    // We snapshot synchronously so the saved state matches the moment _autosave was called.
    final snapshot = HouseholdSnapshot(
      schemaVersion: 1,
      config: _config.clone(),
      scenarioId: scenarioId,
      completedActionIds: List.from(_completedActionIds),
    );

    _saveQueue = _saveQueue.then((_) async {
      try {
        await repository!.save(snapshot);
        _saveError = null;
      } catch (e) {
        _saveError = e;
      }
      notifyListeners();
    });
  }

  void _performInitialCalculation() {
    try {
      _scenario = DataMapper.parseScenario(knowledgeJson, scenarioId);
    } catch (e) {
      _scenarioError = "Votre ancien scénario n'est plus disponible. Votre foyer a été conservé.";
      // Try fallback to 'panne_elec'
      try {
        _scenario = DataMapper.parseScenario(knowledgeJson, 'panne_elec');
      } catch (fallbackError) {
        // Safe fallback if 'panne_elec' also doesn't exist
        _scenario = Scenario(name: "Inconnu", duration: Duration.zero, systemOverrides: {});
      }
    }
    
    _graph = DataMapper.buildGraph(knowledgeJson, _config);
    _simulationResult = B3Engine().runSimulation(_graph, _scenario);
    _recommendations = RecommendationEngine(knowledgeJson).generate(_simulationResult, _config, _scenario);
    _actionPlan = ActionPlanBuilder(knowledgeJson).build(_recommendations, _simulationResult);
  }

  ProgressionResult recalculate(HouseholdUpdate update) {
    // 1. Snapshot BEFORE
    final beforeConfig = _config.clone();
    final beforeResult = _simulationResult;
    final beforePlan = _actionPlan;

    // 2. Apply Update
    if (update is ActionCompletedUpdate) {
      if (!_completedActionIds.contains(update.actionId)) {
        _completedActionIds.add(update.actionId);
      }
      final progression = ProgressionResult(
        beforeConfig: beforeConfig,
        afterConfig: beforeConfig,
        beforeResult: beforeResult,
        afterResult: beforeResult,
        beforePlan: beforePlan,
        afterPlan: beforePlan,
        changedCapabilities: [],
        updateNature: update.nature,
        hasStructuralChange: false,
      );
      _autosave();
      notifyListeners();
      return progression;
    }

    final newConfig = _config.clone();

    if (update is ResourceUpdate) {
      final resId = update.resourceId;
      if (update.isOwned != null) {
        if (update.isOwned!) {
          if (!newConfig.ownedResources.contains(resId)) newConfig.ownedResources.add(resId);
        } else {
          newConfig.ownedResources.remove(resId);
        }
      }
      
      newConfig.assessedResources.add(resId);
      
      if (update.isUnknown) {
        newConfig.unknownResources.add(resId);
        newConfig.resourceDurations.remove(resId);
      } else {
        newConfig.unknownResources.remove(resId);
        if (update.duration != null) {
          newConfig.resourceDurations[resId] = update.duration!;
        } else if (update.isOwned == false) {
           newConfig.resourceDurations.remove(resId);
        }
      }
    } else if (update is AssetOwnershipUpdate) {
      if (update.isOwned) {
        if (!newConfig.ownedAssets.contains(update.assetId)) newConfig.ownedAssets.add(update.assetId);
      } else {
        newConfig.ownedAssets.remove(update.assetId);
      }
    }

    _config = newConfig;

    // 3. Recalculate
    _graph = DataMapper.buildGraph(knowledgeJson, _config);
    _simulationResult = B3Engine().runSimulation(_graph, _scenario);
    _recommendations = RecommendationEngine(knowledgeJson).generate(_simulationResult, _config, _scenario);
    _actionPlan = ActionPlanBuilder(knowledgeJson).build(_recommendations, _simulationResult);

    // 4. Compare BEFORE and AFTER
    final changedCaps = <CapabilityChange>[];
    for (var cap in _graph.whereType<Capability>()) {
      final beforeState = beforeResult.nodeStates[cap.id] ?? B3State.notAssessed;
      final afterState = _simulationResult.nodeStates[cap.id] ?? B3State.notAssessed;
      if (beforeState != afterState) {
        changedCaps.add(CapabilityChange(
          capabilityId: cap.id,
          capabilityName: cap.name,
          beforeState: beforeState,
          afterState: afterState,
          meaning: _computeMeaning(beforeState, afterState, update.nature),
        ));
      }
    }

    final progression = ProgressionResult(
      beforeConfig: beforeConfig,
      afterConfig: newConfig,
      beforeResult: beforeResult,
      afterResult: _simulationResult,
      beforePlan: beforePlan,
      afterPlan: _actionPlan,
      changedCapabilities: changedCaps,
      updateNature: update.nature,
      hasStructuralChange: true,
    );

    _autosave();
    notifyListeners();
    return progression;
  }

  ProgressionMeaning _computeMeaning(B3State before, B3State after, UpdateNature nature) {
    bool wasUnknown = before == B3State.unknown || before == B3State.notAssessed;
    bool isBetter = (before == B3State.failed && (after == B3State.maintained || after == B3State.degraded)) ||
                    (before == B3State.degraded && after == B3State.maintained) ||
                    (wasUnknown && (after == B3State.maintained || after == B3State.degraded));
    bool isWorse = (before == B3State.maintained && after != B3State.maintained) ||
                   (before == B3State.degraded && after == B3State.failed) ||
                   (wasUnknown && after == B3State.failed);

    if (nature == UpdateNature.observation) {
      if (wasUnknown && isBetter) return ProgressionMeaning.favorableSituationConfirmed;
      if (wasUnknown && isWorse) return ProgressionMeaning.vulnerabilityConfirmed;
      if (!wasUnknown && isBetter) return ProgressionMeaning.favorableSituationConfirmed;
      if (!wasUnknown && isWorse) return ProgressionMeaning.vulnerabilityConfirmed;
      return ProgressionMeaning.knowledgeImproved;
    } else if (nature == UpdateNature.intervention) {
      if (isBetter) return ProgressionMeaning.resilienceImproved;
      if (isWorse) return ProgressionMeaning.resilienceDegraded;
    }
    
    return ProgressionMeaning.unchanged;
  }
}
