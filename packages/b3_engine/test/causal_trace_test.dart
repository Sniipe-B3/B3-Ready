import 'package:test/test.dart';
import 'package:b3_engine/b3_engine.dart';

void main() {
  final scenarioElec = DataMapper.parseScenario(b3KnowledgeBase, 'panne_elec');
  DataMapper.parseScenario(b3KnowledgeBase, 'panne_elec_gaz');

  test('TEST A & B — CAUSALITÉ DIRECTE ET INDIRECTE', () {
    final household = HouseholdConfig(
        ownedAssets: ['plaque_elec'], assessedCapabilities: {'cuisiner'});
    final graph = DataMapper.buildGraph(b3KnowledgeBase, household);
    final result = B3Engine().runSimulation(graph, scenarioElec);

    final vuln =
        result.vulnerabilities.firstWhere((v) => v.capability.id == 'cuisiner');

    expect(vuln.causeNodeIds.contains('elec'), true);
  });

  test('TEST D — ALTERNATIVE (Recommandation causale)', () {
    final household = HouseholdConfig(
        ownedAssets: ['plaque_elec'], assessedCapabilities: {'cuisiner'});
    final graph = DataMapper.buildGraph(b3KnowledgeBase, household);
    final result = B3Engine().runSimulation(graph, scenarioElec);
    final recs = RecommendationEngine(b3KnowledgeBase)
        .generate(result, household, scenarioElec);

    final rec = recs.firstWhere((r) => r.targetAssetId == 'rechaud_gaz');

    expect(rec.causeNodeIds.contains('elec'), true);
    expect(rec.reason.contains('Électricité'), true);
  });

  test('TEST E — ALTERNATIVE AVEC RESSOURCE UNKNOWN', () {
    final household = HouseholdConfig(
        ownedAssets: ['plaque_elec', 'rechaud_gaz'],
        ownedResources: ['gaz'],
        assessedResources: {'gaz'}, // mais pas de durée = UNKNOWN
        assessedCapabilities: {'cuisiner'});
    final result = B3Engine().runSimulation(
        DataMapper.buildGraph(b3KnowledgeBase, household), scenarioElec);
    final recs = RecommendationEngine(b3KnowledgeBase)
        .generate(result, household, scenarioElec);

    final unc =
        result.uncertainties.firstWhere((u) => u.capability.id == 'cuisiner');
    expect(unc.causeNodeIds.contains('elec'), true);
    expect(unc.causeNodeIds.contains('gaz'), true);

    final recVer = recs.firstWhere((r) =>
        r.capabilityId == 'cuisiner' && r.type == RecommendationType.verify && r.targetResourceId == 'gaz');
    expect(recVer.causeNodeIds.contains('gaz'), true);
    expect(recVer.causeNodeIds.contains('elec'), false);
  });

  test('TEST F & G — MULTI-SYSTEM / FAUSSE REDONDANCE', () {
    final household = HouseholdConfig(
        ownedAssets: ['plaque_elec', 'four_elec'],
        assessedCapabilities: {'cuisiner'});
    final result = B3Engine().runSimulation(
        DataMapper.buildGraph(b3KnowledgeBase, household), scenarioElec);

    final vuln =
        result.vulnerabilities.firstWhere((v) => v.capability.id == 'cuisiner');

    expect(vuln.causeNodeIds.contains('elec'), true);
    expect(vuln.causeNodeIds.length, 1);
  });

  test('TEST I — NON-INVENTION', () {
    final household = HouseholdConfig(
        ownedAssets: ['rechaud_gaz'], assessedCapabilities: {'cuisiner'});
    final result = B3Engine().runSimulation(
        DataMapper.buildGraph(b3KnowledgeBase, household), scenarioElec);

    final unc =
        result.uncertainties.firstWhere((u) => u.capability.id == 'cuisiner');
    expect(unc.state, B3State.notAssessed);
    expect(unc.causeNodeIds.contains('gaz'), true);
  });
}
