import '../../../data/household_repository.dart';
import 'package:flutter/material.dart';
import 'package:b3_engine/b3_engine.dart';

import '../../action_plan/screens/action_plan_screen.dart';
import 'vulnerability_detail_screen.dart';
import '../../../app/theme/theme.dart';
import '../../progression/models/resilience_session.dart';
import '../../scenarios/screens/overview_screen.dart';

class ResultsScreen extends StatefulWidget {
  final ResilienceSession session;

  const ResultsScreen({
    Key? key,
    required this.session,
  }) : super(key: key);

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _isLoading = true;
  late ResilienceSession _session;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    _session = widget.session;

    // Simulation artificielle d'un temps d'analyse
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                "Analyse des dépendances...",
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _session,
      builder: (context, _) {
        final theme = Theme.of(context);
        
        if (_session.scenarioUnavailable) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Bilan de résilience'),
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Votre analyse', style: theme.textTheme.headlineLarge),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Text(
                        "Aucun scénario compatible n'est actuellement disponible.\nVotre foyer a été conservé.",
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red.shade900),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                        child: const Text('Retour à l\'accueil'),
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        }

        final vulns = _session.simulationResult!.vulnerabilities.where((v) => v.state == B3State.failed).toList();
        final degraded = _session.simulationResult!.vulnerabilities.where((v) => v.state == B3State.degraded).toList();
        
        
        


            
        final scenarioName = _session.scenario?.name ?? 'cette perturbation';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Bilan de résilience'),
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
                      Text(scenarioName, style: theme.textTheme.headlineLarge),
                      const SizedBox(height: 16),
                      if (_session.scenarioError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Text(
                            _session.scenarioError!,
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.orange.shade900),
                          ),
                        ),
                      ],
                      Text('Si la situation durait...', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<PreparednessHorizon>(
                          segments: PreparednessHorizon.values.map((h) => ButtonSegment<PreparednessHorizon>(
                            value: h,
                            label: Text(h.label),
                          )).toList(),
                          selected: {_session.horizon},
                          onSelectionChanged: (Set<PreparednessHorizon> newSelection) {
                            _session.setHorizon(newSelection.first);
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('À cet horizon :', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('• ${_session.graph!.whereType<Capability>().where((c) => _session.simulationResult!.nodeStates[c.id] == B3State.maintained).length} capacité(s) reste(nt) disponible(s)', style: theme.textTheme.bodyLarge),
                      Text('• ${_session.graph!.whereType<Capability>().where((c) => _session.simulationResult!.nodeStates[c.id] == B3State.unknown || _session.simulationResult!.nodeStates[c.id] == B3State.notAssessed).length} capacité(s) à vérifier', style: theme.textTheme.bodyLarge),
                      Text('• ${_session.graph!.whereType<Capability>().where((c) => _session.simulationResult!.nodeStates[c.id] == B3State.failed || _session.simulationResult!.nodeStates[c.id] == B3State.degraded).length} capacité(s) insuffisante(s)', style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 32),
                      
                      ...vulns.map((v) => _buildVulnCard(v, theme, B3Theme.b3Red, "Vulnérable en cas de $scenarioName")),
                      ...degraded.map((v) => _buildVulnCard(v, theme, B3Theme.b3Orange, "Partiellement vulnérable (réserve limitée)")),
                      
                      const SizedBox(height: 32),
                      Card(
                        color: B3Theme.b3Blue.withValues(alpha: 0.1),
                        margin: const EdgeInsets.only(bottom: 24.0),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mon plan d\'action',
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: B3Theme.b3Blue),
                              ),
                              const SizedBox(height: 12),
                              Text('Découvrez les actions prioritaires pour améliorer la résilience de votre foyer.', style: theme.textTheme.bodyLarge),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ActionPlanScreen(session: _session),
                                      ),
                                    );
                                  },
                                  child: const Text('Voir mon plan d\'action'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OverviewScreen(
                                  config: _session.config,
                                  completedActionIds: _session.completedActionIds,
                                  repository: SharedPrefsHouseholdRepository(),
                                ),
                              ),
                            );
                          },
                          child: const Text('Résilience par scénario'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                          child: const Text('Retour à l\'accueil'),
                        ),
                      )
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

  String _getEmoji(String capabilityId) {
    if (capabilityId == 'cuisiner') return '🍳';
    if (capabilityId == 'chauffer') return '🌡️';
    if (capabilityId == 'eclairage') return '💡';
    if (capabilityId == 'disposer_eau') return '🚰';
    if (capabilityId == 'acceder_internet') return '💻';
    if (capabilityId == 'communiquer') return '📞';
    return '🔧';
  }

  

  Widget _buildVulnCard(Vulnerability v, ThemeData theme, Color color, String subtitle) {
    final capId = v.capability.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 24.0),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_getEmoji(capId), style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    v.capability.name.toUpperCase(),
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(subtitle, style: theme.textTheme.bodyLarge?.copyWith(color: color, fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(backgroundColor: color.withValues(alpha: 0.1), foregroundColor: color),
                onPressed: () {
                  final recs = _session.recommendations!.where((r) => r.capabilityId == capId).toList();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VulnerabilityDetailScreen(
                        vulnerability: v,
                        config: _session.config,
                        result: _session.simulationResult!,
                        scenario: _session.scenario!,
                        graph: _session.graph!,
                        recommendations: recs,
                      ),
                    ),
                  );
                },
                child: const Text('Comprendre', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
