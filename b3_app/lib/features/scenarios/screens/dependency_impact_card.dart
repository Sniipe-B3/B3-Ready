import 'package:flutter/material.dart';
import '../models/dependency_impact.dart';

import '../models/global_household_overview.dart';

class DependencyImpactCard extends StatelessWidget {
  final DependencyImpact impact;
  final VoidCallback onDetailTap;
  final String Function(String) getCapabilityName;
  final GlobalHouseholdOverview overview;

  const DependencyImpactCard({
    Key? key,
    required this.impact,
    required this.onDetailTap,
    required this.getCapabilityName,
    required this.overview,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('⚡ ${impact.causeNodeName}', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            
            if (impact.affectedCapabilityIds.isNotEmpty) ...[
              Text('Concerne actuellement :', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
              ...impact.affectedCapabilityIds.map((c) => Text('• ${getCapabilityName(c)}')),
              const SizedBox(height: 12),
            ],
            
            if (impact.vulnerableCapabilityIds.isNotEmpty) ...[
              Text('Vulnérable :', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
              ...impact.vulnerableCapabilityIds.map((c) => Text('• ${getCapabilityName(c)}', style: TextStyle(color: Colors.red.shade700))),
              const SizedBox(height: 12),
            ],

            if (impact.maintainedCapabilityIds.isNotEmpty) ...[
              Text('Actuellement maintenu :', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.green.shade700)),
              ...impact.maintainedCapabilityIds.map((c) => Text('• ${getCapabilityName(c)}', style: TextStyle(color: Colors.green.shade700))),
              const SizedBox(height: 12),
            ],
            
            if (impact.relatedActions.isNotEmpty) ...[
              Text('Actions qui réduisent cette dépendance :', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
              ...impact.relatedActions.map((ra) {
                final action = overview.actions.firstWhere((a) => a.id == ra.crossScenarioActionId);
                return Text('• ${action.title}');
              }),
              const SizedBox(height: 12),
            ],

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onDetailTap,
                child: const Text('Voir le détail'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
