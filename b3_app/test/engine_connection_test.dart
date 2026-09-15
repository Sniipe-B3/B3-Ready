import 'package:flutter_test/flutter_test.dart';
import 'package:b3_engine/b3_engine.dart';

void main() {
  test('B3App peut instancier le B3Engine', () {
    final engine = B3Engine();
    expect(engine, isNotNull);
  });

  test('B3App peut utiliser le DataMapper et le B3Engine ensemble', () {
    final household = HouseholdConfig(
      ownedAssets: [],
      assessedCapabilities: {'cuisiner'},
    );
    final graph = DataMapper.buildGraph(b3KnowledgeBase, household);
    final scenario = DataMapper.parseScenario(b3KnowledgeBase, 'panne_elec');

    final result = B3Engine().runSimulation(graph, scenario);

    expect(result.uncertainties.isNotEmpty || result.vulnerabilities.isNotEmpty,
        true);
  });
}
