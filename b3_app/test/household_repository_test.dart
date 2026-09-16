import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:b3_app/data/household_snapshot.dart';
import 'package:b3_app/data/household_repository.dart';
import 'package:b3_engine/b3_engine.dart';

void main() {
  group('HouseholdSnapshot Serialization', () {
    test('TEST A — ROUND TRIP', () {
      final config = HouseholdConfig(
        ownedAssets: ['poele_bois'],
        ownedResources: ['bois'],
        assessedResources: {'bois', 'gaz'},
        unknownResources: {'gaz'},
        resourceDurations: {'bois': const Duration(hours: 72)},
        assessedCapabilities: {'chauffer'},
        capabilityOverrides: {'cuisiner': B3State.degraded},
      );

      final snapshot = HouseholdSnapshot(
        schemaVersion: 1,
        scenarioId: 'panne_elec',
        completedActionIds: ['action_123'],
        config: config,
      );

      final jsonMap = snapshot.toJson();
      final restored = HouseholdSnapshot.fromJson(jsonMap);

      expect(restored.schemaVersion, 1);
      expect(restored.scenarioId, 'panne_elec');
      expect(restored.completedActionIds, ['action_123']);
      expect(restored.config.ownedAssets, ['poele_bois']);
      expect(restored.config.ownedResources, ['bois']);
      expect(restored.config.assessedResources, {'bois', 'gaz'});
      expect(restored.config.unknownResources, {'gaz'});
      expect(restored.config.resourceDurations['bois']!.inHours, 72);
      expect(restored.config.assessedCapabilities, {'chauffer'});
      expect(restored.config.capabilityOverrides['cuisiner'], B3State.degraded);
    });

    test('TEST B — DURATION (72h stable)', () {
      final config = HouseholdConfig(
        ownedAssets: [],
        resourceDurations: {'bois': const Duration(hours: 72)},
      );
      final snapshot = HouseholdSnapshot(schemaVersion: 1, scenarioId: 'test', completedActionIds: [], config: config);
      final restored = HouseholdSnapshot.fromJson(snapshot.toJson());
      
      expect(restored.config.resourceDurations['bois']?.inHours, 72);
      expect(restored.config.resourceDurations['bois']?.inSeconds, 72 * 3600);
    });

    test('TEST C — UNKNOWN', () {
      final config = HouseholdConfig(
        ownedAssets: [],
        unknownResources: {'bois'},
      );
      final snapshot = HouseholdSnapshot(schemaVersion: 1, scenarioId: 'test', completedActionIds: [], config: config);
      final restored = HouseholdSnapshot.fromJson(snapshot.toJson());
      
      expect(restored.config.unknownResources, contains('bois'));
    });

    test('TEST D — NOT ASSESSED', () {
      final config = HouseholdConfig(
        ownedAssets: [],
      );
      final snapshot = HouseholdSnapshot(schemaVersion: 1, scenarioId: 'test', completedActionIds: [], config: config);
      final restored = HouseholdSnapshot.fromJson(snapshot.toJson());
      
      expect(restored.config.assessedResources, isEmpty);
      expect(restored.config.unknownResources, isEmpty);
      expect(restored.config.ownedResources, isEmpty);
    });

    test('TEST E — OVERRIDE', () {
      final config = HouseholdConfig(
        ownedAssets: [],
        capabilityOverrides: {'chauffer': B3State.degraded},
      );
      final snapshot = HouseholdSnapshot(schemaVersion: 1, scenarioId: 'test', completedActionIds: [], config: config);
      final restored = HouseholdSnapshot.fromJson(snapshot.toJson());
      
      expect(restored.config.capabilityOverrides['chauffer'], B3State.degraded);
    });

    test('TEST F — COMPLETED ACTIONS', () {
      final config = HouseholdConfig(ownedAssets: []);
      final snapshot = HouseholdSnapshot(schemaVersion: 1, scenarioId: 'test', completedActionIds: ['action_1', 'action_2'], config: config);
      final restored = HouseholdSnapshot.fromJson(snapshot.toJson());
      
      expect(restored.completedActionIds, ['action_1', 'action_2']);
    });

    test('TEST G — SCENARIO', () {
      final config = HouseholdConfig(ownedAssets: []);
      final snapshot = HouseholdSnapshot(schemaVersion: 1, scenarioId: 'inondation', completedActionIds: [], config: config);
      final restored = HouseholdSnapshot.fromJson(snapshot.toJson());
      
      expect(restored.scenarioId, 'inondation');
    });

    test('TEST I — INVALID JSON / CORRUPTED', () {
      expect(() => HouseholdSnapshot.fromJson({'bad_json': true}), throwsA(anyOf(isA<TypeError>(), isA<FormatException>())));
    });

    test('TEST J — UNKNOWN SCHEMA VERSION', () {
      expect(() => HouseholdSnapshot.fromJson({'schemaVersion': 999, 'config': {}}), throwsA(isA<FormatException>()));
    });
  });

  group('FakeHouseholdRepository Tests', () {
    test('TEST H — EMPTY STORAGE', () async {
      final repo = FakeHouseholdRepository();
      final loaded = await repo.load();
      expect(loaded, isNull);
    });
    
    test('TEST N — RESET', () async {
      final repo = FakeHouseholdRepository();
      final config = HouseholdConfig(ownedAssets: ['poele_bois']);
      final snapshot = HouseholdSnapshot(schemaVersion: 1, scenarioId: 'test', completedActionIds: [], config: config);
      
      await repo.save(snapshot);
      expect(await repo.load(), isNotNull);
      
      await repo.clear();
      expect(await repo.load(), isNull);
    });

    test('TEST O — EXTERNAL MUTATION', () async {
      final repo = FakeHouseholdRepository();
      final config = HouseholdConfig(ownedAssets: ['poele_bois']);
      final snapshot = HouseholdSnapshot(schemaVersion: 1, scenarioId: 'test', completedActionIds: [], config: config);
      
      await repo.save(snapshot);
      
      config.ownedAssets.add('rad_elec');
      snapshot.completedActionIds.add('action_99');
      
      final loaded = await repo.load();
      expect(loaded!.config.ownedAssets, ['poele_bois']);
      expect(loaded.completedActionIds, isEmpty);
    });
  });

  group('SharedPrefsHouseholdRepository Tests', () {
    test('TEST 35 — Shared Preferences Save/Load/Clear', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SharedPrefsHouseholdRepository();
      
      expect(await repo.load(), isNull);
      
      final config = HouseholdConfig(ownedAssets: ['poele_bois']);
      final snapshot = HouseholdSnapshot(schemaVersion: 1, scenarioId: 'test', completedActionIds: ['test_action'], config: config);
      
      await repo.save(snapshot);
      final loaded = await repo.load();
      expect(loaded, isNotNull);
      expect(loaded!.config.ownedAssets, ['poele_bois']);
      expect(loaded.completedActionIds, ['test_action']);
      
      await repo.clear();
      expect(await repo.load(), isNull);
    });

    test('TEST 35b — Shared Preferences Corrupted Data', () async {
      SharedPreferences.setMockInitialValues({
        'b3_household_snapshot': '{ corrupted_json...',
      });
      final repo = SharedPrefsHouseholdRepository();
      
      final loaded = await repo.load();
      expect(loaded, isNull);
    });
  });
}
