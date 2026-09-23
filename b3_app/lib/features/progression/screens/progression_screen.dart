import 'package:flutter/material.dart';
import 'package:b3_app/core/utils/ui_state_helper.dart';
import '../models/progression_result.dart';
import '../models/household_update.dart';
import '../../../app/theme/theme.dart';

class ProgressionScreen extends StatelessWidget {
  final ProgressionResult result;

  const ProgressionScreen({Key? key, required this.result}) : super(key: key);

  String _getHeaderText() {
    if (!result.hasStructuralChange) return 'Action marquée comme terminée.';
    if (result.updateNature == UpdateNature.observation) {
      if (result.changedCapabilities.any((c) => c.meaning == ProgressionMeaning.vulnerabilityConfirmed)) {
        return 'Analyse précisée';
      }
      return 'Situation mieux connue';
    } else {
      if (result.changedCapabilities.any((c) => c.meaning == ProgressionMeaning.resilienceImproved)) {
        return 'Amélioration enregistrée';
      }
      return 'Situation mise à jour';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse mise à jour'),
        automaticallyImplyLeading: false,
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
                    _getHeaderText(),
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  if (result.changedCapabilities.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'Cette action a bien été enregistrée. Elle ne modifie cependant pas immédiatement votre bilan de résilience.',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    )
                  else
                    ...result.changedCapabilities.map((c) => _buildChangeCard(context, c, theme)),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Voir mon nouveau plan'),
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

  Widget _buildChangeCard(BuildContext context, CapabilityChange change, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              change.capabilityName,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Avant', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(UiStateHelper.getLabel(change.beforeState), style: TextStyle(fontWeight: FontWeight.bold, color: UiStateHelper.getColor(change.beforeState))),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Après', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(UiStateHelper.getLabel(change.afterState), style: TextStyle(fontWeight: FontWeight.bold, color: UiStateHelper.getColor(change.afterState))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (change.meaning == ProgressionMeaning.resilienceImproved)
              const Text('Votre résilience s\'est améliorée !', style: TextStyle(color: B3Theme.b3Green, fontWeight: FontWeight.bold))
            else if (change.meaning == ProgressionMeaning.favorableSituationConfirmed)
              const Text('Cette capacité est maintenant confirmée disponible.', style: TextStyle(color: B3Theme.b3Green, fontWeight: FontWeight.bold))
            else if (change.meaning == ProgressionMeaning.vulnerabilityConfirmed)
              const Text('La vulnérabilité est désormais confirmée.', style: TextStyle(color: B3Theme.b3Orange, fontWeight: FontWeight.bold))
            else if (change.meaning == ProgressionMeaning.knowledgeImproved)
              const Text('Votre situation est maintenant mieux connue.', style: TextStyle(color: B3Theme.b3Blue, fontWeight: FontWeight.bold))
            else if (change.meaning == ProgressionMeaning.resilienceDegraded)
              const Text('Votre capacité est réduite.', style: TextStyle(color: B3Theme.b3Orange, fontWeight: FontWeight.bold))
          ],
        ),
      ),
    );
  }

  

  
}
