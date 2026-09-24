import 'package:flutter/material.dart';
import 'package:b3_engine/b3_engine.dart';
import '../roadmap_builder.dart';
import '../../progression/models/resilience_session.dart';
import '../services/guided_action_mapper.dart';
import 'guided_action_screen.dart';
import '../../progression/screens/progression_screen.dart';
import '../../progression/models/household_update.dart';
import '../../progression/utils/action_update_resolver.dart';
import '../../progression/models/progression_result.dart';
import '../../../data/household_repository.dart';
import '../../../data/app_knowledge_dataset.dart';
import '../../scenarios/models/scenario_analysis.dart';
import '../models/action_plan.dart';

class PreparednessRoadmapScreen extends StatefulWidget {
  final PreparednessRoadmap roadmap;
  final HouseholdConfig config;
  final HouseholdRepository repository;
  final List<ScenarioAnalysis> analyses;
  final List<String> completedActionIds;

  const PreparednessRoadmapScreen({
    Key? key,
    required this.roadmap,
    required this.config,
    required this.repository,
    required this.analyses,
    required this.completedActionIds,
  }) : super(key: key);

  @override
  State<PreparednessRoadmapScreen> createState() => _PreparednessRoadmapScreenState();
}

class _PreparednessRoadmapScreenState extends State<PreparednessRoadmapScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feuille de route'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStageSection(context, 'MAINTENANT', widget.roadmap.now, theme.colorScheme.primary),
              const SizedBox(height: 24),
              _buildStageSection(context, 'ENSUITE', widget.roadmap.next, Colors.orange),
              const SizedBox(height: 24),
              _buildStageSection(context, 'PLUS TARD', widget.roadmap.later, Colors.grey[700]!),
              if ([].isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildStageSection(context, 'TERMINÉES', [], Colors.green),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageSection(BuildContext context, String title, List<RoadmapStep> steps, Color titleColor) {
    if (steps.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium?.copyWith(color: titleColor, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...steps.map((step) {
          final reason = step.item.priorityReasons.isNotEmpty ? step.item.priorityReasons.first.description : '';
          
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: null,
              title: Text(
                step.item.title,
                style: const TextStyle(
                  
                  
                ),
              ),
              subtitle: reason.isNotEmpty ? Text(reason) : null,
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _openGuidedAction(step.item),
            ),
          );
        }).toList(),
      ],
    );
  }

  Future<void> _openGuidedAction(ActionPlanItem item) async {
        final primaryScenarioId = item.primaryScenarioId;
    if (primaryScenarioId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Action globale ne nécessitant pas de mode guidé.")));
      return;
    }
    final session = ResilienceSession(
      knowledgeJson: appKnowledgeBase,
      scenarioId: primaryScenarioId,
      initialConfig: widget.config.clone(),
      initialCompletedActionIds: widget.completedActionIds,
      repository: widget.repository,
    );

    await session.waitForPendingSave();
    final mapper = GuidedActionMapper(appKnowledgeBase);
    final guidedDetails = mapper.map(item, primaryScenarioId);
    
    if (!mounted) return;
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => GuidedActionScreen(
          details: guidedDetails,
          session: session,
          onUnderstand: () {},
          onUpdate: () {
            final HouseholdUpdate update;
            if (item.targetAssetId != null) {
              update = ActionUpdateResolver.resolveAssetUpdate(item, true);
            } else if (item.targetResourceId != null) {
              update = ActionUpdateResolver.resolveResourceUpdate(item, true, const Duration(hours: 24), false);
            } else {
              update = ActionUpdateResolver.resolveActionCompleted(item);
            }
            final result = session.recalculate(update);
            
            final resultWithIds = ProgressionResult(
               beforeConfig: result.beforeConfig,
               afterConfig: result.afterConfig,
               beforeResult: result.beforeResult,
               afterResult: result.afterResult,
               beforePlan: session.actionPlan!,
               afterPlan: session.actionPlan!,
               changedCapabilities: result.changedCapabilities,
               updateNature: result.updateNature,
               hasStructuralChange: result.hasStructuralChange,
               beforeCompletedActionIds: widget.completedActionIds,
               afterCompletedActionIds: session.completedActionIds,
            );
            
            if (!mounted) return;
            Navigator.pushReplacement(
              ctx,
              MaterialPageRoute(
                builder: (_) => ProgressionScreen(
                  result: resultWithIds,
                ),
              ),
            ).then((_) {
               if (!mounted) return;
               Navigator.of(context).popUntil((route) => route.settings.name == '/GlobalOverview' || route.isFirst);
            });
          },
        ),
      ),
    );
  }
}
