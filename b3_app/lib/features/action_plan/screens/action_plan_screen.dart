import 'package:flutter/material.dart';
import 'package:b3_engine/b3_engine.dart';
import '../models/action_plan.dart';
import '../../../app/theme/theme.dart';
import '../../dependency_map/screens/dependency_map_screen.dart';
import '../../progression/models/resilience_session.dart';
import '../../progression/screens/progression_screen.dart';
import '../../progression/models/household_update.dart';

class ActionPlanScreen extends StatelessWidget {
  final ResilienceSession session;

  const ActionPlanScreen({
    Key? key,
    required this.session,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        final plan = session.actionPlan;
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
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _showUpdateDialog(context, item),
                child: const Text('Mettre à jour ma situation'),
              ),
            ),
            if (item.capabilityIds.length == 1)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DependencyMapScreen(
                            capabilityId: item.capabilityIds.first,
                            config: session.config,
                            result: session.simulationResult,
                            scenario: session.scenario,
                            graph: session.graph,
                          ),
                        ),
                      );
                    },
                    child: const Text('Comprendre pourquoi'),
                  ),
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
              Text('Qu\'avez-vous constaté ?', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              if (item.type == RecommendationType.verify || item.type == RecommendationType.organize || item.type == RecommendationType.acquire) ...[
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
              ],
              if (item.type == RecommendationType.createAlternative || item.type == RecommendationType.invest) ...[
                ListTile(
                  title: const Text('J\'ai mis cette solution en place'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _applyAssetUpdate(context, item, true);
                  },
                ),
              ],
              if (item.type == RecommendationType.verify) ...[
                ListTile(
                  title: const Text('Je ne sais toujours pas'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _applyUpdate(context, item, null, null, true);
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
    if (item.targetResourceId != null) {
      final resId = item.targetResourceId!;
      final result = session.recalculate(ResourceUpdate(
        resourceId: resId,
        isOwned: isOwned,
        duration: duration,
        isUnknown: isUnknown,
      ));
      
      Navigator.push(context, MaterialPageRoute(builder: (_) => ProgressionScreen(result: result)));
    } else {
      final result = session.recalculate(ActionCompletedUpdate(actionId: item.id));
      Navigator.push(context, MaterialPageRoute(builder: (_) => ProgressionScreen(result: result)));
    }
  }

  void _applyAssetUpdate(BuildContext context, ActionPlanItem item, bool isOwned) {
    if (item.targetAssetId != null) {
      final assetId = item.targetAssetId!;
      final result = session.recalculate(AssetOwnershipUpdate(assetId: assetId, isOwned: isOwned));
      Navigator.push(context, MaterialPageRoute(builder: (_) => ProgressionScreen(result: result)));
    }
  }

  String _getCapabilityName(String capabilityId) {
    if (capabilityId == 'cuisiner') return 'Cuisiner';
    if (capabilityId == 'chauffer') return 'Se chauffer';
    if (capabilityId == 'eclairage') return 'S\'éclairer';
    return capabilityId;
  }
}
