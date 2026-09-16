import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/data/app_diagnostic_dataset.dart';
import 'package:b3_app/data/app_knowledge_dataset.dart';

void main() {
  late List<DiagnosticQuestion> questions;
  late B3Engine engine;
  late Scenario scenarioElec;

  setUp(() {
    questions = (jsonDecode(appDiagnosticQuestionsJson) as List)
        .map((q) => DiagnosticQuestion.fromJson(q))
        .toList();
    engine = B3Engine();
    scenarioElec = DataMapper.parseScenario(appKnowledgeBase, 'panne_elec');
  });

  test('Cas 5 : Équipement présent + ressource inconnue', () {
    final state = DiagnosticState()
      ..answerMultiple('q_heat_main', ['opt_poele_bois'])
      ..answerQuestion('q_heat_bois_reserve', 'opt_bois_unk');
      
    final conf = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(appKnowledgeBase, conf);
    final res = engine.runSimulation(graph, scenarioElec);
    
    // In phase 4.12.1, unknown resource leads to UNKNOWN state for the resource.
    expect(res.nodeStates['bois'], B3State.unknown);
    expect(res.nodeStates['poele_bois'], B3State.unknown);
  });

  test('Cas 6 : Ressource jamais évaluée', () {
    final state = DiagnosticState()
      ..answerMultiple('q_cook_main', ['opt_gaz_bouteille']);
      
    final conf = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(appKnowledgeBase, conf);
    final res = engine.runSimulation(graph, scenarioElec);
    
    expect(res.nodeStates['gaz_bouteille'], B3State.notAssessed);
    expect(res.nodeStates['rechaud_gaz'], B3State.notAssessed);
    expect(res.nodeStates['cuisiner'], B3State.notAssessed);
  });

  test('Cas 10 : Diagnostic incomplet → inconnu/not assessed, pas absence', () {
    final state = DiagnosticState();
    final conf = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(appKnowledgeBase, conf);
    final res = engine.runSimulation(graph, scenarioElec);
    
    expect(res.nodeStates['chauffer'], B3State.notAssessed);
  });

  test('TEST A — ressource explicitement inconnue', () {
    final state = DiagnosticState()
      ..answerMultiple('q_heat_main', ['opt_poele_bois'])
      ..answerQuestion('q_heat_bois_reserve', 'opt_bois_unk');
      
    final conf = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(appKnowledgeBase, conf);
    final res = engine.runSimulation(graph, scenarioElec);
    
    expect(res.nodeStates['bois'], B3State.unknown);
    expect(res.nodeStates['bois'] != B3State.notAssessed, true);
    expect(res.nodeStates['bois'] != B3State.failed, true);
  });

  test('TEST B — ressource jamais évaluée', () {
    final state = DiagnosticState()
      ..answerMultiple('q_cook_main', ['opt_gaz_bouteille']);
      
    final conf = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(appKnowledgeBase, conf);
    final res = engine.runSimulation(graph, scenarioElec);
    
    expect(res.nodeStates['gaz_bouteille'], B3State.notAssessed);
  });

  test('TEST C — ressource explicitement absente', () {
    final state = DiagnosticState()
      ..answerMultiple('q_heat_main', ['opt_poele_bois'])
      ..answerQuestion('q_heat_bois_reserve', 'opt_bois_no');
      
    final conf = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(appKnowledgeBase, conf);
    final res = engine.runSimulation(graph, scenarioElec);
    
    expect(res.nodeStates['bois'], B3State.failed);
  });

  test('TEST D — aucune invention par défaut', () {
    final state = DiagnosticState(); // Vide
    final conf = state.toHouseholdConfig(questions);
    
    expect(conf.ownedAssets.isEmpty, true);
    expect(conf.ownedResources.isEmpty, true);
    expect(conf.resourceDurations.isEmpty, true);
    expect(conf.unknownResources.isEmpty, true);
  });
}
