import 'package:flutter/material.dart';
import 'package:b3_app/app/theme/theme.dart';
import 'package:b3_app/features/action_plan/models/action_plan.dart';
import 'package:b3_app/features/action_plan/models/guided_action_details.dart';
import 'package:b3_app/features/progression/models/resilience_session.dart';

class GuidedActionScreen extends StatelessWidget {
  final GuidedActionDetails details;
  final ResilienceSession session;
  final VoidCallback onUpdate;
  final VoidCallback onUnderstand;

  const GuidedActionScreen({
    Key? key,
    required this.details,
    required this.session,
    required this.onUpdate,
    required this.onUnderstand,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = session.completedActionIds.contains(details.item.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Action recommandée'),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(details.item.priority).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getPriorityText(details.item.priority).toUpperCase(),
                      style: TextStyle(
                        color: _getPriorityColor(details.item.priority),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    details.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSection(theme, 'Pourquoi cette action est proposée', details.why),
                  const SizedBox(height: 24),
                  if (details.observed.isNotEmpty) ...[
                    _buildSection(theme, 'Ce que B3 a observé', details.observed),
                    const SizedBox(height: 24),
                  ],
                  _buildSection(theme, 'Ce que vous pouvez faire', details.todo),
                  const SizedBox(height: 48),
                  
                  if (isCompleted)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: B3Theme.b3Green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: B3Theme.b3Green),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Vous avez déjà marqué cette action comme terminée.',
                              style: theme.textTheme.bodyMedium?.copyWith(color: B3Theme.b3Green),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onUpdate();
                        },
                        child: Text(details.ctaLabel),
                      ),
                    ),
                  
                  if (details.item.capabilityIds.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: onUnderstand,
                          child: const Text('Comprendre pourquoi (Voir la dépendance)'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
      ],
    );
  }

  Color _getPriorityColor(ActionPriority p) {
    switch (p) {
      case ActionPriority.essential: return B3Theme.b3Red;
      case ActionPriority.important: return B3Theme.b3Orange;
      case ActionPriority.toVerify: return B3Theme.b3Blue;
      case ActionPriority.improvement: return B3Theme.b3Green;
    }
  }
  
  String _getPriorityText(ActionPriority p) {
    switch (p) {
      case ActionPriority.essential: return 'ESSENTIEL';
      case ActionPriority.important: return 'IMPORTANT';
      case ActionPriority.toVerify: return 'À VÉRIFIER';
      case ActionPriority.improvement: return 'AMÉLIORATION';
    }
  }
}
