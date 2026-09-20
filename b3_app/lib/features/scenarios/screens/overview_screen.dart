import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:b3_engine/b3_engine.dart';
import '../../../data/app_knowledge_dataset.dart';
import '../../../data/household_repository.dart';

import '../../progression/models/resilience_session.dart';
import '../../results/screens/results_screen.dart';
import '../models/scenario_analysis.dart';
import '../services/multi_scenario_analyzer.dart';

class OverviewScreen extends StatefulWidget {
  final HouseholdConfig config;
  final List<String> completedActionIds;
  final HouseholdRepository? repository;

  const OverviewScreen({
    Key? key,
    required this.config,
    this.completedActionIds = const [],
    this.repository,
  }) : super(key: key);

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  late List<ScenarioAnalysis> _analyses;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    final analyzer = MultiScenarioAnalyzer(appKnowledgeBase);
    final kb = jsonDecode(appKnowledgeBase);
    final scenariosData = kb['scenarios'] as List<dynamic>;
    final scenarioIds = scenariosData.map((s) => s['id'] as String).toList();
    
    // We can do this sync, it's fast enough for MVP
    final analyses = analyzer.analyze(widget.config, scenarioIds);
    
    if (mounted) {
      setState(() {
        _analyses = analyses;
        _isLoading = false;
      });
    }
  }

  void _openScenario(ScenarioAnalysis analysis) {
    if (!analysis.isAvailable) return;

    final session = ResilienceSession(
      knowledgeJson: appKnowledgeBase,
      scenarioId: analysis.scenarioId,
      initialConfig: widget.config,
      initialCompletedActionIds: widget.completedActionIds,
      repository: widget.repository ?? SharedPrefsHouseholdRepository(),
      isRestored: false, // treat as new session for this scenario, it will autosave
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultsScreen(session: session),
      ),
    ).then((_) {
      // When returning from ResultsScreen, the config might have been modified 
      // by progression loops.
      // So we should ideally refresh. We can do that by getting the latest snapshot.
      _refreshFromRepository();
    });
  }

  Future<void> _refreshFromRepository() async {
    final repo = widget.repository ?? SharedPrefsHouseholdRepository();
    final snapshot = await repo.load();
    if (snapshot != null && mounted) {
      final analyzer = MultiScenarioAnalyzer(appKnowledgeBase);
      final kb = jsonDecode(appKnowledgeBase);
      final scenariosData = kb['scenarios'] as List<dynamic>;
      final scenarioIds = scenariosData.map((s) => s['id'] as String).toList();
      
      final analyses = analyzer.analyze(snapshot.config, scenarioIds);
      setState(() {
        _analyses = analyses;
        // In a real app we'd also update the widget config state, but 
        // since we only use config for the initial analysis this is fine for MVP.
      });
    }
  }

  String _getScenarioEmoji(String id) {
    if (id == 'panne_elec') return '⚡';
    if (id == 'panne_gaz') return '🔥';
    if (id == 'coupure_eau') return '💧';
    if (id == 'panne_internet') return '🌐';
    if (id == 'panne_mobile') return '📱';
    return '⚠️';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Résilience par scénario'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Votre foyer face aux perturbations', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 24),
              ..._analyses.map((analysis) => _buildScenarioCard(analysis, theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScenarioCard(ScenarioAnalysis analysis, ThemeData theme) {
    if (!analysis.isAvailable) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_getScenarioEmoji(analysis.scenarioId)} ${analysis.scenarioName}', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Indisponible : ${analysis.error}', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red)),
            ],
          ),
        ),
      );
    }

    final capCount = analysis.graph?.whereType<Capability>().length ?? 0;
    
    // We want to list "A surveiller" (FAILED / DEGRADED / UNKNOWN)
    // and "Disponible" (MAINTAINED)
    final failedCaps = analysis.simulationResult?.vulnerabilities.where((v) => v.state == B3State.failed).map((v) => v.capability.name).toList() ?? [];
    final degradedCaps = analysis.simulationResult?.vulnerabilities.where((v) => v.state == B3State.degraded).map((v) => v.capability.name).toList() ?? [];
    
    final toWatch = [...failedCaps, ...degradedCaps];
    
    final maintainedCaps = analysis.simulationResult?.nodeStates.entries
      .where((e) => analysis.graph?.any((n) => n is Capability && n.id == e.key) ?? false)
      .where((e) => e.value == B3State.maintained)
      .map((e) => analysis.graph!.firstWhere((n) => n.id == e.key).name)
      .toList() ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openScenario(analysis),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(_getScenarioEmoji(analysis.scenarioId), style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      analysis.scenarioName,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '$capCount capacités analysées',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
              ),
              if (analysis.failedCount > 0)
                Text(
                  '${analysis.failedCount} vulnérabilité(s) critique(s)',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red.shade700, fontWeight: FontWeight.bold),
                )
              else
                Text(
                  'Aucune vulnérabilité critique',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.green.shade700, fontWeight: FontWeight.bold),
                ),
              const SizedBox(height: 16),
              if (toWatch.isNotEmpty) ...[
                Text('À surveiller :', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                ...toWatch.map((c) => Text('• $c', style: theme.textTheme.bodySmall)),
                const SizedBox(height: 8),
              ],
              if (maintainedCaps.isNotEmpty) ...[
                Text('Disponible :', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                ...maintainedCaps.map((c) => Text('• $c', style: theme.textTheme.bodySmall)),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: () => _openScenario(analysis),
                  child: const Text('Voir'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
