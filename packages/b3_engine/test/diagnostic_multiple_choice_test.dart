import 'dart:convert';
import 'package:test/test.dart';
import 'package:b3_engine/src/diagnostic.dart';
import 'package:b3_engine/src/data_mapper.dart'; // pour HouseholdConfig

void main() {
  final jsonQuestions = '''
  [
    {
      "id": "q1",
      "text": "Question single",
      "type": "single_choice",
      "options": [
        {"id": "optA", "text": "A", "facts": [{"type": "add_asset", "value": "assetA"}]},
        {"id": "optB", "text": "B", "facts": [{"type": "add_asset", "value": "assetB"}]}
      ]
    },
    {
      "id": "q2",
      "text": "Question multiple",
      "type": "multiple_choice",
      "options": [
        {"id": "optC", "text": "C", "facts": [{"type": "add_asset", "value": "assetC"}]},
        {"id": "optD", "text": "D", "facts": [{"type": "add_asset", "value": "assetD"}]}
      ]
    },
    {
      "id": "q3",
      "text": "Question dépendante",
      "condition": {"dependsOn": "q2", "hasAnswer": "optC"},
      "options": [
        {"id": "optE", "text": "E", "facts": []}
      ]
    }
  ]
  ''';

  late List<DiagnosticQuestion> questions;
  late DiagnosticEngine engine;

  setUp(() {
    final parsed = jsonDecode(jsonQuestions) as List;
    questions = parsed.map((q) => DiagnosticQuestion.fromJson(q)).toList();
    engine = DiagnosticEngine(questions);
  });

  test('Test A: Question single → une réponse', () {
    final state = DiagnosticState();
    state.answerQuestion('q1', 'optA');
    expect(state.answers['q1'], equals(['optA']));
  });

  test('Test B: Question multiple → plusieurs réponses', () {
    final state = DiagnosticState();
    state.answerMultiple('q2', ['optC', 'optD']);
    expect(state.answers['q2'], equals(['optC', 'optD']));
  });

  test('Test C: Question multiple → application correcte de plusieurs FactRules', () {
    final state = DiagnosticState();
    state.answerMultiple('q2', ['optC', 'optD']);
    
    final config = state.toHouseholdConfig(questions);
    expect(config.ownedAssets.contains('assetC'), isTrue);
    expect(config.ownedAssets.contains('assetD'), isTrue);
  });

  test('Test D: Question multiple → condition dépendante satisfaite lorsqu une réponse pertinente est présente', () {
    final state = DiagnosticState();
    state.answerQuestion('q1', 'optA'); // répondre à q1
    state.answerMultiple('q2', ['optC', 'optD']); // répondre à q2 avec optC (qui déclenche q3)
    
    final nextQ = engine.getNextQuestion(state);
    expect(nextQ?.id, equals('q3'));
  });

  test('Test E: Question multiple → condition non satisfaite lorsqu aucune réponse pertinente n est présente', () {
    final state = DiagnosticState();
    state.answerQuestion('q1', 'optA'); // répondre à q1
    state.answerMultiple('q2', ['optD']); // ne contient pas optC
    
    final nextQ = engine.getNextQuestion(state);
    expect(nextQ, isNull); // Plus de questions
  });

  test('Test F: Question multiple → aucune réponse sélectionnée (liste vide)', () {
    final state = DiagnosticState();
    state.answerMultiple('q2', []); 
    
    expect(state.answers['q2'], isEmpty);
    final config = state.toHouseholdConfig(questions);
    expect(config.ownedAssets, isEmpty);
  });

  test('Test G: Impossible de sélectionner deux fois la même option (le Set dans toHouseholdConfig protège les doublons)', () {
    final state = DiagnosticState();
    state.answerMultiple('q2', ['optC', 'optC']); 
    
    final config = state.toHouseholdConfig(questions);
    expect(config.ownedAssets.where((e) => e == 'assetC').length, equals(1));
  });

  test('Test H & J: Les anciens tests / format JSON continuent de fonctionner', () {
    final state = DiagnosticState();
    state.fromJson({'answers': {'q1': 'optA'}}); // Ancien format String
    
    expect(state.answers['q1'], equals(['optA']));
  });

  test('Test I: toHouseholdConfig ne crée aucun fait non présent', () {
    final state = DiagnosticState();
    state.answerMultiple('q2', ['optC']); 
    
    final config = state.toHouseholdConfig(questions);
    expect(config.ownedAssets.contains('assetD'), isFalse); // D n'est pas sélectionné
  });
}
