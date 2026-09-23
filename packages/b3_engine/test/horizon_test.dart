import 'dart:convert';
import 'package:test/test.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_engine/src/data_mapper.dart';

void main() {
  group('Preparedness Horizons (04.26)', () {
    final knowledgeJson = jsonEncode({
      'capabilities': [
        {'id': 'cap1', 'name': 'Cap 1', 'assets': ['asset1', 'asset2']}
      ],
      'assets': [
        {'id': 'asset1', 'name': 'Asset 1', 'requires': ['res1']},
        {'id': 'asset2', 'name': 'Asset 2', 'requires': []} // sans ressource
      ],
      'resources': [
        {'id': 'res1', 'name': 'Resource 1'}
      ],
      'scenarios': [
        {
          'id': 'scen1',
          'name': 'Scenario 1',
          'duration': 24, // default 24h
          'overrides': {}
        }
      ]
    });

    test('A. resource known = 96h, horizon = 72h -> suffisante (Maintained)', () {
      final config = HouseholdConfig(
        ownedAssets: ['asset1'],
        ownedResources: ['res1'],
        assessedResources: {'res1'},
        resourceDurations: {'res1': const Duration(hours: 96)}
      );
      final scenario = DataMapper.parseScenario(knowledgeJson, 'scen1', PreparednessHorizon.threeDays.duration);
      final graph = DataMapper.buildGraph(knowledgeJson, config);
      final result = B3Engine().runSimulation(graph, scenario);
      
      expect(result.nodeStates['cap1'], B3State.maintained);
    });

    test('B. resource known = 24h, horizon = 72h -> insuffisante (Degraded)', () {
      final config = HouseholdConfig(
        ownedAssets: ['asset1'],
        ownedResources: ['res1'],
        assessedResources: {'res1'},
        resourceDurations: {'res1': const Duration(hours: 24)}
      );
      final scenario = DataMapper.parseScenario(knowledgeJson, 'scen1', PreparednessHorizon.threeDays.duration);
      final graph = DataMapper.buildGraph(knowledgeJson, config);
      final result = B3Engine().runSimulation(graph, scenario);
      
      expect(result.nodeStates['cap1'], B3State.degraded);
    });

    test('C. resource unknown, horizon 6h -> UNKNOWN', () {
      final config = HouseholdConfig(
        ownedAssets: ['asset1'],
        ownedResources: ['res1'],
        assessedResources: {'res1'},
        unknownResources: {'res1'}
      );
      final scenario = DataMapper.parseScenario(knowledgeJson, 'scen1', PreparednessHorizon.sixHours.duration);
      final graph = DataMapper.buildGraph(knowledgeJson, config);
      final result = B3Engine().runSimulation(graph, scenario);
      
      expect(result.nodeStates['cap1'], B3State.unknown);
    });

    test('D. resource unknown, horizon 7j -> UNKNOWN', () {
      final config = HouseholdConfig(
        ownedAssets: ['asset1'],
        ownedResources: ['res1'],
        assessedResources: {'res1'},
        unknownResources: {'res1'}
      );
      final scenario = DataMapper.parseScenario(knowledgeJson, 'scen1', PreparednessHorizon.sevenDays.duration);
      final graph = DataMapper.buildGraph(knowledgeJson, config);
      final result = B3Engine().runSimulation(graph, scenario);
      
      expect(result.nodeStates['cap1'], B3State.unknown);
    });

    test('E. resource absent -> FAILED', () {
      final config = HouseholdConfig(
        ownedAssets: ['asset1'],
        ownedResources: [],
        assessedResources: {'res1'}
      );
      final scenario = DataMapper.parseScenario(knowledgeJson, 'scen1', PreparednessHorizon.sixHours.duration);
      final graph = DataMapper.buildGraph(knowledgeJson, config);
      final result = B3Engine().runSimulation(graph, scenario);
      
      expect(result.nodeStates['cap1'], B3State.failed);
    });

    test('F. resource not assessed -> NOT_ASSESSED', () {
      final config = HouseholdConfig(
        ownedAssets: ['asset1'],
        ownedResources: ['res1'], // implicitly owned but not assessed
        assessedResources: {}
      );
      final scenario = DataMapper.parseScenario(knowledgeJson, 'scen1', PreparednessHorizon.oneDay.duration);
      final graph = DataMapper.buildGraph(knowledgeJson, config);
      final result = B3Engine().runSimulation(graph, scenario);
      
      expect(result.nodeStates['cap1'], B3State.notAssessed);
    });

    test('G. solution sans ressource limitee -> pas artificiellement degradee avec l horizon', () {
      final config = HouseholdConfig(
        ownedAssets: ['asset2'], // uses no resource
        ownedResources: [],
        assessedResources: {}
      );
      final scenario = DataMapper.parseScenario(knowledgeJson, 'scen1', PreparednessHorizon.sevenDays.duration);
      final graph = DataMapper.buildGraph(knowledgeJson, config);
      final result = B3Engine().runSimulation(graph, scenario);
      
      expect(result.nodeStates['cap1'], B3State.maintained);
    });

    test('H. changer horizon ne modifie pas HouseholdConfig', () {
      final config = HouseholdConfig(
        ownedAssets: ['asset1'],
        ownedResources: ['res1'],
        assessedResources: {'res1'},
        resourceDurations: {'res1': const Duration(hours: 48)}
      );
      
      // Initial state
      final resList = config.resourceDurations.keys.toList();
      
      // Parse scenario with 72h horizon
      DataMapper.parseScenario(knowledgeJson, 'scen1', PreparednessHorizon.threeDays.duration);
      
      // Validate HouseholdConfig did not change
      expect(config.resourceDurations.keys.toList(), equals(resList));
      expect(config.resourceDurations['res1']!.inHours, 48);
    });

    test('I. memes inputs + meme horizon -> meme resultat', () {
      final config = HouseholdConfig(
        ownedAssets: ['asset1'],
        ownedResources: ['res1'],
        assessedResources: {'res1'},
        resourceDurations: {'res1': const Duration(hours: 48)}
      );
      final scenario1 = DataMapper.parseScenario(knowledgeJson, 'scen1', PreparednessHorizon.threeDays.duration);
      final result1 = B3Engine().runSimulation(DataMapper.buildGraph(knowledgeJson, config), scenario1);
      
      final scenario2 = DataMapper.parseScenario(knowledgeJson, 'scen1', PreparednessHorizon.threeDays.duration);
      final result2 = B3Engine().runSimulation(DataMapper.buildGraph(knowledgeJson, config), scenario2);
      
      expect(result1.nodeStates['cap1'], result2.nodeStates['cap1']);
    });

    test('J. 24h puis 72h puis 24h -> resultat 24h identique au premier', () {
      final config = HouseholdConfig(
        ownedAssets: ['asset1'],
        ownedResources: ['res1'],
        assessedResources: {'res1'},
        resourceDurations: {'res1': const Duration(hours: 48)}
      );
      
      final sc24_1 = DataMapper.parseScenario(knowledgeJson, 'scen1', PreparednessHorizon.oneDay.duration);
      final r24_1 = B3Engine().runSimulation(DataMapper.buildGraph(knowledgeJson, config), sc24_1);
      expect(r24_1.nodeStates['cap1'], B3State.maintained);
      
      final sc72 = DataMapper.parseScenario(knowledgeJson, 'scen1', PreparednessHorizon.threeDays.duration);
      final r72 = B3Engine().runSimulation(DataMapper.buildGraph(knowledgeJson, config), sc72);
      expect(r72.nodeStates['cap1'], B3State.degraded);
      
      final sc24_2 = DataMapper.parseScenario(knowledgeJson, 'scen1', PreparednessHorizon.oneDay.duration);
      final r24_2 = B3Engine().runSimulation(DataMapper.buildGraph(knowledgeJson, config), sc24_2);
      expect(r24_2.nodeStates['cap1'], B3State.maintained);
    });
    
    test('Invariant UNKNOWN (Critique B3)', () {
      // Une ressource UNKNOWN ne doit jamais devenir MAINTAINED simplement parce que l\'horizon est court
      final config = HouseholdConfig(
        ownedAssets: ['asset1'],
        ownedResources: ['res1'],
        assessedResources: {'res1'},
        unknownResources: {'res1'}
      );
      final scenario = DataMapper.parseScenario(knowledgeJson, 'scen1', PreparednessHorizon.sixHours.duration);
      final graph = DataMapper.buildGraph(knowledgeJson, config);
      final result = B3Engine().runSimulation(graph, scenario);
      
      expect(result.nodeStates['cap1'], B3State.unknown);
      expect(result.nodeStates['cap1'], isNot(B3State.maintained));
    });
  });
}
