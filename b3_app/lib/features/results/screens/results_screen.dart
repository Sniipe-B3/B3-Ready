import 'package:flutter/material.dart';
import 'package:b3_engine/b3_engine.dart';
import '../../../data/app_knowledge_dataset.dart';
import '../../../app/theme/theme.dart';
import 'vulnerability_detail_screen.dart';

class ResultsScreen extends StatefulWidget {
  final DiagnosticState diagnosticState;
  final List<DiagnosticQuestion> questions;

  const ResultsScreen({
    super.key,
    required this.diagnosticState,
    required this.questions,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _isLoading = true;
  late SimulationResult _simulationResult;
  late HouseholdConfig _config;
  late Scenario _scenario;
  late List<B3Node> _graph;
  late List<Recommendation> _recommendations;

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    _config =
        widget.diagnosticState.toHouseholdConfig(widget.questions);
    _graph = DataMapper.buildGraph(appKnowledgeBase, _config);
    _scenario = DataMapper.parseScenario(appKnowledgeBase, 'panne_elec');

    final engine = B3Engine();
    _simulationResult = engine.runSimulation(_graph, _scenario);

    _recommendations = RecommendationEngine(appKnowledgeBase)
        .generate(_simulationResult, _config, _scenario);

    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                "Analyse des dépendances...",
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
        ),
      );
    }

    final vulns = _simulationResult.vulnerabilities.where((v) => v.state == B3State.failed).toList();
    final degraded = _simulationResult.vulnerabilities.where((v) => v.state == B3State.degraded).toList();
    
    final totalPoints = vulns.length + degraded.length;
    
    final String vigilanceText = totalPoints > 1 
        ? "$totalPoints points de vigilance identifiés." 
        : "1 point de vigilance identifié.";

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilan de résilience'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Votre première analyse',
                style: theme.textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              if (totalPoints > 0)
                Text(
                  vigilanceText,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: vulns.isNotEmpty ? B3Theme.b3Red : B3Theme.b3Orange,
                  ),
                )
              else
                Text(
                  "Votre foyer semble bien préparé pour ce scénario.",
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: B3Theme.b3Green,
                  ),
                ),
              const SizedBox(height: 32),
              
              ...vulns.map((v) => _buildVulnCard(v, theme, B3Theme.b3Red, "Vulnérable en cas de panne électrique")),
              ...degraded.map((v) => _buildVulnCard(v, theme, B3Theme.b3Orange, "Partiellement vulnérable (réserve limitée)")),
              
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('Retour à l\'accueil'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  String _getEmoji(String capabilityId) {
    if (capabilityId == 'cuisiner') return '🍳';
    if (capabilityId == 'chauffer') return '🌡️';
    if (capabilityId == 'eclairage') return '💡';
    return '🔧';
  }

  String _getCapabilityName(String capabilityId) {
    if (capabilityId == 'cuisiner') return 'CUISINER';
    if (capabilityId == 'chauffer') return 'SE CHAUFFER';
    if (capabilityId == 'eclairage') return 'S\'ÉCLAIRER';
    return capabilityId.toUpperCase(); // Fallback générique
  }

  Widget _buildVulnCard(Vulnerability v, ThemeData theme, Color color, String subtitle) {
    final capId = v.capability.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 24.0),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _getEmoji(capId),
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getCapabilityName(capId),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: color.withValues(alpha: 0.1),
                  foregroundColor: color,
                ),
                onPressed: () {
                  final recs = _recommendations.where((r) => r.capabilityId == capId).toList();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VulnerabilityDetailScreen(
                        vulnerability: v,
                        config: _config,
                        result: _simulationResult,
                        scenario: _scenario,
                        graph: _graph,
                        recommendations: recs,
                      ),
                    ),
                  );
                },
                child: const Text('Comprendre', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
