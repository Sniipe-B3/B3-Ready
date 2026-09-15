import 'package:flutter/material.dart';
import 'package:b3_engine/b3_engine.dart';

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
  late List<Recommendation> _recommendations;

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    final householdConfig =
        widget.diagnosticState.toHouseholdConfig(widget.questions);
    final graph = DataMapper.buildGraph(b3KnowledgeBase, householdConfig);
    final scenario = DataMapper.parseScenario(b3KnowledgeBase, 'panne_elec');

    final engine = B3Engine();
    _simulationResult = engine.runSimulation(graph, scenario);

    _recommendations = RecommendationEngine(b3KnowledgeBase)
        .generate(_simulationResult, householdConfig, scenario);

    await Future.delayed(const Duration(milliseconds: 600));

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
                "Analyse de votre foyer...",
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
        ),
      );
    }

    final vulnCount = _simulationResult.vulnerabilities.length;
    final unkCount = _simulationResult.uncertainties.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Votre situation'),
        elevation: 0,
        backgroundColor: Colors.transparent,
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
              Text(
                "$vulnCount point\${vulnCount > 1 ? 's' : ''} à améliorer en cas de panne électrique.",
                style: theme.textTheme.titleLarge?.copyWith(
                  color: vulnCount > 0
                      ? theme.colorScheme.error
                      : theme.colorScheme.secondary,
                ),
              ),
              if (unkCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  "$unkCount information\${unkCount > 1 ? 's' : ''} manquante\${unkCount > 1 ? 's' : ''}.",
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 32),
              if (vulnCount > 0)
                ..._simulationResult.vulnerabilities
                    .map((v) => _buildVulnerabilityCard(v, theme)),
              if (vulnCount == 0 && unkCount == 0)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      "Votre foyer semble bien préparé à ce scénario !",
                      style: theme.textTheme.titleLarge
                          ?.copyWith(color: theme.colorScheme.secondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
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

  Widget _buildVulnerabilityCard(Vulnerability v, ThemeData theme) {
    final recsForCap = _recommendations
        .where((r) => r.capabilityId == v.capability.id)
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 24.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: theme.colorScheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    v.capability.name.toUpperCase(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              "En cas de panne électrique, votre capacité à \${v.capability.name.toLowerCase()} dépend d'équipements impactés.",
              style: theme.textTheme.bodyLarge,
            ),
            if (recsForCap.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Action proposée",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recsForCap.first.title,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recsForCap.first.description,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
