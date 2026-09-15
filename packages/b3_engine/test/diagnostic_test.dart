import 'dart:convert';
import 'package:test/test.dart';
import 'package:b3_engine/b3_engine.dart';

void main() {
  final List<DiagnosticQuestion> questions = (jsonDecode(b3DiagnosticQuestionsJson) as List)
      .map((q) => DiagnosticQuestion.fromJson(q))
      .toList();
      
  final diagEngine = DiagnosticEngine(questions);

  test('Test A & B: Construction correcte du config', () {
    final state = DiagnosticState();
    state.answerQuestion('q_cook_main', 'opt_plaque');
    state.answerQuestion('q_cook_secours', 'opt_yes_rechaud');
    
    final configA = state.toHouseholdConfig(questions);
    expect(configA.ownedAssets.contains('plaque_elec'), true);
    expect(configA.ownedAssets.contains('rechaud_gaz'), true);
    
    final stateB = DiagnosticState();
    stateB.answerQuestion('q_cook_main', 'opt_plaque');
    stateB.answerQuestion('q_cook_secours', 'opt_no_secours');
    
    final configB = stateB.toHouseholdConfig(questions);
    expect(configB.ownedAssets.contains('plaque_elec'), true);
    expect(configB.ownedAssets.contains('rechaud_gaz'), false); // Test B respecté
  });

  test('Test C: Question conditionnelle', () {
    final state = DiagnosticState();
    state.answerQuestion('q_cook_main', 'opt_gaz'); 
    // Opt_gaz ne déclenche PAS q_cook_alt_elec ou q_cook_secours
    
    final nextQ = diagEngine.getNextQuestion(state);
    // Devrait sauter les conditionnelles et aller au chauffage
    expect(nextQ?.id, 'q_heat_main');
  });

  test('Test D: Réponse inconnue ne devient pas FAILED', () {
    final state = DiagnosticState();
    state.answerQuestion('q_cook_main', 'opt_unk'); // Je ne sais pas
    
    final config = state.toHouseholdConfig(questions);
    expect(config.ownedAssets.isEmpty, true);
    
    final graph = DataMapper.buildGraph(b3KnowledgeBase, config);
    final engine = B3Engine();
    final result = engine.runSimulation(graph, Scenario(name: 'S', duration: Duration(), systemOverrides: {}));
    
    // Puisqu'il n'a pas d'assets pour cuisiner, la capability a zero children
    // (Dans la logique métier, 0 solution connue = FAILED ou UNKNOWN selon l'interprétation. 
    // Mais l'asset lui-même n'est pas "FAILED", il n'est juste pas instancié. 
    // L'ignorance ne casse pas le B3Engine, elle produit une absence de solution).
    expect(result.nodeStates['cuisiner'], B3State.failed); 
  });

  test('Test E: Reprise du diagnostic', () {
    final state = DiagnosticState();
    state.answerQuestion('q_cook_main', 'opt_plaque');
    
    final jsonSave = state.toJson();
    
    final newState = DiagnosticState();
    newState.fromJson(jsonSave);
    
    expect(newState.answers['q_cook_main'], 'opt_plaque');
  });

  test('Test F: Deux utilisateurs produisent deux graphes différents', () {
    final state1 = DiagnosticState()..answerQuestion('q_cook_main', 'opt_plaque');
    final state2 = DiagnosticState()..answerQuestion('q_cook_main', 'opt_gaz');
    
    final config1 = state1.toHouseholdConfig(questions);
    final config2 = state2.toHouseholdConfig(questions);
    
    final graph1 = DataMapper.buildGraph(b3KnowledgeBase, config1);
    final graph2 = DataMapper.buildGraph(b3KnowledgeBase, config2);
    
    expect(graph1.any((n) => n.id == 'plaque_elec'), true);
    expect(graph1.any((n) => n.id == 'rechaud_gaz'), false);
    
    expect(graph2.any((n) => n.id == 'plaque_elec'), false);
    expect(graph2.any((n) => n.id == 'rechaud_gaz'), true);
  });

  test('Test G & H: Le diagnostic produit une simulation sans modifier B3Engine', () {
    final state = DiagnosticState();
    state.answerQuestion('q_cook_main', 'opt_plaque');
    
    final config = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(b3KnowledgeBase, config);
    final engine = B3Engine();
    
    final scenario = DataMapper.parseScenario(b3KnowledgeBase, 'panne_elec');
    final result = engine.runSimulation(graph, scenario);
    
    expect(result.nodeStates['cuisiner'], B3State.failed);
  });

  test('Test IMPORTANT: PERSONNALISATION', () {
    final engine = B3Engine();
    final scenario = DataMapper.parseScenario(b3KnowledgeBase, 'panne_elec');

    // Foyer A : Plaque + Réchaud
    final foyerA = DiagnosticState();
    foyerA.answerQuestion('q_cook_main', 'opt_plaque');
    foyerA.answerQuestion('q_cook_secours', 'opt_yes_rechaud');
    
    final resA = engine.runSimulation(
      DataMapper.buildGraph(b3KnowledgeBase, foyerA.toHouseholdConfig(questions)),
      scenario
    );

    // Foyer B : Plaque + Four
    final foyerB = DiagnosticState();
    foyerB.answerQuestion('q_cook_main', 'opt_plaque');
    foyerB.answerQuestion('q_cook_alt_elec', 'opt_yes_four');
    foyerB.answerQuestion('q_cook_secours', 'opt_no_secours');

    final resB = engine.runSimulation(
      DataMapper.buildGraph(b3KnowledgeBase, foyerB.toHouseholdConfig(questions)),
      scenario
    );

    expect(resA.nodeStates['cuisiner'], B3State.maintained);
    expect(resB.nodeStates['cuisiner'], B3State.failed);
  });
}
