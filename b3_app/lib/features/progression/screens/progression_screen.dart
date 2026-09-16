import 'package:flutter/material.dart';
import 'package:b3_engine/b3_engine.dart';
import '../models/progression_result.dart';
import '../../../app/theme/theme.dart';

class ProgressionScreen extends StatelessWidget {
  final ProgressionResult result;

  const ProgressionScreen({Key? key, required this.result}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse mise à jour'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Votre situation est maintenant mieux connue.',
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
              change.capabilityName.toUpperCase(),
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
                      Text(_getStateName(change.beforeState), style: TextStyle(fontWeight: FontWeight.bold, color: _getStateColor(change.beforeState))),
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
                      Text(_getStateName(change.afterState), style: TextStyle(fontWeight: FontWeight.bold, color: _getStateColor(change.afterState))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (change.hasImproved)
              const Text('Votre résilience s\'est améliorée !', style: TextStyle(color: B3Theme.b3Green, fontWeight: FontWeight.bold))
            else if (change.hasBetterKnowledge)
              const Text('La vulnérabilité est désormais confirmée.', style: TextStyle(color: B3Theme.b3Orange, fontWeight: FontWeight.bold))
          ],
        ),
      ),
    );
  }

  String _getStateName(B3State state) {
    switch (state) {
      case B3State.maintained: return 'Disponible';
      case B3State.degraded: return 'Partiellement (réserve limitée)';
      case B3State.failed: return 'Indisponible';
      case B3State.unknown: return 'Situation inconnue';
      case B3State.notAssessed: return 'Non évalué';
    }
  }

  Color _getStateColor(B3State state) {
    switch (state) {
      case B3State.maintained: return B3Theme.b3Green;
      case B3State.degraded: return B3Theme.b3Orange;
      case B3State.failed: return B3Theme.b3Red;
      case B3State.unknown: return B3Theme.b3Blue;
      case B3State.notAssessed: return Colors.grey;
    }
  }
}
