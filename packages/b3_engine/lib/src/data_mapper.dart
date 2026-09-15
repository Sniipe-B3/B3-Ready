import 'dart:convert';
import 'models.dart';

class HouseholdConfig {
  final List<String> ownedAssets;
  final Map<String, Duration> resourceDurations;
  final Set<String> assessedCapabilities;
  final Map<String, B3State> capabilityOverrides;

  HouseholdConfig({
    required this.ownedAssets, 
    this.resourceDurations = const {},
    this.assessedCapabilities = const {},
    this.capabilityOverrides = const {},
  });
}

class DataMapper {
  static List<B3Node> buildGraph(String knowledgeJson, HouseholdConfig household) {
    final data = jsonDecode(knowledgeJson);
    final nodes = <String, B3Node>{};
    
    if (data['systems'] != null) {
      for (var sys in data['systems']) {
        nodes[sys['id']] = System(id: sys['id'], name: sys['name']);
      }
    }
    
    if (data['resources'] != null) {
      for (var res in data['resources']) {
        nodes[res['id']] = Resource(id: res['id'], name: res['name'], duration: household.resourceDurations[res['id']]);
      }
    }
    
    if (data['assets'] != null) {
      for (var assetData in data['assets']) {
        final id = assetData['id'];
        if (!household.ownedAssets.contains(id)) continue;
        final children = <B3Node>[];
        if (assetData['requires'] != null) {
          for (var reqId in assetData['requires']) {
            if (nodes.containsKey(reqId)) children.add(nodes[reqId]!);
          }
        }
        nodes[id] = Asset(id: id, name: assetData['name'], children: children);
      }
    }
    
    if (data['capabilities'] != null) {
      for (var capData in data['capabilities']) {
        final id = capData['id'];
        final children = <B3Node>[];
        if (capData['assets'] != null) {
          for (var assetId in capData['assets']) {
            if (nodes.containsKey(assetId)) children.add(nodes[assetId]!);
          }
        }
        
        B3State? override = household.capabilityOverrides[id];
        if (override == null) {
          if (children.isEmpty) {
            if (!household.assessedCapabilities.contains(id)) {
              override = B3State.notAssessed; // Never asked -> Not Assessed
            }
            // else: it was assessed, user said "I have nothing", so it has 0 children. The engine will evaluate evaluateAny([]) = failed.
          }
        }

        nodes[id] = Capability(id: id, name: capData['name'], children: children, overriddenState: override);
      }
    }
    
    return nodes.values.toList();
  }

  static Scenario parseScenario(String knowledgeJson, String scenarioId) {
    final data = jsonDecode(knowledgeJson);
    if (data['scenarios'] != null) {
      for (var scen in data['scenarios']) {
        if (scen['id'] == scenarioId) {
          final overrides = <String, B3State>{};
          if (scen['overrides'] != null) {
            scen['overrides'].forEach((k, v) {
              if (v == 'failed') overrides[k] = B3State.failed;
              if (v == 'maintained') overrides[k] = B3State.maintained;
              if (v == 'degraded') overrides[k] = B3State.degraded;
              if (v == 'unknown') overrides[k] = B3State.unknown;
              if (v == 'notAssessed') overrides[k] = B3State.notAssessed;
            });
          }
          return Scenario(name: scen['name'], duration: Duration(hours: scen['duration'] ?? 0), systemOverrides: overrides);
        }
      }
    }
    throw Exception('Scenario not found');
  }
}
