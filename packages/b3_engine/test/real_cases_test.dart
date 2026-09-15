import 'package:test/test.dart';
import 'package:b3_engine/b3_engine.dart';

void main() {
  final engine = B3Engine();

  test('CAS 1 — Redondance simple', () {
    final elec = System(id: 'elec', name: 'Électricité');
    final plaque = Asset(id: 'plaque', name: 'Plaque électrique', children: [elec]);
    final gaz = Resource(id: 'gaz', name: 'Cartouche gaz');
    final rechaud = Asset(id: 'rechaud', name: 'Réchaud gaz', children: [gaz]);
    final cuisiner = Capability(id: 'cuisiner', name: 'Cuisiner', children: [plaque, rechaud]); // Rule ANY by default

    final result = engine.runSimulation(
      [elec, plaque, gaz, rechaud, cuisiner],
      Scenario(name: 'Panne Elec', duration: Duration(hours: 48), systemOverrides: {'elec': B3State.failed}),
    );

    expect(result.nodeStates['plaque'], B3State.failed);
    expect(result.nodeStates['rechaud'], B3State.maintained);
    expect(result.nodeStates['cuisiner'], B3State.maintained);
  });

  test('CAS 2 — Dépendance directe', () {
    final elec = System(id: 'elec', name: 'Électricité');
    final lampe = Asset(id: 'lampe', name: 'Lampe électrique', children: [elec]);
    final eclairage = Capability(id: 'eclairage', name: 'Éclairage', children: [lampe]);

    final result = engine.runSimulation(
      [elec, lampe, eclairage],
      Scenario(name: 'Panne Elec', duration: Duration(hours: 48), systemOverrides: {'elec': B3State.failed}),
    );

    expect(result.nodeStates['elec'], B3State.failed);
    expect(result.nodeStates['lampe'], B3State.failed);
    expect(result.nodeStates['eclairage'], B3State.failed);
    expect(result.vulnerabilities.any((v) => v.capability.id == 'eclairage'), true);
  });

  test('CAS 3 — Dépendance indirecte / cascade', () {
    final elec = System(id: 'elec', name: 'Électricité');
    final chaudiere = Asset(id: 'chaudiere', name: 'Chaudière gaz', children: [elec]); // Chaudière a besoin d'élec pour fonctionner
    final chauffer = Capability(id: 'chauffer', name: 'Chauffer', children: [chaudiere]);

    final result = engine.runSimulation(
      [elec, chaudiere, chauffer],
      Scenario(name: 'Panne Elec', duration: Duration(hours: 48), systemOverrides: {'elec': B3State.failed}),
    );

    expect(result.nodeStates['chauffer'], B3State.failed);
    expect(result.vulnerabilities.length, 1);
  });

  test('CAS 4 — AND (Les deux conditions nécessaires)', () {
    final eau = System(id: 'eau', name: 'Réseau Eau');
    final elec = System(id: 'elec', name: 'Électricité');
    final douche = Asset(id: 'douche', name: 'Douche chaude', rule: EvaluationRule.all, children: [eau, elec]);
    final hygiene = Capability(id: 'hygiene', name: 'Hygiène', children: [douche]);

    // Test A: MAINTAINED + MAINTAINED
    final resA = engine.runSimulation([eau, elec, douche, hygiene], Scenario(name: 'S', duration: Duration(), systemOverrides: {}));
    expect(resA.nodeStates['hygiene'], B3State.maintained);

    // Test B: FAILED + MAINTAINED
    final resB = engine.runSimulation([eau, elec, douche, hygiene], Scenario(name: 'S', duration: Duration(), systemOverrides: {'eau': B3State.failed}));
    expect(resB.nodeStates['hygiene'], B3State.failed);

    // Test C: MAINTAINED + FAILED
    final resC = engine.runSimulation([eau, elec, douche, hygiene], Scenario(name: 'S', duration: Duration(), systemOverrides: {'elec': B3State.failed}));
    expect(resC.nodeStates['hygiene'], B3State.failed);

    // Test D: FAILED + FAILED
    final resD = engine.runSimulation([eau, elec, douche, hygiene], Scenario(name: 'S', duration: Duration(), systemOverrides: {'eau': B3State.failed, 'elec': B3State.failed}));
    expect(resD.nodeStates['hygiene'], B3State.failed);
  });

  test('CAS 5 — UNKNOWN', () {
    // A: UNKNOWN seul -> UNKNOWN
    final unkNodeA = System(id: 'unkA', name: 'UnkA', overriddenState: B3State.unknown);
    final capA = Capability(id: 'capA', name: 'CapA', children: [unkNodeA]);
    final resA = engine.runSimulation([unkNodeA, capA], Scenario(name: 'S', duration: Duration(), systemOverrides: {}));
    expect(resA.nodeStates['capA'], B3State.unknown);
    expect(resA.uncertainties.any((u) => u.capability.id == 'capA'), true);
    expect(resA.vulnerabilities.any((v) => v.capability.id == 'capA'), false);

    // B: UNKNOWN + MAINTAINED (ANY) -> MAINTAINED
    final mainNode = System(id: 'main', name: 'Main', overriddenState: B3State.maintained);
    final unkNodeB = System(id: 'unkB', name: 'UnkB', overriddenState: B3State.unknown);
    final capB = Capability(id: 'capB', name: 'CapB', children: [mainNode, unkNodeB]); // rule ANY
    final resB = engine.runSimulation([mainNode, unkNodeB, capB], Scenario(name: 'S', duration: Duration(), systemOverrides: {}));
    expect(resB.nodeStates['capB'], B3State.maintained);

    // C: UNKNOWN + FAILED (ANY) -> UNKNOWN
    final failNode = System(id: 'fail', name: 'Fail', overriddenState: B3State.failed);
    final capC = Capability(id: 'capC', name: 'CapC', children: [failNode, unkNodeB]);
    final resC = engine.runSimulation([failNode, unkNodeB, capC], Scenario(name: 'S', duration: Duration(), systemOverrides: {}));
    expect(resC.nodeStates['capC'], B3State.unknown);

    // D: UNKNOWN + UNKNOWN -> UNKNOWN
    final unkNodeC = System(id: 'unkC', name: 'UnkC', overriddenState: B3State.unknown);
    final capD = Capability(id: 'capD', name: 'CapD', children: [unkNodeB, unkNodeC]);
    final resD = engine.runSimulation([unkNodeB, unkNodeC, capD], Scenario(name: 'S', duration: Duration(), systemOverrides: {}));
    expect(resD.nodeStates['capD'], B3State.unknown);
  });

  test('CAS 6 — RESSOURCE LIMITÉE', () {
    final bois24 = Resource(id: 'bois24', name: 'Bois 24h', duration: Duration(hours: 24));
    final poele24 = Asset(id: 'poele24', name: 'Poêle', children: [bois24]);
    final cap24 = Capability(id: 'cap24', name: 'Chauffer', children: [poele24]);
    
    final resDegraded = engine.runSimulation([bois24, poele24, cap24], Scenario(name: 'S72', duration: Duration(hours: 72), systemOverrides: {}));
    expect(resDegraded.nodeStates['cap24'], B3State.degraded);

    final bois72 = Resource(id: 'bois72', name: 'Bois 72h', duration: Duration(hours: 72));
    final poele72 = Asset(id: 'poele72', name: 'Poêle', children: [bois72]);
    final cap72 = Capability(id: 'cap72', name: 'Chauffer', children: [poele72]);
    
    final resMaintained = engine.runSimulation([bois72, poele72, cap72], Scenario(name: 'S48', duration: Duration(hours: 48), systemOverrides: {}));
    expect(resMaintained.nodeStates['cap72'], B3State.maintained);
  });

  test('CAS 7 — DOUBLE PANNE', () {
    final elec = System(id: 'elec', name: 'Électricité');
    final plaque = Asset(id: 'plaque', name: 'Plaque', children: [elec]);
    final gaz = Resource(id: 'gaz', name: 'Gaz', overriddenState: B3State.failed); // Double fail
    final rechaud = Asset(id: 'rechaud', name: 'Réchaud', children: [gaz]);
    final cuisiner = Capability(id: 'cuisiner', name: 'Cuisiner', children: [plaque, rechaud]);

    final result = engine.runSimulation([elec, plaque, gaz, rechaud, cuisiner], Scenario(name: 'Panne Elec', duration: Duration(), systemOverrides: {'elec': B3State.failed}));
    
    expect(result.nodeStates['cuisiner'], B3State.failed);
    expect(result.vulnerabilities.length, 1);
  });

  test('CAS 8 — DÉPENDANCES EN CASCADE', () {
    // Capability -> Asset A -> Asset B -> System
    final system = System(id: 'sys', name: 'Sys');
    final assetB = Asset(id: 'assetB', name: 'Asset B', children: [system]);
    final assetA = Asset(id: 'assetA', name: 'Asset A', children: [assetB]);
    final cap = Capability(id: 'cap', name: 'Capability', children: [assetA]);

    final result = engine.runSimulation([system, assetB, assetA, cap], Scenario(name: 'S', duration: Duration(), systemOverrides: {'sys': B3State.failed}));
    
    expect(result.nodeStates['cap'], B3State.failed);
  });

  test('CAS 9 — FAUSSE REDONDANCE', () {
    final elec = System(id: 'elec', name: 'Électricité');
    final plaque = Asset(id: 'plaque', name: 'Plaque', children: [elec]);
    final four = Asset(id: 'four', name: 'Four', children: [elec]); // Même dépendance
    final cuisiner = Capability(id: 'cuisiner', name: 'Cuisiner', children: [plaque, four]); // ANY

    final result = engine.runSimulation([elec, plaque, four, cuisiner], Scenario(name: 'S', duration: Duration(), systemOverrides: {'elec': B3State.failed}));
    
    // Le moteur comprend que bien qu'il y ait 2 enfants, les deux dépendent de elec qui est failed.
    expect(result.nodeStates['cuisiner'], B3State.failed);
  });

  test('CAS 10 — SCÉNARIO COMPLEXE & TRACE', () {
    final elec = System(id: 'elec', name: 'Électricité');
    final internet = System(id: 'net', name: 'Internet');
    final eau = System(id: 'eau', name: 'Eau');

    final frigo = Asset(id: 'frigo', name: 'Frigo', children: [elec]);
    final nourriture = Capability(id: 'nourriture', name: 'Nourriture', children: [frigo]);

    final wifi = Asset(id: 'wifi', name: 'Box WiFi', children: [elec, internet]);
    final comms = Capability(id: 'comms', name: 'Communications', children: [wifi]);

    final robinet = Asset(id: 'robinet', name: 'Robinet', children: [eau]); // Appart sans pompe
    final hydratation = Capability(id: 'hydratation', name: 'Hydratation', children: [robinet]);

    final graph = [elec, internet, eau, frigo, nourriture, wifi, comms, robinet, hydratation];
    final scenario = Scenario(
      name: 'Blackout & Net', 
      duration: Duration(), 
      systemOverrides: {'elec': B3State.failed, 'net': B3State.failed, 'eau': B3State.maintained}
    );

    final result = engine.runSimulation(graph, scenario);

    expect(result.nodeStates['nourriture'], B3State.failed);
    expect(result.nodeStates['comms'], B3State.failed);
    expect(result.nodeStates['hydratation'], B3State.maintained);

    // Vérifier la structure de la trace pour 'nourriture'
    final trace = result.traces['nourriture']!;
    expect(trace.steps.isNotEmpty, true);
    final lastStep = trace.steps.last;
    expect(lastStep.type, ReasonType.evaluatedChildren);
    expect(lastStep.dependencyStates!['frigo'], B3State.failed);
  });
}
