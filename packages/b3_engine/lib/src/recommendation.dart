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

  Recommendation({
    required this.id,
    required this.type,
    required this.priority,
    required this.capabilityId,
    required this.title,
    required this.description,
    required this.reason,
    this.targetAssetId,
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
    SimulationResult result, 
    HouseholdConfig household, 
    Scenario scenario
  ) {
    final data = jsonDecode(knowledgeJson);
    final recommendations = <Recommendation>[];
    
    // 1. Gérer les incertitudes (UNKNOWN / NOT_ASSESSED)
    for (var unc in result.uncertainties) {
      recommendations.add(Recommendation(
        id: 'rec_verify_${unc.capability.id}',
        type: RecommendationType.verify,
        priority: RecommendationPriority.high,
        capabilityId: unc.capability.id,
        title: 'Évaluer la capacité ${unc.capability.name}',
        description: 'Poursuivez le diagnostic pour lever cette incertitude.',
        reason: 'Information manquante ou incertaine (${unc.state.name}).',
      ));
    }

    // 2. Gérer les vulnérabilités (FAILED / DEGRADED)
    for (var vuln in result.vulnerabilities) {
      final capId = vuln.capability.id;
      final capData = (data['capabilities'] as List).firstWhere((c) => c['id'] == capId);
      final capAssets = List<String>.from(capData['assets'] ?? []);
      
      final priority = vuln.state == B3State.failed ? RecommendationPriority.high : RecommendationPriority.medium;

      final capTrace = result.traces[capId];
      final failedDeps = <String>[];
      if (capTrace != null && capTrace.steps.isNotEmpty) {
         final lastStep = capTrace.steps.last;
         if (lastStep.dependencyStates != null) {
            lastStep.dependencyStates!.forEach((depId, state) {
              if (state == B3State.failed) failedDeps.add(depId);
            });
         }
      }
      
      String reasonPrefix = failedDeps.isNotEmpty 
          ? 'Votre équipement actuel (${failedDeps.join(", ")}) est défaillant. ' 
          : 'Aucune solution disponible. ';

      for (var assetId in capAssets) {
        final assetData = (data['assets'] as List).firstWhere((a) => a['id'] == assetId);
        final requires = List<String>.from(assetData['requires'] ?? []);

        if (household.ownedAssets.contains(assetId)) {
          final assetTrace = result.traces[assetId];
          if (assetTrace != null && assetTrace.steps.isNotEmpty) {
             final lastStep = assetTrace.steps.last;
             
             if (lastStep.dependencyStates != null) {
               lastStep.dependencyStates!.forEach((depId, state) {
                 final isResource = (data['resources'] as List?)?.any((r) => r['id'] == depId) ?? false;
                 if (isResource) {
                   final resName = (data['resources'] as List).firstWhere((r) => r['id'] == depId)['name'];
                   if (state == B3State.degraded || lastStep.type == ReasonType.resourceExhausted) {
                     recommendations.add(Recommendation(
                        id: 'rec_org_${assetId}_$depId',
                        type: RecommendationType.organize,
                        priority: priority,
                        capabilityId: capId,
                        title: 'Augmenter l\'autonomie : $resName',
                        description: 'Vous possédez cette solution mais les réserves sont insuffisantes pour tenir ${scenario.duration.inHours}h.',
                        reason: 'Ressource épuisée avant la fin du scénario.',
                        targetAssetId: assetId,
                     ));
                   } else if (state == B3State.failed) {
                     recommendations.add(Recommendation(
                        id: 'rec_acq_${assetId}_$depId',
                        type: RecommendationType.acquire,
                        priority: priority,
                        capabilityId: capId,
                        title: 'Acquérir la ressource : $resName',
                        description: 'Votre équipement (${assetData['name']}) ne peut pas fonctionner sans cette ressource.',
                        reason: 'Ressource nécessaire absente.',
                        targetAssetId: assetId,
                     ));
                   } else if (state == B3State.unknown || state == B3State.notAssessed) {
                     recommendations.add(Recommendation(
                        id: 'rec_ver_${assetId}_$depId',
                        type: RecommendationType.verify,
                        priority: priority,
                        capabilityId: capId,
                        title: 'Vérifier la disponibilité : $resName',
                        description: 'B3 ne sait pas si vous possédez suffisamment de cette ressource pour faire fonctionner votre équipement.',
                        reason: 'Prérequis inconnu.',
                        targetAssetId: assetId,
                     ));
                   }
                 }
               });
             }
          }
        } else {
          // L'utilisateur ne le possède pas
          bool survives = true;
          bool requiresResource = false;
          
          for (var req in requires) {
            if (scenario.systemOverrides[req] == B3State.failed) {
              survives = false;
              break;
            }
            if ((data['resources'] as List?)?.any((r) => r['id'] == req) ?? false) {
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
                description: 'Cette solution pourrait maintenir la capacité$caveat.',
                reason: reasonPrefix + 'Cette solution est indépendante des systèmes affectés.',
                targetAssetId: assetId,
             ));
          }
        }
      }
    }
    
    recommendations.sort((a, b) {
      if (a.priority != b.priority) return a.priority.index.compareTo(b.priority.index);
      if (a.type != b.type) return a.type.index.compareTo(b.type.index);
      return a.id.compareTo(b.id);
    });
    
    return recommendations;
  }
}
