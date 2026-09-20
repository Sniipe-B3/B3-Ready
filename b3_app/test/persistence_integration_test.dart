import 'package:flutter_test/flutter_test.dart';
import 'package:b3_app/data/household_repository.dart';
import 'package:b3_app/data/household_snapshot.dart';
import 'package:b3_app/features/progression/models/resilience_session.dart';
import 'package:b3_app/features/progression/models/household_update.dart';
import 'package:b3_engine/b3_engine.dart';

class FailingHouseholdRepository implements HouseholdRepository {
  @override
  Future<HouseholdSnapshot?> load() async => null;

  @override
  Future<void> save(HouseholdSnapshot snapshot) async {
    throw Exception('Simulated save error');
  }

  @override
  Future<void> clear() async {}
}

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

  test('TEST K — SAVE AFTER UPDATE (DETERMINISTE)', () async {
    final repo = FakeHouseholdRepository();
    final config = HouseholdConfig(ownedAssets: ['poele_bois']);
    final session = ResilienceSession(
      knowledgeJson: knowledgeJson,
      scenarioId: 'panne_elec',
      initialConfig: config,
      repository: repo,
      isRestored: false,
    );
    await session.waitForPendingSave(); // attente sauvegarde initiale

    session.recalculate(const ResourceUpdate(
      resourceId: 'bois',
      isOwned: true,
      duration: Duration(hours: 72),
      isUnknown: false,
      nature: UpdateNature.intervention,
    ));

    await session.waitForPendingSave();

    final snapshot = await repo.load();
    expect(snapshot, isNotNull);
    expect(snapshot!.config.ownedResources, contains('bois'));
    expect(snapshot.config.resourceDurations['bois']?.inHours, 72);
  });

  test('TEST L — COMPLETION PERSISTÉE (DETERMINISTE)', () async {
    final repo = FakeHouseholdRepository();
    final config = HouseholdConfig(ownedAssets: ['poele_bois']);
    final session = ResilienceSession(
      knowledgeJson: knowledgeJson,
      scenarioId: 'panne_elec',
      initialConfig: config,
      repository: repo,
      isRestored: false,
    );
    await session.waitForPendingSave();

    session.recalculate(const ActionCompletedUpdate(actionId: 'action_1'));
    
    await session.waitForPendingSave();

    final snapshot = await repo.load();
    expect(snapshot, isNotNull);
    expect(snapshot!.completedActionIds, contains('action_1'));
  });

  test('TEST M — RESTORE & RECALCULATE', () async {
    final repo = FakeHouseholdRepository();
    
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
      isRestored: false,
    );
    
    await session1.waitForPendingSave();

    final snapshot = await repo.load();
    expect(snapshot, isNotNull);

    final session2 = ResilienceSession(
      knowledgeJson: knowledgeJson,
      scenarioId: snapshot!.scenarioId,
      initialConfig: snapshot.config,
      initialCompletedActionIds: snapshot.completedActionIds,
      repository: repo,
      isRestored: true, // Should not save initially
    );
    
    // Nothing should be queued on session2 init
    await session2.waitForPendingSave();
    
    final state = session2.simulationResult.nodeStates['chauffer'];
    expect(state, B3State.maintained);
  });

  test('TEST 5 — FAIL SAVE', () async {
    final repo = FailingHouseholdRepository();
    final config = HouseholdConfig(ownedAssets: ['poele_bois']);
    final session = ResilienceSession(
      knowledgeJson: knowledgeJson,
      scenarioId: 'panne_elec',
      initialConfig: config,
      repository: repo,
      isRestored: false,
    );

    // Initial save fails
    await session.waitForPendingSave();
    expect(session.saveError, isNotNull);

    // Engine still works
    session.recalculate(const ResourceUpdate(
      resourceId: 'bois',
      isOwned: true,
      duration: Duration(hours: 72),
      isUnknown: false,
      nature: UpdateNature.intervention,
    ));

    await session.waitForPendingSave();
    expect(session.config.resourceDurations['bois']?.inHours, 72);
    expect(session.saveError, isNotNull); // still failing
  });

  test('TEST 8 — INITIAL SAVE', () async {
    final repo = FakeHouseholdRepository();
    final config = HouseholdConfig(ownedAssets: ['poele_bois']);
    final session = ResilienceSession(
      knowledgeJson: knowledgeJson,
      scenarioId: 'panne_elec',
      initialConfig: config,
      repository: repo,
      isRestored: false,
    );

    await session.waitForPendingSave();
    final snapshot = await repo.load();
    expect(snapshot, isNotNull);
    expect(snapshot!.config.ownedAssets, contains('poele_bois'));
  });

  test('RESTORED SESSION NO SAVE', () async {
    final repo = FakeHouseholdRepository();
    final config = HouseholdConfig(ownedAssets: ['poele_bois']);
    final session = ResilienceSession(
      knowledgeJson: knowledgeJson,
      scenarioId: 'panne_elec',
      initialConfig: config,
      repository: repo,
      isRestored: true, // means restored
    );
    
    await session.waitForPendingSave();
    final snapshot = await repo.load();
    expect(snapshot, isNull); // Shouldn't have saved
  });

  test('TEST 10 — UNKNOWN SCENARIO', () async {
    final repo = FakeHouseholdRepository();
    final config = HouseholdConfig(ownedAssets: ['poele_bois']);
    final session = ResilienceSession(
      knowledgeJson: knowledgeJson,
      scenarioId: 'ancien_scenario_supprime',
      initialConfig: config,
      repository: repo,
      isRestored: true,
    );

    expect(session.scenarioError, isNotNull);
    expect(session.scenario.name, 'Panne électrique'); // Fallback worked
    expect(session.simulationResult, isNotNull); // Doesn't crash
  });

  test('SAVE ORDER TEST', () async {
    final repo = FakeHouseholdRepository();
    final config = HouseholdConfig(ownedAssets: []);
    final session = ResilienceSession(
      knowledgeJson: knowledgeJson,
      scenarioId: 'panne_elec',
      initialConfig: config,
      repository: repo,
      isRestored: false,
    );
    await session.waitForPendingSave();

    // Trigger two updates back to back synchronously
    session.recalculate(const ResourceUpdate(
      resourceId: 'bois',
      duration: Duration(hours: 24),
      nature: UpdateNature.intervention,
    ));
    
    session.recalculate(const ResourceUpdate(
      resourceId: 'bois',
      duration: Duration(hours: 72),
      nature: UpdateNature.intervention,
    ));

    // Wait for everything to finish
    await session.waitForPendingSave();

    final snapshot = await repo.load();
    expect(snapshot!.config.resourceDurations['bois']?.inHours, 72);
  });

  test('TEST 14 — REAL LOGIC RESTART', () async {
    final repo = FakeHouseholdRepository();
    final config = HouseholdConfig(ownedAssets: ['poele_bois']);
    
    final session1 = ResilienceSession(
      knowledgeJson: knowledgeJson,
      scenarioId: 'panne_elec',
      initialConfig: config,
      repository: repo,
      isRestored: false,
    );
    await session1.waitForPendingSave();
    
    session1.recalculate(const ResourceUpdate(
      resourceId: 'bois',
      isOwned: true,
      duration: Duration(hours: 72),
      nature: UpdateNature.intervention,
    ));
    await session1.waitForPendingSave();
    
    // Destroy session 1 conceptually
    
    final snapshot = await repo.load();
    
    final session2 = ResilienceSession(
      knowledgeJson: knowledgeJson,
      scenarioId: snapshot!.scenarioId,
      initialConfig: snapshot.config,
      repository: repo,
      isRestored: true,
    );
    
    // session2 recalculates cleanly without derived data
    expect(session2.simulationResult.nodeStates['chauffer'], B3State.maintained);
  });
}
