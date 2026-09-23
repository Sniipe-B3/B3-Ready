import 'package:flutter/material.dart';
import 'package:b3_engine/b3_engine.dart';
import '../models/action_plan.dart';
import '../../../app/theme/theme.dart';
import '../../dependency_map/screens/dependency_map_screen.dart';
import '../../progression/models/resilience_session.dart';
import '../../progression/screens/progression_screen.dart';
import '../../progression/utils/action_update_resolver.dart';
import 'package:b3_app/data/app_knowledge_dataset.dart';
import '../services/guided_action_mapper.dart';
import './guided_action_screen.dart';

class ActionPlanScreen extends StatefulWidget {
  final ResilienceSession session;

  const ActionPlanScreen({
    Key? key,
    required this.session,
  }) : super(key: key);

  @override
  State<ActionPlanScreen> createState() => _ActionPlanScreenState();
}

class _ActionPlanScreenState extends State<ActionPlanScreen> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.session,
      builder: (context, _) {
        final plan = widget.session.actionPlan;
        if (plan == null) return const Scaffold(body: Center(child: Text("Plan indisponible")));
        final theme = Theme.of(context);

        final items = plan.items;
        final visibleItems = _showAll ? items : items.take(5).toList();
        final hasMore = items.length > 5;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mon plan d\'action'),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${items.length} action(s) prioritaire(s)',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (items.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.check_circle_outline, size: 48, color: theme.colorScheme.primary),
                              const SizedBox(height: 16),
                              const Text("Aucune action prioritaire identifiée pour ce scénario avec les informations actuelles.", textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ...visibleItems.map((item) => _buildActionCard(context, item, theme)),
                      
                      if (hasMore && !_showAll)
                        Center(
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _showAll = true;
                              });
                            },
                            child: Text('Voir toutes les actions (${items.length - 5} masquées)'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
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

    String capabilityName = item.capabilityIds.map((id) => _getCapabilityName(id)).join(', ');
    bool isCompleted = widget.session.completedActionIds.contains(item.id);

    if (isCompleted) {
      return Card(
        margin: const EdgeInsets.only(bottom: 24.0),
        color: Colors.grey.shade100,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: B3Theme.b3Green),
                  SizedBox(width: 8),
                  Text('Terminé', style: TextStyle(color: B3Theme.b3Green, fontWeight: FontWeight.bold)),
                ]
              ),
              const SizedBox(height: 16),
              Text(
                item.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.lineThrough,
                  color: Colors.grey,
                ),
              ),
            ]
          )
        )
      );
    }

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
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final mapper = GuidedActionMapper(appKnowledgeBase);
                  final details = mapper.map(item, widget.session.requestedScenarioId);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GuidedActionScreen(
                        details: details,
                        session: widget.session,
                        onUpdate: () {
                          if (item.type == RecommendationType.organize || 
                              item.type == RecommendationType.learn || 
                              item.type == RecommendationType.useExisting) {
                            _applyActionCompleted(context, item);
                          } else {
                            _showUpdateDialog(context, item);
                          }
                        },
                        onUnderstand: () {
                           if (item.capabilityIds.isNotEmpty) {
                             Navigator.push(
                               context,
                               MaterialPageRoute(
                                 builder: (_) => DependencyMapScreen(
                                   capabilityId: item.capabilityIds.first,
                                   config: widget.session.config,
                                   result: widget.session.simulationResult!,
                                   scenario: widget.session.scenario!,
                                   graph: widget.session.graph!,
                                 ),
                               ),
                             );
                           }
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Voir comment faire'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateDialog(BuildContext context, ActionPlanItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Qu\'avez-vous constaté ou réalisé ?', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              if (item.targetResourceId != null) ...[
                ListTile(
                  title: const Text('Je n\'en ai pas / Ce n\'est pas disponible'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _applyUpdate(context, item, false, null, false);
                  },
                ),
                ListTile(
                  title: const Text('Moins d\'une journée (< 24h)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _applyUpdate(context, item, true, const Duration(hours: 12), false);
                  },
                ),
                ListTile(
                  title: const Text('Environ 1 à 2 jours (48h)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _applyUpdate(context, item, true, const Duration(hours: 48), false);
                  },
                ),
                ListTile(
                  title: const Text('Plusieurs jours (> 72h)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _applyUpdate(context, item, true, const Duration(hours: 72), false);
                  },
                ),
                if (item.type == RecommendationType.verify)
                  ListTile(
                    title: const Text('Je ne sais toujours pas'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _applyUpdate(context, item, null, null, true);
                    },
                  ),
              ] else if (item.targetAssetId != null) ...[
                ListTile(
                  title: const Text('J\'ai mis cette solution en place'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _applyAssetUpdate(context, item, true);
                  },
                ),
                if (item.type == RecommendationType.verify)
                  ListTile(
                    title: const Text('Je ne l\'ai pas'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _applyAssetUpdate(context, item, false);
                    },
                  ),
              ] else ...[
                ListTile(
                  title: const Text('J\'ai terminé cette action'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _applyActionCompleted(context, item);
                  },
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _applyUpdate(BuildContext context, ActionPlanItem item, bool? isOwned, Duration? duration, bool isUnknown) {
    final update = ActionUpdateResolver.resolveResourceUpdate(item, isOwned, duration, isUnknown);
    final result = widget.session.recalculate(update);
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProgressionScreen(result: result)));
  }

  void _applyAssetUpdate(BuildContext context, ActionPlanItem item, bool isOwned) {
    final update = ActionUpdateResolver.resolveAssetUpdate(item, isOwned);
    final result = widget.session.recalculate(update);
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProgressionScreen(result: result)));
  }

  void _applyActionCompleted(BuildContext context, ActionPlanItem item) {
    final update = ActionUpdateResolver.resolveActionCompleted(item);
    final result = widget.session.recalculate(update);
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProgressionScreen(result: result)));
  }

  String _getCapabilityName(String capabilityId) {
    try {
      final node = widget.session.graph?.firstWhere((n) => n.id == capabilityId);
      if (node != null) return node.name;
    } catch (_) {}
    return capabilityId;
  }
}
