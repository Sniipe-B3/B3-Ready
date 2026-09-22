import 'dart:convert';
import 'package:b3_engine/b3_engine.dart';

import '../models/scenario_analysis.dart';
import '../models/global_household_overview.dart';
import '../models/dependency_impact.dart';

class DependencyImpactAnalyzer {
  final String knowledgeJson;

  DependencyImpactAnalyzer(this.knowledgeJson);

  List<DependencyImpact> analyze(List<ScenarioAnalysis> analyses, List<CrossScenarioAction> actions) {
    final validAnalyses = analyses.where((a) => a.isAvailable && a.simulationResult != null).toList();
    
    // We will collect impacts by causeNodeId
    final Map<String, DependencyImpact> impacts = {};
    
    final kb = jsonDecode(knowledgeJson);
    String getNodeName(String id) {
      final collections = ['systems', 'resources', 'assets', 'capabilities'];
      for (var col in collections) {
        final list = kb[col] as List<dynamic>? ?? [];
        final node = list.firstWhere((n) => n['id'] == id, orElse: () => null);
        if (node != null) return node['name'] as String;
      }
      return id;
    }

    Set<String> getStructuralDependencies(B3Node start) {
      final deps = <String>{};
      void walk(B3Node node) {
        if (deps.contains(node.id)) return;
        deps.add(node.id);
        for (var c in node.children) { walk(c); }
      }
      walk(start);
      return deps;
    }

    for (var analysis in validAnalyses) {
      final scenarioId = analysis.scenarioId;
      final result = analysis.simulationResult!;
      final capabilities = analysis.graph!.whereType<Capability>();

      // Identify dependencies that are actually affected in this scenario
      // Usually, a scenario overrides some systems/resources to FAILED.
      // We look at all nodes that are FAILED or DEGRADED in the result, 
      // but to be considered a "Systemic Dependency", it should be a root cause of something, 
      // or at least a known System/Resource.
      for (var cap in capabilities) {
        final rootCauses = result.getRootCauses(cap.id);
        final structuralDeps = getStructuralDependencies(cap)..addAll(rootCauses);
        final state = result.nodeStates[cap.id] ?? B3State.notAssessed;

        for (var depId in structuralDeps) {
          if (depId == cap.id) continue; // Skip self

          // Only consider dependencies that are Systems or Resources (or assets?).
          // In b3_engine, root causes are typically scenario overrides or resource exhausted.
          // Let's filter to only those that are FAILED/DEGRADED in the scenario 
          // AND are actually causing an issue, or would cause an issue.
          final depState = result.nodeStates[depId];
          if (depState != B3State.failed && depState != B3State.degraded) {
            continue; // This dependency is not affected in this scenario, so it has no impact here.
          }

          if (!impacts.containsKey(depId)) {
            impacts[depId] = DependencyImpact(
              causeNodeId: depId,
              causeNodeName: getNodeName(depId),
              affectedCapabilityIds: {},
              affectedScenarioIds: {},
              maintainedCapabilityIds: {},
              vulnerableCapabilityIds: {},
              uncertainCapabilityIds: {},
              relatedActions: [],
            );
          }

          final impact = impacts[depId]!;
          impact.affectedCapabilityIds.add(cap.id);
          impact.affectedScenarioIds.add(scenarioId);

          if (state == B3State.failed || state == B3State.degraded) {
            if (rootCauses.contains(depId)) {
              impact.vulnerableCapabilityIds.add(cap.id);
            }
          } else if (state == B3State.unknown || state == B3State.notAssessed) {
            // UNKNOWN or NOT_ASSESSED
            impact.uncertainCapabilityIds.add(cap.id);
          } else if (state == B3State.maintained) {
            // It structurally depends on depId, depId is FAILED, but cap is MAINTAINED.
            // That means it's protected!
            impact.maintainedCapabilityIds.add(cap.id);
          }
        }
      }
    }

    // Now, relate actions from the GlobalHouseholdOverview
    for (var impact in impacts.values) {
      // Find all CrossScenarioActions that target capabilities affected by this impact,
      // AND explicitly list this impact.causeNodeId in their causeNodeIds.
      for (var action in actions) {
        if (action.causeNodeIds.contains(impact.causeNodeId)) {
          // Which capabilities does this action protect against this cause?
          // It's the intersection of the action's capabilityIds and the impact's affectedCapabilityIds.
          final relevantCaps = action.capabilityIds.intersection(impact.affectedCapabilityIds);
          if (relevantCaps.isNotEmpty) {
            impact.relatedActions.add(DependencyLeverageAction(
              crossScenarioActionId: action.id,
              dependencyNodeId: impact.causeNodeId,
              affectedCapabilityIds: relevantCaps,
              scenarioIds: action.scenarioIds.intersection(impact.affectedScenarioIds),
            ));
          }
        }
      }
    }

    final finalImpacts = impacts.values.where((i) {
      // Only keep structural dependencies that affect at least 2 capabilities OR 2 scenarios
      return i.affectedCapabilityIds.length >= 2 || i.affectedScenarioIds.length >= 2;
    }).toList();

    // Sort order:
    // 1. vulnerable capabilities count (desc)
    // 2. affected scenarios count (desc)
    // 3. deterministic name
    finalImpacts.sort((a, b) {
      int vCmp = b.vulnerableCapabilityIds.length.compareTo(a.vulnerableCapabilityIds.length);
      if (vCmp != 0) return vCmp;

      int sCmp = b.affectedScenarioIds.length.compareTo(a.affectedScenarioIds.length);
      if (sCmp != 0) return sCmp;

      return a.causeNodeId.compareTo(b.causeNodeId);
    });

    return finalImpacts;
  }
}
