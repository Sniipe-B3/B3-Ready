import 'dart:convert';
import 'package:b3_app/features/action_plan/models/action_plan.dart';
import 'package:b3_app/features/action_plan/models/guided_action_details.dart';
import 'package:b3_engine/b3_engine.dart';

class GuidedActionMapper {
  final String knowledgeJson;
  late final Map<String, dynamic> kb;

  GuidedActionMapper(this.knowledgeJson) {
    kb = jsonDecode(knowledgeJson);
  }

  String _getNodeName(String id) {
    for (var type in ['capabilities', 'scenarios', 'systems', 'assets', 'resources']) {
      if (kb[type] != null) {
        for (var node in kb[type]) {
          if (node['id'] == id) return node['name'] ?? id;
        }
      }
    }
    return id;
  }

  GuidedActionDetails map(ActionPlanItem item, String? scenarioId) {
    String title = item.title;
    // Fix vague titles
    if (title == 'Préparer une alternative' || title == 'Envisager une solution' || title == 'Améliorer votre résilience') {
       title = 'Explorer une alternative de secours';
    } else if (title == 'Organiser cette solution') {
       title = 'Organiser et préparer ce matériel';
    }
    
    String ctaLabel = "Mettre à jour mon foyer";
    String why = item.reason;
    String todo = item.description;
    
    switch (item.type) {
      case RecommendationType.verify:
        ctaLabel = "Vérifier mon matériel";
        if (item.targetAssetId == 'stock_eau_potable') {
           why = "B3 a enregistré cette réserve, mais son autonomie réelle est inconnue.";
        } else {
           why = "$why\nCette solution est listée, mais son état ou son autonomie n'ont pas été vérifiés.";
        }
        break;
      case RecommendationType.useExisting:
        ctaLabel = "Configurer cette solution";
        why = "$why\nVous possédez déjà cet équipement, il peut servir de solution de secours.";
        break;
      case RecommendationType.organize:
        ctaLabel = "Marquer comme organisé";
        why = "$why\nUne bonne organisation permet de réagir plus vite lors d'une crise.";
        break;
      case RecommendationType.learn:
        ctaLabel = "Marquer comme appris";
        why = "$why\nPosséder l'équipement n'est utile que si vous savez l'utiliser.";
        break;
      case RecommendationType.createAlternative:
        ctaLabel = "Voir mes options";
        why = "$why\nUne alternative indépendante réduirait la dépendance identifiée.";
        break;
      case RecommendationType.acquire:
        ctaLabel = "J'ai ajouté cette solution";
        if (item.targetAssetId != null) {
          final assetName = _getNodeName(item.targetAssetId!);
          todo = "Ajoutez la solution identifiée par B3 : $assetName.";
        }
        break;
      case RecommendationType.invest:
        ctaLabel = "Explorer cette amélioration";
        why = "$why\nUn investissement structurel améliorerait durablement l'autonomie de votre foyer.";
        break;
    }

    if (item.targetAssetId == 'especes_disponibles' || item.capabilityIds.contains('effectuer_paiement_essentiel')) {
       if (item.type == RecommendationType.createAlternative || item.type == RecommendationType.acquire) {
          todo = "Les espèces constituent une option possible pour une alternative au réseau de paiement électronique.";
       }
    }

    // Explication Causale
    final List<String> chain = [];
    if (item.capabilityIds.isNotEmpty) {
      chain.add(_getNodeName(item.capabilityIds.first));
    }
    // We only show targetAsset if it's explicitly linked as the vulnerability point 
    // BUT the item doesn't give us the "broken asset" directly, it gives us targetAssetId which is the solution to acquire.
    // So we just show capability -> cause -> scenario to avoid inventing a false chain.
    if (item.causeNodeIds.isNotEmpty) {
      final causes = item.causeNodeIds.map((id) => _getNodeName(id)).join(', ');
      chain.add(causes);
    }
    if (scenarioId != null) {
      chain.add(_getNodeName(scenarioId));
    }
    
    final observed = chain.join(' → ');

    return GuidedActionDetails(
      item: item,
      title: title,
      why: why.trim(),
      observed: observed.trim(),
      todo: todo.trim(),
      ctaLabel: ctaLabel,
    );
  }
}
