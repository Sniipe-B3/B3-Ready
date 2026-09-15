import 'package:test/test.dart';
import 'package:b3_engine/b3_engine.dart';
import 'dart:convert';

void main() {
  final auditKnowledge = '''
  {
    "systems": [
      {"id": "sys_a", "name": "System A"},
      {"id": "sys_b", "name": "System B"}
    ],
    "resources": [
      {"id": "res_a", "name": "Res A"},
      {"id": "res_b", "name": "Res B"}
    ],
    "assets": [
      {"id": "asset_level1", "name": "Asset L1", "requires": ["sys_a"]},
      {"id": "asset_level2", "name": "Asset L2", "requires": ["asset_level1"]},
      {"id": "asset_level3", "name": "Asset L3", "requires": ["asset_level2"]},
      {"id": "asset_branch_a", "name": "Branch A", "requires": ["sys_a"]},
      {"id": "asset_branch_b", "name": "Branch B", "requires": ["sys_b"]},
      {"id": "asset_redondant_1", "name": "Redondant 1", "requires": ["sys_a"]},
      {"id": "asset_redondant_2", "name": "Redondant 2", "requires": ["sys_a"]},
      {"id": "asset_with_res", "name": "Asset Res", "requires": ["res_a"]},
      {"id": "asset_cycle_a", "name": "Cycle A", "requires": ["asset_cycle_b"]},
      {"id": "asset_cycle_b", "name": "Cycle B", "requires": ["asset_cycle_a"]}
    ],
    "capabilities": [
      {"id": "cap_deep", "name": "Cap Deep", "assets": ["asset_level3"]},
      {"id": "cap_multi", "name": "Cap Multi", "rule": "all", "assets": ["asset_branch_a", "asset_branch_b"]},
      {"id": "cap_redondant", "name": "Cap Redondant", "assets": ["asset_redondant_1", "asset_redondant_2"]},
      {"id": "cap_saine", "name": "Cap Saine", "assets": ["asset_branch_a", "asset_branch_b"]},
      {"id": "cap_res", "name": "Cap Res", "assets": ["asset_with_res"]},
      {"id": "cap_cycle", "name": "Cap Cycle", "assets": ["asset_cycle_a"]}
    ],
    "scenarios": [
      {"id": "panne_a", "name": "Panne A", "duration": 48, "overrides": {"sys_a": "failed"}},
      {"id": "panne_b", "name": "Panne B", "duration": 48, "overrides": {"sys_b": "failed"}},
      {"id": "panne_ab", "name": "Panne AB", "duration": 48, "overrides": {"sys_a": "failed", "sys_b": "failed"}}
    ]
  }
  ''';

  final scenarioA = DataMapper.parseScenario(auditKnowledge, 'panne_a');
  final scenarioAB = DataMapper.parseScenario(auditKnowledge, 'panne_ab');

  test('TEST 2 — CHAÎNE PROFONDE', () {
    final household = HouseholdConfig(
        ownedAssets: ['asset_level3', 'asset_level2', 'asset_level1'],
        assessedCapabilities: {'cap_deep'});
    final graph = DataMapper.buildGraph(auditKnowledge, household);
    final result = B3Engine().runSimulation(graph, scenarioA);

    final vuln =
        result.vulnerabilities.firstWhere((v) => v.capability.id == 'cap_deep');
    expect(vuln.causeNodeIds.contains('sys_a'), true);
    expect(vuln.causeNodeIds.length, 1);
  });

  test('TEST 3 — CAUSE MULTIPLE (2 branches indépendantes impactées)', () {
    final household = HouseholdConfig(
        ownedAssets: ['asset_branch_a', 'asset_branch_b'],
        assessedCapabilities: {'cap_multi'});
    final graph = DataMapper.buildGraph(auditKnowledge, household);
    final result = B3Engine().runSimulation(graph, scenarioAB);

    final vuln = result.vulnerabilities
        .firstWhere((v) => v.capability.id == 'cap_multi');
    expect(vuln.causeNodeIds.contains('sys_a'), true);
    expect(vuln.causeNodeIds.contains('sys_b'), true);
    expect(vuln.causeNodeIds.length, 2);
  });

  test('TEST 4 — FAUSSE REDONDANCE (Cause commune identifiée 1 seule fois)',
      () {
    final household = HouseholdConfig(
        ownedAssets: ['asset_redondant_1', 'asset_redondant_2'],
        assessedCapabilities: {'cap_redondant'});
    final graph = DataMapper.buildGraph(auditKnowledge, household);
    final result = B3Engine().runSimulation(graph, scenarioA);

    final vuln = result.vulnerabilities
        .firstWhere((v) => v.capability.id == 'cap_redondant');
    expect(vuln.causeNodeIds.contains('sys_a'), true);
    expect(vuln.causeNodeIds.length, 1);
  });

  test('TEST 5 — BRANCHE SAINE (Ne doit pas apparaitre dans les causes)', () {
    final household = HouseholdConfig(ownedAssets: [
      'asset_branch_a',
      'asset_branch_b'
    ], assessedCapabilities: {
      'cap_multi'
    } // ALL logic: si une branche fail, la cap fail.
        );
    final graph = DataMapper.buildGraph(auditKnowledge, household);
    final result =
        B3Engine().runSimulation(graph, scenarioA); // Seulement A tombe
    // We check the trace of the asset directly since capability is MAINTAINED due to ANY rule
    final causeIds = result.getRootCauses('asset_branch_a');
    expect(causeIds.contains('sys_a'), true);
    expect(causeIds.contains('sys_b'), false);
  });

  test('TEST 6 — UNKNOWN', () {
    final b = System(
        id: 'asset_branch_b', name: 'B', overriddenState: B3State.unknown);
    final a = System(
        id: 'asset_branch_a', name: 'A', overriddenState: B3State.failed);
    final cap = Capability(
        id: 'cap_multi',
        name: 'Cap',
        children: [a, b],
        rule: EvaluationRule.all);

    final result = B3Engine().runSimulation([a, b, cap], scenarioA);

    final vuln = result.vulnerabilities
        .firstWhere((v) => v.capability.id == 'cap_multi');
    expect(vuln.causeNodeIds.contains('asset_branch_a'), true);
    expect(vuln.causeNodeIds.contains('asset_branch_b'), true);
  });

  test('TEST 7 — NOT_ASSESSED', () {
    final b = System(
        id: 'asset_branch_b', name: 'B', overriddenState: B3State.notAssessed);
    final a = System(
        id: 'asset_branch_a', name: 'A', overriddenState: B3State.failed);
    final cap = Capability(
        id: 'cap_multi',
        name: 'Cap',
        children: [a, b],
        rule: EvaluationRule.all);

    final result = B3Engine().runSimulation([a, b, cap], scenarioA);

    final vuln = result.vulnerabilities
        .firstWhere((v) => v.capability.id == 'cap_multi');
    expect(vuln.causeNodeIds.contains('asset_branch_a'), true);
    expect(vuln.causeNodeIds.contains('asset_branch_b'), true);
  });

  test('TEST 8 — CYCLE', () {
    final a = Asset(id: 'asset_cycle_a', name: 'A', children: []);
    final b = Asset(id: 'asset_cycle_b', name: 'B', children: []);
    a.children.add(b);
    b.children.add(a); // Create explicit cycle
    final cap = Capability(id: 'cap_cycle', name: 'C', children: [a]);

    final result = B3Engine().runSimulation([a, b, cap],
        Scenario(name: 'S', duration: Duration(hours: 1), systemOverrides: {}));

    final unc =
        result.uncertainties.firstWhere((u) => u.capability.id == 'cap_cycle');
    expect(unc.state, B3State.unknown);
    expect(
        unc.causeNodeIds.contains('asset_cycle_a') ||
            unc.causeNodeIds.contains('asset_cycle_b'),
        true);
  });

  test('TEST 9 — CAUSE SCÉNARIO', () {
    final household = HouseholdConfig(
        ownedAssets: ['asset_level1', 'asset_level2', 'asset_level3'],
        assessedCapabilities: {'cap_deep'});
    final graph = DataMapper.buildGraph(auditKnowledge, household);
    final result = B3Engine().runSimulation(graph, scenarioA);

    final vuln =
        result.vulnerabilities.firstWhere((v) => v.capability.id == 'cap_deep');
    expect(vuln.causeNodeIds.contains('sys_a'), true);
  });

  test('TEST 10 — CAUSE RESSOURCE', () {
    final household = HouseholdConfig(
        ownedAssets: ['asset_with_res'],
        ownedResources: ['res_a'],
        assessedResources: {'res_a'},
        // No duration provided -> UNKNOWN
        assessedCapabilities: {'cap_res'});
    final graph = DataMapper.buildGraph(auditKnowledge, household);
    final result = B3Engine().runSimulation(graph, scenarioA);

    final unc =
        result.uncertainties.firstWhere((u) => u.capability.id == 'cap_res');
    expect(unc.causeNodeIds.contains('res_a'), true);
  });
}
