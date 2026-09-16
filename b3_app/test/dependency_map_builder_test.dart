import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/data/app_knowledge_dataset.dart';
import 'package:b3_app/data/app_diagnostic_dataset.dart';
import 'package:b3_app/features/dependency_map/models/dependency_node.dart';
import 'package:b3_app/features/dependency_map/view_models/dependency_map_builder.dart';

void main() {
  late DependencyMapBuilder builder;
  late B3Engine engine;
  late List<DiagnosticQuestion> questions;

  setUp(() {
    builder = DependencyMapBuilder(appKnowledgeBase);
    engine = B3Engine();
    questions = (jsonDecode(appDiagnosticQuestionsJson) as List)
        .map((q) => DiagnosticQuestion.fromJson(q))
        .toList();
  });

  test('TEST 1: Chaîne simple', () {
    final state = DiagnosticState()..answerMultiple('q_heat_main', ['opt_rad_elec']);
    final config = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(appKnowledgeBase, config);
    final res = engine.runSimulation(graph, DataMapper.parseScenario(appKnowledgeBase, 'panne_elec'));
    
    final node = builder.buildTree('chauffer', config, res);
    
    expect(node.id, 'chauffer');
    expect(node.label, 'Se chauffer');
    expect(node.state, B3State.failed);
    expect(node.children.length, 1);
    
    final asset = node.children.first;
    expect(asset.id, 'radiateur_elec');
    expect(asset.state, B3State.failed);
    expect(asset.children.length, 1);
    
    final req = asset.children.first;
    expect(req.id, 'elec');
    expect(req.type, MapNodeType.system);
    expect(req.state, B3State.failed);
    
    final cause = builder.getCausePhrase(node);
    expect(cause.contains("réseau électrique"), true);
  });

  test('TEST 3: Deux alternatives indépendantes', () {
    final state = DiagnosticState()
      ..answerMultiple('q_heat_main', ['opt_rad_elec', 'opt_poele_bois'])
      ..answerQuestion('q_heat_bois_reserve', 'opt_bois_yes');
      
    final config = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(appKnowledgeBase, config);
    final res = engine.runSimulation(graph, DataMapper.parseScenario(appKnowledgeBase, 'panne_elec'));
    
    final node = builder.buildTree('chauffer', config, res);
    expect(node.state, B3State.maintained);
    expect(node.children.length, 2);
    
    final elecAsset = node.children.firstWhere((n) => n.id == 'radiateur_elec');
    expect(elecAsset.state, B3State.failed);
    
    final boisAsset = node.children.firstWhere((n) => n.id == 'poele_bois');
    expect(boisAsset.state, B3State.maintained);
    
    final cause = builder.getCausePhrase(node);
    expect(cause, "Une alternative indépendante reste disponible.");
  });

  test('TEST 4: Fausse redondance avec racine commune', () {
    final state = DiagnosticState()
      ..answerMultiple('q_heat_main', ['opt_rad_elec', 'opt_pac']);
      
    final config = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(appKnowledgeBase, config);
    final res = engine.runSimulation(graph, DataMapper.parseScenario(appKnowledgeBase, 'panne_elec'));
    
    final node = builder.buildTree('chauffer', config, res);
    expect(node.state, B3State.failed);
    expect(node.children.length, 2);
    
    final cause = builder.getCausePhrase(node);
    expect(cause.contains("Vos 2 solutions dépendent de"), true);
  });

  test('TEST 5: Ressource UNKNOWN', () {
    final state = DiagnosticState()
      ..answerMultiple('q_heat_main', ['opt_poele_bois'])
      ..answerQuestion('q_heat_bois_reserve', 'opt_bois_unk');
      
    final config = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(appKnowledgeBase, config);
    final res = engine.runSimulation(graph, DataMapper.parseScenario(appKnowledgeBase, 'panne_elec'));
    
    final node = builder.buildTree('chauffer', config, res);
    expect(node.state, B3State.unknown);
    
    final req = node.children.first.children.first;
    expect(req.id, 'bois');
    expect(req.state, B3State.unknown);
  });

  test('TEST 6 & 7: Ressource NOT_ASSESSED / FAILED', () {
    // NOT ASSESSED
    final state1 = DiagnosticState()..answerMultiple('q_cook_main', ['opt_gaz_bouteille']);
    final config1 = state1.toHouseholdConfig(questions);
    final g1 = DataMapper.buildGraph(appKnowledgeBase, config1);
    final res1 = engine.runSimulation(g1, DataMapper.parseScenario(appKnowledgeBase, 'panne_elec'));
    final n1 = builder.buildTree('cuisiner', config1, res1);
    expect(n1.children.first.children.first.state, B3State.notAssessed);
    
    // FAILED
    final state2 = DiagnosticState()
      ..answerMultiple('q_heat_main', ['opt_poele_bois'])
      ..answerQuestion('q_heat_bois_reserve', 'opt_bois_no');
    final config2 = state2.toHouseholdConfig(questions);
    final g2 = DataMapper.buildGraph(appKnowledgeBase, config2);
    final res2 = engine.runSimulation(g2, DataMapper.parseScenario(appKnowledgeBase, 'panne_elec'));
    final n2 = builder.buildTree('chauffer', config2, res2);
    expect(n2.children.first.children.first.state, B3State.failed);
  });

  test('TEST 8: Alternative DEGRADED', () {
    final state = DiagnosticState()
      ..answerMultiple('q_heat_main', ['opt_rad_elec', 'opt_poele_bois'])
      ..answerQuestion('q_heat_bois_reserve', 'opt_bois_limit'); // 24h
      
    final config = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(appKnowledgeBase, config);
    final res = engine.runSimulation(graph, DataMapper.parseScenario(appKnowledgeBase, 'panne_elec')); // 72h scenario
    
    final node = builder.buildTree('chauffer', config, res);
    expect(node.state, B3State.degraded);
    
    final boisAsset = node.children.firstWhere((n) => n.id == 'poele_bois');
    expect(boisAsset.state, B3State.degraded);
  });

  test('TEST 9: Aucune invention', () {
    final state = DiagnosticState();
    final config = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(appKnowledgeBase, config);
    final res = engine.runSimulation(graph, DataMapper.parseScenario(appKnowledgeBase, 'panne_elec'));
    
    final node = builder.buildTree('chauffer', config, res);
    expect(node.children.isEmpty, true);
  });

  test('TEST 10: Déterminisme', () {
    final state = DiagnosticState()..answerMultiple('q_heat_main', ['opt_rad_elec']);
    final config = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(appKnowledgeBase, config);
    final scenario = DataMapper.parseScenario(appKnowledgeBase, 'panne_elec');
    
    final res1 = engine.runSimulation(graph, scenario);
    final n1 = builder.buildTree('chauffer', config, res1);
    
    final res2 = engine.runSimulation(graph, scenario);
    final n2 = builder.buildTree('chauffer', config, res2);
    
    expect(n1.state, n2.state);
    expect(n1.children.first.id, n2.children.first.id);
  });
}
