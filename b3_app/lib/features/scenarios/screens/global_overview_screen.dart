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
      Navigator.pop(context, true); 
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vue globale du foyer', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 24),
              
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

              if (_overview.commonDependencies.isNotEmpty) ...[
                Text('Dépendances communes', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                ..._overview.commonDependencies.map((dep) => Card(
                  child: ListTile(
                    title: Text(dep.causeNodeName),
                    subtitle: Text('Impacte actuellement :\n${dep.capabilityIds.map((c) => '• $c').join('\n')}'),
                  ),
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
    );
  }
}
