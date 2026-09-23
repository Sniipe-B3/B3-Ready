import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:b3_app/features/progression/models/resilience_session.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/data/app_knowledge_dataset.dart';

void main() {
  group('ResilienceSession Horizon Tests (04.26.1)', () {
    test('Non-mutation de HouseholdConfig lors du changement d horizon', () {
      final config = HouseholdConfig(
        ownedAssets: ['poele_bois', 'frigo'],
        ownedResources: ['bois'],
        assessedResources: {'bois', 'gaz_bouteille'},
        unknownResources: {'gaz_bouteille'},
        resourceDurations: {'bois': const Duration(hours: 48)},
        assessedCapabilities: {'chauffer', 'conserver_aliments'},
        capabilityOverrides: {'chauffer': B3State.maintained}
      );
      
      final session = ResilienceSession(
        knowledgeJson: appKnowledgeBase,
        scenarioId: 'panne_elec',
        initialConfig: config
      );
      
      // Verification before
      expect(session.horizon, PreparednessHorizon.oneDay);
      expect(config.ownedAssets, ['poele_bois', 'frigo']);
      expect(config.resourceDurations['bois'], const Duration(hours: 48));
      
      // Action
      session.setHorizon(PreparednessHorizon.threeDays);
      
      // Assert AFTER changing to 72h
      expect(session.horizon, PreparednessHorizon.threeDays);
      expect(config.ownedAssets, ['poele_bois', 'frigo']);
      expect(config.ownedResources, ['bois']);
      expect(config.assessedResources, {'bois', 'gaz_bouteille'});
      expect(config.unknownResources, {'gaz_bouteille'});
      expect(config.resourceDurations['bois'], const Duration(hours: 48));
      expect(config.assessedCapabilities, {'chauffer', 'conserver_aliments'});
      expect(config.capabilityOverrides['chauffer'], B3State.maintained);

      // Change through all
      session.setHorizon(PreparednessHorizon.sixHours);
      session.setHorizon(PreparednessHorizon.oneDay);
      session.setHorizon(PreparednessHorizon.sevenDays);
      
      expect(config.ownedAssets, ['poele_bois', 'frigo']);
      expect(config.resourceDurations['bois'], const Duration(hours: 48));
    });

    test('Déterminisme : le résultat 24h reste identique après des changements d horizon', () {
      final config = HouseholdConfig(
        ownedAssets: ['poele_bois'],
        ownedResources: ['bois'],
        assessedResources: {'bois'},
        resourceDurations: {'bois': const Duration(hours: 48)}
      );
      
      final session = ResilienceSession(
        knowledgeJson: appKnowledgeBase,
        scenarioId: 'panne_gaz',
        initialConfig: config
      );
      
      // 1. Snapshot 24h
      expect(session.horizon, PreparednessHorizon.oneDay);
      final res24_1 = session.simulationResult!.nodeStates['chauffer'];
      final rec24_1 = session.recommendations!.map((r) => r.id).toList();
      
      // 2. Changer à 72h
      session.setHorizon(PreparednessHorizon.threeDays);
      final res72 = session.simulationResult!.nodeStates['chauffer'];
      
      // 3. Revenir à 24h
      session.setHorizon(PreparednessHorizon.oneDay);
      final res24_2 = session.simulationResult!.nodeStates['chauffer'];
      final rec24_2 = session.recommendations!.map((r) => r.id).toList();
      
      // Assertions
      expect(res24_1, B3State.maintained);
      expect(res72, B3State.degraded);
      expect(res24_2, B3State.maintained);
      expect(rec24_1, equals(rec24_2));
    });

    test('Action Plan : assertion structurée sur la cause d horizon', () {
      final config = HouseholdConfig(
        ownedAssets: ['poele_bois'],
        ownedResources: ['bois'],
        assessedResources: {'bois'},
        resourceDurations: {'bois': const Duration(hours: 48)}
      );
      
      final session = ResilienceSession(
        knowledgeJson: appKnowledgeBase,
        scenarioId: 'panne_gaz',
        initialConfig: config
      );
      
      // A 24h : Maintained, pas de recommandation Organize
      expect(session.horizon, PreparednessHorizon.oneDay);
      final plan24 = session.actionPlan!;
      final hasOrganize24 = plan24.items.any((a) => a.type == RecommendationType.organize && a.targetResourceId == 'bois');
      expect(hasOrganize24, isFalse);
      
      // A 72h : Degraded (resourceExhausted), recommandation Organize doit apparaitre
      session.setHorizon(PreparednessHorizon.threeDays);
      final plan72 = session.actionPlan!;
      
      final organize72 = plan72.items.firstWhere(
        (a) => a.type == RecommendationType.organize && a.targetResourceId == 'bois',
        orElse: () => throw Exception('Recommendation not found')
      );
      
      // Structured checks
      expect(organize72.priority, ActionPriority.medium);
      expect(organize72.capabilityIds, contains('chauffer'));
      expect(organize72.causeNodeIds, contains('bois'));
    });
    
    test('Default 24H - Contrat explicite', () {
      // Meme si un scenario comme 'panne_elec' a une duration native de 4h (ou autre),
      // Preparedness Horizon override cela avec 24h par defaut pour l'analyse utilisateur.
      final config = HouseholdConfig(ownedAssets: []);
      final session = ResilienceSession(
        knowledgeJson: appKnowledgeBase,
        scenarioId: 'panne_elec', // Un scenario du dataset
        initialConfig: config
      );
      
      expect(session.horizon, PreparednessHorizon.oneDay);
      // It uses the horizon 24h duration, not the scenario's default duration
      expect(session.horizon.duration, const Duration(hours: 24));
      expect(session.scenario?.duration, const Duration(hours: 24));
    });
  });
}
