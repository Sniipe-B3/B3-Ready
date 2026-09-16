import 'package:flutter_test/flutter_test.dart';
import 'package:b3_app/data/household_repository.dart';
import 'package:b3_app/features/progression/models/resilience_session.dart';
import 'package:b3_app/features/progression/models/household_update.dart';
import 'package:b3_engine/b3_engine.dart';

void main() {
  const knowledgeJson = '''
  {
    "systems": [
      {"id": "chauffage", "name": "Chauffage"}
    ],
    "capabilities": [
      {"id": "chauffer", "name": "Se chauffer", "assets": ["poele_bois"]}
    ],
    "assets": [
      {"id": "poele_bois", "name": "Poêle à bois", "requires": ["bois"]}
    ],
    "resources": [
      {"id": "bois", "name": "Bois"}
    ],
    "scenarios": [
      {
        "id": "panne_elec",
        "name": "Panne électrique",
        "duration": 48,
        "overrides": {}
      }
    ]
  }
  ''';

  test('TEST K — SAVE AFTER UPDATE', () async {
    final repo = FakeHouseholdRepository();
    final config = HouseholdConfig(ownedAssets: ['poele_bois']);
    final session = ResilienceSession(
      knowledgeJson: knowledgeJson,
      scenarioId: 'panne_elec',
      initialConfig: config,
      repository: repo,
    );

    // Initial state: not saved yet because it only saves on updates (autosave).
    // Or does it save on init? The prompt says "À chaque HouseholdUpdate STRUCTUREL réussi ... sauvegarder le nouveau HouseholdSnapshot."

    // Apply update
    session.recalculate(const ResourceUpdate(
      resourceId: 'bois',
      isOwned: true,
      duration: Duration(hours: 72),
      isUnknown: false,
      nature: UpdateNature.intervention,
    ));

    // Allow async autosave to finish
    await Future.delayed(Duration.zero);

    final snapshot = await repo.load();
    expect(snapshot, isNotNull);
    expect(snapshot!.config.ownedResources, contains('bois'));
    expect(snapshot.config.resourceDurations['bois']?.inHours, 72);
  });

  test('TEST L — COMPLETION PERSISTÉE', () async {
    final repo = FakeHouseholdRepository();
    final config = HouseholdConfig(ownedAssets: ['poele_bois']);
    final session = ResilienceSession(
      knowledgeJson: knowledgeJson,
      scenarioId: 'panne_elec',
      initialConfig: config,
      repository: repo,
    );

    session.recalculate(const ActionCompletedUpdate(actionId: 'action_1'));
    
    await Future.delayed(Duration.zero);

    final snapshot = await repo.load();
    expect(snapshot, isNotNull);
    expect(snapshot!.completedActionIds, contains('action_1'));
  });

  test('TEST M — RESTORE & RECALCULATE', () async {
    final repo = FakeHouseholdRepository();
    
    // Create initial session and save
    final config = HouseholdConfig(
      ownedAssets: ['poele_bois'],
      ownedResources: ['bois'],
      assessedResources: {'bois'},
      resourceDurations: {'bois': const Duration(hours: 72)},
      assessedCapabilities: {'chauffer'},
    );
    final session1 = ResilienceSession(
      knowledgeJson: knowledgeJson,
      scenarioId: 'panne_elec',
      initialConfig: config,
      repository: repo,
    );
    
    // Force a structural update to trigger autosave
    session1.recalculate(const AssetOwnershipUpdate(
      assetId: 'poele_bois',
      isOwned: true,
      nature: UpdateNature.intervention,
    ));
    await Future.delayed(Duration.zero);

    // Load snapshot
    final snapshot = await repo.load();
    expect(snapshot, isNotNull);

    // Create a NEW session from snapshot
    final session2 = ResilienceSession(
      knowledgeJson: knowledgeJson,
      scenarioId: snapshot!.scenarioId,
      initialConfig: snapshot.config,
      initialCompletedActionIds: snapshot.completedActionIds,
    );

    // The engine should recalculate cleanly
    final state = session2.simulationResult.nodeStates['chauffer'];
    expect(state, B3State.maintained); // Has poele_bois, has bois 72h > 48h (scenario)
  });
}
