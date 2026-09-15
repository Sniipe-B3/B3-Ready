import 'package:flutter/material.dart';
import '../../diagnostic/screens/diagnostic_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('B3 Ready', style: theme.textTheme.headlineLarge),
              const SizedBox(height: 48),
              Text(
                'Moins dépendant.\nPlus préparé.\nPlus serein.',
                style: theme.textTheme.headlineMedium?.copyWith(
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Identifiez ce dont votre foyer dépend, découvrez vos vulnérabilités et améliorez progressivement votre capacité à faire face aux perturbations.",
                style: theme.textTheme.bodyLarge,
              ),
              const Spacer(),
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
                  "Quelques minutes pour commencer.",
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
