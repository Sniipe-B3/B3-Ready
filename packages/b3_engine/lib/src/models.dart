enum B3State {
  maintained,
  degraded,
  unknown,
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
  
  // Modifiable during simulation
  B3State? overriddenState;
  
  // Resource duration
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
  Capability({required String id, required String name, EvaluationRule rule = EvaluationRule.any, List<B3Node> children = const []})
      : super(id: id, name: name, rule: rule, children: children);
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

class TraceStep {
  final B3Node node;
  final B3State state;
  final String reason;

  TraceStep(this.node, this.state, this.reason);
  
  @override
  String toString() => '${node.name} [$state] ($reason)';
}

class ReasoningTrace {
  final List<TraceStep> steps = [];
  
  void add(B3Node node, B3State state, String reason) {
    steps.add(TraceStep(node, state, reason));
  }
}

class Vulnerability {
  final Capability capability;
  final B3State state;
  
  Vulnerability(this.capability, this.state);
}

class SimulationResult {
  final Map<String, B3State> nodeStates;
  final Map<String, ReasoningTrace> traces;
  final List<Vulnerability> vulnerabilities;

  SimulationResult(this.nodeStates, this.traces, this.vulnerabilities);
}
