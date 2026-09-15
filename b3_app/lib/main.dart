import 'package:flutter/material.dart';
import 'package:b3_engine/b3_engine.dart';

void main() {
  runApp(const B3App());
}

class B3App extends StatelessWidget {
  const B3App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'B3 Ready',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final B3Engine _engine = B3Engine();
  String _status = "Moteur B3 non initialisé";

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  void _initEngine() {
    // Initialisation simple pour valider la connexion Flutter <-> B3Engine
    final household = HouseholdConfig(
      ownedAssets: [],
      assessedCapabilities: {'cuisiner', 'boire', 'chauffer'},
    );
    final graph = DataMapper.buildGraph(b3KnowledgeBase, household);
    final scenario = DataMapper.parseScenario(b3KnowledgeBase, 'panne_elec');
    
    final result = _engine.runSimulation(graph, scenario);
    
    setState(() {
      _status = "Moteur B3 connecté !\\n"
          "${result.uncertainties.length} incertitudes trouvées\\n"
          "${result.vulnerabilities.length} vulnérabilités trouvées";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('B3 Ready'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield_outlined, size: 64, color: Colors.blueGrey),
            const SizedBox(height: 16),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
