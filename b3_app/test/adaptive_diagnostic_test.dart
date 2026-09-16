import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/data/app_diagnostic_dataset.dart';
import 'package:b3_app/features/diagnostic/engine/adaptive_diagnostic_engine.dart';

void main() {
  late List<DiagnosticQuestion> questions;
  late AdaptiveDiagnosticEngine adaptiveEngine;

  setUp(() {
    questions = (jsonDecode(appDiagnosticQuestionsJson) as List)
        .map((q) => DiagnosticQuestion.fromJson(q))
        .toList();
    adaptiveEngine = AdaptiveDiagnosticEngine(questions);
  });

  test('TEST 1 & 11 & 12 : PAC seule (pas de dépendance ressource) -> Passe à la capacité suivante', () {
    final state1 = DiagnosticState();
    
    // Au début, aucune capacité n'est évaluée, le moteur propose la première (score 50)
    final q1 = adaptiveEngine.getNextQuestion(state1);
    expect(q1?.id, 'q_heat_main');
    
    // Réponse PAC (dépend uniquement d'élec, aucune ressource locale nécessaire)
    state1.answerMultiple('q_heat_main', ['opt_pac']);
    
    // Le moteur vérifie s'il y a des ressources nécessaires (aucune). 
    // Il passe donc à la capacité suivante (cuisiner ou éclairage) avec score 50.
    final q2 = adaptiveEngine.getNextQuestion(state1);
    expect(q2?.id, 'q_cook_main');
    
    // Déterminisme : refaire l'appel donne le même résultat
    final q2bis = adaptiveEngine.getNextQuestion(state1);
    expect(q2bis?.id, 'q_cook_main');
  });

  test('TEST 2 & 14 : PAC + Poêle à bois -> Recherche la ressource bois', () {
    final state = DiagnosticState();
    state.answerMultiple('q_heat_main', ['opt_pac', 'opt_poele_bois']);
    
    // Poele à bois nécessite la ressource "bois" qui n'est pas évaluée. 
    // Une question de priorité 1 (score 100) doit émerger.
    final qNext = adaptiveEngine.getNextQuestion(state);
    expect(qNext?.id, 'q_heat_bois_reserve', reason: 'Doit vérifier la réserve de bois car poêle sélectionné');
  });

  test('TEST 3 : PAC + Poêle + Bois possédé -> Demande la durée si possible, sinon passe à autre chose', () {
    final state = DiagnosticState();
    state.answerMultiple('q_heat_main', ['opt_pac', 'opt_poele_bois']);
    state.answerQuestion('q_heat_bois_reserve', 'opt_bois_yes'); 
    
    // L'option opt_bois_yes produit déjà la duration (72h) dans notre dataset, donc la durée est connue !
    // Par conséquent, il ne reste plus aucune question ressource pour le chauffage.
    final qNext = adaptiveEngine.getNextQuestion(state);
    expect(qNext?.id, 'q_cook_main', reason: 'Ressource bois et durée connues, doit passer à la cuisine');
  });

  test('TEST 4 : Plaque électrique seule -> Pas de solution alternative supposée', () {
    final state = DiagnosticState();
    state.answerMultiple('q_heat_main', ['opt_rad_elec']); // On évacue le chauffage
    state.answerMultiple('q_cook_main', ['opt_plaque_elec']); // Plaque elec seulement
    
    // Plaque elec ne demande aucune ressource. On passe à la suite.
    final qNext = adaptiveEngine.getNextQuestion(state);
    expect(qNext?.id, 'q_light_main', reason: 'Passe à l\'éclairage sans inventer de question sur le gaz');
  });

  test('TEST 5 : Plaque électrique + réchaud gaz -> Vérification du gaz prioritaire', () {
    final state = DiagnosticState();
    state.answerMultiple('q_heat_main', ['opt_rad_elec']); // On évacue le chauffage
    state.answerMultiple('q_cook_main', ['opt_plaque_elec', 'opt_gaz_bouteille']);
    
    // Réchaud gaz demande du gaz.
    final qNext = adaptiveEngine.getNextQuestion(state);
    expect(qNext?.id, 'q_cook_gaz_reserve', reason: 'Doit demander si du gaz est disponible');
  });

  test('TEST 6 : Réchaud possédé + ressource inconnue -> Passe', () {
    final state = DiagnosticState();
    state.answerMultiple('q_heat_main', ['opt_rad_elec']); 
    state.answerMultiple('q_cook_main', ['opt_plaque_elec', 'opt_gaz_bouteille']);
    state.answerQuestion('q_cook_gaz_reserve', 'opt_gaz_unk'); // L'utilisateur ne sait pas
    
    // L'utilisateur ne sait pas. La ressource est techniquement "évaluée" mais on ne peut pas demander la durée (car on ne l'a pas ajoutée).
    // Donc ça passe.
    final qNext = adaptiveEngine.getNextQuestion(state);
    expect(qNext?.id, 'q_light_main');
  });

  test('TEST 8 & 9 : Diagnostic incomplet / Réponse incertaine ne bloque pas', () {
    final state = DiagnosticState();
    state.answerMultiple('q_heat_main', ['opt_poele_granules']); 
    // Arrête ici.
    
    // Reprise du diagnostic : poele_granules nécessite elec ET granules.
    // Mais on n'a pas de question pour les granulés dans notre dataset ! 
    // Le moteur vérifie "granules". Y a-t-il une question pour les granulés ? Non.
    // Donc maxScore restera 50 pour la prochaine capacité (cuisiner).
    final qNext = adaptiveEngine.getNextQuestion(state);
    expect(qNext?.id, 'q_cook_main');
  });

  test('TEST 10 : Reprise de diagnostic conserve l\'état', () {
    final state = DiagnosticState();
    state.answerMultiple('q_heat_main', ['opt_rad_elec']); 
    
    // Même si un autre objet AdaptiveDiagnosticEngine est instancié, l'état seul détermine la suite.
    final newEngine = AdaptiveDiagnosticEngine(questions);
    final qNext = newEngine.getNextQuestion(state);
    expect(qNext?.id, 'q_cook_main');
  });

  test('TEST 13 : Anti-invention (Ne pose pas de question de ressource si équipement non possédé)', () {
    final state = DiagnosticState();
    state.answerMultiple('q_heat_main', ['opt_rad_elec']); // Pas de bois
    state.answerMultiple('q_cook_main', ['opt_plaque_elec']); // Pas de gaz
    
    // Ne doit pas demander si on a du gaz ou du bois.
    final qNext = adaptiveEngine.getNextQuestion(state);
    expect(qNext?.id, 'q_light_main');
    
    state.answerMultiple('q_light_main', ['opt_lampe_secteur']);
    // Fini !
    expect(adaptiveEngine.getNextQuestion(state), null);
  });
}
