import 'package:flutter/material.dart';
import '../../diagnostic/screens/diagnostic_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Widget _buildFeatureRow(BuildContext context, IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
                const SizedBox(height: 4),
                Text(desc, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('B3 Ready', style: theme.textTheme.headlineLarge),
                    const SizedBox(height: 32),
                    Text(
                      'Moins dépendant.\nPlus préparé.\nPlus serein.',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        height: 1.3,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Découvrez de quoi votre foyer dépend réellement, ce qui pourrait vous manquer en cas de perturbation et quelles améliorations auraient le plus d'impact.",
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 48),
                    _buildFeatureRow(context, Icons.analytics_outlined, "Analyser", "Comprendre les dépendances de votre foyer."),
                    _buildFeatureRow(context, Icons.search_outlined, "Identifier", "Repérer les points vulnérables."),
                    _buildFeatureRow(context, Icons.lightbulb_outline, "Agir", "Améliorer progressivement votre autonomie."),
                    const Spacer(),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const DiagnosticScreen()),
                          );
                        },
                        child: const Text(
                          'Commencer mon diagnostic',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        "Quelques minutes pour découvrir vos premières vulnérabilités.",
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
