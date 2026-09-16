import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/data/app_diagnostic_dataset.dart';
import 'package:b3_app/data/app_knowledge_dataset.dart';
import 'package:b3_app/features/diagnostic/engine/adaptive_diagnostic_engine.dart';

void main() {
  late List<DiagnosticQuestion> questions;
  late AdaptiveDiagnosticEngine adaptiveEngine;
  late B3Engine b3Engine;
  late Scenario scenario;

  setUp(() {
    questions = (jsonDecode(appDiagnosticQuestionsJson) as List)
        .map((q) => DiagnosticQuestion.fromJson(q))
        .toList();
    adaptiveEngine = AdaptiveDiagnosticEngine(questions);
    b3Engine = B3Engine();
    scenario = DataMapper.parseScenario(appKnowledgeBase, 'panne_elec');
  });

  test('TEST 1 — UNKNOWN (Je ne sais pas pour le bois)', () {
    final state = DiagnosticState();
    state.answerMultiple('q_heat_main', ['opt_poele_bois']);
    state.answerQuestion('q_heat_bois_reserve', 'opt_bois_unk');
    
    final config = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(appKnowledgeBase, config);
    final res = b3Engine.runSimulation(graph, scenario);
    
    expect(res.nodeStates['bois'], B3State.unknown);
    expect(res.nodeStates['poele_bois'], B3State.unknown);
  });

  test('TEST 2 — ABSENT (Non pour le bois)', () {
    final state = DiagnosticState();
    state.answerMultiple('q_heat_main', ['opt_poele_bois']);
    state.answerQuestion('q_heat_bois_reserve', 'opt_bois_no');
    
    final config = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(appKnowledgeBase, config);
    final res = b3Engine.runSimulation(graph, scenario);
    
    expect(res.nodeStates['bois'], B3State.failed);
    expect(res.nodeStates['poele_bois'], B3State.failed);
  });

  test('TEST 3 — PRESENT (Oui pour le bois avec durée)', () {
    final state = DiagnosticState();
    state.answerMultiple('q_heat_main', ['opt_poele_bois']);
    state.answerQuestion('q_heat_bois_reserve', 'opt_bois_yes');
    
    final config = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(appKnowledgeBase, config);
    final res = b3Engine.runSimulation(graph, scenario);
    
    expect(res.nodeStates['bois'], B3State.maintained);
    expect(res.nodeStates['poele_bois'], B3State.maintained);
  });

  test('TEST 4 — GRANULÉS (Sait demander la ressource)', () {
    final state = DiagnosticState();
    state.answerMultiple('q_heat_main', ['opt_poele_granules']);
    
    final qNext = adaptiveEngine.getNextQuestion(state);
    expect(qNext?.id, 'q_heat_granules_reserve');
  });

  test('TEST 5 — AUDIT DATASET (Toutes les ressources ont une question)', () {
    final kb = jsonDecode(appKnowledgeBase);
    final resources = <String>{};
    for (var r in kb['resources']) resources.add(r['id']);
    
    final assetsReqs = <String>{};
    for (var a in kb['assets']) {
      if (a['requires'] != null) {
        for (var req in a['requires']) {
          if (resources.contains(req)) assetsReqs.add(req);
        }
      }
    }
    
    final assessedByQuestions = <String>{};
    for (var q in questions) {
      for (var opt in q.options) {
        for (var fact in opt.facts) {
          if (fact.type == 'assess_resource' || fact.type == 'assess_resource_unknown') {
            assessedByQuestions.add(fact.value);
          }
        }
      }
    }
    
    for (var req in assetsReqs) {
      expect(assessedByQuestions.contains(req), isTrue, 
          reason: 'La ressource \$req n\'a aucune question associée dans appDiagnosticQuestionsJson');
    }
  });

  test('TEST 6 & 7 — REDONDANCE CHAUFFAGE & CUISINE', () {
    final state = DiagnosticState();
    state.answerMultiple('q_heat_main', ['opt_rad_elec']); // Seulement rad_elec, vulnérable
    
    final qNext = adaptiveEngine.getNextQuestion(state);
    expect(qNext?.id, 'q_heat_redundancy');
    
    state.answerQuestion('q_heat_redundancy', 'opt_heat_alt_yes');
    final qAlt = adaptiveEngine.getNextQuestion(state);
    expect(qAlt?.id, 'q_heat_alternative');
  });

  test('TEST 8 — FAUSSE REDONDANCE (Rad elec + PAC)', () {
    final state = DiagnosticState();
    state.answerMultiple('q_heat_main', ['opt_rad_elec', 'opt_pac']); // Les deux vulnérables à l'élec
    
    final qNext = adaptiveEngine.getNextQuestion(state);
    expect(qNext?.id, 'q_heat_redundancy'); // Doit quand même chercher une alternative
  });

  test('TEST 9 — VRAIE REDONDANCE (Rad elec + Poele)', () {
    final state = DiagnosticState();
    state.answerMultiple('q_heat_main', ['opt_rad_elec', 'opt_poele_bois']); 
    
    // Le poêle nécessite du bois. La priorité 1 (score 100) est de demander pour le bois !
    final qNext = adaptiveEngine.getNextQuestion(state);
    expect(qNext?.id, 'q_heat_bois_reserve');
    
    state.answerQuestion('q_heat_bois_reserve', 'opt_bois_yes');
    
    // Plus besoin de redundancy_check, car poele_bois est indépendant.
    // On passe à la suite.
    final qAfter = adaptiveEngine.getNextQuestion(state);
    expect(qAfter?.id, 'q_cook_main');
  });

  test('TEST 10 — ANTI-INVENTION', () {
    final state = DiagnosticState();
    state.answerMultiple('q_heat_main', ['opt_rad_elec']);
    state.answerQuestion('q_heat_redundancy', 'opt_heat_alt_no');
    
    final qNext = adaptiveEngine.getNextQuestion(state);
    expect(qNext?.id, 'q_cook_main', reason: 'Ne pose pas de question bois/gaz si on n\'a pas l\'équipement');
  });
}
