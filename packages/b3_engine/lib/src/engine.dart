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
    
    B3State evaluateNode(B3Node node) {
      if (states.containsKey(node.id)) {
        return states[node.id]!;
      }
      
      traces[node.id] = ReasoningTrace();
      
      // 1. Check overrides from Scenario
      if (scenario.systemOverrides.containsKey(node.id)) {
        final state = scenario.systemOverrides[node.id]!;
        states[node.id] = state;
        traces[node.id]!.add(node, state, 'Overridden by scenario');
        return state;
      }
      
      // 2. Check manual initial override
      if (node.overriddenState != null) {
        states[node.id] = node.overriddenState!;
        traces[node.id]!.add(node, node.overriddenState!, 'Initial state');
        return node.overriddenState!;
      }
      
      // 3. Resource duration check
      B3State baseState = B3State.maintained;
      if (node.duration != null && node.duration! < scenario.duration) {
        baseState = B3State.degraded;
        traces[node.id]!.add(node, baseState, 'Resource duration insufficient (${node.duration!.inHours}h < ${scenario.duration.inHours}h)');
      } else if (node.duration != null) {
        traces[node.id]!.add(node, baseState, 'Resource duration sufficient');
      }

      // 4. Evaluate children
      if (node.children.isEmpty) {
        states[node.id] = baseState;
        if (node.duration == null) {
            traces[node.id]!.add(node, baseState, 'No children, default to maintained');
        }
        return baseState;
      }
      
      final childStates = node.children.map((c) => evaluateNode(c)).toList();
      B3State finalState;
      
      if (node.rule == EvaluationRule.all) {
        finalState = evaluateAll(childStates);
        // If baseState is degraded, it can't become maintained even if children are maintained
        if (baseState == B3State.degraded && finalState == B3State.maintained) {
           finalState = B3State.degraded;
        }
        traces[node.id]!.add(node, finalState, 'Evaluated ALL (AND) on children: $childStates');
      } else {
        finalState = evaluateAny(childStates);
        if (baseState == B3State.degraded && finalState == B3State.maintained) {
           finalState = B3State.degraded;
        }
        traces[node.id]!.add(node, finalState, 'Evaluated ANY (OR) on children: $childStates');
      }
      
      states[node.id] = finalState;
      return finalState;
    }
    
    for (var node in graph) {
      evaluateNode(node);
    }
    
    final vulnerabilities = <Vulnerability>[];
    for (var node in graph) {
      if (node is Capability) {
        final state = states[node.id]!;
        if (state == B3State.failed || state == B3State.degraded || state == B3State.unknown) {
          vulnerabilities.add(Vulnerability(node, state));
        }
      }
    }
    
    return SimulationResult(states, traces, vulnerabilities);
  }
}
