import 'dart:convert';
import 'models.dart';

class HouseholdConfig {
  final List<String> ownedAssets;
  final Map<String, Duration> resourceDurations;

  HouseholdConfig({required this.ownedAssets, this.resourceDurations = const {}});
}

class DataMapper {
  static List<B3Node> buildGraph(String knowledgeJson, HouseholdConfig household) {
    final data = jsonDecode(knowledgeJson);
    
    final nodes = <String, B3Node>{};
    
    // 1. Systems
    if (data['systems'] != null) {
      for (var sys in data['systems']) {
        nodes[sys['id']] = System(id: sys['id'], name: sys['name']);
      }
    }
    
    // 2. Resources (Only those present in household config or generic if no duration needed)
    if (data['resources'] != null) {
      for (var res in data['resources']) {
        final duration = household.resourceDurations[res['id']];
        // If a resource is not explicitly in household, we still create it but it might fail or we can default to maintained if unconstrained.
        // For B3: if it's a consumable and not in household, it's failed by default, or we can just model what they have.
        // Let's create all, but if it requires duration and they have 0, it's degraded/failed.
        nodes[res['id']] = Resource(id: res['id'], name: res['name'], duration: duration);
      }
    }
    
    // 3. Assets (Only those OWNED by household)
    if (data['assets'] != null) {
      for (var assetData in data['assets']) {
        final id = assetData['id'];
        if (!household.ownedAssets.contains(id)) continue;
        
        final children = <B3Node>[];
        if (assetData['requires'] != null) {
          for (var reqId in assetData['requires']) {
            if (nodes.containsKey(reqId)) {
              children.add(nodes[reqId]!);
            }
          }
        }
        nodes[id] = Asset(id: id, name: assetData['name'], children: children);
      }
    }
    
    // 4. Capabilities
    if (data['capabilities'] != null) {
      for (var capData in data['capabilities']) {
        final id = capData['id'];
        final children = <B3Node>[];
        if (capData['assets'] != null) {
          for (var assetId in capData['assets']) {
            // Only add the asset to capability if the household owns it (i.e. it exists in nodes)
            if (nodes.containsKey(assetId)) {
              children.add(nodes[assetId]!);
            }
          }
        }
        nodes[id] = Capability(id: id, name: capData['name'], children: children);
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
            });
          }
          return Scenario(
            name: scen['name'],
            duration: Duration(hours: scen['duration'] ?? 0),
            systemOverrides: overrides,
          );
        }
      }
    }
    throw Exception('Scenario not found');
  }
}
