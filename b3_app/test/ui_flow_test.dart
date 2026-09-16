import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:b3_app/app/app.dart';

void main() {
  testWidgets('Parcours complet: Home -> Diagnostic -> Results', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(const B3App());
    await tester.pumpAndSettle();

    expect(find.text('B3 Ready'), findsOneWidget);
    
    final btnStart = find.widgetWithText(FilledButton, 'Commencer mon diagnostic');
    await tester.ensureVisible(btnStart);
    await tester.pumpAndSettle();
    await tester.tap(btnStart);
    await tester.pumpAndSettle();

    // 1. Question chauffage (q_heat_main - multiple_choice)
    expect(find.text('Comment chauffez-vous principalement votre logement ?'), findsOneWidget);
    await tester.tap(find.text('Radiateurs électriques'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // 2. Question redondance (q_heat_redundancy - single_choice)
    expect(find.textContaining('En cas de coupure du système principal'), findsOneWidget);
    await tester.tap(find.text('Oui')); // single choice
    await tester.pumpAndSettle();

    // 3. Question alternative (q_heat_alternative - multiple_choice)
    expect(find.text('Quelle autre solution utilisez-vous ?'), findsOneWidget);
    await tester.tap(find.text('Poêle à bûches (autonome sans électricité)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // 4. Question ressource bois (q_heat_bois_reserve - single_choice)
    expect(find.text("Disposez-vous d'une réserve de bois utilisable ?"), findsOneWidget);
    await tester.tap(find.text('Oui, pour plusieurs jours')); // single choice
    await tester.pumpAndSettle();

    // 5. Question cuisine (q_cook_main - multiple_choice)
    expect(find.text('De quels équipements disposez-vous pour cuisiner ?'), findsOneWidget);
    await tester.tap(find.text('Cuisinière ou réchaud sur bouteille de gaz')); // Independent cooking
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // 6. Question ressource gaz cuisine (q_cook_gaz_reserve - single_choice)
    expect(find.text("Avez-vous une bouteille de gaz de rechange utilisable (actuellement connectée ou en stock) ?"), findsOneWidget);
    await tester.tap(find.text('Oui')); // single choice
    await tester.pumpAndSettle();

    // 7. Question durée gaz cuisine (q_cook_gaz_duration - single_choice)
    expect(find.text("Combien de temps environ pouvez-vous cuisiner avec cette réserve de gaz ?"), findsOneWidget);
    await tester.tap(find.text('Plusieurs jours')); // single choice
    await tester.pumpAndSettle();

    // 8. Question eclairage (q_light_main - multiple_choice)
    expect(find.text("De quoi disposez-vous pour l'éclairage en cas de coupure électrique ?"), findsOneWidget);
    await tester.tap(find.text('Rien de spécifique (luminaires branchés sur secteur)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    
    // We expect it to finish and go to Results Screen
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Résultats
    expect(find.text('Bilan de résilience'), findsOneWidget);
    
    final fullTextStr = tester.allWidgets.whereType<Text>().map((t) => t.data).join(' ');
    // Anti-jargon verification
    expect(fullTextStr.contains('total point >'), false);
    expect(fullTextStr.contains('\${totalPoints'), false);
    expect(fullTextStr.contains('system_'), false);
    expect(fullTextStr.contains('cuisiner_failed'), false);
    expect(fullTextStr.contains('causeNodeIds'), false);
    expect(fullTextStr.contains('B3State.degraded'), false);

    expect(find.textContaining('point de vigilance'), findsOneWidget);

    expect(find.text("S'ÉCLAIRER"), findsOneWidget);

    // Ouvre le détail
    await tester.tap(find.text("Comprendre"));
    await tester.pumpAndSettle();
    
    // Vérifie qu'on est sur le détail
    expect(find.text("Comprendre cette vulnérabilité"), findsOneWidget);
    
    // Ouvre la Dependency Map
    await tester.tap(find.text("Comprendre cette vulnérabilité"));
    await tester.pumpAndSettle();
    
    // Vérifications sur la Dependency Map
    expect(find.text("Dépendances"), findsOneWidget);
    expect(find.text("Panne électrique prolongée"), findsOneWidget);
    expect(find.text("Pourquoi ?"), findsOneWidget);
    
    // Les labels lisibles et pas de jargon
    expect(find.text("S'éclairer"), findsOneWidget); // Capability
    expect(find.text("Lumière (secteur)"), findsOneWidget); // Asset
    expect(find.text("Réseau électrique"), findsOneWidget); // Dependency
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
