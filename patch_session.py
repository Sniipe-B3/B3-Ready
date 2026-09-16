import re

with open('b3_app/lib/features/progression/models/resilience_session.dart', 'r') as f:
    content = f.read()

# Add imports
content = "import '../../../data/household_repository.dart';\nimport '../../../data/household_snapshot.dart';\n" + content

# Add repository field
content = content.replace("final String scenarioId;", "final String scenarioId;\n  final HouseholdRepository? repository;")

# Add to constructor
content = content.replace("required HouseholdConfig initialConfig,\n  })", "required HouseholdConfig initialConfig,\n    this.repository,\n  })")

# Also need to assign completedActionIds if passed from snapshot... wait, should we pass them in constructor?
# The prompt says we can rebuild the session from snapshot. The snapshot has completedActionIds.
# We should probably pass completedActionIds to the constructor too.
content = content.replace("final List<String> _completedActionIds = [];", "final List<String> _completedActionIds = [];")
content = content.replace("required HouseholdConfig initialConfig,", "required HouseholdConfig initialConfig,\n    List<String> initialCompletedActionIds = const [],")
content = content.replace(") : _config = initialConfig.clone() {", ") : _config = initialConfig.clone() {\n    _completedActionIds.addAll(initialCompletedActionIds);")

# Autosave logic
autosave_code = """
  Future<void> _autosave() async {
    if (repository == null) return;
    final snapshot = HouseholdSnapshot(
      schemaVersion: 1,
      config: _config.clone(),
      scenarioId: scenarioId,
      completedActionIds: List.from(_completedActionIds),
    );
    try {
      await repository!.save(snapshot);
    } catch (e) {
      // Autosave failed, but we don't crash the session
    }
  }
"""

content = content.replace("void _performInitialCalculation() {", autosave_code + "\n  void _performInitialCalculation() {")

# Call autosave on notifyListeners
content = content.replace("notifyListeners();\n      return progression;", "_autosave();\n      notifyListeners();\n      return progression;")
content = content.replace("notifyListeners();\n    return progression;", "_autosave();\n    notifyListeners();\n    return progression;")

with open('b3_app/lib/features/progression/models/resilience_session.dart', 'w') as f:
    f.write(content)
