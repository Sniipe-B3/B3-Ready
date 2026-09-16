import 'dart:convert';
import 'package:b3_engine/b3_engine.dart';
import '../models/dependency_node.dart';

class DependencyMapBuilder {
  final Map<String, dynamic> _kb;
  final List<B3Node> _graph;

  DependencyMapBuilder(String knowledgeBaseJson, this._graph)
      : _kb = jsonDecode(knowledgeBaseJson);

  DependencyNode buildTree(String capabilityId, SimulationResult result) {
    final capNode = _graph.firstWhere((n) => n.id == capabilityId, orElse: () => throw Exception('Capability not found in graph'));
    return _buildNodeFromB3Node(capNode, result, {});
  }

  DependencyNode _buildNodeFromB3Node(B3Node b3Node, SimulationResult result, Set<String> visited) {
    if (visited.contains(b3Node.id)) {
      final type = _getB3NodeType(b3Node);
      final def = _getDefForType(type, b3Node.id);
      final label = _getLabel(def, b3Node.id);
      final state = result.nodeStates[b3Node.id] ?? B3State.notAssessed;
      return DependencyNode(id: b3Node.id, label: label, type: type, state: state, children: []);
    }

    final newVisited = Set<String>.from(visited)..add(b3Node.id);
    final type = _getB3NodeType(b3Node);
    final def = _getDefForType(type, b3Node.id);
    final label = _getLabel(def, b3Node.id);
    final state = result.nodeStates[b3Node.id] ?? B3State.notAssessed;

    List<DependencyNode> children = [];
    for (var childB3Node in b3Node.children) {
      children.add(_buildNodeFromB3Node(childB3Node, result, newVisited));
    }

    return DependencyNode(
      id: b3Node.id,
      label: label,
      type: type,
      state: state,
      children: children,
    );
  }

  MapNodeType _getB3NodeType(B3Node node) {
    if (node is Capability) return MapNodeType.capability;
    if (node is Asset) return MapNodeType.asset;
    if (node is System) return MapNodeType.system;
    return MapNodeType.resource;
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

// Removed _getTypeOf
}
