import 'package:flutter/material.dart';
import 'package:b3_engine/b3_engine.dart';
import '../../../app/theme/theme.dart';
import '../models/dependency_node.dart';
import '../view_models/dependency_map_builder.dart';
import '../../../data/app_knowledge_dataset.dart';

class DependencyMapScreen extends StatelessWidget {
  final String capabilityId;
  final HouseholdConfig config;
  final SimulationResult result;
  final Scenario scenario;
  final List<B3Node> graph;

  const DependencyMapScreen({
    Key? key,
    required this.capabilityId,
    required this.config,
    required this.result,
    required this.scenario,
    required this.graph,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final builder = DependencyMapBuilder(appKnowledgeBase, graph);
    final rootNode = builder.buildTree(capabilityId, result);
    final causePhrase = builder.getCausePhrase(rootNode);

    return Scaffold(
      backgroundColor: B3Theme.b3Surface,
      appBar: AppBar(
        title: const Text('Dépendances'),
        backgroundColor: Colors.white,
        foregroundColor: B3Theme.b3Primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SCENARIO HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: B3Theme.b3Primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: B3Theme.b3Red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      scenario.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // CAUSE SUMMARY
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: rootNode.state == B3State.failed ? B3Theme.b3Red.withValues(alpha: (0.1)) : B3Theme.b3Orange.withValues(alpha: (0.1)),
                border: Border.all(
                  color: rootNode.state == B3State.failed ? B3Theme.b3Red : B3Theme.b3Orange,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Pourquoi ?",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: rootNode.state == B3State.failed ? B3Theme.b3Red : B3Theme.b3Orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(causePhrase, style: const TextStyle(color: B3Theme.b3Primary)),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // TREE RENDERER
            _DependencyTreeWidget(node: rootNode, isRoot: true),
          ],
        ),
      ),
    );
  }
}

class _DependencyTreeWidget extends StatelessWidget {
  final DependencyNode node;
  final bool isRoot;

  const _DependencyTreeWidget({required this.node, this.isRoot = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NodeCard(node: node, isRoot: isRoot),
        if (node.children.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(left: 24), // Indentation
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: Colors.black12, width: 2), // Branch line
              ),
            ),
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: Column(
              children: node.children.map((child) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _DependencyTreeWidget(node: child),
              )).toList(),
            ),
          ),
      ],
    );
  }
}

class _NodeCard extends StatelessWidget {
  final DependencyNode node;
  final bool isRoot;

  const _NodeCard({required this.node, required this.isRoot});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getColor(node.state);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: (0.5)), width: isRoot ? 2 : 1),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _getTypeLabel(node.type).toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: B3Theme.b3Gray,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StateBadge(state: node.state),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            node.label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: B3Theme.b3Primary,
              fontSize: isRoot ? 20 : 16,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor(B3State state) {
    switch (state) {
      case B3State.maintained: return B3Theme.b3Green;
      case B3State.degraded: return B3Theme.b3Orange;
      case B3State.failed: return B3Theme.b3Red;
      case B3State.unknown: return Colors.grey.shade600;
      case B3State.notAssessed: return Colors.grey.shade400;
    }
  }

  String _getTypeLabel(MapNodeType type) {
    switch (type) {
      case MapNodeType.capability: return 'Besoin';
      case MapNodeType.asset: return 'Équipement';
      case MapNodeType.system: return 'Service extérieur';
      case MapNodeType.resource: return 'Réserve';
    }
  }
}

class _StateBadge extends StatelessWidget {
  final B3State state;

  const _StateBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final color = _getColor(state);
    final label = _getLabel(state);
    final icon = _getIcon(state);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: (0.1)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor(B3State state) {
    switch (state) {
      case B3State.maintained: return B3Theme.b3Green;
      case B3State.degraded: return B3Theme.b3Orange;
      case B3State.failed: return B3Theme.b3Red;
      case B3State.unknown: return Colors.grey.shade600;
      case B3State.notAssessed: return Colors.grey.shade400;
    }
  }

  String _getLabel(B3State state) {
    switch (state) {
      case B3State.maintained: return 'Disponible';
      case B3State.degraded: return 'Disponible (limité)';
      case B3State.failed: return 'Indisponible';
      case B3State.unknown: return 'Inconnu';
      case B3State.notAssessed: return 'Non évalué';
    }
  }

  IconData _getIcon(B3State state) {
    switch (state) {
      case B3State.maintained: return Icons.check_circle;
      case B3State.degraded: return Icons.warning_rounded;
      case B3State.failed: return Icons.cancel;
      case B3State.unknown: return Icons.help_outline;
      case B3State.notAssessed: return Icons.circle_outlined;
    }
  }
}
