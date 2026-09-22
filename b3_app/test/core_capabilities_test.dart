import 'dart:convert';
import 'package:b3_app/data/app_diagnostic_dataset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/data/app_knowledge_dataset.dart';
import 'package:b3_app/features/scenarios/services/multi_scenario_analyzer.dart';
import 'package:b3_app/features/scenarios/services/cross_scenario_analyzer.dart';

void main() {
  late MultiScenarioAnalyzer multiAnalyzer;
  late CrossScenarioAnalyzer crossAnalyzer;
  

  setUp(() {
    multiAnalyzer = MultiScenarioAnalyzer(appKnowledgeBase);
    crossAnalyzer = CrossScenarioAnalyzer(appKnowledgeBase);
    
  });

  HouseholdConfig _buildConfig({
    List<String> assets = const [],
    List<String> resources = const [],
    Map<String, Duration> resourceDurations = const {},
    Set<String> assessedCapabilities = const {},
    Set<String> assessedResources = const {},
    Set<String> unknownResources = const {},
  }) {
    return HouseholdConfig(
      ownedAssets: assets,
      ownedResources: resources,
      resourceDurations: resourceDurations,
      assessedCapabilities: assessedCapabilities,
      capabilityOverrides: {},
      assessedResources: assessedResources,
      unknownResources: unknownResources,
    );
  }

  test('TEST A — REFRIGERATEUR', () {
    final config = _buildConfig(
      assets: ['refrigerateur'],
      assessedCapabilities: {'conserver_aliments'},
    );
    final results = multiAnalyzer.analyze(config, ['panne_elec']);
    if (results.first.simulationResult == null) { throw Exception(results.first.error); } final res = results.first.simulationResult!;
    expect(res.nodeStates['refrigerateur'], B3State.failed);
    expect(res.nodeStates['conserver_aliments'], B3State.failed);
  });

  test('TEST B — PAS D INVENTION RÉFRIGÉRATEUR', () {
    final config = _buildConfig(
      assets: [],
      assessedCapabilities: {'conserver_aliments'},
    );
    final results = multiAnalyzer.analyze(config, ['panne_elec']);
    final res = results.first.simulationResult!;
    expect(res.nodeStates['refrigerateur'], null);
    // Since asset is not there and no alternatives, it's either failed or absent.
    // Usually B3 engine marks missing assets as not in nodeStates or if capability is evaluated, it becomes absent or failed depending on DataMapper
    expect(res.nodeStates['conserver_aliments'], B3State.failed); 
  });

  test('TEST C — BATTERIE CONNUE', () {
    final config = _buildConfig(
      assets: ['batterie_externe'],
      resources: ['stock_energie_portable'],
      resourceDurations: {'stock_energie_portable': Duration(hours: 72)},
      assessedCapabilities: {'recharger_appareils'},
      assessedResources: {'stock_energie_portable'},
    );
    final results = multiAnalyzer.analyze(config, ['panne_elec']);
    final res = results.first.simulationResult!;
    expect(res.nodeStates['recharger_appareils'], B3State.maintained);
  });

  test('TEST D — BATTERIE UNKNOWN', () {
    final config = _buildConfig(
      assets: ['batterie_externe'],
      resources: ['stock_energie_portable'],
      unknownResources: {'stock_energie_portable'},
      assessedCapabilities: {'recharger_appareils'},
    );
    final results = multiAnalyzer.analyze(config, ['panne_elec']);
    final res = results.first.simulationResult!;
    expect(res.nodeStates['recharger_appareils'], B3State.unknown);
  });

  test('TEST E — BATTERIE ABSENTE', () {
    final config = _buildConfig(
      assets: ['batterie_externe'],
      resources: [],
      assessedResources: {'stock_energie_portable'},
      assessedCapabilities: {'recharger_appareils'},
    );
    final results = multiAnalyzer.analyze(config, ['panne_elec']);
    final res = results.first.simulationResult!;
    // Without battery, recharger_appareils should be failed.
    expect(res.nodeStates['recharger_appareils'], B3State.failed);
  });

  test('TEST F — SANITAIRES', () {
    final config = _buildConfig(
      assets: ['wc_chasse_eau'],
      assessedCapabilities: {'utiliser_sanitaires'},
    );
    final results = multiAnalyzer.analyze(config, ['coupure_eau']);
    final res = results.first.simulationResult!;
    expect(res.nodeStates['wc_chasse_eau'], B3State.failed);
    expect(res.nodeStates['utiliser_sanitaires'], B3State.failed);
  });

  test('TEST G — PAS DE CASCADE FAUSSE', () {
    final config = _buildConfig(
      assets: ['wc_chasse_eau', 'refrigerateur', 'batterie_externe', 'plaque_elec'],
      resources: ['stock_energie_portable'],
      resourceDurations: {'stock_energie_portable': Duration(hours: 72)},
      assessedCapabilities: {'utiliser_sanitaires', 'conserver_aliments', 'recharger_appareils', 'cuisiner'},
      assessedResources: {'stock_energie_portable'},
    );
    final results = multiAnalyzer.analyze(config, ['coupure_eau']);
    final res = results.first.simulationResult!;
    expect(res.nodeStates['utiliser_sanitaires'], B3State.failed);
    expect(res.nodeStates['conserver_aliments'], B3State.maintained);
    expect(res.nodeStates['recharger_appareils'], B3State.maintained);
  });

  test('TEST H — INFORMATION + INTERNET', () {
    final config = _buildConfig(
      assets: ['box_internet', 'radio_autonome'],
      resources: ['stock_energie_portable'],
      resourceDurations: {'stock_energie_portable': Duration(hours: 72)},
      assessedCapabilities: {'acceder_internet', 'recevoir_informations'},
      assessedResources: {'stock_energie_portable'},
    );
    final results = multiAnalyzer.analyze(config, ['panne_internet']);
    final res = results.first.simulationResult!;
    expect(res.nodeStates['acceder_internet'], B3State.failed);
    expect(res.nodeStates['recevoir_informations'], B3State.maintained);
  });

  test('TEST I — INFORMATION SANS ALTERNATIVE', () {
    final config = _buildConfig(
      assets: ['smartphone'],
      assessedCapabilities: {'recevoir_informations'},
    );
    final results = multiAnalyzer.analyze(config, ['panne_mobile']);
    final res = results.first.simulationResult!;
    expect(res.nodeStates['recevoir_informations'], B3State.failed);
  });

  test('TEST J — UNKNOWN INFO', () {
    final config = _buildConfig(
      assets: ['radio_autonome'],
      resources: ['stock_energie_portable'],
      unknownResources: {'stock_energie_portable'},
      assessedCapabilities: {'recevoir_informations'},
    );
    final results = multiAnalyzer.analyze(config, ['panne_elec']);
    final res = results.first.simulationResult!;
    expect(res.nodeStates['recevoir_informations'], B3State.maintained);
  });

  test('TEST K — MULTI-SCENARIO', () {
    final config = _buildConfig(
      assets: ['refrigerateur', 'wc_chasse_eau'],
      assessedCapabilities: {'conserver_aliments', 'utiliser_sanitaires'},
    );
    final results = multiAnalyzer.analyze(config, ['panne_elec', 'panne_gaz', 'coupure_eau', 'panne_internet', 'panne_mobile']);
    expect(results.length, 5);
    final panneElec = results.firstWhere((r) => r.scenarioId == 'panne_elec');
    expect(panneElec.simulationResult!.nodeStates['conserver_aliments'], B3State.failed);
    final coupureEau = results.firstWhere((r) => r.scenarioId == 'coupure_eau');
    expect(coupureEau.simulationResult!.nodeStates['utiliser_sanitaires'], B3State.failed);
  });

  test('TEST L — GLOBAL OVERVIEW', () {
    // If a capability is FAILED in >= 2 scenarios, CrossScenarioAnalyzer creates a RecurringCapabilityIssue
    final config = _buildConfig(
      assets: ['box_internet'],
      assessedCapabilities: {'acceder_internet'},
    );
    final results = multiAnalyzer.analyze(config, ['panne_elec', 'panne_gaz', 'coupure_eau', 'panne_internet', 'panne_mobile']);
    final cross = crossAnalyzer.analyze(results);
    // box_internet depends on internet AND elec. So it fails in panne_elec and panne_internet.
    expect(cross.recurringIssues.any((i) => i.capabilityId == 'acceder_internet'), isTrue);
  });

  test('TEST M — DEPENDENCY IMPACT', () {
    final config = _buildConfig(
      assets: ['refrigerateur', 'batterie_externe', 'plaque_elec'],
      resources: ['stock_energie_portable'],
      resourceDurations: {'stock_energie_portable': Duration(hours: 72)},
      assessedCapabilities: {'conserver_aliments', 'recharger_appareils', 'cuisiner'},
      assessedResources: {'stock_energie_portable'},
    );
    final results = multiAnalyzer.analyze(config, ['panne_elec', 'panne_gaz', 'coupure_eau', 'panne_internet', 'panne_mobile']);
    final overview = crossAnalyzer.analyze(results);
    final impacts = overview.dependencyImpacts;
    
    final elecImpact = impacts.firstWhere((i) => i.causeNodeId == 'elec');
    expect(elecImpact.vulnerableCapabilityIds.contains('conserver_aliments'), isTrue);
    expect(elecImpact.vulnerableCapabilityIds.contains('recharger_appareils'), isFalse);
  });
  
  test('TEST N — DIAGNOSTIC ANTI-INVENTION', () {
    // Minimal answers, check it doesn't create elements out of nowhere.
    final config = HouseholdConfig(
        ownedAssets: [],
        ownedResources: [],
        resourceDurations: {},
        assessedCapabilities: {},
        capabilityOverrides: {},
        assessedResources: {},
        unknownResources: {},
    );
    final results = multiAnalyzer.analyze(config, ['panne_elec']);
    final res = results.first.simulationResult!;
    // conserver_aliments should be notAssessed because we haven't asked yet
    expect(res.nodeStates['conserver_aliments'], B3State.notAssessed);
  });

  test('TEST O — UNKNOWN / NOT_ASSESSED', () {
    final questions = (jsonDecode(appDiagnosticQuestionsJson) as List).map((q) => DiagnosticQuestion.fromJson(q)).toList();
    final state = DiagnosticState();
    
    // Powerbank declared
    state.answerMultiple('q_charge_main', ['opt_powerbank']);
    
    // But charge is unknown
    state.answerQuestion('q_charge_bat_status', 'opt_charge_unk');
    
    final config = state.toHouseholdConfig(questions);
    final nodes = DataMapper.buildGraph(appKnowledgeBase, config);
    final bat = nodes.firstWhere((n) => n.id == 'stock_energie_portable');
    
    expect(bat.overriddenState, equals(B3State.unknown));
    
    // Nothing about sanitaires was asked -> NOT_ASSESSED
    final san = nodes.firstWhere((n) => n.id == 'utiliser_sanitaires');
    expect((san as Capability).overriddenState, equals(B3State.notAssessed));
  });

}
