import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:b3_app/features/home/screens/home_screen.dart';
import 'package:b3_app/features/diagnostic/screens/diagnostic_screen.dart';
import 'package:b3_app/data/app_diagnostic_dataset.dart';
import 'package:b3_app/data/household_repository.dart';
import 'package:b3_app/data/household_snapshot.dart';
import 'package:b3_engine/b3_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

DiagnosticEngine _buildEngine() {
  final List<dynamic> jsonList = jsonDecode(appDiagnosticQuestionsJson);
  final questions = jsonList.map((e) => DiagnosticQuestion.fromJson(e)).toList();
  return DiagnosticEngine(questions);
}

Future<void> answerQuestionById(WidgetTester tester, DiagnosticEngine engine, String questionId, List<String> optionIds) async {
  final question = engine.questions.firstWhere((q) => q.id == questionId);
  expect(find.text(question.text), findsWidgets);

  for (final optionId in optionIds) {
    final option = question.options.firstWhere((o) => o.id == optionId);
    final btn = find.text(option.text).first;
    await tester.ensureVisible(btn);
    await tester.tap(btn);
    await tester.pumpAndSettle();
  }

  if (question.type == QuestionType.multipleChoice) {
    final btnCont = find.text('Continuer').first;
    await tester.ensureVisible(btnCont);
    await tester.tap(btnCont);
    await tester.pumpAndSettle();
  }
}

void main() {
  final engine = _buildEngine();
  
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Diagnostic E2E - Explicit routing', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400); tester.view.devicePixelRatio = 1.0; addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
    final repo = SharedPrefsHouseholdRepository();
    await tester.pumpWidget(MaterialApp(home: HomeScreen(repository: repo)));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Commencer mon diagnostic'));
    await tester.tap(find.text('Commencer mon diagnostic'));
    await tester.pumpAndSettle();

    await answerQuestionById(tester, engine, 'q_heat_main', ['opt_rad_elec']);
    await answerQuestionById(tester, engine, 'q_heat_redundancy', ['opt_heat_alt_no']);
    await answerQuestionById(tester, engine, 'q_cook_main', ['opt_four_elec', 'opt_plaque_elec']);
    await answerQuestionById(tester, engine, 'q_cook_redundancy', ['opt_cook_alt_no']);
    await answerQuestionById(tester, engine, 'q_light_main', ['opt_lampe_secteur']);
    await answerQuestionById(tester, engine, 'q_water_main', ['opt_robinet_eau']);
    await answerQuestionById(tester, engine, 'q_com_main', ['opt_box_internet', 'opt_smartphone']);
    await answerQuestionById(tester, engine, 'q_light_bat_reserve', ['opt_bat_unk']);
    await answerQuestionById(tester, engine, 'q_food_storage', ['opt_frigo']);
    await answerQuestionById(tester, engine, 'q_charge_main', ['opt_none_q_charge_main']);
    await answerQuestionById(tester, engine, 'q_sanitary', ['opt_wc_reseau']);
    await answerQuestionById(tester, engine, 'q_info_main', ['opt_info_tv', 'opt_info_smartphone']);
    await answerQuestionById(tester, engine, 'q_payment_main', ['opt_pay_elec']);

    await tester.ensureVisible(find.text('Continuer'));
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(find.text('Vue globale du foyer').last, findsWidgets);
    
    // Tap "Analyser ce scénario" which creates ResilienceSession and triggers autosave
    await tester.ensureVisible(find.text('Analyser ce scénario').first);
    await tester.tap(find.text('Analyser ce scénario').first);
    await tester.pumpAndSettle();
    expect(find.text('Panne électrique prolongée'), findsOneWidget);
    
    // Wait for the async save
    for(int i=0; i<5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    
    final snap = await repo.load();
    expect(snap, isNotNull);
    expect(snap!.config.ownedAssets.contains('radiateur_elec'), isTrue);
  });

  testWidgets('Action E2E - Structural update', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400); tester.view.devicePixelRatio = 1.0; addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
    final repo = SharedPrefsHouseholdRepository();
    final config = HouseholdConfig(ownedAssets: ['radiateur_elec'], ownedResources: [], resourceDurations: {});
    await repo.save(HouseholdSnapshot(schemaVersion: 1, config: config, completedActionIds: [], scenarioId: 'panne_elec'));
    
    await tester.pumpWidget(MaterialApp(home: HomeScreen(repository: repo)));
    await tester.pumpAndSettle();
    
    await tester.ensureVisible(find.text('Reprendre mon analyse'));
    await tester.tap(find.text('Reprendre mon analyse'));
    await tester.pumpAndSettle();
    
    await tester.ensureVisible(find.text("Voir mon plan d'action"));
    await tester.tap(find.text("Voir mon plan d'action"));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text("Voir comment faire").first);
    await tester.tap(find.text("Voir comment faire").first);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();
    
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    
    expect(find.text("Voir mon nouveau plan"), findsOneWidget);
    await tester.tap(find.text("Voir mon nouveau plan"));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(milliseconds: 500));
    final snap = await repo.load();
    expect(snap!.scenarioId, 'panne_elec');
    expect(snap.completedActionIds.isNotEmpty || snap.config.ownedAssets.length > 1, isTrue);
  });

  testWidgets('Completion E2E - STRICT', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400); tester.view.devicePixelRatio = 1.0; addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
    final repo = SharedPrefsHouseholdRepository();
    final config = HouseholdConfig(ownedAssets: [], ownedResources: [], resourceDurations: {});
    final initialConfig = config.clone();
    
    await repo.save(HouseholdSnapshot(schemaVersion: 1, config: config, completedActionIds: [], scenarioId: 'panne_elec'));
    
    await tester.pumpWidget(MaterialApp(home: HomeScreen(repository: repo)));
    await tester.pumpAndSettle();
    
    await tester.ensureVisible(find.text('Reprendre mon analyse'));
    await tester.tap(find.text('Reprendre mon analyse'));
    await tester.pumpAndSettle();
    
    await tester.tap(find.text("Voir mon plan d'action"));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text("Voir comment faire").last);
    await tester.tap(find.text("Voir comment faire").last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();
    
    if (find.byType(ListTile).evaluate().isNotEmpty) {
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();
    }
    
    expect(find.text("Voir mon nouveau plan"), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    final snap = await repo.load();
    
    expect(snap!.completedActionIds.isNotEmpty, isTrue);
    expect(snap.config.ownedAssets, equals(initialConfig.ownedAssets));
    expect(snap.config.ownedResources, equals(initialConfig.ownedResources));
    expect(snap.config.assessedResources, equals(initialConfig.assessedResources));
    expect(snap.config.unknownResources, equals(initialConfig.unknownResources));
    expect(snap.config.resourceDurations, equals(initialConfig.resourceDurations));
    expect(snap.config.assessedCapabilities, equals(initialConfig.assessedCapabilities));
    expect(snap.config.capabilityOverrides, equals(initialConfig.capabilityOverrides));
  });

  testWidgets('Back Navigation E2E', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400); tester.view.devicePixelRatio = 1.0; addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
    final repo = SharedPrefsHouseholdRepository();
    final config = HouseholdConfig(ownedAssets: [], ownedResources: [], resourceDurations: {});
    await repo.save(HouseholdSnapshot(schemaVersion: 1, config: config, completedActionIds: [], scenarioId: 'panne_elec'));
    
    await tester.pumpWidget(MaterialApp(home: HomeScreen(repository: repo)));
    await tester.pumpAndSettle();
    
    await tester.ensureVisible(find.text('Vue globale du foyer').last);
    await tester.tap(find.text('Vue globale du foyer').last);
    await tester.pumpAndSettle();
    expect(find.text('Vue globale du foyer').last, findsWidgets);
    
    await tester.ensureVisible(find.text('Analyser ce scénario').first);
    await tester.tap(find.text('Analyser ce scénario').first);
    await tester.pumpAndSettle();
    expect(find.text('Panne électrique prolongée'), findsOneWidget);

    await tester.ensureVisible(find.text("Voir mon plan d'action"));
    await tester.tap(find.text("Voir mon plan d'action"));
    await tester.pumpAndSettle();
    expect(find.text("Mon plan d'action"), findsWidgets);

    await tester.ensureVisible(find.text("Voir comment faire").first);
    await tester.tap(find.text("Voir comment faire").first);
    await tester.pumpAndSettle();
    
    await tester.tap(find.byTooltip('Back').first);
    await tester.pumpAndSettle();
    expect(find.text("Mon plan d'action"), findsWidgets);

    await tester.tap(find.byTooltip('Back').first);
    await tester.pumpAndSettle();
    expect(find.text('Panne électrique prolongée'), findsOneWidget);
    
    await tester.tap(find.byTooltip('Back').first);
    await tester.pumpAndSettle();
    expect(find.text('Vue globale du foyer').last, findsWidgets);
  });

  testWidgets('UNKNOWN UI and NOT_ASSESSED UI rendering', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400); tester.view.devicePixelRatio = 1.0; addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
    final repo = SharedPrefsHouseholdRepository();
    final config = HouseholdConfig(
      ownedAssets: ['poele_bois', 'lampe_batterie', 'lampe_secteur', 'radiateur_elec'],
      ownedResources: ['batterie'],
      assessedResources: {'batterie'},
      unknownResources: {'batterie'},
      resourceDurations: {},
      assessedCapabilities: {'eclairage'}, 
    );
    await repo.save(HouseholdSnapshot(schemaVersion: 1, config: config, completedActionIds: [], scenarioId: 'panne_elec'));
    
    await tester.pumpWidget(MaterialApp(home: HomeScreen(repository: repo)));
    await tester.pumpAndSettle();
    
    await tester.tap(find.text('Vue globale du foyer').last);
    await tester.pumpAndSettle();
    
    await tester.ensureVisible(find.text('Vue globale du foyer').last);
    await tester.tap(find.text('Vue globale du foyer').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Voir le détail').first);
    await tester.tap(find.text('Voir le détail').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('À vérifier'), findsWidgets);
    expect(find.textContaining('Non évalué'), findsWidgets);
    expect(find.text('UNKNOWN'), findsNothing);
    expect(find.text('NOT_ASSESSED'), findsNothing);
  });

  testWidgets('Empty Action Plan and Anti-Jargon', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400); tester.view.devicePixelRatio = 1.0; addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
    final repo = SharedPrefsHouseholdRepository();
    
    final config = HouseholdConfig(
      ownedAssets: [
        'especes_disponibles', 'plaque_elec', 'radiateur_elec', 'lampe_secteur', 
        'robinet_eau', 'refrigerateur', 'box_internet', 'smartphone', 
        'batterie_externe', 'wc_chasse_eau', 'tv_box'
      ],
      ownedResources: ['charge_powerbank', 'batterie'],
      assessedResources: {'charge_powerbank', 'batterie'},
      resourceDurations: {'charge_powerbank': const Duration(hours: 72), 'batterie': const Duration(hours: 72)},
      assessedCapabilities: {
        'effectuer_paiement_essentiel', 'cuisiner', 'chauffer', 'eclairage', 
        'boire_eau_potable', 'conserver_aliments', 'disposer_eau', 'acceder_internet', 
        'communiquer', 'recharger_appareils', 'utiliser_sanitaires', 'recevoir_informations'
      },
    );
    await repo.save(HouseholdSnapshot(schemaVersion: 1, config: config, completedActionIds: [], scenarioId: 'panne_paiement'));
    
    await tester.pumpWidget(MaterialApp(home: HomeScreen(repository: repo)));
    await tester.pumpAndSettle();
    
    await tester.ensureVisible(find.text('Reprendre mon analyse'));
    await tester.tap(find.text('Reprendre mon analyse'));
    await tester.pumpAndSettle();
    
    final str1 = tester.allWidgets.whereType<Text>().map((t) => t.data).join(' ');
    expect(str1.contains('maintained'), isFalse);
    expect(str1.contains('degraded'), isFalse);
    expect(str1.contains('unknown'), isFalse);
    expect(str1.contains('notAssessed'), isFalse);
    expect(str1.contains('failed'), isFalse);

    await tester.ensureVisible(find.text("Voir mon plan d'action"));
    await tester.tap(find.text("Voir mon plan d'action"));
    await tester.pumpAndSettle();

    expect(find.textContaining("Aucune action prioritaire identifiée"), findsOneWidget);
  });

  testWidgets('Responsive Widths on Inner Screens', (WidgetTester tester) async {
    final widths = [320.0, 360.0, 390.0, 430.0];
    
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final w in widths) {
      tester.view.physicalSize = Size(w, 2400);
      tester.view.devicePixelRatio = 1.0;
      
      final repo = SharedPrefsHouseholdRepository();
      final config = HouseholdConfig(ownedAssets: [], ownedResources: [], resourceDurations: {});
      await repo.save(HouseholdSnapshot(schemaVersion: 1, config: config, completedActionIds: [], scenarioId: 'panne_elec'));
      
      if (w == 320.0) {
        await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: const DiagnosticScreen()));
        await tester.pumpAndSettle();
        expect(find.textContaining('Comment chauffez-vous principalement votre logement ?'), findsWidgets);
        expect(tester.takeException(), isNull);
      }
      
      await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: HomeScreen(repository: repo)));
      await tester.pumpAndSettle();
      
      await tester.ensureVisible(find.text('Reprendre mon analyse'));
      await tester.tap(find.text('Reprendre mon analyse'));
      await tester.pumpAndSettle();
      
      await tester.ensureVisible(find.text("Voir mon plan d'action"));
      await tester.tap(find.text("Voir mon plan d'action"));
      await tester.pumpAndSettle();
      
      await tester.ensureVisible(find.text("Voir comment faire").first);
      await tester.tap(find.text("Voir comment faire").first);
      await tester.pumpAndSettle();
      
      expect(tester.takeException(), isNull);
    }
  });
}
