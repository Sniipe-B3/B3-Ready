import 'package:test/test.dart';
import 'package:b3_engine/b3_engine.dart';

void main() {
  const b3KnowledgeBase = '''{
    "capabilities": [{"id": "cap1", "name": "Cap1", "type": "ALL", "systems": [], "assets": ["asset1"]}],
    "assets": [{"id": "asset1", "name": "Asset1", "type": "INDEPENDENT", "dependencies": [], "requires": ["resC"]}],
    "resources": [{"id": "resC", "name": "ResC"}],
    "systems": [],
    "scenarios": [{"id": "s", "name": "S", "impactedSystems": [], "description": ""}]
  }''';

  final scenario = DataMapper.parseScenario(b3KnowledgeBase, 's');
  
  test('TEST ENGINE 1 — UNKNOWN réel', () {
    final household = HouseholdConfig(
      ownedAssets: ['asset1'],
      ownedResources: ['resC'],
      unknownResources: {'resC'},
      assessedCapabilities: {'cap1'},
    );
    final graph = DataMapper.buildGraph(b3KnowledgeBase, household);
    final engine = B3Engine();
    final result = engine.runSimulation(graph, scenario);
    
    expect(result.nodeStates['resC'], B3State.unknown);
    
    final recs = RecommendationEngine(b3KnowledgeBase).generate(result, household, scenario);
    
    final specificVerify = recs.firstWhere((r) => r.type == RecommendationType.verify && r.targetResourceId == 'resC', orElse: () => throw Exception('No specific verify found'));
    expect(specificVerify.description, 'Vous ne connaissez pas encore la quantité disponible.');
  });

  test('TEST ENGINE 2 — NOT_ASSESSED réel', () {
    final household = HouseholdConfig(
      ownedAssets: ['asset1'],
      ownedResources: ['resC'],
      unknownResources: {},
      assessedCapabilities: {'cap1'},
    );
    final graph = DataMapper.buildGraph(b3KnowledgeBase, household);
    final engine = B3Engine();
    final result = engine.runSimulation(graph, scenario);
    
    expect(result.nodeStates['resC'], B3State.notAssessed);
    
    final recs = RecommendationEngine(b3KnowledgeBase).generate(result, household, scenario);
    
    final specificVerify = recs.firstWhere((r) => r.type == RecommendationType.verify && r.targetResourceId == 'resC', orElse: () => throw Exception('No specific verify found'));
    expect(specificVerify.description, 'Cette information n\'a pas encore été vérifiée.');
  });
}
