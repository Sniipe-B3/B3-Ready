import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'household_snapshot.dart';

abstract class HouseholdRepository {
  Future<HouseholdSnapshot?> load();
  Future<void> save(HouseholdSnapshot snapshot);
  Future<void> clear();
}

class SharedPrefsHouseholdRepository implements HouseholdRepository {
  static const String _key = 'b3_household_snapshot';

  @override
  Future<HouseholdSnapshot?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_key);
      if (jsonStr == null) return null;
      
      final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);
      return HouseholdSnapshot.fromJson(jsonMap);
    } catch (e) {
      // Documented behavior: In case of corrupted data or unsupported schema, return null/error.
      // We catch it so the app doesn't crash, allowing the user to start fresh.
      return null;
    }
  }

  @override
  Future<void> save(HouseholdSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(snapshot.toJson());
    await prefs.setString(_key, jsonStr);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

class FakeHouseholdRepository implements HouseholdRepository {
  HouseholdSnapshot? _storedSnapshot;
  
  @override
  Future<HouseholdSnapshot?> load() async {
    if (_storedSnapshot == null) return null;
    // Simulate JSON serialization to ensure deep decoupling
    final jsonMap = jsonDecode(jsonEncode(_storedSnapshot!.toJson()));
    return HouseholdSnapshot.fromJson(jsonMap);
  }

  @override
  Future<void> save(HouseholdSnapshot snapshot) async {
    // Deep decouple by simulating a serialize-deserialize cycle
    final jsonMap = jsonDecode(jsonEncode(snapshot.toJson()));
    _storedSnapshot = HouseholdSnapshot.fromJson(jsonMap);
  }

  @override
  Future<void> clear() async {
    _storedSnapshot = null;
  }
}
