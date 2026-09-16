import 'package:flutter/material.dart';
import 'package:b3_engine/b3_engine.dart';
import '../models/action_plan.dart';
import '../../../app/theme/theme.dart';
import '../../dependency_map/screens/dependency_map_screen.dart';

class ActionPlanScreen extends StatelessWidget {
  final ActionPlan plan;
  final HouseholdConfig config;
  final SimulationResult result;
  final Scenario scenario;
  final List<B3Node> graph;

  const ActionPlanScreen({
    Key? key,
    required this.plan,
    required this.config,
    required this.result,
    required this.scenario,
    required this.graph,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon plan d\'action'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${plan.items.length} actions prioritaires',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ...plan.items.map((item) => _buildActionCard(context, item, theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, ActionPlanItem item, ThemeData theme) {
    String priorityText;
    Color priorityColor;

    switch (item.priority) {
      case ActionPriority.essential:
        priorityText = 'ESSENTIEL';
        priorityColor = B3Theme.b3Red;
        break;
      case ActionPriority.important:
        priorityText = 'IMPORTANT';
        priorityColor = B3Theme.b3Orange;
        break;
      case ActionPriority.toVerify:
        priorityText = 'À VÉRIFIER';
        priorityColor = B3Theme.b3Blue;
        break;
      case ActionPriority.improvement:
        priorityText = 'AMÉLIORATION';
        priorityColor = B3Theme.b3Green;
        break;
    }

    String capabilityName = item.capabilityIds.map(_getCapabilityName).join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 24.0),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: priorityColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                priorityText,
                style: TextStyle(
                  color: priorityColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              item.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.description,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(
              item.reason,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Lié à : $capabilityName',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (item.capabilityIds.length == 1) // On affiche "Comprendre" seulement s'il y a 1 capa claire (plus simple)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DependencyMapScreen(
                          capabilityId: item.capabilityIds.first,
                          config: config,
                          result: result,
                          scenario: scenario,
                          graph: graph,
                        ),
                      ),
                    );
                  },
                  child: const Text('Comprendre pourquoi'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getCapabilityName(String capabilityId) {
    if (capabilityId == 'cuisiner') return 'Cuisiner';
    if (capabilityId == 'chauffer') return 'Se chauffer';
    if (capabilityId == 'eclairage') return 'S\'éclairer';
    return capabilityId;
  }
}

