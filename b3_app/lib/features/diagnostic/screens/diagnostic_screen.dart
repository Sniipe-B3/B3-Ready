import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:b3_engine/b3_engine.dart';
import '../engine/adaptive_diagnostic_engine.dart';
import '../../scenarios/screens/overview_screen.dart';
import '../../../data/app_diagnostic_dataset.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  late final AdaptiveDiagnosticEngine _engine;
  late final List<DiagnosticQuestion> _allQuestions;
  
  DiagnosticState _currentState = DiagnosticState();
  final List<DiagnosticState> _history = [];
  
  DiagnosticQuestion? _currentQuestion;
  int _questionCount = 1;

  // Local state for multiple choice
  final Set<String> _selectedMultipleOptions = {};

  @override
  void initState() {
    super.initState();
    final questionsJson = jsonDecode(appDiagnosticQuestionsJson) as List;
    _allQuestions =
        questionsJson.map((q) => DiagnosticQuestion.fromJson(q)).toList();
    _engine = AdaptiveDiagnosticEngine(_allQuestions);

    _currentQuestion = _engine.getNextQuestion(_currentState);
  }

  void _goBack() {
    if (_history.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _currentState = _history.removeLast();
      _currentQuestion = _engine.getNextQuestion(_currentState);
      _questionCount--;
      _selectedMultipleOptions.clear();
      // Restore selected options if they exist in state for the current question?
      // Actually, if we go back, the current question hasn't been answered in _currentState.
    });
  }

  void _onSingleOptionSelected(QuestionOption option) {
    if (_currentQuestion == null) return;
    
    // Save history
    final clonedState = DiagnosticState();
    clonedState.fromJson(_currentState.toJson());
    _history.add(clonedState);

    _currentState.answerQuestion(_currentQuestion!.id, option.id);
    _advance();
  }

  void _onMultipleOptionToggled(String optionId) {
    setState(() {
      if (_selectedMultipleOptions.contains(optionId)) {
        _selectedMultipleOptions.remove(optionId);
      } else {
        _selectedMultipleOptions.add(optionId);
      }
    });
  }

  void _submitMultipleChoice() {
    if (_currentQuestion == null) return;
    
    // Save history
    final clonedState = DiagnosticState();
    clonedState.fromJson(_currentState.toJson());
    _history.add(clonedState);

    _currentState.answerMultiple(_currentQuestion!.id, _selectedMultipleOptions.toList());
    _selectedMultipleOptions.clear();
    _advance();
  }

  void _advance() {
    final nextQuestion = _engine.getNextQuestion(_currentState);

    if (nextQuestion == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OverviewScreen(
            config: _currentState.toHouseholdConfig(_allQuestions),
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

    final isMultiple = _currentQuestion!.type == QuestionType.multipleChoice;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        title: Text('Analyse en cours (Étape $_questionCount)', style: const TextStyle(fontSize: 16)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentQuestion!.text,
                      style: theme.textTheme.headlineMedium?.copyWith(fontSize: 24),
                    ),
                    if (isMultiple) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Sélectionnez toutes les options applicables',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    ..._currentQuestion!.options.map((option) {
                      if (isMultiple) {
                        final isSelected = _selectedMultipleOptions.contains(option.id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: InkWell(
                            onTap: () => _onMultipleOptionToggled(option.id),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected ? theme.colorScheme.primary : const Color(0xFFE5E7EB),
                                  width: isSelected ? 2 : 1.5,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.05) : Colors.white,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                    color: isSelected ? theme.colorScheme.primary : const Color(0xFF9CA3AF),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      option.text,
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontSize: 16,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        color: isSelected ? theme.colorScheme.primary : const Color(0xFF374151),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      } else {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _onSingleOptionSelected(option),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                                alignment: Alignment.centerLeft,
                                backgroundColor: Colors.white,
                              ),
                              child: Text(
                                option.text,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF374151),
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                    }).toList(),
                  ],
                ),
              ),
            ),
            if (isMultiple)
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      offset: const Offset(0, -4),
                      blurRadius: 8,
                    )
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _selectedMultipleOptions.isEmpty 
                        ? () => _submitMultipleChoice() // Allow empty if they really want, but maybe we should disable? The prompt says "Rien de tout cela" is an option. If it's empty, we let them proceed.
                        : _submitMultipleChoice,
                    child: const Text('Continuer'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
