import 'dart:convert';
import 'package:b3_engine/b3_engine.dart';
import '../../../data/app_knowledge_dataset.dart';

class AdaptiveDiagnosticEngine {
  final List<DiagnosticQuestion> questions;
  final Set<String> _resourceIds = {};
  final Set<String> _systemIds = {};
  final Map<String, List<String>> _assetReqs = {};
  final Map<String, List<String>> _capabilityAssets = {};

  AdaptiveDiagnosticEngine(this.questions) {
    final kb = jsonDecode(appKnowledgeBase);
    
    for (var r in kb['resources'] ?? []) {
      _resourceIds.add(r['id']);
    }
    for (var s in kb['systems'] ?? []) {
      _systemIds.add(s['id']);
    }
    
    for (var a in kb['assets'] ?? []) {
      _assetReqs[a['id']] = List<String>.from(a['requires'] ?? []);
    }
    
    for (var c in kb['capabilities'] ?? []) {
      _capabilityAssets[c['id']] = List<String>.from(c['assets'] ?? []);
    }
  }

  DiagnosticQuestion? getNextQuestion(DiagnosticState state) {
    final config = state.toHouseholdConfig(questions);
    
    // 1. Déterminer les ressources nécessaires pour les équipements
    final neededResources = <String>{};
    for (var assetId in config.ownedAssets) {
      final reqs = _assetReqs[assetId] ?? [];
      for (var req in reqs) {
        if (_resourceIds.contains(req)) {
          neededResources.add(req);
        }
      }
    }

    // 2. Déterminer si une capacité évaluée manque de redondance
    final needsRedundancyCheck = <String>{};
    for (var capId in config.assessedCapabilities) {
      final capAssets = _capabilityAssets[capId] ?? [];
      final ownedForCap = config.ownedAssets.where((a) => capAssets.contains(a)).toList();
      
      if (ownedForCap.isEmpty) continue; // Pas d'équipement géré pour le moment
      
      bool needsRedundancy = false;
      final assetSystems = <String, Set<String>>{};
      for (var a in ownedForCap) {
        final reqs = _assetReqs[a] ?? [];
        assetSystems[a] = reqs.where((r) => _systemIds.contains(r)).toSet();
      }
      
      bool hasAutonomous = assetSystems.values.any((sys) => sys.isEmpty);
      
      if (!hasAutonomous) {
        if (ownedForCap.length == 1) {
          needsRedundancy = true;
        } else {
          Set<String> commonSystems = Set.from(assetSystems.values.first);
          for (var sys in assetSystems.values.skip(1)) {
            commonSystems = commonSystems.intersection(sys);
          }
          if (commonSystems.isNotEmpty) {
            needsRedundancy = true;
          }
        }
      }
      
      if (needsRedundancy) {
        needsRedundancyCheck.add(capId);
      }
    }

    DiagnosticQuestion? bestQuestion;
    int maxScore = 0;

    for (var q in questions) {
      if (state.answers.containsKey(q.id)) continue;

      if (q.condition != null) {
        final prev = state.answers[q.condition!.dependsOnQuestionId];
        if (prev == null || !prev.contains(q.condition!.hasAnswerId)) continue;
      }

      int score = _scoreQuestion(q, config, neededResources, needsRedundancyCheck);
      
      if (score > maxScore) {
        maxScore = score;
        bestQuestion = q;
      }
    }

    return bestQuestion;
  }

  int _scoreQuestion(
      DiagnosticQuestion q, 
      HouseholdConfig config, 
      Set<String> neededResources,
      Set<String> needsRedundancyCheck) {
      
    int maxScore = 0;

    // SCORE 90: Redundancy check
    if (q.metadata['purpose'] == 'redundancy_check') {
      final cap = q.metadata['capability'];
      if (needsRedundancyCheck.contains(cap)) {
        if (90 > maxScore) maxScore = 90;
      }
    }
    
    // SCORE 85: Alternative discovery
    if (q.metadata['purpose'] == 'alternative_discovery') {
      final cap = q.metadata['capability'];
      if (needsRedundancyCheck.contains(cap)) {
        if (85 > maxScore) maxScore = 85;
      }
    }

    for (var opt in q.options) {
      for (var fact in opt.facts) {
        // SCORE 100: Resource critique manquante
        if (fact.type == 'assess_resource' || fact.type == 'assess_resource_unknown') {
          final resId = fact.value;
          if (neededResources.contains(resId) && 
              !config.assessedResources.contains(resId) && 
              !config.unknownResources.contains(resId)) {
            if (100 > maxScore) maxScore = 100;
          }
        } 
        // SCORE 80: Durée de ressource
        else if (fact.type == 'add_resource_duration') {
          final resId = fact.value;
          if (config.ownedResources.contains(resId) && !config.resourceDurations.containsKey(resId)) {
            if (80 > maxScore) maxScore = 80;
          }
        } 
        // SCORE 50: Capacité non évaluée
        else if (fact.type == 'assess_capability') {
          final capId = fact.value;
          if (!config.assessedCapabilities.contains(capId)) {
            if (50 > maxScore) maxScore = 50;
          }
        }
      }
    }
    
    // SCORE 10: Fallback

    return maxScore;
  }
}
