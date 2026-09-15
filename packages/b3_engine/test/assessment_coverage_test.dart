import 'dart:convert';
import 'package:test/test.dart';
import 'package:b3_engine/b3_engine.dart';

void main() {
  final List<DiagnosticQuestion> questions = (jsonDecode(b3DiagnosticQuestionsJson) as List)
      .map((q) => DiagnosticQuestion.fromJson(q))
      .toList();
  final scenario = DataMapper.parseScenario(b3KnowledgeBase, 'panne_elec');

  test('Test : Foyer partiellement diagnostiqué (NOT_ASSESSED)', () {
    final state = DiagnosticState();
    // L'utilisateur répond uniquement à cuisson et chauffage
    state.answerQuestion('q_cook_main', 'opt_plaque');
    state.answerQuestion('q_heat_main', 'opt_rad_elec');
    
    final config = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(b3KnowledgeBase, config);
    final result = B3Engine().runSimulation(graph, scenario);

    // Cuisson et chauffage ont été évalués (et échouent sous panne électrique)
    expect(result.nodeStates['cuisiner'], B3State.failed);
    expect(result.nodeStates['chauffer'], B3State.failed);
    
    // Mais Eau, Communication, Éclairage, Conserver n'ont pas été évalués !
    expect(result.nodeStates['boire'], B3State.notAssessed);
    expect(result.nodeStates['communiquer'], B3State.notAssessed);
    expect(result.nodeStates['eclairage'], B3State.notAssessed);
    expect(result.nodeStates['conserver'], B3State.notAssessed);
    
    // NOT_ASSESSED n'est PAS une vulnérabilité (il est classé en incertitude)
    expect(result.vulnerabilities.any((v) => v.capability.id == 'boire'), false);
    expect(result.uncertainties.any((u) => u.capability.id == 'boire' && u.state == B3State.notAssessed), true);
  });

  test('Test : Absence réelle (CONFIRMED_ABSENT)', () {
    final state = DiagnosticState();
    // On répond "Je n'ai aucun éclairage"
    state.answerQuestion('q_light_main', 'opt_no_light_at_all');
    
    final config = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(b3KnowledgeBase, config);
    final result = B3Engine().runSimulation(graph, scenario);

    // C'est évalué, il y a 0 solutions, donc c'est FAILED !
    expect(result.nodeStates['eclairage'], B3State.failed);
    expect(result.vulnerabilities.any((v) => v.capability.id == 'eclairage'), true);
  });

  test('Test : Je ne sais pas (UNKNOWN)', () {
    final state = DiagnosticState();
    state.answerQuestion('q_cook_main', 'opt_unk');
    
    final config = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(b3KnowledgeBase, config);
    final result = B3Engine().runSimulation(graph, scenario);

    expect(result.nodeStates['cuisiner'], B3State.unknown);
    expect(result.vulnerabilities.any((v) => v.capability.id == 'cuisiner'), false);
    expect(result.uncertainties.any((u) => u.capability.id == 'cuisiner' && u.state == B3State.unknown), true);
  });

  test('Test : Présence confirmée', () {
    final state = DiagnosticState();
    state.answerQuestion('q_cook_main', 'opt_gaz');
    
    final config = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(b3KnowledgeBase, config);
    final result = B3Engine().runSimulation(graph, scenario);

    expect(result.nodeStates['cuisiner'], B3State.maintained);
  });

  test('Test : Évolution du diagnostic', () {
    final state = DiagnosticState();
    
    // JOUR 1 : Éclairage non évalué
    var config = state.toHouseholdConfig(questions);
    var graph = DataMapper.buildGraph(b3KnowledgeBase, config);
    var result = B3Engine().runSimulation(graph, scenario);
    expect(result.nodeStates['eclairage'], B3State.notAssessed);

    // JOUR 2 : B3 pose la question, on répond "Lampe batterie"
    state.answerQuestion('q_light_main', 'opt_lamp_bat');
    config = state.toHouseholdConfig(questions);
    graph = DataMapper.buildGraph(b3KnowledgeBase, config);
    result = B3Engine().runSimulation(graph, scenario);
    
    // Évolue proprement vers un état évalué
    expect(result.nodeStates['eclairage'], B3State.maintained);
    
    // AUTRE FOYER JOUR 2 : On répond "Aucun"
    final stateB = DiagnosticState();
    stateB.answerQuestion('q_light_main', 'opt_no_light_at_all');
    config = stateB.toHouseholdConfig(questions);
    graph = DataMapper.buildGraph(b3KnowledgeBase, config);
    result = B3Engine().runSimulation(graph, scenario);
    expect(result.nodeStates['eclairage'], B3State.failed); // Devient une absence confirmée
  });

  test('Test : Non-invention', () {
    final state = DiagnosticState();
    // Le foyer ne mentionne pas "réchaud_gaz" ou "poele_bois"
    final config = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(b3KnowledgeBase, config);
    
    // Le graphe métier inclut tous les systèmes mais ne crée les assets que s'ils sont possédés
    expect(graph.any((n) => n.id == 'rechaud_gaz'), false);
    expect(graph.any((n) => n.id == 'poele_bois'), false);
    
    // Et le statut des capacités non évaluées reste bien NOT_ASSESSED
    final result = B3Engine().runSimulation(graph, scenario);
    expect(result.nodeStates['cuisiner'], B3State.notAssessed);
  });
}
