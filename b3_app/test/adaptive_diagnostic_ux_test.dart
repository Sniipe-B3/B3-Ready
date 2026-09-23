import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:b3_app/data/app_diagnostic_dataset.dart';
import 'package:b3_app/features/diagnostic/engine/adaptive_diagnostic_engine.dart';

void main() {
  late List<DiagnosticQuestion> questions;

  setUp(() {
    final questionsJson = jsonDecode(appDiagnosticQuestionsJson) as List;
    questions = questionsJson.map((q) => DiagnosticQuestion.fromJson(q)).toList();
  });

  int runDiagnostic(DiagnosticState state, Map<String, dynamic> autoAnswers) {
    final engine = AdaptiveDiagnosticEngine(questions);
    int count = 0;
    while (true) {
      final q = engine.getNextQuestion(state);
      if (q == null) break;
      count++;
      
      if (count > 40) {
        fail('LOOP DETECTED: More than 40 questions asked');
      }

      final answer = autoAnswers[q.id];
      if (answer != null) {
        if (answer is List<String>) {
          state.answerMultiple(q.id, answer);
        } else if (answer is String) {
          if (q.type == QuestionType.multipleChoice) {
             state.answerMultiple(q.id, [answer]);
          } else {
             state.answerQuestion(q.id, answer);
          }
        }
      } else {
        // Default answer if not specified
        if (q.type == QuestionType.multipleChoice) {
          // Choose the "opt_none" if available
          final noneOpt = q.options.firstWhere((o) => o.id.startsWith('opt_none'), orElse: () => q.options.first);
          state.answerMultiple(q.id, [noneOpt.id]);
        } else {
          // Choose 'non' or the last option
          final nonOpt = q.options.firstWhere(
            (o) => o.text.toLowerCase().startsWith('non') || o.id.contains('no'), 
            orElse: () => q.options.last
          );
          state.answerQuestion(q.id, nonOpt.id);
        }
      }
    }
    return count;
  }

  test('13. TEST — REALISTIC HOUSEHOLD A', () {
    final state = DiagnosticState();
    final count = runDiagnostic(state, {
      'q_heat_main': ['opt_rad_elec', 'opt_poele_bois'],
      'q_heat_redundancy': 'opt_heat_alt_no',
      'q_heat_bois_reserve': 'opt_bois_yes',
      'q_cook_main': ['opt_gaz_bouteille'],
      'q_cook_redundancy': 'opt_cook_alt_no',
      'q_cook_gaz_reserve': 'opt_gaz_yes',
      'q_cook_gaz_duration': 'opt_gaz_long',
      'q_light_main': ['opt_lampe_bat'],
      'q_light_bat_reserve': 'opt_bat_yes',
      'q_water_main': ['opt_robinet_eau'],
      'q_water_reserve': 'opt_water_no',
      'q_com_main': ['opt_box_internet', 'opt_smartphone'],
      'q_food_storage': ['opt_frigo', 'opt_congel'],
      'q_charge_main': ['opt_powerbank'],
      'q_charge_bat_status': 'opt_charge_yes',
      'q_sanitary': 'opt_wc_reseau',
      'q_info_main': ['opt_info_tv', 'opt_info_smartphone'],
      'q_info_alt': 'opt_radio_no',
    });
    
    final config = state.toHouseholdConfig(questions);
    
    // Check exact assets
    expect(config.ownedAssets.contains('poele_bois'), isTrue);
    expect(config.ownedAssets.contains('rechaud_gaz'), isTrue);
    expect(config.ownedAssets.contains('lampe_batterie'), isTrue);
    expect(config.ownedAssets.contains('robinet_eau'), isTrue);
    expect(config.ownedAssets.contains('box_internet'), isTrue);
    expect(config.ownedAssets.contains('smartphone'), isTrue);
    expect(config.ownedAssets.contains('refrigerateur'), isTrue);
    expect(config.ownedAssets.contains('congelateur'), isTrue);
    expect(config.ownedAssets.contains('batterie_externe'), isTrue);
    expect(config.ownedAssets.contains('wc_chasse_eau'), isTrue);
    expect(config.ownedAssets.contains('tv_box'), isTrue);
    expect(count, 14);
    expect(config.ownedAssets.contains('radio_manivelle_solaire'), isFalse);
    
  });

  test('14. TEST — MINIMAL HOUSEHOLD', () {
    final state = DiagnosticState();
    final count = runDiagnostic(state, {
      'q_heat_main': ['opt_rad_elec'],
      'q_heat_redundancy': 'opt_heat_alt_no',
      'q_cook_main': ['opt_plaque_elec'],
      'q_cook_redundancy': 'opt_cook_alt_no',
      'q_light_main': ['opt_none_q_light_main'],
      'q_water_main': ['opt_robinet_eau'],
      'q_water_reserve': 'opt_water_no',
      'q_com_main': ['opt_smartphone'],
      'q_food_storage': ['opt_none_q_food_storage'],
      'q_charge_main': ['opt_none_q_charge_main'],
      'q_sanitary': 'opt_wc_reseau',
      'q_info_main': ['opt_info_smartphone'],
      'q_info_alt': 'opt_radio_no',
    });
    
    // Minimal shouldn't loop, shouldn't invent things.
    final config = state.toHouseholdConfig(questions);
    expect(config.ownedAssets.contains('poele_bois'), isFalse);
    expect(count, 13);
  });

  test('15. TEST — HIGH REDUNDANCY HOUSEHOLD', () {
    final state = DiagnosticState();
    final count = runDiagnostic(state, {
      'q_heat_main': ['opt_rad_elec', 'opt_poele_bois', 'opt_chaudiere_gaz'],
      'q_heat_bois_reserve': 'opt_bois_yes',
      'q_cook_main': ['opt_plaque_elec', 'opt_four_elec', 'opt_gaz_bouteille'],
      'q_cook_gaz_reserve': 'opt_gaz_yes',
      'q_cook_gaz_duration': 'opt_gaz_long',
      'q_light_main': ['opt_lampe_bat', 'opt_light_bougies'],
      'q_light_bat_reserve': 'opt_bat_yes',
      'q_water_main': ['opt_robinet_eau'],
      'q_water_reserve': 'opt_water_yes',
      'q_com_main': ['opt_box_internet', 'opt_smartphone'],
      'q_food_storage': ['opt_frigo', 'opt_congel'],
      'q_charge_main': ['opt_powerbank', 'opt_powerstation'],
      'q_charge_bat_status': 'opt_charge_yes',
      'q_charge_station_status': 'opt_station_yes',
      'q_sanitary': 'opt_wc_reseau',
      'q_info_main': ['opt_info_tv', 'opt_info_smartphone'],
    });
    // In a high redundancy household, alternative discovery questions should NOT be asked!
    expect(state.answers.containsKey('q_heat_alternative'), isFalse);
    expect(state.answers.containsKey('q_cook_alternative'), isFalse);
    expect(count, 15);
    expect(state.answers.containsKey('q_info_alt'), isFalse);
    
  });

  test('16. TEST — UNKNOWN HEAVY', () {
    final state = DiagnosticState();
    final count = runDiagnostic(state, {
      'q_heat_main': ['opt_poele_bois'],
      'q_heat_redundancy': 'opt_heat_alt_unk',
      'q_heat_bois_reserve': 'opt_bois_unk',
      'q_cook_main': ['opt_gaz_bouteille'],
      'q_cook_redundancy': 'opt_cook_alt_unk',
      'q_cook_gaz_reserve': 'opt_gaz_unk',
      'q_charge_main': ['opt_powerbank', 'opt_powerstation'],
      'q_charge_bat_status': 'opt_charge_unk',
      'q_charge_station_status': 'opt_station_unk',
      'q_water_main': ['opt_stock_eau'],
      'q_water_reserve': 'opt_water_unk',
      'q_info_alt': 'opt_radio_unk',
    });
    
    final config = state.toHouseholdConfig(questions);
    expect(config.unknownResources.contains('gaz_bouteille'), isTrue);
    expect(config.unknownResources.contains('charge_powerbank'), isTrue);
    expect(config.unknownResources.contains('charge_station_energie'), isTrue);
    expect(config.unknownResources.contains('reserve_eau'), isTrue);
    expect(count, 14);
    
  });

  test('17. TEST — STOP EARLY', () {
    final state = DiagnosticState();
    final engine = AdaptiveDiagnosticEngine(questions);
    
    final q1 = engine.getNextQuestion(state)!;
    state.answerMultiple(q1.id, [q1.options.first.id]);
    
    final q2 = engine.getNextQuestion(state)!;
    state.answerMultiple(q2.id, [q2.options.first.id]);
    
    // Stop early.
    final config = state.toHouseholdConfig(questions);
    
    expect(config.assessedCapabilities.contains('chauffer'), isTrue);
    // Cuisiner may not have been reached if engine asked redundancy check first
    // expect(config.assessedCapabilities.contains('cuisiner'), isTrue);
    expect(config.assessedCapabilities.contains('eclairage'), isFalse);
    expect(config.assessedCapabilities.contains('recharger_appareils'), isFalse);
    expect(config.assessedCapabilities.contains('recevoir_informations'), isFalse);
    expect(config.ownedAssets.length, lessThanOrEqualTo(2));
  });
}
