import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:b3_app/app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Parcours complet: Home -> Diagnostic -> Results', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 5000);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(const B3App());
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();

    expect(find.text('B3 Ready'), findsOneWidget);
    
    final btnStart = find.widgetWithText(FilledButton, 'Commencer mon diagnostic');
    await tester.ensureVisible(btnStart);
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();
    await tester.tap(btnStart);
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();

    // 1. Question chauffage (q_heat_main - multiple_choice)
    expect(find.text('Comment chauffez-vous principalement votre logement ?'), findsOneWidget);
    await tester.tap(find.text('Radiateurs électriques'));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();

    // 2. Question redondance (q_heat_redundancy - single_choice)
    expect(find.textContaining('En cas de coupure du système principal'), findsOneWidget);
    await tester.tap(find.text('Oui')); // single choice
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();

    // 3. Question alternative (q_heat_alternative - multiple_choice)
    expect(find.text('Quelle autre solution utilisez-vous ?'), findsOneWidget);
    await tester.tap(find.text('Poêle à bûches (autonome sans électricité)'));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();

    // 4. Question ressource bois (q_heat_bois_reserve - single_choice)
    expect(find.text("Disposez-vous d'une réserve de bois utilisable ?"), findsOneWidget);
    await tester.tap(find.text('Je ne sais pas')); // single choice
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();

    // 5. Question cuisine (q_cook_main - multiple_choice)
    expect(find.text('De quels équipements disposez-vous pour cuisiner ?'), findsOneWidget);
    await tester.tap(find.text('Cuisinière sur bouteille de gaz')); // Independent cooking
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();

    // 6. Question ressource gaz cuisine (q_cook_gaz_reserve - single_choice)
    expect(find.text("Avez-vous une bouteille de gaz de rechange utilisable (actuellement connectée ou en stock) ?"), findsOneWidget);
    await tester.tap(find.text('Oui')); // single choice
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();

    // 7. Question durée gaz cuisine (q_cook_gaz_duration - single_choice)
    expect(find.text("Combien de temps environ pouvez-vous cuisiner avec cette réserve de gaz ?"), findsOneWidget);
    await tester.tap(find.text('Plusieurs jours')); // single choice
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();

    // 8. Question eclairage (q_light_main - multiple_choice)
    expect(find.text("De quoi disposez-vous pour l'éclairage en cas de coupure électrique ?"), findsOneWidget);
    await tester.tap(find.text('Rien de spécifique (luminaires branchés sur secteur)'));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();

    // 9. Question water (q_water_main)
    expect(find.text("Comment accédez-vous à l'eau courante ?"), findsOneWidget);
    await tester.tap(find.text('Eau du réseau public'));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();
    
    // 10. Question comms
    expect(find.text("Quels moyens de communication utilisez-vous ?"), findsOneWidget);
    await tester.tap(find.text('Box Internet fixe'));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // Drain all remaining questions
    while (find.text('Résilience par scénario').evaluate().isEmpty) {
       if (find.text('Continuer').evaluate().isNotEmpty) {
          await tester.tap(find.text('Continuer').first);
       } else if (find.text('Oui').evaluate().isNotEmpty) {
          await tester.tap(find.text('Oui').first);
       } else if (find.textContaining('Non').evaluate().isNotEmpty) {
          await tester.tap(find.textContaining('Non').first);
       } else if (find.text('Je ne sais pas').evaluate().isNotEmpty) {
          await tester.tap(find.text('Je ne sais pas').first);
       } else {
          break;
       }
       await tester.pump(); await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();

    // Résultats
    expect(find.text('Résilience par scénario'), findsOneWidget);
    expect(find.textContaining('Panne électrique'), findsOneWidget);

    final voirBtn = find.text('Voir').first;
    await tester.ensureVisible(voirBtn);
    await tester.tap(voirBtn);
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();

    expect(find.text('Panne électrique prolongée'), findsOneWidget);
    
    final fullTextStr = tester.allWidgets.whereType<Text>().map((t) => t.data).join(' ');
    // Anti-jargon verification
    expect(fullTextStr.contains('total point >'), false);
    expect(fullTextStr.contains('\${totalPoints'), false);
    expect(fullTextStr.contains('system_'), false);
    expect(fullTextStr.contains('cuisiner_failed'), false);
    expect(fullTextStr.contains('causeNodeIds'), false);
    expect(fullTextStr.contains('B3State.degraded'), false);

    expect(find.textContaining('vigilance'), findsOneWidget);

    expect(find.text("S'ÉCLAIRER"), findsOneWidget);

    // Ouvre le plan d'action
    final btnActionPlan = find.text("Voir mon plan d'action");
    await tester.ensureVisible(btnActionPlan);
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();
    await tester.tap(btnActionPlan);
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();
    
    // Vérifie qu'on est sur le plan d'action
    expect(find.text("Mon plan d'action"), findsWidgets);
    expect(find.textContaining('actions prioritaires'), findsOneWidget);
    
    // Vérifie les priorités traduites (pas d'enums)
    expect(find.text('ESSENTIEL'), findsWidgets);
    
    // Anti-jargon plan
    final planStr = tester.allWidgets.whereType<Text>().map((t) => t.data).join(' ');
    expect(planStr.contains('RecommendationType'), false);
    expect(planStr.contains('ActionPriority'), false);
    expect(planStr.contains('causeNodeIds'), false);
    expect(planStr.contains('targetAssetId'), false);
    
    // Ouvre la Dependency Map depuis une action
    final btnComprendre = find.text("Comprendre pourquoi").first;
    await tester.ensureVisible(btnComprendre);
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();
    await tester.tap(btnComprendre);
    await tester.pump(); await tester.pump(const Duration(milliseconds: 100)); await tester.pumpAndSettle();
    
    // Vérifications sur la Dependency Map
    expect(find.text("Dépendances"), findsOneWidget);
    expect(find.text("Panne électrique prolongée"), findsOneWidget);
    
    // Les labels lisibles et pas de jargon
    expect(find.text("S'éclairer"), findsOneWidget); // Capability
    expect(find.text("Lampe sur secteur"), findsOneWidget); // Asset
    expect(find.text("Réseau Électrique"), findsOneWidget); // Dependency
    expect(find.text("Indisponible"), findsWidgets); // B3State traduit
    
    // Anti-jargon map
    final mapStr = tester.allWidgets.whereType<Text>().map((t) => t.data).join(' ');
    expect(mapStr.contains('elec'), false);
    expect(mapStr.contains('eclairage'), false);
    expect(mapStr.contains('lampe_secteur'), false);
    
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
