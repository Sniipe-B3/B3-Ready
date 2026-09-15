
import 'models.dart';
import 'data_mapper.dart';

class FactRule {
  final String type; // 'add_asset', 'add_resource_duration', 'assess_capability', 'override_capability'
  final String value;
  final int? duration;
  final String? state; // for override_capability

  FactRule({required this.type, required this.value, this.duration, this.state});
  
  factory FactRule.fromJson(Map<String, dynamic> json) {
    return FactRule(
      type: json['type'],
      value: json['value'],
      duration: json['duration'],
      state: json['state'],
    );
  }
  
  Map<String, dynamic> toJson() => {
    'type': type,
    'value': value,
    if (duration != null) 'duration': duration,
    if (state != null) 'state': state,
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
  final String type;
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
  final Map<String, String> answers = {};

  void answerQuestion(String questionId, String optionId) {
    answers[questionId] = optionId;
  }
  
  Map<String, dynamic> toJson() => {'answers': answers};
  void fromJson(Map<String, dynamic> json) {
    final map = json['answers'] as Map<String, dynamic>?;
    if (map != null) {
      map.forEach((k, v) => answers[k] = v.toString());
    }
  }

  HouseholdConfig toHouseholdConfig(List<DiagnosticQuestion> questions) {
    final ownedAssets = <String>{};
    final ownedResources = <String>{};
    final assessedResources = <String>{};
    final resourceDurations = <String, Duration>{};
    final assessedCapabilities = <String>{};
    final capabilityOverrides = <String, B3State>{};

    for (var entry in answers.entries) {
      final q = questions.cast<DiagnosticQuestion?>().firstWhere((q) => q?.id == entry.key, orElse: () => null);
      if (q == null) continue;
      
      final opt = q.options.cast<QuestionOption?>().firstWhere((o) => o?.id == entry.value, orElse: () => null);
      if (opt == null) continue;
      
      for (var fact in opt.facts) {
        if (fact.type == 'add_resource') {
          ownedResources.add(fact.value);
        } else if (fact.type == 'assess_resource') {
          assessedResources.add(fact.value);
        } else if (fact.type == 'add_asset') {
          ownedAssets.add(fact.value);
        } else if (fact.type == 'add_resource_duration' && fact.duration != null) {
          resourceDurations[fact.value] = Duration(hours: fact.duration!);
        } else if (fact.type == 'assess_capability') {
          assessedCapabilities.add(fact.value);
        } else if (fact.type == 'override_capability' && fact.state != null) {
          if (fact.state == 'unknown') capabilityOverrides[fact.value] = B3State.unknown;
          if (fact.state == 'failed') capabilityOverrides[fact.value] = B3State.failed;
        }
      }
    }

    return HouseholdConfig(
      ownedAssets: ownedAssets.toList(),
      ownedResources: ownedResources.toList(),
      assessedResources: assessedResources,
      resourceDurations: resourceDurations,
      assessedCapabilities: assessedCapabilities,
      capabilityOverrides: capabilityOverrides,
    );
  }
}

class DiagnosticEngine {
  final List<DiagnosticQuestion> questions;

  DiagnosticEngine(this.questions);

  DiagnosticQuestion? getNextQuestion(DiagnosticState state) {
    for (var q in questions) {
      if (state.answers.containsKey(q.id)) continue;
      if (q.condition != null) {
        final cond = q.condition!;
        final previousAnswer = state.answers[cond.dependsOnQuestionId];
        if (previousAnswer != cond.hasAnswerId) continue;
      }
      return q;
    }
    return null;
  }
}
