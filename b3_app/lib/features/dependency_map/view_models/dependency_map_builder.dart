import 'dart:convert';
import 'package:b3_engine/b3_engine.dart';
import '../models/dependency_node.dart';

class DependencyMapBuilder {
  final Map<String, dynamic> _kb;

  DependencyMapBuilder(String knowledgeBaseJson)
      : _kb = jsonDecode(knowledgeBaseJson);

  DependencyNode buildTree(String capabilityId, HouseholdConfig config, SimulationResult result) {
    return _buildNode(capabilityId, config, result, {});
  }

  DependencyNode _buildNode(String id, HouseholdConfig config, SimulationResult result, Set<String> visited) {
    if (visited.contains(id)) {
      final type = _getTypeOf(id);
      final def = _getDefForType(type, id);
      final label = _getLabel(def, id);
      final state = result.nodeStates[id] ?? B3State.notAssessed;
      return DependencyNode(id: id, label: label, type: type, state: state, children: []);
    }

    final newVisited = Set<String>.from(visited)..add(id);
    final type = _getTypeOf(id);
    final def = _getDefForType(type, id);
    final label = _getLabel(def, id);
    final state = result.nodeStates[id] ?? B3State.notAssessed;

    List<DependencyNode> children = [];

    if (type == MapNodeType.capability) {
      final possibleAssets = List<String>.from(def['assets'] ?? []);
      final ownedAssets = possibleAssets.where((a) => config.ownedAssets.contains(a)).toList();
      for (var aId in ownedAssets) {
        children.add(_buildNode(aId, config, result, newVisited));
      }
    } else {
      final reqs = List<String>.from(def['requires'] ?? []);
      for (var rId in reqs) {
        children.add(_buildNode(rId, config, result, newVisited));
      }
    }

    return DependencyNode(
      id: id,
      label: label,
      type: type,
      state: state,
      children: children,
    );
  }

  Map<String, dynamic> _getDefForType(MapNodeType type, String id) {
    switch (type) {
      case MapNodeType.capability: return _getDef('capabilities', id);
      case MapNodeType.asset: return _getDef('assets', id);
      case MapNodeType.system: return _getDef('systems', id);
      case MapNodeType.resource: return _getDef('resources', id);
    }
  }

  String getCausePhrase(DependencyNode rootNode) {
    if (rootNode.state == B3State.notAssessed) {
      return "Nous n'avons pas encore assez d'informations.";
    }

    if (rootNode.state == B3State.unknown) {
      return "La situation est inconnue pour ce besoin.";
    }

    if (rootNode.state == B3State.maintained) {
      bool hasFailedOrDegradedChildren = rootNode.children.any((c) => c.state == B3State.failed || c.state == B3State.degraded);
      if (hasFailedOrDegradedChildren) {
        return "Une autre solution reste disponible malgré cette panne.";
      }
      return "Votre solution principale reste disponible.";
    }
    
    if (rootNode.state == B3State.degraded) {
       return "Ce besoin est partiellement dégradé (ressource limitée).";
    }

    if (rootNode.state == B3State.failed) {
      if (rootNode.children.isEmpty) return "Aucun équipement déclaré pour ce besoin.";

      final causesByAsset = <String, Set<String>>{};
      for (var assetNode in rootNode.children) {
        if (assetNode.state == B3State.failed) {
           final failedDeps = _findFailedDependencies(assetNode);
           if (failedDeps.isNotEmpty) {
             causesByAsset[assetNode.label] = failedDeps;
           }
        }
      }

      if (causesByAsset.isEmpty) {
        return "Indisponibilité confirmée (causes détaillées dans l'arbre).";
      }

      if (rootNode.children.length == 1) {
        final depsStr = causesByAsset.values.first.join(" et ");
        return "Votre solution dépend de : $depsStr, indisponible(s) ici.";
      } else {
        final allCausesList = causesByAsset.values.toList();
        bool sameCauses = true;
        if (allCausesList.isNotEmpty) {
          final firstCauses = allCausesList.first;
          for (var causes in allCausesList) {
            if (causes.length != firstCauses.length || !causes.containsAll(firstCauses)) {
              sameCauses = false;
              break;
            }
          }
          if (sameCauses) {
            return "Vos ${rootNode.children.length} solutions dépendent de : ${firstCauses.join(" et ")}, indisponible(s) ici.";
          }
        }

        final buffer = StringBuffer("Vos solutions sont toutes indisponibles dans ce scénario.");
        causesByAsset.forEach((asset, causes) {
          buffer.write("\n• $asset : ${causes.join(" et ")} indisponible(s)");
        });
        return buffer.toString();
      }
    }
    return "État non pris en charge.";
  }

  Set<String> _findFailedDependencies(DependencyNode node, [Set<String>? visited]) {
    visited ??= {};
    if (visited.contains(node.id)) return {};
    visited.add(node.id);

    final failed = <String>{};
    if (node.children.isEmpty) {
        if (node.state == B3State.failed) {
            failed.add(node.label.toLowerCase());
        }
        return failed;
    }
    
    bool hasFailedChild = false;
    for (var child in node.children) {
      if (child.state == B3State.failed) {
        hasFailedChild = true;
        failed.addAll(_findFailedDependencies(child, visited));
      }
    }
    
    if (!hasFailedChild && node.state == B3State.failed) {
       failed.add(node.label.toLowerCase());
    }
    return failed;
  }

  Map<String, dynamic> _getDef(String collection, String id) {
    final list = _kb[collection] as List?;
    if (list != null) {
      return list.firstWhere((e) => e['id'] == id, orElse: () => <String, dynamic>{});
    }
    return {};
  }

  String _getLabel(Map<String, dynamic> def, String fallbackId) {
    if (def.containsKey('name') && def['name'] != null && def['name'].toString().isNotEmpty) {
      return def['name'];
    }
    
    // minimal fallback if absolutely needed, but ideally rely on dataset
    final map = {
      'chauffer': 'Se chauffer',
      'cuisiner': 'Cuisiner',
      'eclairage': 'S\'éclairer',
      'radiateur_elec': 'Radiateur électrique',
      'pompe_chaleur': 'Pompe à chaleur',
      'chaudiere_gaz': 'Chaudière gaz',
      'chaudiere_bois': 'Chaudière bois/granulés',
      'poele_granules': 'Poêle à granulés',
      'poele_bois': 'Poêle à bûches',
      'plaque_elec': 'Plaque électrique',
      'four_elec': 'Four électrique',
      'gaziniere_ville': 'Gazinière (ville)',
      'rechaud_gaz': 'Réchaud gaz',
      'barbecue': 'Barbecue',
      'lampe_secteur': 'Lumière (secteur)',
      'lampe_batterie': 'Lampe (batterie)',
      'elec': 'Réseau électrique',
      'reseau_gaz': 'Réseau de gaz',
      'bois': 'Bois',
      'granules': 'Granulés',
      'gaz_bouteille': 'Bouteille de gaz',
      'charbon': 'Charbon',
      'batterie': 'Piles / Batterie'
    };
    
    if (map.containsKey(fallbackId)) {
      return map[fallbackId]!;
    }
    
    throw StateError("No human readable label found for entity $fallbackId. Raw ID is not allowed in UI.");
  }

  MapNodeType _getTypeOf(String id) {
    if ((_kb['capabilities'] as List?)?.any((e) => e['id'] == id) ?? false) return MapNodeType.capability;
    if ((_kb['assets'] as List?)?.any((e) => e['id'] == id) ?? false) return MapNodeType.asset;
    if ((_kb['systems'] as List?)?.any((e) => e['id'] == id) ?? false) return MapNodeType.system;
    return MapNodeType.resource;
  }
}
