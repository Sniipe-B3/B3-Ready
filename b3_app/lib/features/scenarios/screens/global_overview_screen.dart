import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:b3_engine/b3_engine.dart';
import '../../progression/models/resilience_session.dart';
import '../../progression/models/household_update.dart';
import '../../progression/screens/progression_screen.dart';
import '../../progression/utils/action_update_resolver.dart';
import '../../action_plan/models/action_plan.dart';
import '../../../data/household_repository.dart';
import '../../../data/app_knowledge_dataset.dart';
import '../models/scenario_analysis.dart';
import '../models/global_household_overview.dart';
import '../services/cross_scenario_analyzer.dart';
import '../models/dependency_impact.dart';
import 'dependency_impact_card.dart';

class GlobalOverviewScreen extends StatefulWidget {
  final List<ScenarioAnalysis> analyses;
  final HouseholdConfig config;
  final List<String> completedActionIds;
  final HouseholdRepository repository;

  const GlobalOverviewScreen({
    Key? key,
    required this.analyses,
    required this.config,
    required this.completedActionIds,
    required this.repository,
  }) : super(key: key);

  @override
  State<GlobalOverviewScreen> createState() => _GlobalOverviewScreenState();
}

class _GlobalOverviewScreenState extends State<GlobalOverviewScreen> {
  late GlobalHouseholdOverview _overview;
  late CrossScenarioAnalyzer _analyzer;

  @override
  void initState() {
    super.initState();
    _analyzer = CrossScenarioAnalyzer(appKnowledgeBase);
    _overview = _analyzer.analyze(widget.analyses);
  }

  String _formatState(B3State state) {
    switch (state) {
      case B3State.failed: return 'Vulnérable';
      case B3State.degraded: return 'Partiellement disponible';
      case B3State.unknown: return 'À vérifier';
      case B3State.notAssessed: return 'Non évalué';
      case B3State.maintained: return 'Disponible';
    }
  }

  void _showCapabilityDetails(RecurringCapabilityIssue issue) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(issue.capabilityName, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                ...issue.statesByScenario.entries.map((e) => ListTile(
                  title: Text(e.key),
                  trailing: Text(_formatState(e.value)),
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showActionDetails(CrossScenarioAction action) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(action.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Concerne ${action.scenarioIds.length} scénario(s)'),
                const SizedBox(height: 16),
                const Text('Scénarios concernés:'),
                ...action.scenarioIds.map((s) => Text('• $s')),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _applyAction(action);
                  },
                  child: const Text('Ouvrir dans mon plan d\'action'),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  String _getNodeName(String id) {
    final kb = jsonDecode(appKnowledgeBase);
    final collections = ['systems', 'resources', 'assets', 'capabilities'];
    for (var col in collections) {
      final list = kb[col] as List<dynamic>? ?? [];
      final node = list.firstWhere((n) => n['id'] == id, orElse: () => null);
      if (node != null) return node['name'] as String;
    }
    return id;
  }

  void _showDependencyDetails(DependencyImpact impact) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(impact.causeNodeName, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  const Text('Scénarios concernés :', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...impact.affectedScenarioIds.map((scenarioId) {
                    // Find the capability states for this scenario
                    final children = <Widget>[];
                    for (var cap in impact.affectedCapabilityIds) {
                      String capState = 'Inconnu';
                      // We need to look up the state in the original analyses
                      final analysis = widget.analyses.firstWhere((a) => a.scenarioId == scenarioId, orElse: () => widget.analyses.first);
                      if (analysis.scenarioId == scenarioId && analysis.simulationResult != null) {
                        final s = analysis.simulationResult!.nodeStates[cap];
                        if (s != null) capState = _formatState(s);
                      }
                      children.add(Text('→ ${_getNodeName(cap)} : $capState'));
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(scenarioId),
                          ...children,
                        ],
                      ),
                    );
                  }),
                  
                  const SizedBox(height: 16),
                  const Text('Actions associées :', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (impact.relatedActions.isEmpty)
                    const Text('Aucune action spécifique n\'est encore proposée pour cette dépendance.')
                  else
                    ...impact.relatedActions.map((ra) {
                      final action = _overview.actions.firstWhere((a) => a.id == ra.crossScenarioActionId);
                      final caps = ra.affectedCapabilityIds.map((c) => _getNodeName(c)).join(', ');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(action.title),
                            Text('→ agit sur $caps'),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _applyAction(action);
                              },
                              child: const Text('Voir l\'action'),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _applyAction(CrossScenarioAction action) async {
    final scenarioId = action.scenarioIds.isNotEmpty ? action.scenarioIds.first : 'global';
    final reason = action.reasonsByScenario[scenarioId] ?? '';
    
    final item = ActionPlanItem(
      id: action.id,
      title: action.title,
      description: '',
      reason: reason,
      type: action.type,
      priority: action.highestPriority,
      capabilityIds: action.capabilityIds,
      causeNodeIds: action.causeNodeIds,
      targetAssetId: action.targetAssetId,
      targetResourceId: action.targetResourceId,
    );

    final tempSession = ResilienceSession(
      knowledgeJson: appKnowledgeBase,
      scenarioId: scenarioId,
      initialConfig: widget.config.clone(),
      initialCompletedActionIds: List.from(widget.completedActionIds),
      repository: widget.repository,
      isRestored: false,
    );

    // Depending on the target, we apply the right update.
    // Since this is MVP and we just want a physical action applied,
    // we assume asset update if targetAssetId != null, else action completed.
    final HouseholdUpdate update;
    if (item.targetAssetId != null) {
      update = ActionUpdateResolver.resolveAssetUpdate(item, true);
    } else {
      update = ActionUpdateResolver.resolveActionCompleted(item);
    }
    
    final result = tempSession.recalculate(update);
    
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProgressionScreen(result: result),
        ),
      );
      if (!mounted) return; Navigator.pop(context, true); 
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Synthèse de résilience'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vue globale du foyer', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 24),
                  
                  if (_overview.recurringIssues.isEmpty && _overview.dependencyImpacts.isEmpty && _overview.actions.isEmpty && _overview.uncertainties.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.shield_outlined, size: 48, color: theme.colorScheme.primary),
                          const SizedBox(height: 16),
                          const Text("Aucune fragilité critique croisée n'a été détectée. Votre foyer présente une excellente résilience globale.", textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  
                  if (_overview.recurringIssues.isNotEmpty) ...[
                    Text('Fragilités récurrentes', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ..._overview.recurringIssues.map((issue) => Card(
                      child: ListTile(
                        title: Text(issue.capabilityName),
                        subtitle: Text('Vulnérable dans ${issue.failedScenarioIds.length + issue.degradedScenarioIds.length} scénario(s)'),
                        trailing: const Text('Voir'),
                        onTap: () => _showCapabilityDetails(issue),
                      ),
                    )),
                    const SizedBox(height: 24),
                  ],

                  if (_overview.dependencyImpacts.isNotEmpty) ...[
                    Text('Points de dépendance du foyer', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ..._overview.dependencyImpacts.map((dep) => DependencyImpactCard(
                      impact: dep,
                      onDetailTap: () => _showDependencyDetails(dep),
                      getCapabilityName: _getNodeName,
                      overview: _overview,
                    )),
                    const SizedBox(height: 24),
                  ],

                  if (_overview.actions.isNotEmpty) ...[
                    Text('Actions utiles dans plusieurs scénarios', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ..._overview.actions.map((action) => Card(
                      child: ListTile(
                        title: Text(action.title),
                        subtitle: Text('Concerne ${action.scenarioIds.length} scénario(s)'),
                        trailing: const Text('Voir l\'action'),
                        onTap: () => _showActionDetails(action),
                      ),
                    )),
                    const SizedBox(height: 24),
                  ],

                  if (_overview.uncertainties.isNotEmpty) ...[
                    Text('Informations à vérifier', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ..._overview.uncertainties.map((unc) => Card(
                      child: ListTile(
                        title: Text(unc.nodeName),
                        subtitle: Text('Dans ${unc.scenarioIds.length} scénario(s)'),
                      ),
                    )),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
