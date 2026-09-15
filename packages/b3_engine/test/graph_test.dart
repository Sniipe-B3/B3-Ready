import 'package:test/test.dart';
import 'package:b3_engine/b3_engine.dart';

void main() {
  final engine = B3Engine();

  test('Step 4 & 5: First Graph and ReasoningTrace', () {
    // Électricité = FAILED -> Plaque électrique = FAILED
    // Cartouche gaz = MAINTAINED -> Réchaud = MAINTAINED
    // Cuisiner = MAINTAINED
    
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
    expect(result.nodeStates['cartouche'], B3State.maintained); // Default state
    expect(result.nodeStates['rechaud'], B3State.maintained);
    expect(result.nodeStates['cuisiner'], B3State.maintained);
    
    // Check ReasoningTrace for 'cuisiner'
    final trace = result.traces['cuisiner']!;
    expect(trace.steps.isNotEmpty, true);
    expect(trace.steps.last.state, B3State.maintained);
    expect(trace.steps.last.reason.contains('Evaluated ANY (OR)'), true);
  });

  test('Step 6: DEGRADED Case (Resource duration)', () {
    final wood = Resource(id: 'wood', name: 'Bois', duration: Duration(hours: 24));
    final stove = Asset(id: 'stove', name: 'Poêle à bois', children: [wood]);
    final heating = Capability(id: 'heating', name: 'Chauffage', children: [stove]);
    
    final graph = [wood, stove, heating];
    final scenario = Scenario(
      name: 'Tempete longue',
      duration: Duration(hours: 72),
      systemOverrides: {},
    );
    
    final result = engine.runSimulation(graph, scenario);
    
    expect(result.nodeStates['wood'], B3State.degraded);
    expect(result.nodeStates['stove'], B3State.degraded);
    expect(result.nodeStates['heating'], B3State.degraded);
  });

  test('Step 7: UNKNOWN Cases in ANY logic', () {
    // UNKNOWN + FAILED = UNKNOWN
    final failNode = System(id: 'fail', name: 'Fail', overriddenState: B3State.failed);
    final unknownNode = System(id: 'unk', name: 'Unk', overriddenState: B3State.unknown);
    final anyFailUnk = Capability(id: 'cap1', name: 'Cap1', children: [failNode, unknownNode]);
    
    final result1 = engine.runSimulation([failNode, unknownNode, anyFailUnk], Scenario(name: 'S', duration: Duration(), systemOverrides: {}));
    expect(result1.nodeStates['cap1'], B3State.unknown);
    
    // UNKNOWN + MAINTAINED = MAINTAINED
    final mainNode = System(id: 'main', name: 'Main', overriddenState: B3State.maintained);
    final anyMainUnk = Capability(id: 'cap2', name: 'Cap2', children: [mainNode, unknownNode]);
    
    final result2 = engine.runSimulation([mainNode, unknownNode, anyMainUnk], Scenario(name: 'S', duration: Duration(), systemOverrides: {}));
    expect(result2.nodeStates['cap2'], B3State.maintained);
    
    // UNKNOWN + DEGRADED = DEGRADED
    final degNode = System(id: 'deg', name: 'Deg', overriddenState: B3State.degraded);
    final anyDegUnk = Capability(id: 'cap3', name: 'Cap3', children: [degNode, unknownNode]);
    
    final result3 = engine.runSimulation([degNode, unknownNode, anyDegUnk], Scenario(name: 'S', duration: Duration(), systemOverrides: {}));
    expect(result3.nodeStates['cap3'], B3State.degraded);
  });

  test('Step 8: Determinism', () {
    final elec = System(id: 'e', name: 'E');
    final cap = Capability(id: 'c', name: 'C', children: [elec]);
    final graph = [elec, cap];
    final scenario = Scenario(name: 'S', duration: Duration(hours: 1), systemOverrides: {'e': B3State.failed});
    
    final result1 = engine.runSimulation(graph, scenario);
    final result2 = engine.runSimulation(graph, scenario);
    
    expect(result1.nodeStates, equals(result2.nodeStates));
    // Verify specific output is identical
    expect(result1.nodeStates['c'], B3State.failed);
    expect(result2.nodeStates['c'], B3State.failed);
  });
}
