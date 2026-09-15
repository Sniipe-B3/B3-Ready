import 'dart:convert';
import 'models.dart';
import 'data_mapper.dart';

class FactRule {
  final String type; // 'add_asset', 'add_resource_duration'
  final String value; // asset id or resource id
  final int? duration;

  FactRule({required this.type, required this.value, this.duration});
  
  factory FactRule.fromJson(Map<String, dynamic> json) {
    return FactRule(
      type: json['type'],
      value: json['value'],
      duration: json['duration'],
    );
  }
  
  Map<String, dynamic> toJson() => {
    'type': type,
    'value': value,
    if (duration != null) 'duration': duration,
  };
}

class QuestionOption {
  final String id;
  final String text;
  final List<FactRule> facts;

  QuestionOption({required this.id, required this.text, required this.facts});
  
  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    var factsList = (json['facts'] as List?)?.map((f) => FactRule.fromJson(f)).toList() ?? [];
    return QuestionOption(id: json['id'], text: json['text'], facts: factsList);
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'facts': facts.map((f) => f.toJson()).toList(),
  };
}

class QuestionCondition {
  final String dependsOnQuestionId;
  final String hasAnswerId;

  QuestionCondition({required this.dependsOnQuestionId, required this.hasAnswerId});
  
  factory QuestionCondition.fromJson(Map<String, dynamic> json) {
    return QuestionCondition(
      dependsOnQuestionId: json['dependsOn'],
      hasAnswerId: json['hasAnswer'],
    );
  }
  
  Map<String, dynamic> toJson() => {
    'dependsOn': dependsOnQuestionId,
    'hasAnswer': hasAnswerId,
  };
}

class DiagnosticQuestion {
  final String id;
  final String text;
  final String type; // 'single_choice'
  final List<QuestionOption> options;
  final QuestionCondition? condition;

  DiagnosticQuestion({
    required this.id,
    required this.text,
    required this.type,
    required this.options,
    this.condition,
  });

  factory DiagnosticQuestion.fromJson(Map<String, dynamic> json) {
    var opts = (json['options'] as List).map((o) => QuestionOption.fromJson(o)).toList();
    var cond = json['condition'] != null ? QuestionCondition.fromJson(json['condition']) : null;
    return DiagnosticQuestion(
      id: json['id'],
      text: json['text'],
      type: json['type'],
      options: opts,
      condition: cond,
    );
  }
}

class DiagnosticState {
  final Map<String, String> answers = {}; // questionId -> optionId

  void answerQuestion(String questionId, String optionId) {
    answers[questionId] = optionId;
  }
  
  // Reprise du diagnostic
  Map<String, dynamic> toJson() => {'answers': answers};
  void fromJson(Map<String, dynamic> json) {
    final map = json['answers'] as Map<String, dynamic>?;
    if (map != null) {
      map.forEach((k, v) => answers[k] = v.toString());
    }
  }

  HouseholdConfig toHouseholdConfig(List<DiagnosticQuestion> questions) {
    final ownedAssets = <String>{};
    final resourceDurations = <String, Duration>{};

    for (var entry in answers.entries) {
      final q = questions.cast<DiagnosticQuestion?>().firstWhere((q) => q?.id == entry.key, orElse: () => null);
      if (q == null) continue;
      
      final opt = q.options.cast<QuestionOption?>().firstWhere((o) => o?.id == entry.value, orElse: () => null);
      if (opt == null) continue;
      
      for (var fact in opt.facts) {
        if (fact.type == 'add_asset') {
          ownedAssets.add(fact.value);
        } else if (fact.type == 'add_resource_duration' && fact.duration != null) {
          resourceDurations[fact.value] = Duration(hours: fact.duration!);
        }
      }
    }

    return HouseholdConfig(
      ownedAssets: ownedAssets.toList(),
      resourceDurations: resourceDurations,
    );
  }
}

class DiagnosticEngine {
  final List<DiagnosticQuestion> questions;

  DiagnosticEngine(this.questions);

  DiagnosticQuestion? getNextQuestion(DiagnosticState state) {
    for (var q in questions) {
      // Si déjà répondu, on passe
      if (state.answers.containsKey(q.id)) continue;
      
      // Vérifier les conditions
      if (q.condition != null) {
        final cond = q.condition!;
        final previousAnswer = state.answers[cond.dependsOnQuestionId];
        if (previousAnswer != cond.hasAnswerId) {
          continue; // La condition n'est pas remplie, on ignore cette question pour le moment
        }
      }
      
      return q;
    }
    return null; // Plus aucune question
  }
}
