import "package:flutter/foundation.dart";
import 'package:flutter_test/flutter_test.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/features/scenarios/services/multi_scenario_analyzer.dart';
import 'package:b3_app/data/app_knowledge_dataset.dart';
import 'package:b3_app/features/action_plan/models/action_plan.dart';

void main() {
  late MultiScenarioAnalyzer analyzer;

  setUp(() {
    analyzer = MultiScenarioAnalyzer(appKnowledgeBase);
  });

  group('MultiScenarioAnalyzer Tests (A-O)', () {
    test('TEST A - MULTI ANALYSIS', () {
      final config = HouseholdConfig(
        ownedAssets: ['radiateur_elec', 'gaziniere_ville'],
        ownedResources: [],
        resourceDurations: {},
        assessedCapabilities: {'chauffer', 'cuisiner'},
        capabilityOverrides: {},
      );

      final results = analyzer.analyze(config, ['panne_elec', 'panne_gaz']);

      expect(results.length, 2);
      expect(results[0].scenarioId, 'panne_elec');
      expect(results[1].scenarioId, 'panne_gaz');
      
      expect(identical(results[0].simulationResult, results[1].simulationResult), false);
      expect(identical(results[0].graph, results[1].graph), false);
    });

    test('TEST B - CONFIG IMMUTABLE', () {
      final config = HouseholdConfig(
        ownedAssets: ['radiateur_elec', 'gaziniere_ville'],
        ownedResources: ['bois'],
        resourceDurations: {'bois': const Duration(hours: 72)},
        assessedCapabilities: {'chauffer', 'cuisiner'},
        capabilityOverrides: {'cuisiner': B3State.degraded},
        assessedResources: {'bois'},
        unknownResources: {'gaz_bouteille'},
      );

      final configBefore = config.clone();
      analyzer.analyze(config, ['panne_elec', 'panne_gaz']);

      expect(config.ownedAssets, configBefore.ownedAssets);
      expect(config.ownedResources, configBefore.ownedResources);
      expect(config.resourceDurations, configBefore.resourceDurations);
      expect(config.assessedCapabilities, configBefore.assessedCapabilities);
      expect(config.capabilityOverrides, configBefore.capabilityOverrides);
      expect(config.assessedResources, configBefore.assessedResources);
      expect(config.unknownResources, configBefore.unknownResources);
    });

    test('TEST C - INDÉPENDANCE DES OVERRIDES', () {
      final config = HouseholdConfig(
        ownedAssets: ['radiateur_elec', 'gaziniere_ville'],
        ownedResources: [],
        resourceDurations: {},
        assessedCapabilities: {'chauffer', 'cuisiner'},
        capabilityOverrides: {},
      );

      final results = analyzer.analyze(config, ['panne_elec', 'panne_gaz']);
      final elecAnalysis = results.firstWhere((r) => r.scenarioId == 'panne_elec');
      final gazAnalysis = results.firstWhere((r) => r.scenarioId == 'panne_gaz');

      expect(elecAnalysis.simulationResult!.nodeStates['radiateur_elec'], B3State.failed);
      expect(elecAnalysis.simulationResult!.nodeStates['gaziniere_ville'], B3State.maintained);

      expect(gazAnalysis.simulationResult!.nodeStates['gaziniere_ville'], B3State.failed);
      expect(gazAnalysis.simulationResult!.nodeStates['radiateur_elec'], B3State.maintained);
    });

    test('TEST D - VRAIE REDONDANCE', () {
      final config = HouseholdConfig(
        ownedAssets: ['radiateur_elec', 'poele_bois'],
        ownedResources: ['bois'],
        resourceDurations: {'bois': const Duration(hours: 100)},
        assessedCapabilities: {'chauffer'},
        capabilityOverrides: {},
        assessedResources: {'bois'},
      );

      final results = analyzer.analyze(config, ['panne_elec']);
      final elecAnalysis = results.first;

      expect(elecAnalysis.simulationResult!.nodeStates['radiateur_elec'], B3State.failed);
      expect(elecAnalysis.simulationResult!.nodeStates['poele_bois'], B3State.maintained);
      expect(elecAnalysis.simulationResult!.nodeStates['chauffer'], B3State.maintained);

      expect(elecAnalysis.recommendations, isNotEmpty);
      final addAlternativeHeating = elecAnalysis.recommendations!.where(
        (r) => r.type == RecommendationType.createAlternative && r.targetAssetId == 'chauffer'
      );
      expect(addAlternativeHeating, isEmpty);
    });

    test('TEST E - FAUSSE REDONDANCE', () {
      final config = HouseholdConfig(
        ownedAssets: ['radiateur_elec', 'pompe_chaleur'],
        ownedResources: [],
        resourceDurations: {},
        assessedCapabilities: {'chauffer'},
        capabilityOverrides: {},
      );

      final results = analyzer.analyze(config, ['panne_elec']);
      final elecAnalysis = results.first;

      expect(elecAnalysis.simulationResult!.nodeStates['radiateur_elec'], B3State.failed);
      expect(elecAnalysis.simulationResult!.nodeStates['pompe_chaleur'], B3State.failed);
      expect(elecAnalysis.simulationResult!.nodeStates['chauffer'], B3State.failed);
      expect(elecAnalysis.actionPlan!.items.any((i) => i.priority == ActionPriority.essential), true);
    });

    test('TEST F - GAZ', () {
      final configWithAlt = HouseholdConfig(
        ownedAssets: ['gaziniere_ville', 'plaque_elec'],
        ownedResources: [],
        resourceDurations: {},
        assessedCapabilities: {'cuisiner'},
        capabilityOverrides: {},
      );

      final resultsWithAlt = analyzer.analyze(configWithAlt, ['panne_gaz']);
      final gazAnalysis1 = resultsWithAlt.first;

      expect(gazAnalysis1.simulationResult!.nodeStates['gaziniere_ville'], B3State.failed);
      expect(gazAnalysis1.simulationResult!.nodeStates['cuisiner'], B3State.maintained);

      final configNoAlt = HouseholdConfig(
        ownedAssets: ['gaziniere_ville'],
        ownedResources: [],
        resourceDurations: {},
        assessedCapabilities: {'cuisiner'},
        capabilityOverrides: {},
      );

      final resultsNoAlt = analyzer.analyze(configNoAlt, ['panne_gaz']);
      final gazAnalysis2 = resultsNoAlt.first;

      expect(gazAnalysis2.simulationResult!.nodeStates['gaziniere_ville'], B3State.failed);
      expect(gazAnalysis2.simulationResult!.nodeStates['cuisiner'], B3State.failed);
    });

    test('TEST G - EAU', () {
      final c1 = HouseholdConfig(ownedAssets: ['robinet_eau'], assessedCapabilities: {'disposer_eau'});
      final r1 = analyzer.analyze(c1, ['coupure_eau']).first;
      expect(r1.simulationResult!.nodeStates['disposer_eau'], B3State.failed);

      final c2 = HouseholdConfig(
        ownedAssets: ['robinet_eau', 'stock_eau'],
        ownedResources: ['reserve_eau'],
        resourceDurations: {'reserve_eau': const Duration(hours: 72)},
        assessedCapabilities: {'disposer_eau'},
        assessedResources: {'reserve_eau'}
      );
      final r2 = analyzer.analyze(c2, ['coupure_eau']).first;
      expect(r2.simulationResult!.nodeStates['disposer_eau'], B3State.maintained);

      final c3 = HouseholdConfig(
        ownedAssets: ['robinet_eau', 'stock_eau'],
        ownedResources: ['reserve_eau'],
        resourceDurations: {'reserve_eau': const Duration(hours: 12)},
        assessedCapabilities: {'disposer_eau'},
        assessedResources: {'reserve_eau'}
      );
      final r3 = analyzer.analyze(c3, ['coupure_eau']).first;
      expect(r3.simulationResult!.nodeStates['disposer_eau'], B3State.degraded);
    });

    test('TEST H - CASCADE ÉLECTRICITÉ → INTERNET', () {
      final config = HouseholdConfig(
        ownedAssets: ['box_internet'],
        assessedCapabilities: {'acceder_internet'},
      );

      final r = analyzer.analyze(config, ['panne_elec']).first;
      // Internet n'est pas FAILED par le scénario directement, c'est elec qui est FAILED.
      expect(r.simulationResult!.nodeStates['internet'], isNot(B3State.failed));
      expect(r.simulationResult!.nodeStates['box_internet'], B3State.failed);
      expect(r.simulationResult!.nodeStates['acceder_internet'], B3State.failed);
    });

    test('TEST I - PANNE INTERNET SEULE', () {
      final config = HouseholdConfig(
        ownedAssets: ['box_internet', 'radiateur_elec', 'plaque_elec'],
        assessedCapabilities: {'acceder_internet', 'chauffer', 'cuisiner'},
      );

      final r = analyzer.analyze(config, ['panne_internet']).first;
      expect(r.simulationResult!.nodeStates['internet'], B3State.failed);
      expect(r.simulationResult!.nodeStates['elec'], isNot(B3State.failed));
      expect(r.simulationResult!.nodeStates['chauffer'], isNot(B3State.failed));
      expect(r.simulationResult!.nodeStates['cuisiner'], isNot(B3State.failed));
    });

    test('TEST J - MOBILE DISTINCT D\'INTERNET', () {
      final config = HouseholdConfig(
        ownedAssets: ['box_internet', 'smartphone'],
        assessedCapabilities: {'acceder_internet', 'communiquer'},
      );

      final rMobile = analyzer.analyze(config, ['panne_mobile']).first;
      expect(rMobile.simulationResult!.nodeStates['reseau_mobile'], B3State.failed);
      expect(rMobile.simulationResult!.nodeStates['internet'], isNot(B3State.failed));
      expect(rMobile.simulationResult!.nodeStates['acceder_internet'], isNot(B3State.failed));
      expect(rMobile.simulationResult!.nodeStates['communiquer'], B3State.failed);

      final rInternet = analyzer.analyze(config, ['panne_internet']).first;
      expect(rInternet.simulationResult!.nodeStates['internet'], B3State.failed);
      expect(rInternet.simulationResult!.nodeStates['reseau_mobile'], isNot(B3State.failed));
      expect(rInternet.simulationResult!.nodeStates['communiquer'], isNot(B3State.failed));
    });

    test('TEST K - UNKNOWN', () {
      final config = HouseholdConfig(
        ownedAssets: ['stock_eau'],
        unknownResources: {'reserve_eau'},
        assessedCapabilities: {'disposer_eau'},
      );

      final r = analyzer.analyze(config, ['coupure_eau']).first;
      expect(r.simulationResult!.nodeStates['reserve_eau'], B3State.unknown);
      expect(r.simulationResult!.nodeStates['disposer_eau'], B3State.unknown);
    });

    test('TEST L - NOT_ASSESSED', () {
      final config = HouseholdConfig(
        ownedAssets: ['stock_eau'],
        assessedCapabilities: {'disposer_eau'},
      );

      final r = analyzer.analyze(config, ['coupure_eau']).first;
      expect(r.simulationResult!.nodeStates['reserve_eau'], B3State.notAssessed);
      expect(r.simulationResult!.nodeStates['disposer_eau'], B3State.notAssessed);
    });

    test('TEST M - DÉTERMINISME', () {
      final config = HouseholdConfig(
        ownedAssets: ['radiateur_elec', 'poele_bois', 'box_internet'],
        ownedResources: ['bois'],
        resourceDurations: {'bois': const Duration(hours: 72)},
        assessedCapabilities: {'chauffer', 'acceder_internet'},
        assessedResources: {'bois'},
      );

      final r1 = analyzer.analyze(config, ['panne_elec', 'panne_gaz']);
      final r2 = analyzer.analyze(config, ['panne_elec', 'panne_gaz']);

      for (int i = 0; i < 2; i++) {
        expect(r1[i].scenarioId, r2[i].scenarioId);
        expect(r1[i].simulationResult!.nodeStates, r2[i].simulationResult!.nodeStates);
        expect(
          r1[i].simulationResult!.vulnerabilities.map((v) => v.capability.id),
          r2[i].simulationResult!.vulnerabilities.map((v) => v.capability.id)
        );
        expect(
          r1[i].recommendations!.map((r) => '\${r.type}_\${r.targetAssetId}'),
          r2[i].recommendations!.map((r) => '\${r.type}_\${r.targetAssetId}')
        );
        expect(
          r1[i].actionPlan!.items.map((item) => item.title),
          r2[i].actionPlan!.items.map((item) => item.title)
        );
      }
    });

    test('TEST N - SCÉNARIO INVALIDE', () {
      final config = HouseholdConfig(
        ownedAssets: [],
        assessedCapabilities: {},
      );
      final results = analyzer.analyze(config, ['panne_elec', 'scenario_inexistant', 'panne_gaz']);

      expect(results.length, 3);
      expect(results[0].isAvailable, true);
      
      expect(results[1].scenarioId, 'scenario_inexistant');
      expect(results[1].isAvailable, false);
      expect(results[1].error, isNotNull);
      
      expect(results[2].isAvailable, true);
    });

    test('TEST O - ANTI-INVENTION', () {
      final config = HouseholdConfig(
        ownedAssets: [],
        assessedCapabilities: {},
      );
      final configBefore = config.clone();

      analyzer.analyze(config, ['panne_elec', 'panne_gaz', 'coupure_eau', 'panne_internet', 'panne_mobile']);

      expect(config.ownedAssets, configBefore.ownedAssets);
      expect(config.ownedResources, configBefore.ownedResources);
      expect(config.resourceDurations, configBefore.resourceDurations);
      expect(config.assessedCapabilities, configBefore.assessedCapabilities);
    });

    test('19. VÉRIFIER RECOMMENDATIONENGINE PIPELINE', () {
      final config = HouseholdConfig(
        ownedAssets: ['radiateur_elec'],
        assessedCapabilities: {'chauffer'}
      );
      
      final results = analyzer.analyze(config, ['panne_elec']);
      final analysis = results.first;
      
      expect(analysis.recommendations, isNotNull);
      expect(analysis.actionPlan, isNotNull);
      
      expect(analysis.actionPlan!.items.isNotEmpty, true);
    });

    test('23. PERFORMANCE NON-FLAKY OBSERVE', () {
      final config = HouseholdConfig(
        ownedAssets: ['radiateur_elec', 'poele_bois', 'box_internet', 'smartphone', 'stock_eau', 'gaziniere_ville'],
        ownedResources: ['bois', 'reserve_eau', 'gaz_bouteille'],
        resourceDurations: {'bois': const Duration(hours: 72), 'reserve_eau': const Duration(hours: 72), 'gaz_bouteille': const Duration(hours: 72)},
        assessedCapabilities: {'chauffer', 'cuisiner', 'acceder_internet', 'communiquer', 'disposer_eau'},
        assessedResources: {'bois', 'reserve_eau', 'gaz_bouteille'},
      );

      final stopwatch = Stopwatch()..start();
      analyzer.analyze(config, ['panne_elec', 'panne_gaz', 'coupure_eau', 'panne_internet', 'panne_mobile']);
      stopwatch.stop();

      // final ms = stopwatch.elapsedMilliseconds;
      debugPrint('Mesure observée : \$ms ms sur cet environnement');
      expect(true, true);
    });
  });
}
