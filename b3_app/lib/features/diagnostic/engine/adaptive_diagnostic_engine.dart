import 'dart:convert';
import 'package:b3_engine/b3_engine.dart';
import '../../../data/app_knowledge_dataset.dart';

class AdaptiveDiagnosticEngine {
  final List<DiagnosticQuestion> questions;
  final Set<String> _resourceIds = {};
  final Map<String, List<String>> _assetReqs = {};
  final Map<String, List<String>> _capabilityAssets = {};

  AdaptiveDiagnosticEngine(this.questions) {
    final kb = jsonDecode(appKnowledgeBase);
    
    // Identifier toutes les ressources
    for (var r in kb['resources'] ?? []) {
      _resourceIds.add(r['id']);
    }
    
    // Mapper les dépendances des équipements (assets -> requires)
    for (var a in kb['assets'] ?? []) {
      _assetReqs[a['id']] = List<String>.from(a['requires'] ?? []);
    }
    
    // Mapper les capacités vers leurs équipements (capability -> assets)
    for (var c in kb['capabilities'] ?? []) {
      _capabilityAssets[c['id']] = List<String>.from(c['assets'] ?? []);
    }
  }

  DiagnosticQuestion? getNextQuestion(DiagnosticState state) {
    final config = state.toHouseholdConfig(questions);
    
    // 1. Déterminer les ressources nécessaires pour les équipements que le foyer possède
    final neededResources = <String>{};
    for (var assetId in config.ownedAssets) {
      final reqs = _assetReqs[assetId] ?? [];
      for (var req in reqs) {
        if (_resourceIds.contains(req)) {
          neededResources.add(req);
        }
      }
    }

    DiagnosticQuestion? bestQuestion;
    int maxScore = -1;

    for (var q in questions) {
      // Ignorer les questions déjà répondues
      if (state.answers.containsKey(q.id)) continue;

      // Vérifier les conditions d'affichage basiques (ex: afficher "combien de bois ?" seulement si "poêle à bois")
      if (q.condition != null) {
        final prev = state.answers[q.condition!.dependsOnQuestionId];
        if (prev == null || !prev.contains(q.condition!.hasAnswerId)) continue;
      }

      int score = _scoreQuestion(q, config, neededResources);
      
      // On choisit la question avec le plus haut score. En cas d'égalité, l'ordre de la liste prime.
      if (score > maxScore) {
        maxScore = score;
        bestQuestion = q;
      }
    }

    return bestQuestion;
  }

  int _scoreQuestion(DiagnosticQuestion q, HouseholdConfig config, Set<String> neededResources) {
    int maxScore = 0; // Score de base si la condition est remplie mais aucun fait prioritaire

    for (var opt in q.options) {
      for (var fact in opt.facts) {
        // PRIORITÉ 1 (Score 100) : Vérifier la disponibilité d'une ressource critique
        // L'utilisateur possède un équipement qui a besoin de cette ressource, mais on ne sait pas s'il l'a.
        if (fact.type == 'assess_resource') {
          final resId = fact.value;
          if (neededResources.contains(resId) && !config.assessedResources.contains(resId)) {
            if (100 > maxScore) maxScore = 100;
          }
        } 
        // PRIORITÉ 2 (Score 80) : Estimer la durée d'une ressource possédée
        // L'utilisateur possède la ressource, mais on ne connaît pas son autonomie.
        else if (fact.type == 'add_resource_duration') {
          final resId = fact.value;
          if (config.ownedResources.contains(resId) && !config.resourceDurations.containsKey(resId)) {
            if (80 > maxScore) maxScore = 80;
          }
        } 
        // PRIORITÉ 3 (Score 50) : Évaluer une capacité encore inconnue
        else if (fact.type == 'assess_capability') {
          final capId = fact.value;
          if (!config.assessedCapabilities.contains(capId)) {
            if (50 > maxScore) maxScore = 50;
          }
        }
      }
    }
    
    // PRIORITÉ 4 (Score 10) : Question de secours / fallback pertinente
    if (maxScore == 0) {
      maxScore = 10;
    }

    return maxScore;
  }
}
