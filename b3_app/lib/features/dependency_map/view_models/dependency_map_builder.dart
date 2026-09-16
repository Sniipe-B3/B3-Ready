import 'dart:convert';
import 'package:b3_engine/b3_engine.dart';
import '../models/dependency_node.dart';

class DependencyMapBuilder {
  final Map<String, dynamic> _kb;

  DependencyMapBuilder(String knowledgeBaseJson)
      : _kb = jsonDecode(knowledgeBaseJson);

  DependencyNode buildTree(String capabilityId, HouseholdConfig config, SimulationResult result) {
    final capDef = _getDef('capabilities', capabilityId);
    final capLabel = _getLabel(capDef, capabilityId);
    final capState = result.nodeStates[capabilityId] ?? B3State.notAssessed;

    final children = <DependencyNode>[];
    
    // Find assets that provide this capability AND are owned by user
    final possibleAssets = List<String>.from(capDef['assets'] ?? []);
    final ownedAssets = possibleAssets.where((a) => config.ownedAssets.contains(a)).toList();

    for (var assetId in ownedAssets) {
      final assetDef = _getDef('assets', assetId);
      final assetLabel = _getLabel(assetDef, assetId);
      final assetState = result.nodeStates[assetId] ?? B3State.notAssessed;
      
      final assetChildren = <DependencyNode>[];
      final reqs = List<String>.from(assetDef['requires'] ?? []);
      
      for (var reqId in reqs) {
        final reqType = _getTypeOf(reqId);
        final reqDef = _getDef(reqType == MapNodeType.system ? 'systems' : 'resources', reqId);
        final reqLabel = _getLabel(reqDef, reqId);
        final reqState = result.nodeStates[reqId] ?? B3State.notAssessed;
        
        assetChildren.add(DependencyNode(
          id: reqId,
          label: reqLabel,
          type: reqType,
          state: reqState,
        ));
      }

      children.add(DependencyNode(
        id: assetId,
        label: assetLabel,
        type: MapNodeType.asset,
        state: assetState,
        children: assetChildren,
      ));
    }

    return DependencyNode(
      id: capabilityId,
      label: capLabel,
      type: MapNodeType.capability,
      state: capState,
      children: children,
    );
  }

  String getCausePhrase(DependencyNode rootNode) {
    if (rootNode.state == B3State.maintained) {
      if (rootNode.children.length > 1) {
        return "Une alternative indépendante reste disponible.";
      }
      return "Votre solution principale reste disponible.";
    }

    if (rootNode.state == B3State.notAssessed) {
      return "Nous n'avons pas encore assez d'informations.";
    }

    final failedDeps = <String>{};
    for (var assetNode in rootNode.children) {
      for (var depNode in assetNode.children) {
        if (depNode.state == B3State.failed) {
          failedDeps.add(depNode.label.toLowerCase());
        }
      }
    }

    if (failedDeps.isEmpty) {
      if (rootNode.children.isEmpty) return "Aucun équipement déclaré pour ce besoin.";
      return "La situation est inconnue ou partiellement dégradée.";
    }

    final depsStr = failedDeps.toList().join(" et ");
    if (rootNode.children.length == 1) {
      return "Votre solution dépend de : $depsStr, indisponible(s) ici.";
    } else {
      return "Vos ${rootNode.children.length} solutions dépendent de : $depsStr, indisponible(s) ici.";
    }
  }

  Map<String, dynamic> _getDef(String collection, String id) {
    final list = _kb[collection] as List?;
    if (list != null) {
      return list.firstWhere((e) => e['id'] == id, orElse: () => <String, dynamic>{});
    }
    return {};
  }

  String _getLabel(Map<String, dynamic> def, String fallbackId) {
    // Dans notre knowledge_dataset, y'a-t-il un "name" ou "label"? 
    // Généralement, il n'y a pas toujours un "name".
    // Nous ajoutons une traduction manuelle pour un MVP clair et sans jargon,
    // car le dataset technique a des IDs comme "lampe_secteur".
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
    return map[fallbackId] ?? def['name'] ?? fallbackId;
  }

  MapNodeType _getTypeOf(String id) {
    final systems = _kb['systems'] as List?;
    if (systems != null && systems.any((s) => s['id'] == id)) return MapNodeType.system;
    return MapNodeType.resource;
  }
}
