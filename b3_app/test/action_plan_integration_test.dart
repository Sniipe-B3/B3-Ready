import 'package:flutter_test/flutter_test.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/features/action_plan/action_plan_builder.dart';
import 'package:b3_app/features/action_plan/models/action_plan.dart';

const integrationDataset = '''{
  "systems": [
    {"id": "elec", "name": "Réseau Electrique"},
    {"id": "sys_y", "name": "System Y"}
  ],
  "resources": [
    {"id": "bois", "name": "Bois"},
    {"id": "res_y", "name": "Res Y"},
    {"id": "res_commune", "name": "Res Commune"},
    {"id": "res_1", "name": "Res 1"},
    {"id": "res_2", "name": "Res 2"}
  ],
  "assets": [
    {"id": "rad_elec", "name": "Radiateur", "requires": ["elec"]},
    {"id": "plaque_elec", "name": "Plaque", "requires": ["elec"]},
    {"id": "pac", "name": "Pompe à chaleur", "requires": ["elec"]},
    {"id": "poele_bois", "name": "Poêle à bois", "requires": ["bois"]},
    {"id": "asset_y", "name": "Asset Y", "requires": ["sys_y", "res_y"]},
    {"id": "asset_comm1", "name": "AC 1", "requires": ["res_commune"]},
    {"id": "asset_comm2", "name": "AC 2", "requires": ["res_commune"]},
    {"id": "asset_diff1", "name": "AD 1", "requires": ["res_1"]},
    {"id": "asset_diff2", "name": "AD 2", "requires": ["res_2"]}
  ],
  "capabilities": [
    {"id": "chauffer", "name": "Chauffer", "assets": ["rad_elec", "pac", "poele_bois"]},
    {"id": "cuisiner", "name": "Cuisiner", "assets": ["plaque_elec"]},
    {"id": "cap_y", "name": "Cap Y", "assets": ["asset_y"]},
    {"id": "cap_z1", "name": "Cap Z1", "assets": ["asset_comm1"]},
    {"id": "cap_z2", "name": "Cap Z2", "assets": ["asset_comm2"]},
    {"id": "cap_d1", "name": "Cap D1", "assets": ["asset_diff1"]},
    {"id": "cap_d2", "name": "Cap D2", "assets": ["asset_diff2"]}
  ],
  "scenarios": [
    {"id": "panne_elec", "name": "Panne Elec", "duration": 48, "overrides": {"elec": "failed"}},
    {"id": "double_panne", "name": "Double Panne", "duration": 48, "overrides": {"elec": "failed", "sys_y": "failed"}},
    {"id": "normal", "name": "Normal", "duration": 48, "overrides": {}}
  ]
}''';

ActionPlan runPipeline(HouseholdConfig config, String scenarioId) {
  final scenario = DataMapper.parseScenario(integrationDataset, scenarioId);
  final graph = DataMapper.buildGraph(integrationDataset, config);
  final result = B3Engine().runSimulation(graph, scenario);
  final recs = RecommendationEngine(integrationDataset).generate(result, config, scenario);
  return ActionPlanBuilder(integrationDataset).build(recs, result);
}

void main() {
  test('INTÉGRATION A — UNKNOWN RÉEL', () {
    final config = HouseholdConfig(
      ownedAssets: ['poele_bois'],
      ownedResources: ['bois'],
      unknownResources: {'bois'},
      assessedCapabilities: {'chauffer'},
    );
    final plan = runPipeline(config, 'panne_elec');
    expect(plan.items.isNotEmpty, true);
    final verifyItem = plan.items.firstWhere((i) => i.type == RecommendationType.verify);
    expect(verifyItem.description, 'Vous ne connaissez pas encore la quantité disponible.');
    expect(verifyItem.priority, ActionPriority.toVerify);
  });

  test('INTÉGRATION B — NOT_ASSESSED RÉEL', () {
    final config = HouseholdConfig(
      ownedAssets: ['poele_bois'],
      ownedResources: ['bois'],
      unknownResources: {},
      assessedResources: {}, // NOT_ASSESSED
      assessedCapabilities: {'chauffer'},
    );
    final plan = runPipeline(config, 'panne_elec');
    final verifyItem = plan.items.firstWhere((i) => i.type == RecommendationType.verify);
    expect(verifyItem.description, "Cette information n'a pas encore été vérifiée.");
    expect(verifyItem.priority, ActionPriority.toVerify);
  });

  test('INTÉGRATION C — CHAUFFAGE ÉLECTRIQUE SEUL', () {
    final config = HouseholdConfig(
      ownedAssets: ['rad_elec'],
      assessedCapabilities: {'chauffer'},
    );
    final plan = runPipeline(config, 'panne_elec');
    final essentialItem = plan.items.firstWhere((i) => i.priority == ActionPriority.essential);
    expect(essentialItem.type, RecommendationType.createAlternative);
  });

  test('INTÉGRATION D — VRAIE REDONDANCE', () {
    final config = HouseholdConfig(
      ownedAssets: ['rad_elec', 'poele_bois'],
      ownedResources: ['bois'],
      assessedResources: {'bois'},
      resourceDurations: {'bois': const Duration(hours: 72)},
      assessedCapabilities: {'chauffer'},
    );
    final plan = runPipeline(config, 'panne_elec');
    expect(plan.items.any((i) => i.priority == ActionPriority.essential), false);
    expect(plan.items.any((i) => i.priority == ActionPriority.important), false);
  });

  test('INTÉGRATION E — FAUSSE REDONDANCE', () {
    final config = HouseholdConfig(
      ownedAssets: ['rad_elec', 'pac'],
      assessedCapabilities: {'chauffer'},
    );
    final plan = runPipeline(config, 'panne_elec');
    expect(plan.items.any((i) => i.priority == ActionPriority.essential), true);
  });

  test('INTÉGRATION F — RESSOURCE LIMITÉE', () {
    final config = HouseholdConfig(
      ownedAssets: ['rad_elec', 'poele_bois'],
      ownedResources: ['bois'],
      assessedResources: {'bois'},
      resourceDurations: {'bois': const Duration(hours: 24)}, // scénario 48h
      assessedCapabilities: {'chauffer'},
    );
    final plan = runPipeline(config, 'panne_elec');
    final item = plan.items.firstWhere((i) => i.type == RecommendationType.organize);
    expect(item.priority, ActionPriority.important);
  });

  test('INTÉGRATION G — ANTI-INVENTION RÉELLE', () {
    final config = HouseholdConfig(
      ownedAssets: [],
      ownedResources: [],
      assessedCapabilities: {'chauffer'},
    );
    final plan = runPipeline(config, 'panne_elec');
    expect(plan.items.any((i) => i.type == RecommendationType.acquire), false);
    expect(plan.items.any((i) => i.type == RecommendationType.organize), false);
    expect(plan.items.any((i) => i.type == RecommendationType.createAlternative), true);
  });

  test('INTÉGRATION H — CAUSE PARTAGÉE RÉELLE & DÉDOUBLONNAGE', () {
    final config = HouseholdConfig(
      ownedAssets: ['asset_comm1', 'asset_comm2'],
      ownedResources: ['res_commune'],
      unknownResources: {'res_commune'}, 
      assessedCapabilities: {'cap_z1', 'cap_z2'},
    );
    final plan = runPipeline(config, 'normal');
    final verifyItems = plan.items.where((i) => i.type == RecommendationType.verify && i.title.contains('Res Commune')).toList();
    
    expect(verifyItems.length, 1);
    final mergedItem = verifyItems.first;
    expect(mergedItem.capabilityIds.contains('cap_z1'), true);
    expect(mergedItem.capabilityIds.contains('cap_z2'), true);
    expect(mergedItem.causeNodeIds.contains('res_commune'), true);
  });

  test('INTÉGRATION I — CAUSES DIFFÉRENTES (PAS DE DÉDOUBLONNAGE ABUSIF)', () {
    final config = HouseholdConfig(
      ownedAssets: ['asset_diff1', 'asset_diff2'],
      ownedResources: ['res_1', 'res_2'],
      unknownResources: {'res_1', 'res_2'}, // Les deux sont de durée inconnue
      assessedCapabilities: {'cap_d1', 'cap_d2'},
    );
    final plan = runPipeline(config, 'normal');
    
    // Les deux génèrent un VERIFY. 
    // Ils sont de même type (verify), de même priorité (toVerify).
    // Mais ils ciblent des ressources différentes (res_1 et res_2).
    // Le dédoublonnage utilise targetResourceId, donc ils ne doivent PAS être fusionnés.
    final verifyItems = plan.items.where((i) => i.type == RecommendationType.verify).toList();
    expect(verifyItems.where((i) => i.capabilityIds.contains('cap_d1') || i.capabilityIds.contains('cap_d2')).length, 2);
  });

  test('INTÉGRATION J — FAILED INDÉPENDANT VS VERIFY', () {
    final config = HouseholdConfig(
      ownedAssets: ['rad_elec', 'asset_y'],
      ownedResources: ['res_y'],
      unknownResources: {'res_y'}, // cap_y est UNKNOWN (toVerify)
      assessedCapabilities: {'chauffer', 'cap_y'},
    );
    final plan = runPipeline(config, 'panne_elec');
    
    final firstItem = plan.items.first;
    expect(firstItem.priority, ActionPriority.essential); // CreateAlternative pour chauffer
    final lastItem = plan.items.last;
    expect(lastItem.priority, ActionPriority.toVerify); // Verify pour res_y
  });
}
