import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:b3_engine/b3_engine.dart';
import '../../results/screens/results_screen.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  late final DiagnosticEngine _engine;
  late final List<DiagnosticQuestion> _allQuestions;
  final DiagnosticState _state = DiagnosticState();

  DiagnosticQuestion? _currentQuestion;
  int _questionCount = 1;

  @override
  void initState() {
    super.initState();
    // Charger les questions depuis le dataset de l'engine
    final questionsJson = jsonDecode(b3DiagnosticQuestionsJson) as List;
    _allQuestions =
        questionsJson.map((q) => DiagnosticQuestion.fromJson(q)).toList();
    _engine = DiagnosticEngine(_allQuestions);

    _currentQuestion = _engine.getNextQuestion(_state);
  }

  void _onOptionSelected(QuestionOption option) {
    if (_currentQuestion == null) return;

    _state.answerQuestion(_currentQuestion!.id, option.id);

    final nextQuestion = _engine.getNextQuestion(_state);

    if (nextQuestion == null) {
      // Fin du diagnostic
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultsScreen(
            diagnosticState: _state,
            questions: _allQuestions,
          ),
        ),
      );
    } else {
      setState(() {
        _currentQuestion = nextQuestion;
        _questionCount++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_currentQuestion == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Question $_questionCount',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _currentQuestion!.text,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 48),
              Expanded(
                child: ListView.separated(
                  itemCount: _currentQuestion!.options.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final option = _currentQuestion!.options[index];
                    return SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _onOptionSelected(option),
                        child: Text(
                          option.text,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
