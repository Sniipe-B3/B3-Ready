import '../../../data/app_knowledge_dataset.dart';
import 'package:flutter/material.dart';
import '../../diagnostic/screens/diagnostic_screen.dart';
import '../../results/screens/results_screen.dart';
import '../../progression/models/resilience_session.dart';
import '../../../data/household_repository.dart';
import '../../../data/household_snapshot.dart';
import '../../scenarios/screens/overview_screen.dart';

class HomeScreen extends StatefulWidget {
  final HouseholdRepository? repository;

  const HomeScreen({super.key, this.repository});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HouseholdSnapshot? _snapshot;
  bool _isLoading = true;
  late final HouseholdRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SharedPrefsHouseholdRepository();
    _loadSnapshot();
  }

  Future<void> _loadSnapshot() async {
    final snapshot = await _repository.load();
    if (mounted) {
      setState(() {
        _snapshot = snapshot;
        _isLoading = false;
      });
    }
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Réinitialiser mon foyer"),
        content: const Text("Toutes vos données locales seront supprimées. Confirmer ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Réinitialiser"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _repository.clear();
      _loadSnapshot();
    }
  }



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

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
                    
                    if (_snapshot != null) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            final session = ResilienceSession(
                              knowledgeJson: appKnowledgeBase,
                              scenarioId: _snapshot!.scenarioId,
                              initialConfig: _snapshot!.config,
                              initialCompletedActionIds: _snapshot!.completedActionIds,
                              repository: _repository,
                              isRestored: true,
                            );
                            if (!mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ResultsScreen(session: session)),
                            );
                          },
                          child: const Text(
                            'Reprendre mon foyer',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OverviewScreen(
                                  config: _snapshot!.config,
                                  completedActionIds: _snapshot!.completedActionIds,
                                  repository: _repository,
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            'Résilience par scénario',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: _reset,
                          child: const Text("Réinitialiser mon foyer", style: TextStyle(color: Colors.red)),
                        ),
                      ),
                    ] else ...[
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
                    ],
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        "Vos données sont enregistrées uniquement sur cet appareil.",
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
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
