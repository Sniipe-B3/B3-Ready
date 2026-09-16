import 'package:b3_engine/b3_engine.dart';

class HouseholdSnapshot {
  final int schemaVersion;
  final HouseholdConfig config;
  final String scenarioId;
  final List<String> completedActionIds;

  HouseholdSnapshot({
    required this.schemaVersion,
    required this.config,
    required this.scenarioId,
    required this.completedActionIds,
  });

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'scenarioId': scenarioId,
      'completedActionIds': completedActionIds,
      'config': {
        'ownedAssets': config.ownedAssets,
        'ownedResources': config.ownedResources,
        'assessedResources': config.assessedResources.toList(),
        'unknownResources': config.unknownResources.toList(),
        'resourceDurations': config.resourceDurations.map((k, v) => MapEntry(k, v.inSeconds)),
        'assessedCapabilities': config.assessedCapabilities.toList(),
        'capabilityOverrides': config.capabilityOverrides.map((k, v) => MapEntry(k, _b3StateToString(v))),
      }
    };
  }

  static HouseholdSnapshot fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw FormatException('Unsupported schemaVersion: ${json['schemaVersion']}');
    }

    final configJson = json['config'] as Map<String, dynamic>;

    final resourceDurations = <String, Duration>{};
    if (configJson['resourceDurations'] != null) {
      final rdJson = configJson['resourceDurations'] as Map<String, dynamic>;
      rdJson.forEach((k, v) {
        resourceDurations[k] = Duration(seconds: v as int);
      });
    }

    final capabilityOverrides = <String, B3State>{};
    if (configJson['capabilityOverrides'] != null) {
      final coJson = configJson['capabilityOverrides'] as Map<String, dynamic>;
      coJson.forEach((k, v) {
        capabilityOverrides[k] = _stringToB3State(v as String);
      });
    }

    final config = HouseholdConfig(
      ownedAssets: List<String>.from(configJson['ownedAssets'] ?? []),
      ownedResources: List<String>.from(configJson['ownedResources'] ?? []),
      assessedResources: Set<String>.from(configJson['assessedResources'] ?? []),
      unknownResources: Set<String>.from(configJson['unknownResources'] ?? []),
      resourceDurations: resourceDurations,
      assessedCapabilities: Set<String>.from(configJson['assessedCapabilities'] ?? []),
      capabilityOverrides: capabilityOverrides,
    );

    return HouseholdSnapshot(
      schemaVersion: json['schemaVersion'] as int,
      scenarioId: json['scenarioId'] as String,
      completedActionIds: List<String>.from(json['completedActionIds'] ?? []),
      config: config,
    );
  }

  static String _b3StateToString(B3State state) {
    switch (state) {
      case B3State.maintained: return 'maintained';
      case B3State.degraded: return 'degraded';
      case B3State.failed: return 'failed';
      case B3State.unknown: return 'unknown';
      case B3State.notAssessed: return 'notAssessed';
    }
  }

  static B3State _stringToB3State(String val) {
    switch (val) {
      case 'maintained': return B3State.maintained;
      case 'degraded': return B3State.degraded;
      case 'failed': return B3State.failed;
      case 'unknown': return B3State.unknown;
      case 'notAssessed': return B3State.notAssessed;
      default: throw FormatException('Invalid B3State value: $val');
    }
  }
}
