import 'package:test/test.dart';
import 'package:b3_engine/b3_engine.dart';

void main() {
  test('BUG DEMO: RecommendationEngine does not generate specific verify for UNKNOWN resources', () {
    final kb = '''{
      "capabilities": [{"id": "capA", "name": "Cap A", "assets": ["assetB"]}],
      "assets": [{"id": "assetB", "name": "Asset B", "requires": ["resC"]}],
      "resources": [{"id": "resC", "name": "Res C"}],
      "scenarios": [{"id": "s", "name": "S", "duration": 24, "overrides": {}}]
    }''';

    final config = HouseholdConfig(
      ownedAssets: ['assetB'],
      ownedResources: ['resC'],
      // assessedResources is empty -> resC is NOT_ASSESSED
    );

    final graph = DataMapper.buildGraph(kb, config);
    final scenario = DataMapper.parseScenario(kb, 's');
    final result = B3Engine().runSimulation(graph, scenario);
    
    // Capability is NOT_ASSESSED/UNKNOWN
    expect(result.uncertainties.length, 1);
    
    final engine = RecommendationEngine(kb);
    final recs = engine.generate(result, config, scenario);
    
    // We expect a specific 'verify' recommendation for resC (id: rec_ver_assetB_resC)
    // But currently, it only generates a generic 'rec_verify_capA'
    final hasSpecificVerify = recs.any((r) => r.id == 'rec_ver_assetB_resC');
    print('Specific verify found: \$hasSpecificVerify');
    
    // If the bug exists, this will fail
    expect(hasSpecificVerify, true);
  });
}
