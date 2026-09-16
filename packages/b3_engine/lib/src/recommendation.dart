import 'dart:convert';
import 'models.dart';
import 'data_mapper.dart';

enum RecommendationType {
  verify,
  organize,
  learn,
  useExisting,
  createAlternative,
  acquire,
  invest,
}

enum RecommendationPriority {
  high,
  medium,
  low,
}

class Recommendation {
  final String id;
  final RecommendationType type;
  final RecommendationPriority priority;
  final String capabilityId;
  final String title;
  final String description;
  final String reason;
  final String? targetAssetId;
  final String? targetResourceId;
  final Set<String> causeNodeIds;

  Recommendation({
    required this.id,
    required this.type,
    required this.priority,
    required this.capabilityId,
    required this.title,
    required this.description,
    required this.reason,
    this.targetAssetId,
    this.targetResourceId,
    this.causeNodeIds = const {},
  });

  @override
  String toString() {
    return '[$priority] $type - $title ($reason)';
  }
}

class RecommendationEngine {
  final String knowledgeJson;

  RecommendationEngine(this.knowledgeJson);

  List<Recommendation> generate(
      SimulationResult result, HouseholdConfig household, Scenario scenario) {
    final data = jsonDecode(knowledgeJson);
    final recommendations = <Recommendation>[];

    // Combinaison des vulnérabilités et incertitudes pour analyser les causes internes (ressources)
    final allIssues = [
      ...result.vulnerabilities.map((v) => {'cap': v.capability, 'state': v.state, 'causes': v.causeNodeIds}),
      ...result.uncertainties.map((u) => {'cap': u.capability, 'state': u.state, 'causes': u.causeNodeIds})
    ];

    for (var issue in allIssues) {
      final cap = issue['cap'] as Capability;
      final capState = issue['state'] as B3State;
      final causeNodeIds = issue['causes'] as Set<String>;
      final capId = cap.id;
      final capData =
          (data['capabilities'] as List).firstWhere((c) => c['id'] == capId);
      final capAssets = List<String>.from(capData['assets'] ?? []);

      final priority = capState == B3State.failed
          ? RecommendationPriority.high
          : (capState == B3State.degraded ? RecommendationPriority.medium : RecommendationPriority.high);

      final failedDeps = causeNodeIds.toList();
      
      String getHumanName(String id) {
        String? search(String listName) {
          final list = data[listName] as List?;
          if (list != null) {
            for (var item in list) {
              if (item is Map && item['id'] == id) {
                return item['name'] as String?;
              }
            }
          }
          return null;
        }
        
        return search('capabilities') ?? search('assets') ?? search('resources') ?? search('systems') ?? id;
      }
      
      final failedDepsNames = failedDeps.map(getHumanName).toList();
      String reasonPrefix = failedDepsNames.isNotEmpty
          ? 'Cause identifiée : ${failedDepsNames.join(", ")}. '
          : 'Aucune solution disponible. ';

      bool specificRecGenerated = false;

      for (var assetId in capAssets) {
        final assetData =
            (data['assets'] as List).firstWhere((a) => a['id'] == assetId);
        final requires = List<String>.from(assetData['requires'] ?? []);

        if (household.ownedAssets.contains(assetId)) {
          final assetCauses = result.getRootCauses(assetId);
          for (var causeId in assetCauses) {
            final state = result.nodeStates[causeId];
            final isResource =
                (data['resources'] as List?)?.any((r) => r['id'] == causeId) ??
                    false;

            if (isResource) {
              final resName = (data['resources'] as List)
                  .firstWhere((r) => r['id'] == causeId)['name'];
              if (state == B3State.degraded) {
                recommendations.add(Recommendation(
                  id: 'rec_org_${assetId}_$causeId',
                  type: RecommendationType.organize,
                  priority: priority,
                  capabilityId: capId,
                  title: 'Augmenter l\'autonomie : $resName',
                  description:
                      'Vous possédez cette solution mais les réserves sont insuffisantes pour tenir ${scenario.duration.inHours}h.',
                  reason: 'Ressource épuisée avant la fin du scénario.',
                  targetAssetId: assetId,
                  targetResourceId: causeId,
                  causeNodeIds: {causeId},
                ));
                specificRecGenerated = true;
              } else if (state == B3State.failed) {
                recommendations.add(Recommendation(
                  id: 'rec_acq_${assetId}_$causeId',
                  type: RecommendationType.acquire,
                  priority: priority,
                  capabilityId: capId,
                  title: 'Acquérir la ressource : $resName',
                  description:
                      'Votre équipement (${assetData['name']}) ne peut pas fonctionner sans cette ressource.',
                  reason: 'Ressource nécessaire absente.',
                  targetAssetId: assetId,
                  targetResourceId: causeId,
                  causeNodeIds: {causeId},
                ));
                specificRecGenerated = true;
              } else if (state == B3State.unknown ||
                  state == B3State.notAssessed) {
                recommendations.add(Recommendation(
                  id: 'rec_ver_${assetId}_$causeId',
                  type: RecommendationType.verify,
                  priority: priority,
                  capabilityId: capId,
                  title: 'Vérifier la disponibilité : $resName',
                  description:
                      'B3 ne sait pas si vous possédez suffisamment de cette ressource pour faire fonctionner votre équipement.',
                  reason: 'Prérequis inconnu.',
                  targetAssetId: assetId,
                  targetResourceId: causeId,
                  causeNodeIds: {causeId},
                ));
                specificRecGenerated = true;
              }
            }
          }
        } else {
          // L'utilisateur ne le possède pas
          // Ne générer des recommandations de création d'alternative que si la capacité est en échec/dégradée
          // Si la capacité est juste UNKNOWN, on ne propose pas d'acheter de nouveaux équipements
          if (capState == B3State.failed || capState == B3State.degraded) {
            bool survives = true;
            bool requiresResource = false;

            for (var req in requires) {
              if (scenario.systemOverrides[req] == B3State.failed) {
                survives = false;
                break;
              }
              if ((data['resources'] as List?)?.any((r) => r['id'] == req) ??
                  false) {
                requiresResource = true;
              }
            }

            if (survives) {
              String caveat = requiresResource
                  ? ' (sous réserve que le combustible/ressource nécessaire soit disponible)'
                  : '';

              recommendations.add(Recommendation(
                id: 'rec_alt_$assetId',
                type: RecommendationType.createAlternative,
                priority: priority,
                capabilityId: capId,
                title: 'Créer une alternative : ${assetData['name']}',
                description:
                    'Cette solution pourrait maintenir la capacité$caveat.',
                reason: reasonPrefix +
                    'Cette solution est indépendante des systèmes affectés.',
                targetAssetId: assetId,
                causeNodeIds: causeNodeIds,
              ));
            }
          }
        }
      }

      // Si c'est une incertitude et qu'aucune recommandation spécifique n'a été générée, on ajoute la générique
      if ((capState == B3State.unknown || capState == B3State.notAssessed) && !specificRecGenerated) {
        recommendations.add(Recommendation(
          id: 'rec_verify_$capId',
          type: RecommendationType.verify,
          priority: RecommendationPriority.high,
          capabilityId: capId,
          title: 'Évaluer la capacité ${cap.name}',
          description: 'Poursuivez le diagnostic pour lever cette incertitude.',
          reason: 'Information manquante ou incertaine (${capState.name}).',
          causeNodeIds: causeNodeIds,
        ));
      }
    }

    recommendations.sort((a, b) {
      if (a.priority != b.priority)
        return a.priority.index.compareTo(b.priority.index);
      if (a.type != b.type) return a.type.index.compareTo(b.type.index);
      return a.id.compareTo(b.id);
    });

    return recommendations;
  }
}
