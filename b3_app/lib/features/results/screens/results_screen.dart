import '../../../data/household_repository.dart';
import 'package:flutter/material.dart';
import 'package:b3_engine/b3_engine.dart';
import '../../../data/app_knowledge_dataset.dart';
import '../../action_plan/screens/action_plan_screen.dart';
import 'vulnerability_detail_screen.dart';
import '../../../app/theme/theme.dart';
import '../../progression/models/resilience_session.dart';

class ResultsScreen extends StatefulWidget {
  final DiagnosticState? diagnosticState;
  final List<DiagnosticQuestion>? questions;
  final ResilienceSession? session;

  const ResultsScreen({
    Key? key,
    this.diagnosticState,
    this.questions,
    this.session,
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
    if (widget.session != null) {
      _session = widget.session!;
    } else {
      final config = widget.diagnosticState!.toHouseholdConfig(widget.questions!);
      _session = ResilienceSession(
        knowledgeJson: appKnowledgeBase,
        scenarioId: 'panne_elec',
        initialConfig: config,
        repository: SharedPrefsHouseholdRepository(),
        isRestored: false,
      );
    }


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
        final vulns = _session.simulationResult.vulnerabilities.where((v) => v.state == B3State.failed).toList();
        final degraded = _session.simulationResult.vulnerabilities.where((v) => v.state == B3State.degraded).toList();
        
        final totalPoints = vulns.length + degraded.length;
        final String vigilanceText = totalPoints > 1 
            ? "$totalPoints points de vigilance identifiés." 
            : "1 point de vigilance identifié.";

        return Scaffold(
          appBar: AppBar(
            title: const Text('Bilan de résilience'),
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Votre analyse', style: theme.textTheme.headlineLarge),
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
                  if (totalPoints > 0)
                    Text(
                      vigilanceText,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: vulns.isNotEmpty ? B3Theme.b3Red : B3Theme.b3Orange,
                      ),
                    )
                  else
                    Text(
                      "Votre foyer semble bien préparé pour ce scénario.",
                      style: theme.textTheme.titleLarge?.copyWith(color: B3Theme.b3Green),
                    ),
                  const SizedBox(height: 32),
                  
                  ...vulns.map((v) => _buildVulnCard(v, theme, B3Theme.b3Red, "Vulnérable en cas de panne électrique")),
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
      },
    );
  }

  String _getEmoji(String capabilityId) {
    if (capabilityId == 'cuisiner') return '🍳';
    if (capabilityId == 'chauffer') return '🌡️';
    if (capabilityId == 'eclairage') return '💡';
    return '🔧';
  }

  String _getCapabilityName(String capabilityId) {
    if (capabilityId == 'cuisiner') return 'CUISINER';
    if (capabilityId == 'chauffer') return 'SE CHAUFFER';
    if (capabilityId == 'eclairage') return 'S\'ÉCLAIRER';
    return capabilityId.toUpperCase();
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
                    _getCapabilityName(capId),
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
                  final recs = _session.recommendations.where((r) => r.capabilityId == capId).toList();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VulnerabilityDetailScreen(
                        vulnerability: v,
                        config: _session.config,
                        result: _session.simulationResult,
                        scenario: _session.scenario,
                        graph: _session.graph,
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
