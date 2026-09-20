import 'package:b3_engine/b3_engine.dart';
import '../../action_plan/models/action_plan.dart';

class ScenarioAnalysis {
  final String scenarioId;
  final String scenarioName;
  final bool isAvailable;
  final String? error;
  
  final Scenario? scenario;
  final SimulationResult? simulationResult;
  final List<Recommendation>? recommendations;
  final ActionPlan? actionPlan;
  final List<B3Node>? graph;

  ScenarioAnalysis({
    required this.scenarioId,
    required this.scenarioName,
    this.isAvailable = true,
    this.error,
    this.scenario,
    this.simulationResult,
    this.recommendations,
    this.actionPlan,
    this.graph,
  });

  factory ScenarioAnalysis.error({
    required String scenarioId,
    required String scenarioName,
    required String error,
  }) {
    return ScenarioAnalysis(
      scenarioId: scenarioId,
      scenarioName: scenarioName,
      isAvailable: false,
      error: error,
    );
  }

  int get failedCount => simulationResult?.vulnerabilities.where((v) => v.state == B3State.failed).length ?? 0;
  int get degradedCount => simulationResult?.vulnerabilities.where((v) => v.state == B3State.degraded).length ?? 0;
  int get unknownCount => simulationResult?.nodeStates.values.where((s) => s == B3State.unknown).length ?? 0;
  int get notAssessedCount => simulationResult?.nodeStates.values.where((s) => s == B3State.notAssessed).length ?? 0;
  int get maintainedCount => simulationResult?.nodeStates.entries
    .where((e) => graph?.any((n) => n is Capability && n.id == e.key) ?? false)
    .where((e) => e.value == B3State.maintained)
    .length ?? 0;
}

