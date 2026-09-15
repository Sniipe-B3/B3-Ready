import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:b3_app/app/app.dart';

void main() {
  testWidgets('Parcours complet: Home -> Diagnostic -> Results',
      (WidgetTester tester) async {
    // 1. Démarrer l'application (viewport plus haut pour ne pas avoir à scroller tout le temps)
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(const B3App());
    await tester.pumpAndSettle();

    // Vérifier qu'on est sur la Home
    expect(find.text('B3 Ready'), findsOneWidget);
    
    final btnStart = find.widgetWithText(FilledButton, 'Commencer mon diagnostic');
    await tester.ensureVisible(btnStart);
    await tester.pumpAndSettle();

    // 2. Cliquer sur commencer
    await tester.tap(btnStart);
    await tester.pumpAndSettle();

    // 3. Question 1: Cuisine (multiple_choice)
    expect(find.text('Comment pouvez-vous cuisiner actuellement ?'), findsOneWidget);
    await tester.tap(find.text('Plaque électrique')); // Select checkbox
    await tester.pumpAndSettle();
    
    // Test backward navigation (Optionnel)
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Commencer mon diagnostic'), findsOneWidget); // Retour à la home
    
    // Re-rentrer
    await tester.tap(btnStart);
    await tester.pumpAndSettle();
    
    // Re-selectionner
    await tester.tap(find.text('Plaque électrique'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer')); // C'est un multiple_choice
    await tester.pumpAndSettle();

    // 4. Question: Chauffage (multiple_choice)
    expect(find.text('Comment chauffez-vous votre logement ?'), findsOneWidget);
    await tester.tap(find.text('Radiateurs / pompe à chaleur électrique'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // 5. Question: Éclairage (multiple_choice)
    expect(find.text("De quoi disposez-vous pour l'éclairage de nuit ?"), findsOneWidget);
    await tester.tap(find.text('Luminaires classiques (branchés sur secteur)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    
    // Le diagnostic charge les résultats (async 800ms)
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // 6. Résultats
    expect(find.text('Bilan de résilience'), findsOneWidget);
    
    // Vérifier l'absence de jargon technique
    expect(find.text('cuisiner'), findsNothing); // Tout est formaté CUISINER
    expect(find.text('system_elec'), findsNothing);

    expect(find.text('CUISINER'), findsOneWidget);
    expect(find.text('SE CHAUFFER'), findsOneWidget);

    // 7. Ouvrir un détail
    await tester.ensureVisible(find.text('Comprendre').first);
    await tester.tap(find.text('Comprendre').first);
    await tester.pumpAndSettle();

    // Vérifier l'écran de détail
    expect(find.text('Pourquoi ?'), findsOneWidget);
    expect(find.text('Ce que cela signifie'), findsOneWidget);
    
    // Revenir
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    
    expect(find.text('Bilan de résilience'), findsOneWidget);
    
    // reset
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
