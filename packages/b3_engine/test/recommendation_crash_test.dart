import 'package:test/test.dart';
import 'package:b3_engine/b3_engine.dart';
import 'dart:convert';

void main() {
  final recEngine = RecommendationEngine(b3KnowledgeBase);
  final scenarioElec = DataMapper.parseScenario(b3KnowledgeBase, 'panne_elec');
  final scenarioElecGaz =
      DataMapper.parseScenario(b3KnowledgeBase, 'panne_elec_gaz');

  test('CAS A — Solution alternative réellement viable', () {
    final household = HouseholdConfig(
        ownedAssets: ['plaque_elec'], assessedCapabilities: {'cuisiner'});
    final result = B3Engine().runSimulation(
        DataMapper.buildGraph(b3KnowledgeBase, household), scenarioElec);
    final recs = recEngine.generate(result, household, scenarioElec);

    expect(result.nodeStates['cuisiner'], B3State.failed);
    expect(recs.any((r) => r.targetAssetId == 'rechaud_gaz'),
        true); // Indépendant de l'élec
    expect(recs.any((r) => r.targetAssetId == 'four_elec'),
        false); // Dépend de l'élec, ne doit PAS être proposé
  });

  test('CAS B — Fausse alternative inter-capacité', () {
    final household = HouseholdConfig(
        ownedAssets: ['plaque_elec'], assessedCapabilities: {'cuisiner'});
    final result = B3Engine().runSimulation(
        DataMapper.buildGraph(b3KnowledgeBase, household), scenarioElec);
    final recs = recEngine.generate(result, household, scenarioElec);

    // Ne doit pas proposer un radiateur électrique pour cuisiner !
    expect(recs.any((r) => r.targetAssetId == 'radiateur_elec'), false);
    // Vérifier que toutes les recs de cuisiner sont bien pour cuisiner
    for (var r in recs.where((r) =>
        r.capabilityId == 'cuisiner' &&
        r.type == RecommendationType.createAlternative)) {
      final capData = (jsonDecode(b3KnowledgeBase)['capabilities'] as List)
          .firstWhere((c) => c['id'] == 'cuisiner');
      expect((capData['assets'] as List).contains(r.targetAssetId), true);
    }
  });

  test('CAS C — Alternative possédée mais inutilisable (Ressource faible)', () {
    final household = HouseholdConfig(
        ownedAssets: ['plaque_elec', 'rechaud_bois'],
        ownedResources: ['bois'],
        assessedResources: {'bois'},
        resourceDurations: {'bois': Duration(hours: 12)}, // 12h < 48h
        assessedCapabilities: {'cuisiner'});
    final result = B3Engine().runSimulation(
        DataMapper.buildGraph(b3KnowledgeBase, household), scenarioElec);
    final recs = recEngine.generate(result, household, scenarioElec);

    expect(result.nodeStates['cuisiner'], B3State.degraded);

    // Doit proposer d'augmenter le bois (organize), pas de racheter un réchaud à bois (createAlternative)
    final orgRecs = recs.where((r) => r.targetAssetId == 'rechaud_bois');
    expect(orgRecs.length, 1);
    expect(orgRecs.first.type, RecommendationType.organize);
  });

  test('CAS D & Redondance réelle — Alternative possédée et fonctionnelle', () {
    final household = HouseholdConfig(
        ownedAssets: ['plaque_elec', 'rechaud_gaz'],
        ownedResources: ['gaz'],
        assessedResources: {'gaz'},
        resourceDurations: {'gaz': Duration(hours: 72)},
        assessedCapabilities: {'cuisiner'});
    final result = B3Engine().runSimulation(
        DataMapper.buildGraph(b3KnowledgeBase, household), scenarioElec);
    final recs = recEngine.generate(result, household, scenarioElec);

    expect(result.nodeStates['cuisiner'], B3State.maintained);
    // 0 recommandations pour la cuisson
    expect(recs.any((r) => r.capabilityId == 'cuisiner'), false);
  });

  test(
      'CAS E — Ressource inconnue (Limite du modèle actuel testée explicitement)',
      () {
    // Dans le modèle actuel, si duration est null, le moteur considère la ressource comme infinie.
    // C'est une limite documentée : nous n'avons pas d'état 'ResourceUnknown' provoquant un état UNKNOWN.
    final household = HouseholdConfig(
        ownedAssets: ['rechaud_gaz'],
        ownedResources: ['gaz'],
        assessedResources: {'gaz'},
        // Pas de durée de gaz spécifiée
        assessedCapabilities: {'cuisiner'});
    final result = B3Engine().runSimulation(
        DataMapper.buildGraph(b3KnowledgeBase, household), scenarioElec);

    // Le comportement a été corrigé ! Si la durée n'est pas renseignée, ce n'est pas infini, c'est inconnu.
    expect(result.nodeStates['cuisiner'], B3State.unknown);
    // Limite documentée : Le moteur devrait idéalement retourner UNKNOWN si on ne connait pas le stock.
  });

  test('NON-INVENTION — Dataset restreint', () {
    final minimalJson = '''
    {
      "systems": [{"id": "sys_elec", "name": "Electricité"}],
      "assets": [{"id": "plaque", "name": "Plaque", "requires": ["sys_elec"]}],
      "capabilities": [{"id": "cuisiner", "name": "Cuisiner", "assets": ["plaque"]}],
      "scenarios": [{"id": "panne", "name": "Panne", "duration": 24, "overrides": {"sys_elec": "failed"}}]
    }
    ''';
    final customEngine = RecommendationEngine(minimalJson);
    final scenario = DataMapper.parseScenario(minimalJson, 'panne');
    final household = HouseholdConfig(
        ownedAssets: ['plaque'], assessedCapabilities: {'cuisiner'});
    final result = B3Engine()
        .runSimulation(DataMapper.buildGraph(minimalJson, household), scenario);
    final recs = customEngine.generate(result, household, scenario);

    // Cuisiner = FAILED
    expect(result.nodeStates['cuisiner'], B3State.failed);
    // Mais 0 recommandation d'achat, car la base de connaissance ne connaît AUCUNE alternative
    expect(
        recs
            .where((r) => r.type == RecommendationType.createAlternative)
            .isEmpty,
        true);
  });

  test('TEST 6 — Fausse redondance', () {
    final household = HouseholdConfig(
        ownedAssets: ['plaque_elec', 'four_elec'],
        assessedCapabilities: {'cuisiner'});
    final result = B3Engine().runSimulation(
        DataMapper.buildGraph(b3KnowledgeBase, household), scenarioElec);

    expect(result.nodeStates['cuisiner'], B3State.failed); // Les deux tombent
  });

  test('TEST 7 & 8 — UNKNOWN et NOT_ASSESSED', () {
    final household = HouseholdConfig(
        ownedAssets: [], // Rien
        assessedCapabilities: {}, // Rien n'est évalué
        capabilityOverrides: {
          'cuisiner': B3State.unknown
        } // Cuisiner est forcé à UNKNOWN par le diagnostic
        );
    final result = B3Engine().runSimulation(
        DataMapper.buildGraph(b3KnowledgeBase, household), scenarioElec);
    final recs = recEngine.generate(result, household, scenarioElec);

    // Cuisiner = UNKNOWN
    expect(result.nodeStates['cuisiner'], B3State.unknown);
    // Chauffer = NOT_ASSESSED
    expect(result.nodeStates['chauffer'], B3State.notAssessed);

    // Recommandations DOIVENT être de type VERIFY
    expect(
        recs.any((r) =>
            r.capabilityId == 'cuisiner' &&
            r.type == RecommendationType.verify),
        true);
    expect(
        recs.any((r) =>
            r.capabilityId == 'chauffer' &&
            r.type == RecommendationType.verify),
        true);

    // Aucune recommandation de type createAlternative ou acquire
    expect(recs.any((r) => r.type != RecommendationType.verify), false);
  });

  test('TEST 9 — Plusieurs vulnérabilités distinctes', () {
    final household = HouseholdConfig(
        ownedAssets: ['plaque_elec', 'radiateur_elec', 'lampe_secteur'],
        assessedCapabilities: {'cuisiner', 'chauffer', 'eclairage'});
    final result = B3Engine().runSimulation(
        DataMapper.buildGraph(b3KnowledgeBase, household), scenarioElec);
    final recs = recEngine.generate(result, household, scenarioElec);

    // 3 vulnérabilités
    expect(result.vulnerabilities.length, 3);
    // Il y a des recommandations pour cuisiner, chauffer et eclairage
    expect(recs.any((r) => r.capabilityId == 'cuisiner'), true);
    expect(recs.any((r) => r.capabilityId == 'chauffer'), true);
    expect(recs.any((r) => r.capabilityId == 'eclairage'), true);
  });

  test('TEST 10 — Scénarios multi-systèmes', () {
    final household = HouseholdConfig(
        ownedAssets: ['plaque_elec'], assessedCapabilities: {'cuisiner'});
    // Panne elec ET panne gaz
    final result = B3Engine().runSimulation(
        DataMapper.buildGraph(b3KnowledgeBase, household), scenarioElecGaz);
    final recs = recEngine.generate(result, household, scenarioElecGaz);

    expect(result.nodeStates['cuisiner'], B3State.failed);

    // Le moteur DOIT proposer le réchaud à bois car il survit
    expect(recs.any((r) => r.targetAssetId == 'rechaud_bois'), true);
    // Le moteur NE DOIT PAS proposer le réchaud gaz car il dépend du gaz qui est défaillant !
    expect(recs.any((r) => r.targetAssetId == 'rechaud_gaz'), false);
  });

  test('TEST 11 — Qualité des explications et Traçabilité', () {
    final household = HouseholdConfig(
        ownedAssets: ['plaque_elec'], assessedCapabilities: {'cuisiner'});
    final result = B3Engine().runSimulation(
        DataMapper.buildGraph(b3KnowledgeBase, household), scenarioElec);
    final recs = recEngine.generate(result, household, scenarioElec);

    final rec = recs.firstWhere((r) => r.targetAssetId == 'rechaud_gaz');

    // L'explication contient la dépendance défaillante (elec)
    expect(rec.reason.contains('elec'), true);
    // L'explication met en avant l'indépendance de l'alternative
    expect(rec.reason.contains('indépendante des systèmes affectés'), true);
  });

  test('TEST 12 — Pas de recommandations dupliquées', () {
    final household = HouseholdConfig(
        ownedAssets: ['plaque_elec'], assessedCapabilities: {'cuisiner'});
    final result = B3Engine().runSimulation(
        DataMapper.buildGraph(b3KnowledgeBase, household), scenarioElec);
    final recs = recEngine.generate(result, household, scenarioElec);

    final setIds = recs.map((r) => r.id).toSet();
    // Le Set élimine les doublons. Si la taille est identique, il n'y a pas de doublon.
    expect(setIds.length, recs.length);
  });

  test('TEST 14 — Déterminisme strict', () {
    final household = HouseholdConfig(
        ownedAssets: ['plaque_elec'], assessedCapabilities: {'cuisiner'});
    final result1 = B3Engine().runSimulation(
        DataMapper.buildGraph(b3KnowledgeBase, household), scenarioElec);
    final result2 = B3Engine().runSimulation(
        DataMapper.buildGraph(b3KnowledgeBase, household), scenarioElec);

    final recs1 = recEngine.generate(result1, household, scenarioElec);
    final recs2 = recEngine.generate(result2, household, scenarioElec);

    expect(recs1.length, recs2.length);
    for (int i = 0; i < recs1.length; i++) {
      expect(recs1[i].id, recs2[i].id);
    }
  });
}
