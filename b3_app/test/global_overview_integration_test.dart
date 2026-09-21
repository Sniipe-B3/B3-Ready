import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/data/app_knowledge_dataset.dart';
import 'package:b3_app/data/household_snapshot.dart';
import 'package:b3_app/data/household_repository.dart';
import 'package:b3_app/features/progression/models/resilience_session.dart';
import 'package:b3_app/features/progression/utils/action_update_resolver.dart';
import 'package:b3_app/features/scenarios/services/multi_scenario_analyzer.dart';
import 'package:b3_app/features/scenarios/services/cross_scenario_analyzer.dart';
import 'package:b3_app/features/action_plan/models/action_plan.dart';

void main() {
  test('TEST M - ACTION PHYSIQUE', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SharedPrefsHouseholdRepository();
    
    var config = HouseholdConfig(
      ownedAssets: ['radiateur_elec'],
      ownedResources: [],
      resourceDurations: {},
      assessedCapabilities: {'chauffer'},
      capabilityOverrides: {},
      assessedResources: {},
      unknownResources: {},
    );
    await repo.save(HouseholdSnapshot(config: config, schemaVersion: 1, scenarioId: 'panne_elec', completedActionIds: []));
    
    final multiAnalyzer = MultiScenarioAnalyzer(appKnowledgeBase);
    final crossAnalyzer = CrossScenarioAnalyzer(appKnowledgeBase);
    
    var analyses = multiAnalyzer.analyze(config, ['panne_elec', 'panne_gaz']);
    var overview = crossAnalyzer.analyze(analyses);
    
    // Avant: poele_bois absent
    expect(config.ownedAssets.contains('poele_bois'), isFalse);
    
    // On trouve l'action poele_bois
    final poeleAction = overview.actions.firstWhere((a) => a.targetAssetId == 'poele_bois');
    
    final item = ActionPlanItem(
      id: poeleAction.id,
      title: poeleAction.title,
      description: '',
      reason: '',
      type: poeleAction.type,
      priority: poeleAction.highestPriority,
      capabilityIds: poeleAction.capabilityIds,
      causeNodeIds: poeleAction.causeNodeIds,
      targetAssetId: poeleAction.targetAssetId,
      targetResourceId: poeleAction.targetResourceId,
    );

    // Application workflow
    final session = ResilienceSession(
      knowledgeJson: appKnowledgeBase,
      scenarioId: poeleAction.scenarioIds.first,
      initialConfig: config.clone(),
      initialCompletedActionIds: [],
      repository: repo,
      isRestored: true, // as requested
    );
    
    final update = ActionUpdateResolver.resolveAssetUpdate(item, true);
    final result = session.recalculate(update);
    
    // Attendu: HouseholdConfig contient poele_bois
    expect(result.afterConfig.ownedAssets.contains('poele_bois'), isTrue);
    
    // Validation globale exacte après action
    var newAnalyses = multiAnalyzer.analyze(result.afterConfig, ['panne_elec', 'panne_gaz']);
    var newOverview = crossAnalyzer.analyze(newAnalyses);
    
    // Poele à bois devrait avoir résolu la vulnérabilité de chauffage dans panne_elec (car redondance)
    final chaufferIssue = newOverview.recurringIssues.where((i) => i.capabilityId == 'chauffer').toList();
    // Chauffer n'est plus "FAILED" dans les 2 scénarios (dans panne gaz c'était OK, dans elec ça devient OK car poêle).
    expect(chaufferIssue.isEmpty, isTrue);
  });

  test('TEST N - PERSISTENCE / RESTART', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SharedPrefsHouseholdRepository();
    
    var config = HouseholdConfig(
      ownedAssets: ['poele_bois'],
      ownedResources: [],
      resourceDurations: {},
      assessedCapabilities: {'chauffer'},
      capabilityOverrides: {},
      assessedResources: {},
      unknownResources: {},
    );
    await repo.save(HouseholdSnapshot(config: config, schemaVersion: 1, scenarioId: 'panne_elec', completedActionIds: []));
    
    final multiAnalyzer = MultiScenarioAnalyzer(appKnowledgeBase);
    final crossAnalyzer = CrossScenarioAnalyzer(appKnowledgeBase);
    
    var analyses = multiAnalyzer.analyze(config, ['panne_elec', 'panne_gaz']);
    var overview = crossAnalyzer.analyze(analyses);
    
    // Restart from repo
    final snapshot = await repo.load();
    var analysesRestart = multiAnalyzer.analyze(snapshot!.config, ['panne_elec', 'panne_gaz']);
    var overviewRestart = crossAnalyzer.analyze(analysesRestart);
    
    expect(overview.recurringIssues.length, overviewRestart.recurringIssues.length);
    expect(overview.actions.length, overviewRestart.actions.length);
    expect(overview.uncertainties.length, overviewRestart.uncertainties.length);
  });

  test('AUTOSAVE SESSION TEMPORAIRE', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SharedPrefsHouseholdRepository();
    var config = HouseholdConfig(
      ownedAssets: [],
      ownedResources: [],
      resourceDurations: {},
      assessedCapabilities: {},
      capabilityOverrides: {},
      assessedResources: {},
      unknownResources: {},
    );
    await repo.save(HouseholdSnapshot(config: config, schemaVersion: 1, scenarioId: 'original', completedActionIds: []));
    
    // Session temporaire
    final session = ResilienceSession(
      knowledgeJson: appKnowledgeBase,
      scenarioId: 'panne_elec',
      initialConfig: config.clone(),
      initialCompletedActionIds: [],
      repository: repo,
      isRestored: true, // Empêche l'autosave immédiat (Test exigé: aucune donnée modifiée sans action)
    );
    
    // Attendre un tick
    await Future.delayed(const Duration(milliseconds: 10));
    
    final snapshot = await repo.load();
    // scenarioId ne doit PAS être "panne_elec", il doit être resté "original" car pas d'autosave intempestif.
    expect(snapshot!.scenarioId, 'original');
  });
}
