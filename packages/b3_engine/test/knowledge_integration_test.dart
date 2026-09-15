import 'package:test/test.dart';
import 'package:b3_engine/b3_engine.dart';

void main() {
  final engine = B3Engine();

  test('Test 1: Le JSON est correctement chargé', () {
    final household = HouseholdConfig(
        ownedAssets: ['plaque_elec', 'rechaud_gaz'],
        ownedResources: ['gaz'],
        assessedResources: {'gaz'},
        resourceDurations: {'gaz': Duration(hours: 72)});
    final graph = DataMapper.buildGraph(b3KnowledgeBase, household);

    final cuisiner = graph.firstWhere((n) => n.id == 'cuisiner') as Capability;
    expect(cuisiner.children.length, 2);
    expect(cuisiner.children.any((c) => c.id == 'plaque_elec'), true);
    expect(cuisiner.children.any((c) => c.id == 'rechaud_gaz'), true);
  });

  test('Test 2: Panne électrique fait échouer la plaque', () {
    final household = HouseholdConfig(ownedAssets: ['plaque_elec']);
    final graph = DataMapper.buildGraph(b3KnowledgeBase, household);
    final scenario = DataMapper.parseScenario(b3KnowledgeBase, 'panne_elec');

    final result = engine.runSimulation(graph, scenario);
    expect(result.nodeStates['plaque_elec'], B3State.failed);
    expect(result.nodeStates['cuisiner'], B3State.failed);
  });

  test('Test 3: Le réchaud gaz maintient la capacité', () {
    final household = HouseholdConfig(
        ownedAssets: ['plaque_elec', 'rechaud_gaz'],
        ownedResources: ['gaz'],
        assessedResources: {'gaz'},
        resourceDurations: {'gaz': Duration(hours: 72)});
    final graph = DataMapper.buildGraph(b3KnowledgeBase, household);
    final scenario = DataMapper.parseScenario(b3KnowledgeBase, 'panne_elec');

    final result = engine.runSimulation(graph, scenario);
    expect(result.nodeStates['plaque_elec'], B3State.failed);
    expect(result.nodeStates['rechaud_gaz'], B3State.maintained);
    expect(result.nodeStates['cuisiner'], B3State.maintained);
  });

  test('Test 4: Panne électrique + gaz fait échouer cuisiner', () {
    final household = HouseholdConfig(
        ownedAssets: ['plaque_elec', 'rechaud_gaz'],
        ownedResources: ['gaz'],
        assessedResources: {'gaz'},
        resourceDurations: {'gaz': Duration(hours: 72)});
    final graph = DataMapper.buildGraph(b3KnowledgeBase, household);
    final scenario =
        DataMapper.parseScenario(b3KnowledgeBase, 'panne_elec_gaz');

    final result = engine.runSimulation(graph, scenario);
    expect(result.nodeStates['cuisiner'], B3State.failed);
  });

  test('Test 5: Plaque + four n est pas une vraie redondance', () {
    final household =
        HouseholdConfig(ownedAssets: ['plaque_elec', 'four_elec']);
    final graph = DataMapper.buildGraph(b3KnowledgeBase, household);
    final scenario = DataMapper.parseScenario(b3KnowledgeBase, 'panne_elec');

    final result = engine.runSimulation(graph, scenario);
    expect(result.nodeStates['plaque_elec'], B3State.failed);
    expect(result.nodeStates['four_elec'], B3State.failed);
    expect(result.nodeStates['cuisiner'], B3State.failed);
  });

  test('Test 6: Scénario internet affecte uniquement les capacités dépendantes',
      () {
    final household = HouseholdConfig(ownedAssets: ['plaque_elec', 'voip']);
    final graph = DataMapper.buildGraph(b3KnowledgeBase, household);
    final scenario =
        DataMapper.parseScenario(b3KnowledgeBase, 'panne_internet');

    final result = engine.runSimulation(graph, scenario);
    expect(result.nodeStates['cuisiner'], B3State.maintained);
    expect(result.nodeStates['communiquer'], B3State.failed);
  });

  test('Test 7: Panne électrique affecte plusieurs capacités simultanément',
      () {
    final household = HouseholdConfig(ownedAssets: [
      'plaque_elec',
      'lampe_secteur',
      'radiateur_elec',
      'frigo',
      'robinet'
    ]);
    final graph = DataMapper.buildGraph(b3KnowledgeBase, household);
    final scenario = DataMapper.parseScenario(b3KnowledgeBase, 'panne_elec');

    final result = engine.runSimulation(graph, scenario);
    expect(result.nodeStates['cuisiner'], B3State.failed);
    expect(result.nodeStates['eclairage'], B3State.failed);
    expect(result.nodeStates['chauffer'], B3State.failed);
    expect(result.nodeStates['conserver'], B3State.failed);
    expect(result.nodeStates['boire'],
        B3State.maintained); // Robinet direct dépend de l'eau, pas elec
  });

  test('Test 8: Le moteur fonctionne sans connaître le vocabulaire', () {
    // Injecting completely generic JSON to prove Engine ignorance
    final genericJson = '''
    {
      "systems": [{"id": "s1", "name": "Sys1"}],
      "assets": [{"id": "a1", "name": "Asset1", "requires": ["s1"]}],
      "capabilities": [{"id": "c1", "name": "Cap1", "assets": ["a1"]}],
      "scenarios": [{"id": "scen1", "name": "Scen1", "overrides": {"s1": "failed"}}]
    }
    ''';
    final household = HouseholdConfig(ownedAssets: ['a1']);
    final graph = DataMapper.buildGraph(genericJson, household);
    final scenario = DataMapper.parseScenario(genericJson, 'scen1');

    final result = engine.runSimulation(graph, scenario);
    expect(result.nodeStates['c1'], B3State.failed);
  });
}
