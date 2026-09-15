import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/data/app_knowledge_dataset.dart';
import 'package:b3_app/data/app_diagnostic_dataset.dart';

void main() {
  final engine = B3Engine();
  final scenarioElec = DataMapper.parseScenario(appKnowledgeBase, 'panne_elec');
  final questions = (jsonDecode(appDiagnosticQuestionsJson) as List).map((q) => DiagnosticQuestion.fromJson(q)).toList();

  HouseholdConfig getConfig(void Function(DiagnosticState state) populate) {
    final state = DiagnosticState();
    populate(state);
    return state.toHouseholdConfig(questions);
  }

  test('Cas 1 : PAC ≠ radiateur électrique', () {
    final confPac = getConfig((s) => s.answerMultiple('q_heat_main', ['opt_pac']));
    final graphPac = DataMapper.buildGraph(appKnowledgeBase, confPac);
    final resPac = engine.runSimulation(graphPac, scenarioElec);

    final confRad = getConfig((s) => s.answerMultiple('q_heat_main', ['opt_rad_elec']));
    final graphRad = DataMapper.buildGraph(appKnowledgeBase, confRad);
    final resRad = engine.runSimulation(graphRad, scenarioElec);

    expect(confPac.ownedAssets.contains('pompe_chaleur'), true);
    expect(confRad.ownedAssets.contains('radiateur_elec'), true);
    expect(confPac.ownedAssets.contains('radiateur_elec'), false);
    
    expect(resPac.nodeStates['chauffer'], B3State.failed);
    expect(resRad.nodeStates['chauffer'], B3State.failed);
  });

  test('Cas 2 & 3 : Poêle à bois ≠ barbecue, Chaudière bois ≠ poêle', () {
    final conf = getConfig((s) => s.answerMultiple('q_heat_main', ['opt_chaudiere_bois', 'opt_poele_bois']));
    expect(conf.ownedAssets.contains('chaudiere_bois'), true);
    expect(conf.ownedAssets.contains('poele_bois'), true);

    // Chaudiere depends on elec, Poele does not. So if we have both AND wood, heating should be maintained even in power outage.
    final stateWithWood = DiagnosticState()
      ..answerMultiple('q_heat_main', ['opt_chaudiere_bois', 'opt_poele_bois'])
      ..answerQuestion('q_heat_bois_reserve', 'opt_bois_yes');
      
    final confWood = stateWithWood.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(appKnowledgeBase, confWood);
    final res = engine.runSimulation(graph, scenarioElec);
    
    // chaudiere_bois fails (no elec), but poele_bois succeeds (has wood). So heating is maintained.
    expect(res.nodeStates['chaudiere_bois'], B3State.failed);
    expect(res.nodeStates['poele_bois'], B3State.maintained);
    expect(res.nodeStates['chauffer'], B3State.maintained);
  });

  test('Cas 4 : Équipement présent + ressource absente', () {
    final state = DiagnosticState()
      ..answerMultiple('q_cook_main', ['opt_gaz_bouteille'])
      ..answerQuestion('q_cook_gaz_reserve', 'opt_gaz_no'); // resource assessed and absent
      
    final conf = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(appKnowledgeBase, conf);
    final res = engine.runSimulation(graph, scenarioElec);
    
    // Res should be FAILED because gas is confirmed absent
    expect(res.nodeStates['rechaud_gaz'], B3State.failed);
    expect(res.nodeStates['cuisiner'], B3State.failed);
  });

  test('Cas 5 : Équipement présent + ressource inconnue', () {
    final state = DiagnosticState()
      ..answerMultiple('q_cook_main', ['opt_gaz_bouteille'])
      ..answerQuestion('q_cook_gaz_reserve', 'opt_gaz_unk'); // resource assessed but unknown
      
    final conf = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(appKnowledgeBase, conf);
    final res = engine.runSimulation(graph, scenarioElec);
    
    // Should be UNKNOWN
    expect(res.nodeStates['rechaud_gaz'], B3State.notAssessed);
    expect(res.nodeStates['cuisiner'], B3State.notAssessed);
  });

  test('Cas 6 : Ressource jamais évaluée', () {
    final state = DiagnosticState()
      ..answerMultiple('q_cook_main', ['opt_gaz_bouteille']); // Next question skipped for whatever reason
      
    final conf = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(appKnowledgeBase, conf);
    final res = engine.runSimulation(graph, scenarioElec);
    
    // Never assessed resource -> NOT_ASSESSED
    expect(res.nodeStates['rechaud_gaz'], B3State.notAssessed);
    expect(res.nodeStates['cuisiner'], B3State.notAssessed);
  });

  test('Cas 7 : Plusieurs équipements pour une même capacité', () {
    final state = DiagnosticState()
      ..answerMultiple('q_cook_main', ['opt_plaque_elec', 'opt_gaz_bouteille'])
      ..answerQuestion('q_cook_gaz_reserve', 'opt_gaz_yes')
      ..answerQuestion('q_cook_gaz_duration', 'opt_gaz_long');
      
    final conf = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(appKnowledgeBase, conf);
    final res = engine.runSimulation(graph, scenarioElec);
    
    // Plaque fails, but gaz is good. So cooking is maintained.
    expect(res.nodeStates['plaque_elec'], B3State.failed);
    expect(res.nodeStates['rechaud_gaz'], B3State.maintained);
    expect(res.nodeStates['cuisiner'], B3State.maintained);
  });

  test('Cas 8 & 9 : Une solution disponible mais non utilisable faute de ressource', () {
    final state = DiagnosticState()
      ..answerMultiple('q_cook_main', ['opt_plaque_elec', 'opt_gaz_bouteille'])
      ..answerQuestion('q_cook_gaz_reserve', 'opt_gaz_no');
      
    final conf = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(appKnowledgeBase, conf);
    final res = engine.runSimulation(graph, scenarioElec);
    
    // Both fail. Cooking fails.
    expect(res.nodeStates['plaque_elec'], B3State.failed);
    expect(res.nodeStates['rechaud_gaz'], B3State.failed);
    expect(res.nodeStates['cuisiner'], B3State.failed);
  });

  test('Cas 10 : Diagnostic incomplet → inconnu/not assessed, pas absence', () {
    final state = DiagnosticState();
    final conf = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(appKnowledgeBase, conf);
    final res = engine.runSimulation(graph, scenarioElec);
    
    // Since nothing answered, capability defaults to notAssessed because we assume they might have something we didn't ask.
    // Wait, the engine defaults to NOT_ASSESSED if the capability has no children evaluated as maintained/failed.
    expect(res.nodeStates['chauffer'], B3State.notAssessed);
  });

  test('Cas 11 : Régression complète du diagnostic', () {
    // A fully filled happy path
    final state = DiagnosticState()
      ..answerMultiple('q_heat_main', ['opt_poele_bois'])
      ..answerQuestion('q_heat_bois_reserve', 'opt_bois_yes')
      ..answerMultiple('q_cook_main', ['opt_gaz_bouteille'])
      ..answerQuestion('q_cook_gaz_reserve', 'opt_gaz_yes')
      ..answerQuestion('q_cook_gaz_duration', 'opt_gaz_long')
      ..answerMultiple('q_light_main', ['opt_lampe_bat'])
      ..answerQuestion('q_light_bat_reserve', 'opt_bat_yes');
      
    final conf = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(appKnowledgeBase, conf);
    final res = engine.runSimulation(graph, scenarioElec);
    
    expect(res.nodeStates['chauffer'], B3State.maintained);
    expect(res.nodeStates['cuisiner'], B3State.maintained);
    expect(res.nodeStates['eclairage'], B3State.maintained);
  });
}
