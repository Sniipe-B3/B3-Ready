import re

with open('b3_app/lib/features/results/screens/results_screen.dart', 'r') as f:
    content = f.read()

old_ctor = """class ResultsScreen extends StatefulWidget {
  final DiagnosticState diagnosticState;
  final List<DiagnosticQuestion> questions;

  const ResultsScreen({
    Key? key,
    required this.diagnosticState,
    required this.questions,
  }) : super(key: key);"""

new_ctor = """class ResultsScreen extends StatefulWidget {
  final DiagnosticState? diagnosticState;
  final List<DiagnosticQuestion>? questions;
  final ResilienceSession? session;

  const ResultsScreen({
    Key? key,
    this.diagnosticState,
    this.questions,
    this.session,
  }) : super(key: key);"""

content = content.replace(old_ctor, new_ctor)

with open('b3_app/lib/features/results/screens/results_screen.dart', 'w') as f:
    f.write(content)
