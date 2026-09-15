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
          // L'utilisateur le possède déjà mais il a échoué (ou dégradé)
          bool isResourceExhausted = false;
          final assetTrace = result.traces[assetId];
          if (assetTrace != null && assetTrace.steps.isNotEmpty) {
             final lastStep = assetTrace.steps.last;
             if (lastStep.type == ReasonType.resourceExhausted) isResourceExhausted = true;
             
             // Check children recursively for resource exhaustion
             if (lastStep.dependencyStates != null) {
               for (var depId in lastStep.dependencyStates!.keys) {
                 final depTrace = result.traces[depId];
                 if (depTrace != null && depTrace.steps.isNotEmpty && depTrace.steps.last.type == ReasonType.resourceExhausted) {
                   isResourceExhausted = true;
                 }
               }
             }
             
             if (isResourceExhausted) {
                // Manque de ressource (ex: bois, gaz, batterie)
                recommendations.add(Recommendation(
                  id: 'rec_org_$assetId',
                  type: RecommendationType.organize,
                  priority: priority,
                  capabilityId: capId,
                  title: 'Augmenter l\'autonomie : ${assetData['name']}',
                  description: 'Vous possédez cette solution mais les réserves sont insuffisantes pour tenir ${scenario.duration.inHours}h.',
                  reason: 'Ressource épuisée avant la fin du scénario.',
                  targetAssetId: assetId,
                ));
             }
          }
        } else {
          // L'utilisateur ne le possède pas. Est-ce une bonne alternative ?
          bool survives = true;
          for (var req in requires) {
            if (scenario.systemOverrides[req] == B3State.failed) {
              survives = false;
              break;
            }
          }
          
          if (survives) {
             recommendations.add(Recommendation(
                id: 'rec_alt_$assetId',
                type: RecommendationType.createAlternative,
                priority: priority,
                capabilityId: capId,
                title: 'Créer une alternative : ${assetData['name']}',
                description: 'Ajouter cette solution permettrait de restaurer la capacité.',
                reason: reasonPrefix + 'Cette solution est indépendante des systèmes affectés.',
                targetAssetId: assetId,
             ));
          }
        }
      }
    }
    
    // Assurer le déterminisme de la liste
    recommendations.sort((a, b) {
      if (a.priority != b.priority) return a.priority.index.compareTo(b.priority.index);
      if (a.type != b.type) return a.type.index.compareTo(b.type.index);
      return a.id.compareTo(b.id);
    });
    
    return recommendations;
  }
}
