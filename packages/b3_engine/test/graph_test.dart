import 'package:test/test.dart';
import 'package:b3_engine/b3_engine.dart';

void main() {
  final engine = B3Engine();

  test('Step 4 & 5: First Graph and ReasoningTrace', () {
    final electricite = System(id: 'elec', name: 'Électricité');
    final plaque = Asset(id: 'plaque', name: 'Plaque électrique', children: [electricite]);
    final cartouche = Resource(id: 'cartouche', name: 'Cartouche gaz');
    final rechaud = Asset(id: 'rechaud', name: 'Réchaud gaz', children: [cartouche]);
    final cuisiner = Capability(id: 'cuisiner', name: 'CUISINER', children: [plaque, rechaud]);
    
    final graph = [electricite, plaque, cartouche, rechaud, cuisiner];
    final scenario = Scenario(
      name: 'Panne Electrique',
      duration: Duration(hours: 48),
      systemOverrides: {'elec': B3State.failed},
    );
    
    final result = engine.runSimulation(graph, scenario);
    
    expect(result.nodeStates['elec'], B3State.failed);
    expect(result.nodeStates['plaque'], B3State.failed);
    expect(result.nodeStates['cartouche'], B3State.maintained);
    expect(result.nodeStates['rechaud'], B3State.maintained);
    expect(result.nodeStates['cuisiner'], B3State.maintained);
    
    final trace = result.traces['cuisiner']!;
    expect(trace.steps.isNotEmpty, true);
    expect(trace.steps.last.state, B3State.maintained);
    expect(trace.steps.last.type, ReasonType.evaluatedChildren);
  });

  test('Step 6: DEGRADED Case (Resource duration)', () {
    final wood = Resource(id: 'wood', name: 'Bois', duration: Duration(hours: 24));
    final stove = Asset(id: 'stove', name: 'Poêle à bois', children: [wood]);
    final heating = Capability(id: 'heating', name: 'Chauffage', children: [stove]);
    
    final result = engine.runSimulation([wood, stove, heating], Scenario(name: 'S', duration: Duration(hours: 72), systemOverrides: {}));
    
    expect(result.nodeStates['heating'], B3State.degraded);
  });

  test('Step 7: UNKNOWN Cases in ANY logic', () {
    final failNode = System(id: 'fail', name: 'Fail', overriddenState: B3State.failed);
    final unknownNode = System(id: 'unk', name: 'Unk', overriddenState: B3State.unknown);
    final mainNode = System(id: 'main', name: 'Main', overriddenState: B3State.maintained);
    final degNode = System(id: 'deg', name: 'Deg', overriddenState: B3State.degraded);

    final anyFailUnk = Capability(id: 'cap1', name: 'Cap1', children: [failNode, unknownNode]);
    expect(engine.runSimulation([failNode, unknownNode, anyFailUnk], Scenario(name: 'S', duration: Duration(), systemOverrides: {})).nodeStates['cap1'], B3State.unknown);
    
    final anyMainUnk = Capability(id: 'cap2', name: 'Cap2', children: [mainNode, unknownNode]);
    expect(engine.runSimulation([mainNode, unknownNode, anyMainUnk], Scenario(name: 'S', duration: Duration(), systemOverrides: {})).nodeStates['cap2'], B3State.maintained);
    
    final anyDegUnk = Capability(id: 'cap3', name: 'Cap3', children: [degNode, unknownNode]);
    expect(engine.runSimulation([degNode, unknownNode, anyDegUnk], Scenario(name: 'S', duration: Duration(), systemOverrides: {})).nodeStates['cap3'], B3State.degraded);
  });

  test('Test A: Cycle Detection', () {
    final nodeA = Asset(id: 'a', name: 'A', children: []);
    final nodeB = Asset(id: 'b', name: 'B', children: [nodeA]);
    // Inject cycle
    nodeA.children.add(nodeB);
    
    final result = engine.runSimulation([nodeA, nodeB], Scenario(name: 'S', duration: Duration(), systemOverrides: {}));
    
    // The cycle should break with UNKNOWN, resulting in all nodes in cycle being UNKNOWN
    expect(result.nodeStates['a'], B3State.unknown);
    expect(result.nodeStates['b'], B3State.unknown);
    
    // Check trace for cycle detection
    expect(result.traces['a']!.steps.any((s) => s.type == ReasonType.cycleDetected || s.type == ReasonType.evaluatedChildren), true);
  });

  test('Test B: Structured ReasoningTrace', () {
    final elec = System(id: 'elec', name: 'Élec');
    final plaque = Asset(id: 'plaque', name: 'Plaque', children: [elec]);
    final gaz = Resource(id: 'gaz', name: 'Gaz');
    final rechaud = Asset(id: 'rechaud', name: 'Réchaud', children: [gaz]);
    final cuisiner = Capability(id: 'cuisiner', name: 'Cuisiner', children: [plaque, rechaud]);
    
    final scenario = Scenario(name: 'Panne', duration: Duration(), systemOverrides: {'elec': B3State.failed});
    final result = engine.runSimulation([elec, plaque, gaz, rechaud, cuisiner], scenario);
    
    final elecTrace = result.traces['elec']!.steps.last;
    expect(elecTrace.type, ReasonType.scenarioOverride);
    expect(elecTrace.scenario?.name, 'Panne');

    final cuisinerTrace = result.traces['cuisiner']!.steps.last;
    expect(cuisinerTrace.type, ReasonType.evaluatedChildren);
    expect(cuisinerTrace.dependencyStates, isNotNull);
    expect(cuisinerTrace.dependencyStates!['plaque'], B3State.failed);
    expect(cuisinerTrace.dependencyStates!['rechaud'], B3State.maintained);
  });

  test('Test C: UNKNOWN vs Vulnerability', () {
    final unkSys = System(id: 'unk', name: 'Unk', overriddenState: B3State.unknown);
    final failSys = System(id: 'fail', name: 'Fail', overriddenState: B3State.failed);
    
    final capUnknown = Capability(id: 'capU', name: 'CapU', children: [unkSys]);
    final capFailed = Capability(id: 'capF', name: 'CapF', children: [failSys]);
    
    final result = engine.runSimulation([unkSys, failSys, capUnknown, capFailed], Scenario(name: 'S', duration: Duration(), systemOverrides: {}));
    
    expect(result.vulnerabilities.length, 1);
    expect(result.vulnerabilities.first.capability.id, 'capF');
    
    expect(result.uncertainties.length, 1);
    expect(result.uncertainties.first.capability.id, 'capU');
  });

  test('Test D: UNKNOWN protected', () {
    final unkSys = System(id: 'unk', name: 'Unk', overriddenState: B3State.unknown);
    final mainSys = System(id: 'main', name: 'Main', overriddenState: B3State.maintained);
    final cap = Capability(id: 'cap', name: 'Cap', children: [unkSys, mainSys]); // rule = ANY
    
    final result = engine.runSimulation([unkSys, mainSys, cap], Scenario(name: 'S', duration: Duration(), systemOverrides: {}));
    
    expect(result.nodeStates['cap'], B3State.maintained);
    final trace = result.traces['cap']!.steps.last;
    expect(trace.type, ReasonType.evaluatedChildren);
    expect(trace.dependencyStates!['unk'], B3State.unknown);
    expect(trace.dependencyStates!['main'], B3State.maintained);
  });

  test('Test E: Determinism', () {
    final unkSys = System(id: 'unk', name: 'Unk', overriddenState: B3State.unknown);
    final mainSys = System(id: 'main', name: 'Main', overriddenState: B3State.maintained);
    final cap = Capability(id: 'cap', name: 'Cap', children: [unkSys, mainSys]); // rule = ANY
    final graph = [unkSys, mainSys, cap];
    final scenario = Scenario(name: 'S', duration: Duration(), systemOverrides: {});
    
    final r1 = engine.runSimulation(graph, scenario);
    final r2 = engine.runSimulation(graph, scenario);
    
    expect(r1.nodeStates, equals(r2.nodeStates));
    expect(r1.traces['cap']!.steps.last.state, r2.traces['cap']!.steps.last.state);
  });
}
