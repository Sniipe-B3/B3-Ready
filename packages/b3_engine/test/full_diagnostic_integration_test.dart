import 'dart:convert';
import 'package:test/test.dart';
import 'package:b3_engine/b3_engine.dart';

void main() {
  final List<DiagnosticQuestion> questions = (jsonDecode(b3DiagnosticQuestionsJson) as List)
      .map((q) => DiagnosticQuestion.fromJson(q))
      .toList();
      
  // Le scénario commun : Panne électrique de 48h
  final scenario = DataMapper.parseScenario(b3KnowledgeBase, 'panne_elec');

  test('PARCOURS 1 : Le diagnostic se comporte comme une conversation (Foyer A - Résilient)', () {
    final diagEngine = DiagnosticEngine(questions);
    final state = DiagnosticState();

    // Boucle de conversation simulée
    DiagnosticQuestion? currentQuestion;
    
    // Q1 : Cuisson
    currentQuestion = diagEngine.getNextQuestion(state);
    expect(currentQuestion?.id, 'q_cook_main');
    state.answerQuestion(currentQuestion!.id, 'opt_plaque'); // Réponse : Plaque
    
    // Q2 : Conditionnelle 1 (Four)
    currentQuestion = diagEngine.getNextQuestion(state);
    expect(currentQuestion?.id, 'q_cook_alt_elec');
    state.answerQuestion(currentQuestion!.id, 'opt_no_four'); // Réponse : Non
    
    // Q3 : Conditionnelle 2 (Secours)
    currentQuestion = diagEngine.getNextQuestion(state);
    expect(currentQuestion?.id, 'q_cook_secours');
    state.answerQuestion(currentQuestion!.id, 'opt_yes_rechaud'); // Réponse : Oui, réchaud gaz
    
    // Q4 : Chauffage
    currentQuestion = diagEngine.getNextQuestion(state);
    expect(currentQuestion?.id, 'q_heat_main');
    state.answerQuestion(currentQuestion!.id, 'opt_poele'); // Réponse : Poêle à bois
    
    // Q5 : Éclairage
    currentQuestion = diagEngine.getNextQuestion(state);
    expect(currentQuestion?.id, 'q_light_main');
    state.answerQuestion(currentQuestion!.id, 'opt_lamp_bat'); // Réponse : Lampe sur batterie
    
    // Fin du diagnostic
    currentQuestion = diagEngine.getNextQuestion(state);
    expect(currentQuestion, isNull);

    // Analyse B3
    final config = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(b3KnowledgeBase, config);
    final result = B3Engine().runSimulation(graph, scenario);

    // Vérifications Foyer Résilient
    expect(result.nodeStates['cuisiner'], B3State.maintained); // Maintenu par le réchaud gaz
    expect(result.nodeStates['chauffer'], B3State.maintained); // Maintenu par le poêle à bois
    expect(result.nodeStates['eclairage'], B3State.maintained); // Maintenu par la lampe batterie
    
    expect(result.vulnerabilities.isEmpty, true); // Aucune vulnérabilité majeure
  });

  test('PARCOURS 2 : La vraie vulnérabilité et fausse redondance (Foyer B)', () {
    final state = DiagnosticState();
    
    // Cuisson : Plaque + Four (fausse redondance)
    state.answerQuestion('q_cook_main', 'opt_plaque');
    state.answerQuestion('q_cook_alt_elec', 'opt_yes_four');
    state.answerQuestion('q_cook_secours', 'opt_no_secours');
    // Chauffage : Radiateur électrique
    state.answerQuestion('q_heat_main', 'opt_rad_elec');
    // Éclairage : Secteur uniquement
    state.answerQuestion('q_light_main', 'opt_no_lamp');

    final config = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(b3KnowledgeBase, config);
    final result = B3Engine().runSimulation(graph, scenario);

    // Vérifications Foyer Vulnérable
    expect(result.nodeStates['cuisiner'], B3State.failed);
    expect(result.nodeStates['chauffer'], B3State.failed);
    expect(result.nodeStates['eclairage'], B3State.failed);

    expect(result.vulnerabilities.length, 3);

    // Vérification de la Trace pour Cuisiner (Fausse redondance)
    final cookTrace = result.traces['cuisiner']!.steps.last;
    expect(cookTrace.type, ReasonType.evaluatedChildren);
    
    // Le moteur doit avoir évalué que la plaque ET le four sont failed
    expect(cookTrace.dependencyStates!['plaque_elec'], B3State.failed);
    expect(cookTrace.dependencyStates!['four_elec'], B3State.failed);
  });

  test('PARCOURS 3 : Branche conditionnelle sautée', () {
    final diagEngine = DiagnosticEngine(questions);
    final state = DiagnosticState();

    DiagnosticQuestion? currentQuestion = diagEngine.getNextQuestion(state);
    expect(currentQuestion?.id, 'q_cook_main');
    
    // Si on répond Gazinière...
    state.answerQuestion(currentQuestion!.id, 'opt_gaz'); 
    
    currentQuestion = diagEngine.getNextQuestion(state);
    // ... le diagnostic SAUTE les questions alternatives électriques et secours, et passe directement au chauffage
    expect(currentQuestion?.id, 'q_heat_main');
  });

  test('PARCOURS 4 : Incertitude protégée (Foyer C)', () {
    final state = DiagnosticState();
    // "Je ne sais pas"
    state.answerQuestion('q_cook_main', 'opt_unk');
    // ... skip conditions and other questions for brevity
    
    final config = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(b3KnowledgeBase, config);
    // On ajoute le système inconnu en unknown pour le scénario comme dans la vraie vie (défaut)
    final scen = Scenario(name: 'Panne', duration: Duration(), systemOverrides: {'unk_sys': B3State.unknown});
    final result = B3Engine().runSimulation(graph, scen);

    // L'incertitude remonte proprement, sans inventer un échec ni une réussite
    expect(result.nodeStates['cuisiner'], B3State.unknown);
    
    // Ce n'est PAS une vulnérabilité (qui nécessiterait une action d'urgence)
    expect(result.vulnerabilities.any((v) => v.capability.id == 'cuisiner'), false);
    // C'est une incertitude (qui nécessite un diagnostic plus poussé)
    expect(result.uncertainties.any((u) => u.capability.id == 'cuisiner'), true);
  });

  test('PARCOURS 5 : Reprise d un diagnostic incomplet', () {
    final diagEngine = DiagnosticEngine(questions);
    final stateJour1 = DiagnosticState();

    stateJour1.answerQuestion('q_cook_main', 'opt_plaque');
    stateJour1.answerQuestion('q_cook_alt_elec', 'opt_no_four');
    
    // Sauvegarde en base (simulée)
    final sauvegardeJson = stateJour1.toJson();

    // Reprise Jour 3
    final stateJour3 = DiagnosticState();
    stateJour3.fromJson(sauvegardeJson);
    
    final currentQuestion = diagEngine.getNextQuestion(stateJour3);
    // Le moteur reprend exactement là où il s'est arrêté (condition secours)
    expect(currentQuestion?.id, 'q_cook_secours');
  });
}
