import 'models.dart';

class B3Engine {
  B3State evaluateAll(Iterable<B3State> states) {
    if (states.isEmpty) return B3State.maintained;
    if (states.any((s) => s == B3State.failed)) return B3State.failed;
    if (states.any((s) => s == B3State.unknown)) return B3State.unknown;
    if (states.any((s) => s == B3State.degraded)) return B3State.degraded;
    return B3State.maintained;
  }

  B3State evaluateAny(Iterable<B3State> states) {
    if (states.isEmpty) return B3State.failed;
    if (states.any((s) => s == B3State.maintained)) return B3State.maintained;
    if (states.any((s) => s == B3State.degraded)) return B3State.degraded;
    if (states.any((s) => s == B3State.unknown)) return B3State.unknown;
    return B3State.failed;
  }
  
  SimulationResult runSimulation(List<B3Node> graph, Scenario scenario) {
    final states = <String, B3State>{};
    final traces = <String, ReasoningTrace>{};
    final visiting = <String>{}; // Cycle detection
    
    B3State evaluateNode(B3Node node) {
      if (states.containsKey(node.id)) {
        return states[node.id]!;
      }
      
      if (visiting.contains(node.id)) {
        // Cycle detected
        traces.putIfAbsent(node.id, () => ReasoningTrace()).add(TraceStep(
          node: node,
          state: B3State.unknown,
          type: ReasonType.cycleDetected,
          description: 'Cycle detected during evaluation, assuming UNKNOWN state to prevent loop',
        ));
        return B3State.unknown;
      }
      
      visiting.add(node.id);
      traces[node.id] = ReasoningTrace();
      
      // 1. Check overrides from Scenario
      if (scenario.systemOverrides.containsKey(node.id)) {
        final state = scenario.systemOverrides[node.id]!;
        states[node.id] = state;
        traces[node.id]!.add(TraceStep(
          node: node,
          state: state,
          type: ReasonType.scenarioOverride,
          description: 'Overridden by scenario',
          scenario: scenario,
        ));
        visiting.remove(node.id);
        return state;
      }
      
      // 2. Check manual initial override
      if (node.overriddenState != null) {
        states[node.id] = node.overriddenState!;
        traces[node.id]!.add(TraceStep(
          node: node,
          state: node.overriddenState!,
          type: ReasonType.initialOverride,
          description: 'Initial manual override',
        ));
        visiting.remove(node.id);
        return node.overriddenState!;
      }
      
      // 3. Resource duration check
      B3State baseState = B3State.maintained;
      if (node.duration != null && node.duration! < scenario.duration) {
        baseState = B3State.degraded;
        traces[node.id]!.add(TraceStep(
          node: node,
          state: baseState,
          type: ReasonType.resourceExhausted,
          description: 'Resource duration insufficient (${node.duration!.inHours}h < ${scenario.duration.inHours}h)',
        ));
      } else if (node.duration != null) {
        traces[node.id]!.add(TraceStep(
          node: node,
          state: baseState,
          type: ReasonType.resourceSufficient,
          description: 'Resource duration sufficient',
        ));
      }

      // 4. Evaluate children
      if (node.children.isEmpty) {
                if (node.rule == EvaluationRule.any) {
           states[node.id] = evaluateAny([]); // qui retourne failed
           baseState = states[node.id]!;
        } else {
           states[node.id] = baseState;
        }
    
        if (node.duration == null) {
            traces[node.id]!.add(TraceStep(
              node: node,
              state: baseState,
              type: ReasonType.noDependencies,
              description: 'No children dependencies, default to maintained',
            ));
        }
        visiting.remove(node.id);
        return baseState;
      }
      
      final childStates = <String, B3State>{};
      for (var c in node.children) {
        childStates[c.id] = evaluateNode(c);
      }
      
      B3State finalState;
      if (node.rule == EvaluationRule.all) {
        finalState = evaluateAll(childStates.values);
        if (baseState == B3State.degraded && finalState == B3State.maintained) {
           finalState = B3State.degraded;
        }
        traces[node.id]!.add(TraceStep(
          node: node,
          state: finalState,
          type: ReasonType.evaluatedChildren,
          description: 'Evaluated ALL (AND)',
          dependencyStates: childStates,
        ));
      } else {
        finalState = evaluateAny(childStates.values);
        if (baseState == B3State.degraded && finalState == B3State.maintained) {
           finalState = B3State.degraded;
        }
        traces[node.id]!.add(TraceStep(
          node: node,
          state: finalState,
          type: ReasonType.evaluatedChildren,
          description: 'Evaluated ANY (OR)',
          dependencyStates: childStates,
        ));
      }
      
      states[node.id] = finalState;
      visiting.remove(node.id);
      return finalState;
    }
    
    for (var node in graph) {
      evaluateNode(node);
    }
    
    final vulnerabilities = <Vulnerability>[];
    final uncertainties = <Uncertainty>[];
    
    for (var node in graph) {
      if (node is Capability) {
        final state = states[node.id]!;
        if (state == B3State.failed || state == B3State.degraded) {
          vulnerabilities.add(Vulnerability(node, state));
        } else if (state == B3State.unknown) {
          uncertainties.add(Uncertainty(node));
        }
      }
    }
    
    return SimulationResult(states, traces, vulnerabilities, uncertainties);
  }
}
