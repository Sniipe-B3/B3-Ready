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
  final String requestedScenarioId;
  final HouseholdRepository? repository;
  final bool isRestored;

  HouseholdConfig _config;
  Scenario? _scenario;
  List<B3Node>? _graph;
  SimulationResult? _simulationResult;
  List<Recommendation>? _recommendations;
  ActionPlan? _actionPlan;

  final List<String> _completedActionIds = [];

  PreparednessHorizon _horizon = PreparednessHorizon.oneDay;
  PreparednessHorizon get horizon => _horizon;

  void setHorizon(PreparednessHorizon h) {
    if (_horizon == h) return;
    _horizon = h;
    if (scenarioUnavailable) return;
    
    _scenario = DataMapper.parseScenario(knowledgeJson, _activeScenarioId, _horizon.duration);
    _simulationResult = B3Engine().runSimulation(_graph!, _scenario!);
    _recommendations = RecommendationEngine(knowledgeJson).generate(_simulationResult!, _config, _scenario!);
    _actionPlan = ActionPlanBuilder(knowledgeJson).build(_recommendations!, _simulationResult!);
    notifyListeners();
  }

  Object? _saveError;
  String? _scenarioError;
  bool scenarioUnavailable = false;
  Future<void> _saveQueue = Future.value();
  int _pendingSaveCount = 0;
  late String _activeScenarioId;

  HouseholdConfig get config => _config;
  Scenario? get scenario => _scenario;
  List<B3Node>? get graph => _graph;
  SimulationResult? get simulationResult => _simulationResult;
  List<Recommendation>? get recommendations => _recommendations;
  ActionPlan? get actionPlan => _actionPlan;
  List<String> get completedActionIds => _completedActionIds;
  
  Object? get saveError => _saveError;
  String? get scenarioError => _scenarioError;
  bool get isSaving => _pendingSaveCount > 0;
  String get scenarioId => _activeScenarioId;

  Future<void> waitForPendingSave() => _saveQueue;

  ResilienceSession({
    required this.knowledgeJson,
    required String scenarioId,
    required HouseholdConfig initialConfig,
    List<String> initialCompletedActionIds = const [],
    this.repository,
    this.isRestored = false,
  }) : requestedScenarioId = scenarioId, _config = initialConfig.clone() {
    _completedActionIds.addAll(initialCompletedActionIds);
    _performInitialCalculation();
    
    // We save initially if not restored, OR if we had to fallback to panne_elec during a restore
    if (!isRestored && repository != null) {
      _autosave();
    }
  }

  void _autosave() {
    if (repository == null) return;
    
    final snapshot = HouseholdSnapshot(
      schemaVersion: 1,
      config: _config.clone(),
      scenarioId: _activeScenarioId,
      completedActionIds: List.from(_completedActionIds),
    );

    _pendingSaveCount++;
    notifyListeners();

    _saveQueue = _saveQueue.then((_) async {
      try {
        await repository!.save(snapshot);
        _saveError = null;
      } catch (e) {
        _saveError = e;
      } finally {
        _pendingSaveCount--;
        notifyListeners();
      }
    });
  }

  void _performInitialCalculation() {
    bool didFallback = false;
    try {
      _scenario = DataMapper.parseScenario(knowledgeJson, requestedScenarioId, _horizon.duration);
      _activeScenarioId = requestedScenarioId;
    } catch (e) {
      _scenarioError = "Votre ancien scénario n'est plus disponible. Votre foyer a été conservé.";
      try {
        _scenario = DataMapper.parseScenario(knowledgeJson, 'panne_elec', _horizon.duration);
        _activeScenarioId = 'panne_elec';
        didFallback = true;
      } catch (fallbackError) {
        scenarioUnavailable = true;
        _scenario = null;
        _activeScenarioId = 'panne_elec'; // Arbitrary fallback so snapshot keeps something
      }
    }
    
    if (scenarioUnavailable) {
      _graph = null;
      _simulationResult = null;
      _recommendations = null;
      _actionPlan = null;
      return;
    }

    _graph = DataMapper.buildGraph(knowledgeJson, _config);
    _simulationResult = B3Engine().runSimulation(_graph!, _scenario!);
    _recommendations = RecommendationEngine(knowledgeJson).generate(_simulationResult!, _config, _scenario!);
    _actionPlan = ActionPlanBuilder(knowledgeJson).build(_recommendations!, _simulationResult!);
    
    if (isRestored && didFallback) {
      _autosave();
    }
  }

  ProgressionResult recalculate(HouseholdUpdate update) {
    if (scenarioUnavailable) {
      return ProgressionResult(
        beforeConfig: _config.clone(),
        afterConfig: _config.clone(),
        beforeResult: null,
        afterResult: null,
        beforePlan: null,
        afterPlan: null,
        changedCapabilities: [],
        updateNature: update.nature,
        hasStructuralChange: false,
      );
    }

    final beforeConfig = _config.clone();
    final beforeResult = _simulationResult!;
    final beforePlan = _actionPlan!;

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

    _graph = DataMapper.buildGraph(knowledgeJson, _config);
    _simulationResult = B3Engine().runSimulation(_graph!, _scenario!);
    _recommendations = RecommendationEngine(knowledgeJson).generate(_simulationResult!, _config, _scenario!);
    _actionPlan = ActionPlanBuilder(knowledgeJson).build(_recommendations!, _simulationResult!);

    final changedCaps = <CapabilityChange>[];
    for (var cap in _graph!.whereType<Capability>()) {
      final beforeState = beforeResult.nodeStates[cap.id] ?? B3State.notAssessed;
      final afterState = _simulationResult!.nodeStates[cap.id] ?? B3State.notAssessed;
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
      afterResult: _simulationResult!,
      beforePlan: beforePlan,
      afterPlan: _actionPlan!,
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
