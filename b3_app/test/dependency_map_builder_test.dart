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

  test('TEST 2: Cascade profonde', () {
    final syntheticKb = '''{
      "capabilities": [{"id": "capA", "name": "Cap A", "assets": ["assetB"]}],
      "assets": [{"id": "assetB", "name": "Asset B", "requires": ["sysC"]}],
      "systems": [
        {"id": "sysC", "name": "System C", "requires": ["sysD"]},
        {"id": "sysD", "name": "System D", "requires": []}
      ],
      "scenarios": [
        {"id": "failD", "name": "Fail D", "duration": 24, "overrides": {"sysD": "failed"}}
      ]
    }''';
    final b = DependencyMapBuilder(syntheticKb);
    final config = HouseholdConfig(ownedAssets: ['assetB']);
    final graph = DataMapper.buildGraph(syntheticKb, config);
    final res = engine.runSimulation(graph, DataMapper.parseScenario(syntheticKb, 'failD'));
    
    final node = b.buildTree('capA', config, res);
    
    expect(node.id, 'capA');
    expect(node.state, B3State.failed);
    expect(node.children.length, 1);
    
    final bNode = node.children.first;
    expect(bNode.id, 'assetB');
    expect(bNode.state, B3State.failed);
    expect(bNode.children.length, 1);
    
    final cNode = bNode.children.first;
    expect(cNode.id, 'sysC');
    expect(cNode.state, B3State.failed);
    expect(cNode.children.length, 1);
    
    final dNode = cNode.children.first;
    expect(dNode.id, 'sysD');
    expect(dNode.state, B3State.failed);
    expect(dNode.children.isEmpty, true);
  });

  test('TEST 11: Cycle', () {
    final syntheticKb = '''{
      "capabilities": [{"id": "capA", "name": "Cap A", "assets": ["assetB"]}],
      "assets": [{"id": "assetB", "name": "Asset B", "requires": ["sysC"]}],
      "systems": [
        {"id": "sysC", "name": "System C", "requires": ["sysD"]},
        {"id": "sysD", "name": "System D", "requires": ["sysC"]}
      ],
      "scenarios": [
        {"id": "test", "name": "Test", "duration": 24, "overrides": {}}
      ]
    }''';
    final b = DependencyMapBuilder(syntheticKb);
    final config = HouseholdConfig(ownedAssets: ['assetB']);
    final graph = DataMapper.buildGraph(syntheticKb, config);
    final res = engine.runSimulation(graph, DataMapper.parseScenario(syntheticKb, 'test'));
    
    // Should not throw or stack overflow
    final node = b.buildTree('capA', config, res);
    
    final cNode = node.children.first.children.first;
    expect(cNode.id, 'sysC');
    final dNode = cNode.children.first;
    expect(dNode.id, 'sysD');
    // Cycle is broken here, sysC under sysD has no children
    final cNodeCycle = dNode.children.first;
    expect(cNodeCycle.id, 'sysC');
    expect(cNodeCycle.children.isEmpty, true);
  });

  test('TEST 12: Multiples causes différentes', () {
    final syntheticKb = '''{
      "capabilities": [{"id": "capA", "name": "Cap A", "assets": ["assetB", "assetC"]}],
      "assets": [
        {"id": "assetB", "name": "Asset B", "requires": ["sysX"]},
        {"id": "assetC", "name": "Asset C", "requires": ["sysY"]}
      ],
      "systems": [
        {"id": "sysX", "name": "System X", "requires": []},
        {"id": "sysY", "name": "System Y", "requires": []}
      ],
      "scenarios": [
        {"id": "failXY", "name": "Fail XY", "duration": 24, "overrides": {"sysX": "failed", "sysY": "failed"}}
      ]
    }''';
    final b = DependencyMapBuilder(syntheticKb);
    final config = HouseholdConfig(ownedAssets: ['assetB', 'assetC']);
    final graph = DataMapper.buildGraph(syntheticKb, config);
    final res = engine.runSimulation(graph, DataMapper.parseScenario(syntheticKb, 'failXY'));
    
    final node = b.buildTree('capA', config, res);
    final cause = b.getCausePhrase(node);
    
    expect(cause.contains("Vos solutions sont toutes indisponibles"), true);
    expect(cause.contains("Asset B : system x indisponible"), true);
    expect(cause.contains("Asset C : system y indisponible"), true);
  });

  test('TEST 13: Alternative réellement disponible', () {
    final state = DiagnosticState()
      ..answerMultiple('q_heat_main', ['opt_rad_elec', 'opt_poele_bois'])
      ..answerQuestion('q_heat_bois_reserve', 'opt_bois_yes');
      
    final config = state.toHouseholdConfig(questions);
    final graph = DataMapper.buildGraph(appKnowledgeBase, config);
    final res = engine.runSimulation(graph, DataMapper.parseScenario(appKnowledgeBase, 'panne_elec'));
    
    final node = builder.buildTree('chauffer', config, res);
    final cause = builder.getCausePhrase(node);
    
    expect(node.state, B3State.maintained);
    // Because elec is failed but bois is maintained
    expect(cause, "Une autre solution reste disponible malgré cette panne.");
  });

  test('TEST 14: Labels humains / Aucun ID technique', () {
    final syntheticKb = '''{
      "capabilities": [{"id": "capA", "name": "", "assets": ["assetB"]}],
      "assets": [{"id": "assetB", "name": "", "requires": []}],
      "scenarios": [{"id": "test", "name": "Test", "duration": 24, "overrides": {}}]
    }''';
    final b = DependencyMapBuilder(syntheticKb);
    final config = HouseholdConfig(ownedAssets: ['assetB']);
    final graph = DataMapper.buildGraph(syntheticKb, config);
    final res = engine.runSimulation(graph, DataMapper.parseScenario(syntheticKb, 'test'));
    
    expect(() => b.buildTree('capA', config, res), throwsStateError);
  });
}
