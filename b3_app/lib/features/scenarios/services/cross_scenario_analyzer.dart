import 'dart:convert';
import 'package:b3_engine/b3_engine.dart';
import '../../action_plan/models/action_plan.dart';
import '../models/scenario_analysis.dart';
import '../models/global_household_overview.dart';

class CrossScenarioAnalyzer {
  final String knowledgeJson;

  CrossScenarioAnalyzer(this.knowledgeJson);

  GlobalHouseholdOverview analyze(List<ScenarioAnalysis> analyses) {
    final validAnalyses = analyses.where((a) => a.isAvailable).toList();

    final Map<String, Map<String, B3State>> capabilityStates = {};
    final Map<String, Map<String, B3State>> uncertaintyStates = {};
    final Map<String, CommonDependencyIssue> dependencies = {};
    final Map<String, CrossScenarioAction> actionsMap = {};

    final kb = jsonDecode(knowledgeJson);
    
    // Check all collections for the id
    String getNodeName(String id) {
      final collections = ['systems', 'resources', 'assets', 'capabilities'];
      for (var col in collections) {
        final list = kb[col] as List<dynamic>? ?? [];
        final node = list.firstWhere((n) => n['id'] == id, orElse: () => null);
        if (node != null) {
          return node['name'] as String;
        }
      }
      return id; // fallback
    }

    for (var analysis in validAnalyses) {
      final scenarioId = analysis.scenarioId;
      final result = analysis.simulationResult;

      if (result == null) continue;

      // Capabilities
      final capabilities = analysis.graph!.whereType<Capability>();
      for (var cap in capabilities) {
        final state = result.nodeStates[cap.id] ?? B3State.notAssessed;

        if (state == B3State.failed || state == B3State.degraded) {
          capabilityStates.putIfAbsent(cap.id, () => {})[scenarioId] = state;

          // Causes
          final causes = result.getRootCauses(cap.id);
          for (var causeId in causes) {
            if (!dependencies.containsKey(causeId)) {
              dependencies[causeId] = CommonDependencyIssue(
                causeNodeId: causeId,
                causeNodeName: getNodeName(causeId),
                capabilityIds: {},
                scenarioIds: {},
              );
            }
            dependencies[causeId]!.capabilityIds.add(cap.id);
            dependencies[causeId]!.scenarioIds.add(scenarioId);
          }
        } else if (state == B3State.unknown || state == B3State.notAssessed) {
          uncertaintyStates.putIfAbsent(cap.id, () => {})[scenarioId] = state;
        }
      }

      // Uncertainties (Resources and Assets)
      for (var entry in result.nodeStates.entries) {
        if (entry.value == B3State.unknown || entry.value == B3State.notAssessed) {
          uncertaintyStates.putIfAbsent(entry.key, () => {})[scenarioId] = entry.value;
        }
      }

      // Actions
      if (analysis.actionPlan != null) {
        for (var item in analysis.actionPlan!.items) {
          final target = item.targetResourceId ?? item.targetAssetId;
          final String fallbackTarget;
          if (target != null) {
            fallbackTarget = target;
          } else if (item.capabilityIds.isNotEmpty) {
            final caps = item.capabilityIds.toList()..sort();
            fallbackTarget = caps.join('_');
          } else if (item.causeNodeIds.isNotEmpty) {
            final causes = item.causeNodeIds.toList()..sort();
            fallbackTarget = causes.join('_');
          } else {
            fallbackTarget = 'null';
          }
          final actionId = '${item.type.name}_$fallbackTarget';

          if (!actionsMap.containsKey(actionId)) {
            actionsMap[actionId] = CrossScenarioAction(
              id: actionId,
              title: item.title,
              type: item.type,
              targetAssetId: item.targetAssetId,
              targetResourceId: item.targetResourceId,
              scenarioIds: {},
              capabilityIds: {},
              prioritiesByScenario: {},
              reasonsByScenario: {},
              causeNodeIds: {},
            );
          }

          final action = actionsMap[actionId]!;
          action.scenarioIds.add(scenarioId);
          action.capabilityIds.addAll(item.capabilityIds);
          action.causeNodeIds.addAll(item.causeNodeIds);
          action.prioritiesByScenario[scenarioId] = item.priority;
          action.reasonsByScenario[scenarioId] = item.reason;
        }
      }
    }

    final recurringIssues = capabilityStates.entries
      .where((e) => e.value.length >= 2) // Must be at least 2 scenarios
      .map((e) {
      return RecurringCapabilityIssue(
        capabilityId: e.key,
        capabilityName: getNodeName(e.key),
        statesByScenario: e.value,
      );
    }).toList();

    // Filter dependencies: must affect multiple capabilities OR multiple scenarios
    final commonDependencies = dependencies.values
      .where((d) => d.scenarioIds.length >= 2 || d.capabilityIds.length >= 2)
      .toList();
    commonDependencies.sort((a, b) {
      int sCmp = b.scenarioIds.length.compareTo(a.scenarioIds.length);
      if (sCmp != 0) return sCmp;
      return b.capabilityIds.length.compareTo(a.capabilityIds.length);
    });

    final actions = actionsMap.values.toList();
    
    // Sort logic
    int priorityValue(ActionPriority p) {
      switch (p) {
        case ActionPriority.essential: return 0;
        case ActionPriority.important: return 1;
        case ActionPriority.toVerify: return 2;
        case ActionPriority.improvement: return 3;
      }
    }

    int typeValue(RecommendationType t) {
      switch (t) {
        case RecommendationType.verify: return 0;
        case RecommendationType.useExisting: return 1;
        case RecommendationType.organize: return 2;
        case RecommendationType.learn: return 3;
        case RecommendationType.createAlternative: return 4;
        case RecommendationType.acquire: return 5;
        case RecommendationType.invest: return 6;
      }
    }

    actions.sort((a, b) {
      int pCmp = priorityValue(a.highestPriority).compareTo(priorityValue(b.highestPriority));
      if (pCmp != 0) return pCmp;

      int tCmp = typeValue(a.type).compareTo(typeValue(b.type));
      if (tCmp != 0) return tCmp;

      int sCmp = b.scenarioIds.length.compareTo(a.scenarioIds.length);
      if (sCmp != 0) return sCmp;

      int cCmp = b.capabilityIds.length.compareTo(a.capabilityIds.length);
      if (cCmp != 0) return cCmp;

      return a.id.compareTo(b.id);
    });

    final uncertainties = uncertaintyStates.entries.map((e) {
      return GlobalUncertainty(
        nodeId: e.key,
        nodeName: getNodeName(e.key),
        statesByScenario: e.value,
      );
    }).toList();
    
    uncertainties.sort((a, b) {
       int sCmp = b.scenarioIds.length.compareTo(a.scenarioIds.length);
       if (sCmp != 0) return sCmp;
       return a.nodeName.compareTo(b.nodeName);
    });
    
    recurringIssues.sort((a, b) {
       int sCmp = b.scenarioIds.length.compareTo(a.scenarioIds.length);
       if (sCmp != 0) return sCmp;
       return a.capabilityName.compareTo(b.capabilityName);
    });

    return GlobalHouseholdOverview(
      recurringIssues: recurringIssues,
      commonDependencies: commonDependencies,
      actions: actions,
      uncertainties: uncertainties,
    );
  }
}
