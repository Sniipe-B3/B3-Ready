enum B3State {
  maintained,
  degraded,
  unknown,
  notAssessed,
  failed,
}

enum EvaluationRule {
  all, // AND
  any, // OR
}

abstract class B3Node {
  final String id;
  final String name;
  final EvaluationRule rule;
  final List<B3Node> children;
  
  B3State? overriddenState;
  final Duration? duration;

  B3Node({
    required this.id,
    required this.name,
    this.rule = EvaluationRule.all,
    this.children = const [],
    this.overriddenState,
    this.duration,
  });
}

class Capability extends B3Node {
  Capability({required String id, required String name, EvaluationRule rule = EvaluationRule.any, List<B3Node> children = const [], B3State? overriddenState})
      : super(id: id, name: name, rule: rule, children: children, overriddenState: overriddenState);
}

class System extends B3Node {
  System({required String id, required String name, B3State? overriddenState})
      : super(id: id, name: name, rule: EvaluationRule.all, overriddenState: overriddenState);
}

class Asset extends B3Node {
  Asset({required String id, required String name, EvaluationRule rule = EvaluationRule.all, List<B3Node> children = const []})
      : super(id: id, name: name, rule: rule, children: children);
}

class Resource extends B3Node {
  Resource({required String id, required String name, Duration? duration, B3State? overriddenState})
      : super(id: id, name: name, rule: EvaluationRule.all, duration: duration, overriddenState: overriddenState);
}

class Scenario {
  final String name;
  final Duration duration;
  final Map<String, B3State> systemOverrides;

  Scenario({required this.name, required this.duration, required this.systemOverrides});
}

enum ReasonType {
  scenarioOverride,
  initialOverride,
  resourceExhausted,
  resourceSufficient,
  noDependencies,
  evaluatedChildren,
  cycleDetected,
}

class TraceStep {
  final B3Node node;
  final B3State state;
  final ReasonType type;
  final String description;
  final Map<String, B3State>? dependencyStates;
  final Scenario? scenario;

  TraceStep({
    required this.node,
    required this.state,
    required this.type,
    required this.description,
    this.dependencyStates,
    this.scenario,
  });
  
  @override
  String toString() {
    var deps = dependencyStates != null ? ' deps:$dependencyStates' : '';
    return '${node.name} [$state] (${type.name}: $description)$deps';
  }
}

class ReasoningTrace {
  final List<TraceStep> steps = [];
  
  void add(TraceStep step) {
    steps.add(step);
  }
}

class Vulnerability {
  final Capability capability;
  final B3State state;
  
  Vulnerability(this.capability, this.state);
}

class Uncertainty {
  final Capability capability;
  final B3State state;
  
  Uncertainty(this.capability, this.state);
}

class SimulationResult {
  final Map<String, B3State> nodeStates;
  final Map<String, ReasoningTrace> traces;
  final List<Vulnerability> vulnerabilities;
  final List<Uncertainty> uncertainties;

  SimulationResult(this.nodeStates, this.traces, this.vulnerabilities, this.uncertainties);
}
