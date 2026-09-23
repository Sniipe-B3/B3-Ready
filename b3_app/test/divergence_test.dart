import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:b3_app/features/progression/models/resilience_session.dart';
import 'package:b3_app/features/scenarios/services/multi_scenario_analyzer.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/data/app_knowledge_dataset.dart';

void main() {
  test('Divergence Global Overview vs Scenario Detail (Powerbank 24h)', () {
    // Foyer possede un smartphone et un powerbank (24h d'autonomie)
    final config = HouseholdConfig(
      ownedAssets: ['smartphone', 'powerbank'],
      ownedResources: ['elec', 'charge_powerbank'],
      assessedResources: {'elec', 'charge_powerbank'},
      resourceDurations: {'charge_powerbank': const Duration(hours: 24)},
      assessedCapabilities: {'com_mobile'}
    );

    // 1. Analyse Global Overview
    final globalOverview = MultiScenarioAnalyzer(appKnowledgeBase).analyze(config, ["panne_elec"]);
    final panneElecAnalysis = globalOverview.firstWhere((a) => a.scenarioId == 'panne_elec');
    
    // Dans panne_elec, sans elec, le smartphone depend du powerbank (24h).
    // Le scenario par defaut est 48h. Donc 24h < 48h -> DEGRADED.
    final stateGlobal = panneElecAnalysis.simulationResult!.nodeStates['com_mobile'];
    
    // 2. Analyse Scenario Detail (Session)
    final session = ResilienceSession(
      knowledgeJson: appKnowledgeBase,
      scenarioId: 'panne_elec',
      initialConfig: config
    );
    
    // La session utilise l'horizon 24h par defaut.
    // 24h >= 24h -> MAINTAINED.
    final stateDetail = session.simulationResult!.nodeStates['com_mobile'];
    
    // Preuve de la divergence
    expect(stateGlobal, B3State.degraded);
    expect(stateDetail, B3State.maintained);
    expect(stateGlobal, isNot(equals(stateDetail)));
  });
}
